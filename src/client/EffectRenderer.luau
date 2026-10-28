--!strict
-- Draws visual-only weapon effects sent through Remotes.WeaponEffects: Chain Lightning bolts (with
-- sparks and a flash of light where they strike) and Holy Ground zones (a translucent disc with a
-- glowing rim, rising motes of light, and a soft light; Sanctuary zones also sparkle over players
-- they heal). Damage is already dealt on the server by the time these arrive. (Frost Nova's Chill
-- effect is drawn by EnemyRenderer, which owns the enemy models.)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local CurrentArena = require(script.Parent.CurrentArena)
local Particles = require(script.Parent.Particles)
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
local ZAP_PARTICLES = 5 -- sparks at each enemy a bolt strikes

-- Zones are big and flat, so they're plain translucent gold rather than neon, whose glow would
-- bloom to white and wash out the floor.
local HOLY_GROUND_COLOR = Color3.fromRGB(255, 200, 60)
local SANCTUARY_COLOR = Color3.fromRGB(255, 225, 120)
local ZONE_THICKNESS = 0.2
local ZONE_HEIGHT = 0.15 -- above the floor, under everything else
local ZONE_TRANSPARENCY = 0.45
-- Zones fade out over their last this many seconds, so players see one is about to end.
local ZONE_FADE_TIME = 0.5
-- The rim is solid gold too: a neon rim (and bright lights) bloomed whole zones to white.
local RIM_COLOR = Color3.fromRGB(255, 205, 70)
local RIM_TRANSPARENCY = 0.15
local RIM_SCALE = 1.08 -- the rim disc's size relative to the zone, so its edge shows as a ring
local MOTE_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
local ZONE_LIGHT_BRIGHTNESS = 0.5
-- Sanctuary sparkles over each player standing in it, this often (seconds).
local HEAL_SPARKLE_INTERVAL = 0.35

type Zone = {
	disc: BasePart,
	rim: BasePart,
	source: BasePart, -- an invisible flat box the motes rise from
	motes: ParticleEmitter,
	light: PointLight,
	radius: number,
	evolved: boolean,
	endsAt: number, -- game time (shared/GameClock)
	owner: Player?, -- the zone follows this player's character (Sanctuary)
}

local random = Random.new()
local zones: { Zone } = {}
local sinceHealSparkle = 0
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
			Particles.emit("Zap", point, ZAP_PARTICLES)
			if index == 3 then
				-- The first enemy struck lights up.
				Particles.flash(point, color, 3, 12, LIGHTNING_TIME)
			end
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
	local evolved = info.evolved == true
	local radius: number = info.radius
	local diameter = radius * 2
	local center = Vector3.new(info.x, ArenaConfig.ORIGIN.Y + ZONE_HEIGHT, info.z)
	-- A cylinder's axis is its X size; turn it upright so it lies flat as a disc.
	local flat = CFrame.Angles(0, 0, math.rad(90))

	local disc = newPart("HolyGround", if evolved then SANCTUARY_COLOR else HOLY_GROUND_COLOR)
	disc.Shape = Enum.PartType.Cylinder
	disc.Material = Enum.Material.SmoothPlastic
	disc.Size = Vector3.new(ZONE_THICKNESS, diameter, diameter)
	disc.CFrame = CFrame.new(center) * flat
	disc.Transparency = ZONE_TRANSPARENCY
	disc.Parent = folder
	-- A slightly bigger glowing disc just underneath shows as a bright rim around the edge.
	local rim = newPart("HolyGroundRim", RIM_COLOR)
	rim.Shape = Enum.PartType.Cylinder
	rim.Material = Enum.Material.SmoothPlastic
	rim.Size = Vector3.new(ZONE_THICKNESS * 0.5, diameter * RIM_SCALE, diameter * RIM_SCALE)
	rim.CFrame = CFrame.new(center - Vector3.new(0, 0.05, 0)) * flat
	rim.Transparency = RIM_TRANSPARENCY
	rim.Parent = folder
	local light = Instance.new("PointLight")
	light.Color = RIM_COLOR
	light.Range = radius * 1.2
	light.Brightness = ZONE_LIGHT_BRIGHTNESS
	light.Parent = disc

	local source = newPart("HolyGroundMotes", RIM_COLOR)
	source.Size = Vector3.new(diameter * 0.8, 0.2, diameter * 0.8)
	source.Transparency = 1
	source.CFrame = CFrame.new(center)
	source.Parent = folder
	local motes = Instance.new("ParticleEmitter")
	motes.Texture = MOTE_TEXTURE
	motes.Color = ColorSequence.new(if evolved then Color3.fromRGB(255, 245, 190) else RIM_COLOR)
	motes.LightEmission = 1
	motes.Shape = Enum.ParticleEmitterShape.Box
	motes.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	motes.Lifetime = NumberRange.new(0.9, 1.5)
	motes.Speed = NumberRange.new(1.5, 3)
	motes.SpreadAngle = Vector2.new(10, 10)
	motes.Size = NumberSequence.new(0.5, 0)
	motes.Acceleration = Vector3.new(0, 1.5, 0)
	motes.Rate = (4 + radius * 1.5) * (if evolved then 1.5 else 1)
	motes.Parent = source

	local owner = if typeof(info.ownerId) == "number" then Players:GetPlayerByUserId(info.ownerId) else nil
	table.insert(zones, {
		disc = disc,
		rim = rim,
		source = source,
		motes = motes,
		light = light,
		radius = radius,
		evolved = evolved,
		endsAt = info.startedAt + info.duration,
		owner = owner,
	})
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

local function destroyZone(zone: Zone)
	zone.disc:Destroy()
	zone.rim:Destroy()
	zone.source:Destroy()
end

-- Every player in the arena standing in a Sanctuary zone gets a few rising sparkles.
local function sparkleHealed(currentArena: Instance)
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") or player:GetAttribute("ArenaName") ~= currentArena.Name then
			continue
		end
		for _, zone in zones do
			local center = zone.disc.Position
			local dx, dz = root.Position.X - center.X, root.Position.Z - center.Z
			if zone.evolved and dx * dx + dz * dz <= zone.radius * zone.radius then
				Particles.emit("HolyRise", root.Position - Vector3.new(0, 1.5, 0), 3)
				break
			end
		end
	end
end

-- Fades zones near their end, moves following zones, and removes zones once over. Uses game time,
-- so zones hold still through a level-up pause like the server's do.
local function render(dt: number)
	local currentArena = CurrentArena.get()
	if not currentArena or #zones == 0 then
		return
	end
	local now = GameClock.read(currentArena)
	for index = #zones, 1, -1 do
		local zone = zones[index]
		local left = zone.endsAt - now
		if left <= 0 then
			destroyZone(zone)
			table.remove(zones, index)
			continue
		end
		local fade = 1 - math.min(left / ZONE_FADE_TIME, 1)
		zone.disc.Transparency = ZONE_TRANSPARENCY + (1 - ZONE_TRANSPARENCY) * fade
		zone.rim.Transparency = RIM_TRANSPARENCY + (1 - RIM_TRANSPARENCY) * fade
		zone.light.Brightness = ZONE_LIGHT_BRIGHTNESS * (1 - fade)
		zone.motes.Enabled = fade == 0
		local character = zone.owner and zone.owner.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			for _, part in { zone.disc, zone.rim, zone.source } do
				local position = part.Position
				part.Position = Vector3.new(root.Position.X, position.Y, root.Position.Z)
			end
		end
	end
	sinceHealSparkle += dt
	if sinceHealSparkle >= HEAL_SPARKLE_INTERVAL then
		sinceHealSparkle = 0
		sparkleHealed(currentArena)
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
