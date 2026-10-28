--!strict
-- Hit feedback on enemies: spark bursts on hits, a puff when one dies (a gold burst and a flash of
-- light for elites and bosses), and floating damage numbers. Bursts come from client/Particles;
-- damage numbers come from a fixed pool. Caps live in Config.Effects.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CurrentArena = require(script.Parent.CurrentArena)
local EnemyRenderer = require(script.Parent.EnemyRenderer)
local Particles = require(script.Parent.Particles)
local Config = require(ReplicatedStorage.Shared.Config.Effects)
local EnemiesConfig = require(ReplicatedStorage.Shared.Config.Enemies)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local NUMBER_COLOR = Color3.fromRGB(255, 255, 255)
local BIG_NUMBER_COLOR = Color3.fromRGB(255, 215, 70)
local NUMBER_HEIGHT = 4 -- studs above the floor, plus the enemy's size
local NUMBER_SIZE = 22
local BIG_NUMBER_SIZE = 30

type Number = {
	attachment: Attachment,
	gui: BillboardGui,
	label: TextLabel,
	enemyId: number,
	amount: number,
	startedAt: number, -- os.clock time
	big: boolean,
}

local random = Random.new()
-- Holds every damage number's attachment and billboard. (Not in PlayerGui: it's cleared of
-- everything but ScreenGuis when the character respawns.)
local anchor: Part = nil :: any
local ELITE_FLASH_COLOR = Color3.fromRGB(255, 220, 120)
local freeNumbers: { Number } = {}
local activeNumbers: { Number } = {}
local started = false

local HitEffects = {}

-- An enemy's size, for placing effects on it.
local function radiusOf(kind: string?, elite: boolean): number
	local def = kind and EnemiesConfig.TYPES[kind]
	local radius = if def then def.radius else 1.5
	return if elite then radius * EnemiesConfig.ELITE.scale else radius
end

local function newNumber(): Number
	local attachment = Instance.new("Attachment")
	attachment.Name = "DamageNumber"
	attachment.Parent = anchor
	local gui = Instance.new("BillboardGui")
	gui.Name = "DamageNumber"
	gui.Size = UDim2.fromOffset(90, 36)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Adornee = attachment
	gui.Enabled = false
	gui.Parent = anchor
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextStrokeTransparency = 0.2
	label.TextStrokeColor3 = Color3.fromRGB(30, 20, 20)
	label.Parent = gui
	return {
		attachment = attachment,
		gui = gui,
		label = label,
		enemyId = 0,
		amount = 0,
		startedAt = 0,
		big = false,
	}
end

local function setAmount(number: Number, amount: number)
	number.amount = amount
	number.big = amount >= Config.BIG_HIT
	number.label.Text = tostring(math.round(amount))
	number.label.TextColor3 = if number.big then BIG_NUMBER_COLOR else NUMBER_COLOR
end

local function release(index: number)
	local number = table.remove(activeNumbers, index) :: Number
	number.gui.Enabled = false
	table.insert(freeNumbers, number)
end

local function showNumber(id: number, amount: number, position: Vector3, radius: number)
	local now = os.clock()
	-- Merge into a recent number on the same enemy.
	for _, number in activeNumbers do
		if number.enemyId == id and now - number.startedAt < Config.NUMBER_MERGE_TIME then
			setAmount(number, number.amount + amount)
			number.startedAt = now
			return
		end
	end
	local number = table.remove(freeNumbers)
	if not number then
		if amount < Config.NUMBER_STEAL_MIN or #activeNumbers == 0 then
			return
		end
		release(1) -- the oldest
		number = table.remove(freeNumbers) :: Number
	end
	number.enemyId = id
	number.startedAt = now
	setAmount(number, amount)
	number.attachment.WorldPosition = position
		+ Vector3.new(random:NextNumber(-1, 1), NUMBER_HEIGHT + radius, random:NextNumber(-1, 1))
	number.gui.StudsOffsetWorldSpace = Vector3.zero
	number.gui.Enabled = true
	table.insert(activeNumbers, number)
end

local function onHit(list: any)
	if typeof(list) ~= "table" then
		return
	end
	local sparked = 0
	for index = 1, #list - 1, 2 do
		local id, amount = list[index], list[index + 1]
		if typeof(id) ~= "number" or typeof(amount) ~= "number" or amount <= 0 then
			continue
		end
		local position = EnemyRenderer.getPosition(id)
		if not position then
			continue
		end
		local kind, elite = EnemyRenderer.getKind(id)
		local radius = radiusOf(kind, elite)
		if sparked < Config.SPARK_ENEMIES_PER_BATCH then
			sparked += 1
			Particles.emit("Sparks", position + Vector3.new(0, radius + 1, 0), Config.SPARKS_PER_HIT)
		end
		showNumber(id, amount, position, radius)
	end
end

local puffedThisFrame = 0

local function onRemoved(_id: number, position: Vector3, kind: string, elite: boolean)
	if puffedThisFrame >= Config.PUFFS_PER_BATCH then
		return
	end
	puffedThisFrame += 1
	local def = EnemiesConfig.TYPES[kind]
	if def and def.behavior == "prop" then
		Particles.emit("Puff", position + Vector3.new(0, 1.5, 0), Config.PUFF_PARTICLES)
		return
	end
	local radius = radiusOf(kind, elite)
	local big = elite or (def ~= nil and def.isBoss == true)
	local center = position + Vector3.new(0, radius, 0)
	Particles.emit("Puff", center, if big then Config.ELITE_PUFF_PARTICLES else Config.PUFF_PARTICLES)
	if big then
		Particles.emit("GoldBurst", center, Config.ELITE_PUFF_PARTICLES)
		Particles.flash(center + Vector3.new(0, 2, 0), ELITE_FLASH_COLOR, 4, 16, 0.4)
	end
end

local function render()
	puffedThisFrame = 0
	local now = os.clock()
	for index = #activeNumbers, 1, -1 do
		local number = activeNumbers[index]
		local age = (now - number.startedAt) / Config.NUMBER_LIFETIME
		if age >= 1 then
			release(index)
			continue
		end
		number.gui.StudsOffsetWorldSpace = Vector3.new(0, Config.NUMBER_RISE * age, 0)
		-- Pop in a little bigger, settle, then fade over the last 40%.
		local baseSize = if number.big then BIG_NUMBER_SIZE else NUMBER_SIZE
		local pop = if age < 0.15 then 1 + (0.15 - age) * 2 else 1
		number.label.TextSize = math.round(baseSize * pop)
		local fade = math.clamp((age - 0.6) / 0.4, 0, 1)
		number.label.TextTransparency = fade
		number.label.TextStrokeTransparency = 0.2 + 0.8 * fade
	end
end

function HitEffects.start()
	assert(not started, "HitEffects.start() was called twice")
	started = true

	local folder = Instance.new("Folder")
	folder.Name = "HitEffects"
	folder.Parent = workspace
	anchor = Instance.new("Part")
	anchor.Name = "EffectAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.Parent = folder

	for _ = 1, Config.NUMBER_POOL do
		table.insert(freeNumbers, newNumber())
	end

	-- A new world: drop every number still showing.
	CurrentArena.onReset(function()
		for index = #activeNumbers, 1, -1 do
			release(index)
		end
	end)

	Remotes.EnemiesHit.OnClientEvent:Connect(onHit)
	EnemyRenderer.onRemoved(onRemoved)
	RunService.RenderStepped:Connect(render)
end

return HitEffects
