--!strict
-- Draws XP gems: bobbing and spinning on the floor, then flying to whoever picked them up. Gems
-- don't move on the server, so they only need spawn and collected events (see server/Progression).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ArenaConfig = require(ReplicatedStorage.Shared.Config.Arena)
local Config = require(ReplicatedStorage.Shared.Config.Progression)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

-- Seconds a collected gem takes to reach the player.
local FLY_TIME = 0.25
local HOVER_HEIGHT = 1.2
-- Turns a cube into a diamond standing on its point.
local DIAMOND = CFrame.Angles(math.rad(45), 0, math.rad(45))

type Gem = {
	part: BasePart,
	position: Vector3,
	phase: number, -- offsets the bob and spin so gems don't move in lockstep
}

type Flying = {
	part: BasePart,
	from: Vector3,
	player: Player?,
	startedAt: number,
}

local gems: { [number]: Gem } = {}
local flying: { Flying } = {}
local pool: { BasePart } = {}
local folder: Folder? = nil
local started = false

-- Reused every frame for BulkMoveTo.
local moveParts: { BasePart } = {}
local moveCFrames: { CFrame } = {}

local GemRenderer = {}

local function tierFor(value: number): Config.GemTier
	local chosen = Config.GEM_TIERS[1]
	for _, tier in Config.GEM_TIERS do
		if value >= tier.minValue then
			chosen = tier
		end
	end
	return chosen
end

local function acquire(value: number): BasePart
	local part = table.remove(pool)
	if not part then
		local newPart = Instance.new("Part")
		newPart.Name = "Gem"
		newPart.Material = Enum.Material.Neon
		newPart.Anchored = true
		newPart.CanCollide = false
		newPart.CanQuery = false
		newPart.CanTouch = false
		newPart.CastShadow = false
		part = newPart
	end
	local tier = tierFor(value)
	part.Color = tier.color
	part.Size = Vector3.one * tier.size
	part.Parent = folder
	return part
end

local function release(part: BasePart)
	part.Parent = nil
	table.insert(pool, part)
end

local function onSpawned(list: any)
	if typeof(list) ~= "table" then
		return
	end
	local groundY = ArenaConfig.ORIGIN.Y + HOVER_HEIGHT
	for _, info in list do
		if typeof(info) ~= "table" or gems[info.id] then
			continue
		end
		gems[info.id] = {
			part = acquire(info.value),
			position = Vector3.new(info.x, groundY, info.z),
			phase = (info.id * 0.618) % 1 * math.pi * 2,
		}
	end
end

local function onCollected(list: any)
	if typeof(list) ~= "table" then
		return
	end
	local now = os.clock()
	for _, info in list do
		if typeof(info) ~= "table" then
			continue
		end
		local gem = gems[info.id]
		if not gem then
			continue
		end
		gems[info.id] = nil
		local player = if info.userId ~= 0 then Players:GetPlayerByUserId(info.userId) else nil
		if player then
			table.insert(flying, { part = gem.part, from = gem.position, player = player, startedAt = now })
		else
			release(gem.part)
		end
	end
end

local function render()
	local now = os.clock()
	table.clear(moveParts)
	table.clear(moveCFrames)

	for _, gem in gems do
		local bob = math.sin(now * 3 + gem.phase) * 0.25
		table.insert(moveParts, gem.part)
		table.insert(
			moveCFrames,
			CFrame.new(gem.position + Vector3.new(0, bob, 0)) * CFrame.Angles(0, now * 2 + gem.phase, 0) * DIAMOND
		)
	end

	-- Iterate backwards so finished gems can be removed in place.
	for index = #flying, 1, -1 do
		local fly = flying[index]
		local alpha = (now - fly.startedAt) / FLY_TIME
		local character = fly.player and fly.player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if alpha >= 1 or not root or not root:IsA("BasePart") then
			release(fly.part)
			table.remove(flying, index)
		else
			table.insert(moveParts, fly.part)
			table.insert(moveCFrames, CFrame.new(fly.from:Lerp(root.Position, alpha * alpha)) * DIAMOND)
		end
	end

	if #moveParts > 0 then
		workspace:BulkMoveTo(moveParts, moveCFrames, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

function GemRenderer.start()
	assert(not started, "GemRenderer.start() was called twice")
	started = true

	local newFolder = Instance.new("Folder")
	newFolder.Name = "GemVisuals"
	newFolder.Parent = workspace
	folder = newFolder

	Remotes.GemsSpawned.OnClientEvent:Connect(onSpawned)
	Remotes.GemsCollected.OnClientEvent:Connect(onCollected)
	RunService.RenderStepped:Connect(render)
end

return GemRenderer
