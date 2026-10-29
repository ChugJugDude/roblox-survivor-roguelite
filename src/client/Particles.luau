--!strict
-- One-shot particle bursts and light flashes for every visual effect. Each preset is a single
-- ParticleEmitter on an attachment that's moved into place before each Emit, so a burst costs no new
-- instances however many play. Textures are the engine's built-in particle images.

local TweenService = game:GetService("TweenService")

local Graphics = require(script.Parent.Graphics)

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"
local LIGHT_POOL = 6

export type Preset =
	"Sparks"
	| "Puff"
	| "GoldBurst"
	| "Sparkles"
	| "Embers"
	| "Smoke"
	| "IceShards"
	| "Zap"
	| "WardPop"
	| "HolyRise"

local PRESETS: { [Preset]: { [string]: any } } = {
	-- Hit sparks on enemies.
	Sparks = {
		Texture = SPARKLE,
		Color = ColorSequence.new(Color3.fromRGB(255, 250, 220), Color3.fromRGB(255, 200, 90)),
		LightEmission = 1,
		Lifetime = NumberRange.new(0.15, 0.3),
		Speed = NumberRange.new(10, 18),
		SpreadAngle = Vector2.new(180, 180),
		Size = NumberSequence.new(0.7, 0),
		Drag = 6,
	},
	-- An enemy dying (and crates breaking).
	Puff = {
		Texture = SMOKE,
		Color = ColorSequence.new(Color3.fromRGB(230, 230, 235)),
		Lifetime = NumberRange.new(0.35, 0.55),
		Speed = NumberRange.new(3, 6),
		SpreadAngle = Vector2.new(180, 180),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 3) }),
		Transparency = NumberSequence.new(0.3, 1),
		Drag = 4,
		Rotation = NumberRange.new(0, 360),
	},
	-- Elites and bosses dying.
	GoldBurst = {
		Texture = SPARKLE,
		Color = ColorSequence.new(Color3.fromRGB(255, 220, 90)),
		LightEmission = 1,
		Lifetime = NumberRange.new(0.4, 0.7),
		Speed = NumberRange.new(14, 24),
		SpreadAngle = Vector2.new(180, 180),
		Size = NumberSequence.new(1.2, 0),
		Drag = 4,
	},
	-- Level-ups and evolutions (colored per use).
	Sparkles = {
		Texture = SPARKLE,
		LightEmission = 1,
		Lifetime = NumberRange.new(0.5, 0.9),
		Speed = NumberRange.new(8, 16),
		SpreadAngle = Vector2.new(180, 180),
		Size = NumberSequence.new(1, 0),
		Drag = 3,
		Acceleration = Vector3.new(0, 6, 0),
	},
	-- Fireball and Meteor blasts.
	Embers = {
		Texture = FIRE,
		Color = ColorSequence.new(Color3.fromRGB(255, 200, 80), Color3.fromRGB(255, 80, 20)),
		LightEmission = 1,
		Lifetime = NumberRange.new(0.3, 0.6),
		Speed = NumberRange.new(10, 20),
		SpreadAngle = Vector2.new(180, 180),
		Size = NumberSequence.new(1.6, 0),
		Drag = 5,
		Acceleration = Vector3.new(0, 8, 0),
	},
	Smoke = {
		Texture = SMOKE,
		Color = ColorSequence.new(Color3.fromRGB(90, 80, 75)),
		Lifetime = NumberRange.new(0.6, 1),
		Speed = NumberRange.new(4, 8),
		SpreadAngle = Vector2.new(180, 180),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 5) }),
		Transparency = NumberSequence.new(0.4, 1),
		Drag = 3,
		Rotation = NumberRange.new(0, 360),
		Acceleration = Vector3.new(0, 4, 0),
	},
	-- Frost Nova bursts and enemies freezing.
	IceShards = {
		Texture = SPARKLE,
		Color = ColorSequence.new(Color3.fromRGB(220, 245, 255), Color3.fromRGB(130, 200, 255)),
		LightEmission = 0.6,
		Lifetime = NumberRange.new(0.4, 0.8),
		Speed = NumberRange.new(2, 6),
		SpreadAngle = Vector2.new(60, 60),
		Size = NumberSequence.new(1.1, 0),
		Drag = 2,
		Acceleration = Vector3.new(0, 3, 0),
		Rotation = NumberRange.new(0, 360),
	},
	-- Each enemy a lightning bolt strikes.
	Zap = {
		Texture = SPARKLE,
		Color = ColorSequence.new(Color3.fromRGB(230, 240, 255)),
		LightEmission = 1,
		Lifetime = NumberRange.new(0.1, 0.25),
		Speed = NumberRange.new(12, 22),
		SpreadAngle = Vector2.new(180, 180),
		Size = NumberSequence.new(0.8, 0),
		Drag = 8,
	},
	-- A Warding ring destroying an enemy shot.
	WardPop = {
		Texture = SPARKLE,
		Color = ColorSequence.new(Color3.fromRGB(200, 230, 255)),
		LightEmission = 1,
		Lifetime = NumberRange.new(0.2, 0.4),
		Speed = NumberRange.new(8, 14),
		SpreadAngle = Vector2.new(180, 180),
		Size = NumberSequence.new(1, 0),
		Drag = 6,
	},
	-- Sanctuary healing a player.
	HolyRise = {
		Texture = SPARKLE,
		Color = ColorSequence.new(Color3.fromRGB(255, 240, 160)),
		LightEmission = 1,
		Lifetime = NumberRange.new(0.6, 1),
		Speed = NumberRange.new(2, 4),
		SpreadAngle = Vector2.new(25, 25),
		Size = NumberSequence.new(0.6, 0),
		Acceleration = Vector3.new(0, 4, 0),
	},
}

local emitters: { [Preset]: ParticleEmitter } = {}
local lights: { PointLight } = {}
local nextLight = 1
local anchor: Part? = nil

local Particles = {}

local function getAnchor(): Part
	if anchor then
		return anchor
	end
	local folder = Instance.new("Folder")
	folder.Name = "Particles"
	folder.Parent = workspace
	local part = Instance.new("Part")
	part.Name = "ParticleAnchor"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.one
	part.Parent = folder
	anchor = part
	return part
end

local function getEmitter(preset: Preset): ParticleEmitter
	local existing = emitters[preset]
	if existing then
		return existing
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = preset
	attachment.Parent = getAnchor()
	local particles = Instance.new("ParticleEmitter")
	particles.Name = preset
	particles.Enabled = false
	for key, value in PRESETS[preset] do
		(particles :: any)[key] = value
	end
	particles.Parent = attachment
	emitters[preset] = particles
	return particles
end

-- Emits `count` particles of `preset` at `position`. `color` recolors the preset (it also tints its
-- particles still in the air, so use it only for rare effects like level-ups).
function Particles.emit(preset: Preset, position: Vector3, count: number, color: Color3?)
	local particles = getEmitter(preset)
	if color then
		particles.Color = ColorSequence.new(color)
	end
	(particles.Parent :: Attachment).WorldPosition = position
	particles:Emit(count)
end

-- A brief point of light at `position` that fades out over `duration` seconds.
function Particles.flash(position: Vector3, color: Color3, brightness: number, range: number, duration: number)
	if not Graphics.profile().lights then
		return
	end
	local light = lights[nextLight]
	if not light then
		local attachment = Instance.new("Attachment")
		attachment.Name = "Flash"
		attachment.Parent = getAnchor()
		light = Instance.new("PointLight")
		light.Parent = attachment
		lights[nextLight] = light
	end
	nextLight = nextLight % LIGHT_POOL + 1
	(light.Parent :: Attachment).WorldPosition = position
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	TweenService:Create(light, TweenInfo.new(duration), { Brightness = 0 }):Play()
end

return Particles
