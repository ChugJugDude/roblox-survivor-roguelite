--!strict
-- Draws visual-only weapon effects sent through Remotes.WeaponEffects: Chain Lightning bolts and
-- Holy Ground zones. Damage is already dealt on the server by the time these arrive. (Frost Nova's
-- Chill effect is drawn by EnemyRenderer, which owns the enemy models.)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local CurrentArena = require(script.Parent.CurrentArena)
local ArenaConfig = require(ReplicatedStorage.Shared.Config.Arena)
local GameClock = require(ReplicatedStorage.Shared.GameClock)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local LIGHTNING_COLOR = Color3.fromRGB(200, 230, 255)
local THUNDERSTORM_COLOR = Color3.fromRGB(205, 160, 255)
local LIGHTNING_WIDTH = 0.35
local THUNDERSTORM_WIDTH = 0.6
local LIGHTNING_HEIGHT = 3 -- above the floor
-- Each hop bends once, sideways by up to this fraction of its length, so it reads as lightning.
local JAG = 0.25
local LIGHTNING_TIME = 0.2 -- seconds to fade out

-- Zones are big and flat, so they're plain translucent gold rather than neon, whose glow would
-- bloom to white and wash out the floor.
local HOLY_GROUND_COLOR = Color3.fromRGB(255, 200, 60)
local SANCTUARY_COLOR = Color3.fromRGB(255, 225, 120)
local ZONE_THICKNESS = 0.2
local ZONE_HEIGHT = 0.15 -- above the floor, under everything else
local ZONE_TRANSPARENCY = 0.45
-- Zones fade out over their last this many seconds, so players see one is about to end.
local ZONE_FADE_TIME = 0.5

type Zone = {
	part: BasePart,
	endsAt: number, -- game time (shared/GameClock)
	owner: Player?, -- the zone follows this player's character (Sanctuary)
}

local random = Random.new()
local zones: { Zone } = {}
local folder: Folder? = nil
local started = false

local EffectRenderer = {}

local function newPart(name: string, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Color = color
	part.Material = Enum.Material.Neon
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	return part
end

local function segment(from: Vector3, to: Vector3, color: Color3, width: number)
	local length = (to - from).Magnitude
	if length < 1e-3 then
		return
	end
	local part = newPart("Lightning", color)
	part.Size = Vector3.new(width, width, length)
	part.CFrame = CFrame.lookAt((from + to) / 2, to)
	part.Parent = folder
	local tween = TweenService:Create(part, TweenInfo.new(LIGHTNING_TIME), { Transparency = 1 })
	tween.Completed:Once(function()
		part:Destroy()
	end)
	tween:Play()
end

local function drawLightning(points: { any }, evolved: boolean)
	local color = if evolved then THUNDERSTORM_COLOR else LIGHTNING_COLOR
	local width = if evolved then THUNDERSTORM_WIDTH else LIGHTNING_WIDTH
	local height = ArenaConfig.ORIGIN.Y + LIGHTNING_HEIGHT
	local previous: Vector3? = nil
	for index = 1, #points - 1, 2 do
		local x, z = points[index], points[index + 1]
		if typeof(x) ~= "number" or typeof(z) ~= "number" then
			return
		end
		local point = Vector3.new(x, height, z)
		if previous then
			-- Kink the hop at its middle, sideways on the ground plane.
			local hop = point - previous
			local side = Vector3.new(-hop.Z, 0, hop.X) * random:NextNumber(-JAG, JAG)
			local middle = (previous + point) / 2 + side
			segment(previous, middle, color, width)
			segment(middle, point, color, width)
		end
		previous = point
	end
end

local function addZone(info: any)
	if
		typeof(info.x) ~= "number"
		or typeof(info.z) ~= "number"
		or typeof(info.radius) ~= "number"
		or typeof(info.startedAt) ~= "number"
		or typeof(info.duration) ~= "number"
	then
		return
	end
	local part = newPart("HolyGround", if info.evolved == true then SANCTUARY_COLOR else HOLY_GROUND_COLOR)
	-- A cylinder's axis is its X size; turn it upright so it lies flat as a disc.
	part.Shape = Enum.PartType.Cylinder
	part.Material = Enum.Material.SmoothPlastic
	part.Size = Vector3.new(ZONE_THICKNESS, info.radius * 2, info.radius * 2)
	part.CFrame = CFrame.new(info.x, ArenaConfig.ORIGIN.Y + ZONE_HEIGHT, info.z) * CFrame.Angles(0, 0, math.rad(90))
	part.Transparency = ZONE_TRANSPARENCY
	part.Parent = folder
	local owner = if typeof(info.ownerId) == "number" then Players:GetPlayerByUserId(info.ownerId) else nil
	table.insert(zones, { part = part, endsAt = info.startedAt + info.duration, owner = owner })
end

local function onEffects(list: any)
	if typeof(list) ~= "table" then
		return
	end
	for _, info in list do
		if typeof(info) ~= "table" then
			continue
		end
		if info.kind == "Lightning" and typeof(info.points) == "table" then
			drawLightning(info.points, info.evolved == true)
		elseif info.kind == "HolyGround" then
			addZone(info)
		end
	end
end

-- Fades zones near their end and removes them once over. Uses game time, so zones hold still
-- through a level-up pause like the server's do.
local function render()
	local currentArena = CurrentArena.get()
	if not currentArena or #zones == 0 then
		return
	end
	local now = GameClock.read(currentArena)
	for index = #zones, 1, -1 do
		local zone = zones[index]
		local left = zone.endsAt - now
		if left <= 0 then
			zone.part:Destroy()
			table.remove(zones, index)
		else
			local fade = 1 - math.min(left / ZONE_FADE_TIME, 1)
			zone.part.Transparency = ZONE_TRANSPARENCY + (1 - ZONE_TRANSPARENCY) * fade
			local character = zone.owner and zone.owner.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				local position = zone.part.Position
				zone.part.Position = Vector3.new(root.Position.X, position.Y, root.Position.Z)
			end
		end
	end
end

function EffectRenderer.start()
	assert(not started, "EffectRenderer.start() was called twice")
	started = true

	local newFolder = Instance.new("Folder")
	newFolder.Name = "EffectVisuals"
	newFolder.Parent = workspace
	folder = newFolder

	-- The player moved to another world: drop every effect.
	CurrentArena.onReset(function()
		table.clear(zones)
		newFolder:ClearAllChildren()
	end)

	Remotes.WeaponEffects.OnClientEvent:Connect(onEffects)
	RunService.RenderStepped:Connect(render)
end

return EffectRenderer
