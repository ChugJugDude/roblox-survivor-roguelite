--!strict
-- Draws visual-only weapon effects sent through Remotes.WeaponEffects: Chain Lightning bolts (with
-- sparks and a flash of light where they strike) and Holy Ground zones: a consecrated circle drawn on
-- the floor (a SurfaceGui with glowing rings, a turning band of rune marks, and an eight-point star),
-- rising motes of light, and a soft light. Sanctuary zones are brighter, pulse, and sparkle over
-- players they heal. Damage is already dealt on the server by the time these arrive. (Frost Nova's
-- Chill effect is drawn by EnemyRenderer, which owns the enemy models.)

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

local HOLY_COLOR = Color3.fromRGB(255, 205, 80)
local SANCTUARY_COLOR = Color3.fromRGB(255, 228, 125)
local ZONE_HEIGHT = 0.12 -- above the floor, under everything else
-- The drawing's plate is a bit bigger than the zone so the outer ring's stroke isn't clipped.
local PLATE_SCALE = 1.15
local CANVAS = 512 -- pixels across the drawing
local RUNE_COUNT = 12
local RUNE_SPEED = 18 -- degrees per second; the star turns the other way at half speed
local GROW_TIME = 0.25 -- seconds for a new zone to grow to full size
-- Zones fade out over their last this many seconds, so players see one is about to end.
local ZONE_FADE_TIME = 0.5
local MOTE_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
local ZONE_LIGHT_BRIGHTNESS = 0.5
-- Sanctuary pulses its glow at this many cycles per second, and sparkles over each player standing
-- in it this often (seconds).
local SANCTUARY_PULSE = 1.2
local HEAL_SPARKLE_INTERVAL = 0.35

-- A piece of the drawing that fades with the zone: its property's value when fully shown.
type Fadeable = {
	instance: Instance,
	property: string,
	base: number,
}

type Zone = {
	plate: BasePart, -- carries the drawing
	source: BasePart, -- an invisible flat box the motes rise from
	motes: ParticleEmitter,
	light: PointLight,
	runes: Frame, -- turned each frame
	star: Frame,
	glow: Frame, -- pulsed for Sanctuary
	fadeables: { Fadeable },
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

-- A centered circle `size` (fraction of the canvas) across: an optional fill and an optional ring.
local function circle(
	parent: Instance,
	size: number,
	color: Color3,
	fill: number?,
	ring: number?,
	fadeables: { Fadeable }
): Frame
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(size, size)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.BackgroundColor3 = color
	frame.BackgroundTransparency = fill or 1
	frame.BorderSizePixel = 0
	frame.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = frame
	if fill then
		table.insert(fadeables, { instance = frame, property = "BackgroundTransparency", base = fill })
	end
	if ring then
		local stroke = Instance.new("UIStroke")
		stroke.Color = color
		stroke.Thickness = ring
		stroke.Parent = frame
		table.insert(fadeables, { instance = stroke, property = "Transparency", base = 0 })
	end
	return frame
end

-- An outlined square, `size` across and turned `rotation` degrees (two make an eight-point star).
local function square(parent: Instance, size: number, rotation: number, color: Color3, fadeables: { Fadeable })
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(size, size)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Rotation = rotation
	frame.BackgroundTransparency = 1
	frame.Parent = parent
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = 9
	stroke.Parent = frame
	table.insert(fadeables, { instance = stroke, property = "Transparency", base = 0.1 })
end

-- Draws the consecrated circle on a SurfaceGui on the plate's top face.
local function drawCircle(plate: BasePart, color: Color3, fadeables: { Fadeable }): (Frame, Frame, Frame)
	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Top
	surface.CanvasSize = Vector2.new(CANVAS, CANVAS)
	surface.LightInfluence = 0
	surface.Brightness = 1.25
	surface.Parent = plate
	local root = Instance.new("Frame")
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundTransparency = 1
	root.Parent = surface
	local grow = Instance.new("UIScale")
	grow.Scale = 0.5
	grow.Parent = root
	TweenService:Create(grow, TweenInfo.new(GROW_TIME, Enum.EasingStyle.Back), { Scale = 1 }):Play()

	local zone = 1 / PLATE_SCALE -- the zone's edge, as a fraction of the canvas
	local glow = circle(root, zone, color, 0.66, nil, fadeables)
	circle(root, zone, color, nil, 16, fadeables)
	circle(root, zone * 0.88, color, nil, 6, fadeables)
	circle(root, zone * 0.5, color, nil, 8, fadeables)

	-- The rune band: diamond marks evenly around a ring between the outer and inner circles.
	local runes = Instance.new("Frame")
	runes.Size = UDim2.fromScale(zone * 0.72, zone * 0.72)
	runes.Position = UDim2.fromScale(0.5, 0.5)
	runes.AnchorPoint = Vector2.new(0.5, 0.5)
	runes.BackgroundTransparency = 1
	runes.Parent = root
	for index = 1, RUNE_COUNT do
		local angle = index / RUNE_COUNT * 2 * math.pi
		local mark = Instance.new("Frame")
		local markSize = if index % 3 == 0 then 34 else 22
		mark.Size = UDim2.fromOffset(markSize, markSize)
		mark.Position = UDim2.fromScale(0.5 + 0.5 * math.cos(angle), 0.5 + 0.5 * math.sin(angle))
		mark.AnchorPoint = Vector2.new(0.5, 0.5)
		mark.Rotation = 45
		mark.BackgroundColor3 = color
		mark.BorderSizePixel = 0
		mark.Parent = runes
		table.insert(fadeables, { instance = mark, property = "BackgroundTransparency", base = 0 })
	end

	-- The eight-point star in the middle.
	local star = Instance.new("Frame")
	star.Size = UDim2.fromScale(zone * 0.42, zone * 0.42)
	star.Position = UDim2.fromScale(0.5, 0.5)
	star.AnchorPoint = Vector2.new(0.5, 0.5)
	star.BackgroundTransparency = 1
	star.Parent = root
	square(star, 0.7, 0, color, fadeables)
	square(star, 0.7, 45, color, fadeables)
	return runes, star, glow
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
	local color = if evolved then SANCTUARY_COLOR else HOLY_COLOR
	local radius: number = info.radius
	local diameter = radius * 2
	local center = Vector3.new(info.x, ArenaConfig.ORIGIN.Y + ZONE_HEIGHT, info.z)

	local plate = newPart("HolyGround", color)
	plate.Size = Vector3.new(diameter * PLATE_SCALE, 0.1, diameter * PLATE_SCALE)
	plate.CFrame = CFrame.new(center)
	plate.Transparency = 1
	plate.Parent = folder
	local fadeables: { Fadeable } = {}
	local runes, star, glow = drawCircle(plate, color, fadeables)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = radius * 1.2
	light.Brightness = ZONE_LIGHT_BRIGHTNESS
	light.Parent = plate

	local source = newPart("HolyGroundMotes", color)
	source.Size = Vector3.new(diameter * 0.8, 0.2, diameter * 0.8)
	source.Transparency = 1
	source.CFrame = CFrame.new(center)
	source.Parent = folder
	local motes = Instance.new("ParticleEmitter")
	motes.Texture = MOTE_TEXTURE
	motes.Color = ColorSequence.new(color)
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
		plate = plate,
		source = source,
		motes = motes,
		light = light,
		runes = runes,
		star = star,
		glow = glow,
		fadeables = fadeables,
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
	zone.plate:Destroy()
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
			local center = zone.plate.Position
			local dx, dz = root.Position.X - center.X, root.Position.Z - center.Z
			if zone.evolved and dx * dx + dz * dz <= zone.radius * zone.radius then
				Particles.emit("HolyRise", root.Position - Vector3.new(0, 1.5, 0), 3)
				break
			end
		end
	end
end

-- Turns, pulses, fades, and moves zones, and removes them once over. Uses game time, so zones hold
-- still through a level-up pause like the server's do.
local function render(dt: number)
	local currentArena = CurrentArena.get()
	if not currentArena or #zones == 0 then
		return
	end
	local now = GameClock.read(currentArena)
	local spin = if GameClock.isPaused(currentArena) then 0 else RUNE_SPEED * dt
	for index = #zones, 1, -1 do
		local zone = zones[index]
		local left = zone.endsAt - now
		if left <= 0 then
			destroyZone(zone)
			table.remove(zones, index)
			continue
		end
		zone.runes.Rotation += spin
		zone.star.Rotation -= spin * 0.5
		local fade = 1 - math.min(left / ZONE_FADE_TIME, 1)
		for _, piece in zone.fadeables do
			(piece.instance :: any)[piece.property] = piece.base + (1 - piece.base) * fade
		end
		if zone.evolved and fade == 0 then
			local pulse = 0.5 + 0.5 * math.sin(now * SANCTUARY_PULSE * 2 * math.pi)
			zone.glow.BackgroundTransparency = 0.62 + 0.15 * pulse
		end
		zone.light.Brightness = ZONE_LIGHT_BRIGHTNESS * (1 - fade)
		zone.motes.Enabled = fade == 0
		local character = zone.owner and zone.owner.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			for _, part in { zone.plate, zone.source } do
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
