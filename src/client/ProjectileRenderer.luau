--!strict
-- Draws projectiles and explosions. Projectiles fly in straight lines, so each one is placed from its
-- spawn event and the shared server clock until it reaches max distance or the server removes it.
-- A projectile is a few parts (pieces) placed at offsets from one moving CFrame, pooled by kind;
-- fireballs carry a fire trail and a light.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local CurrentArena = require(script.Parent.CurrentArena)
local Graphics = require(script.Parent.Graphics)
local Particles = require(script.Parent.Particles)
local ArenaConfig = require(ReplicatedStorage.Shared.Config.Arena)
local EntityNet = require(ReplicatedStorage.Shared.EntityNet)
local GameClock = require(ReplicatedStorage.Shared.GameClock)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local FIRE_TEXTURE = "rbxasset://textures/particles/fire_main.dds"
local FIRE_RATE = 60 -- flame particles per second (scaled by the graphics quality)

type Piece = {
	size: Vector3,
	color: Color3,
	shape: Enum.PartType?, -- default Block
	material: Enum.Material?, -- default Neon
	offset: CFrame?, -- from the projectile's CFrame, which faces along -Z
}

type Look = {
	pieces: { Piece },
	height: number, -- above the floor
	fire: number?, -- a fire trail and light on the first piece, this big
}

local ARROW_SHAFT = Color3.fromRGB(170, 120, 70)
local ARROW_HEAD = Color3.fromRGB(225, 230, 240)
local ARROW_FLETCH = Color3.fromRGB(255, 245, 225)
-- Enemy shots must read at a glance over anything the player has: a solid crimson orb (not neon,
-- whose glow washes red toward orange next to gold) flying above the blades, so the top-down camera
-- always draws it on top.
local ENEMY_SHOT_COLOR = Color3.fromRGB(190, 0, 35)

local LOOKS: { [string]: Look } = {
	Arrow = {
		pieces = {
			{ size = Vector3.new(0.18, 0.18, 2.4), color = ARROW_SHAFT, material = Enum.Material.Wood },
			-- A diamond head (a small block turned 45 degrees) and two crossed fletching vanes.
			{
				size = Vector3.new(0.45, 0.12, 0.45),
				color = ARROW_HEAD,
				material = Enum.Material.Metal,
				offset = CFrame.new(0, 0, -1.25) * CFrame.Angles(0, math.rad(45), 0),
			},
			{ size = Vector3.new(0.6, 0.04, 0.45), color = ARROW_FLETCH, offset = CFrame.new(0, 0, 1.0) },
			{ size = Vector3.new(0.04, 0.6, 0.45), color = ARROW_FLETCH, offset = CFrame.new(0, 0, 1.0) },
		},
		height = 2.5,
	},
	Fireball = {
		pieces = {
			{ size = Vector3.new(1.8, 1.8, 1.8), color = Color3.fromRGB(255, 140, 40), shape = Enum.PartType.Ball },
		},
		height = 3,
		fire = 1.6,
	},
	Meteor = {
		pieces = {
			{ size = Vector3.new(3.4, 3.4, 3.4), color = Color3.fromRGB(255, 90, 30), shape = Enum.PartType.Ball },
		},
		height = 4,
		fire = 3.2,
	},
	EnemyArrow = {
		pieces = {
			{
				size = Vector3.new(1.9, 1.9, 1.9),
				color = ENEMY_SHOT_COLOR,
				shape = Enum.PartType.Ball,
				material = Enum.Material.SmoothPlastic,
			},
		},
		height = 4.5,
	},
	-- A boss's ring shot: the same crimson orb, bigger.
	BossOrb = {
		pieces = {
			{
				size = Vector3.new(2.6, 2.6, 2.6),
				color = ENEMY_SHOT_COLOR,
				shape = Enum.PartType.Ball,
				material = Enum.Material.SmoothPlastic,
			},
		},
		height = 4.5,
	},
}
local ENEMY_SHOTS: { [string]: boolean } = { EnemyArrow = true, BossOrb = true }

local EXPLOSION_COLOR = Color3.fromRGB(255, 140, 40)
local EXPLOSION_TIME = 0.3
local SHOCKWAVE_TIME = 0.5
-- Flat shockwaves by explosion kind.
local SHOCKWAVE_COLORS: { [string]: Color3 } = {
	Bomb = Color3.fromRGB(255, 235, 200),
	Frost = Color3.fromRGB(140, 215, 255),
	Blizzard = Color3.fromRGB(205, 240, 255),
}
local FROST_KINDS: { [string]: boolean } = { Frost = true, Blizzard = true }
-- Ice shards around a frost burst's edge: this many points, each with a few shards.
local FROST_RING_POINTS = 14

type Visual = {
	parts: { BasePart },
	fire: ParticleEmitter?,
	light: PointLight?,
}

type Active = {
	info: EntityNet.ProjectileInfo,
	visual: Visual,
	kind: string,
	facing: CFrame, -- rotation only
	height: number,
}

local active: { [number]: Active } = {}
local pools: { [string]: { Visual } } = {}
local folder: Folder? = nil
local shotStoppedListeners: { (position: Vector3) -> () } = {}
local started = false

-- Reused every frame for BulkMoveTo.
local moveParts: { BasePart } = {}
local moveCFrames: { CFrame } = {}

local ProjectileRenderer = {}

local function newVisual(kind: string): Visual
	local look = LOOKS[kind] or LOOKS.Arrow
	local parts = {}
	for _, spec in look.pieces do
		local part = Instance.new("Part")
		part.Name = kind
		part.Shape = spec.shape or Enum.PartType.Block
		part.Size = spec.size
		part.Color = spec.color
		part.Material = spec.material or Enum.Material.Neon
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		table.insert(parts, part)
	end
	local fire: ParticleEmitter? = nil
	local fireLight: PointLight? = nil
	if look.fire then
		-- Particles stay where they're born, so a moving fireball leaves a trail of flame.
		local emitter = Instance.new("ParticleEmitter")
		emitter.Texture = FIRE_TEXTURE
		emitter.Color = ColorSequence.new(Color3.fromRGB(255, 210, 90), Color3.fromRGB(255, 70, 20))
		emitter.LightEmission = 1
		emitter.Lifetime = NumberRange.new(0.2, 0.35)
		emitter.Rate = FIRE_RATE
		emitter.Speed = NumberRange.new(0.5, 1.5)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Size = NumberSequence.new(look.fire, 0)
		emitter.Enabled = false
		emitter.Parent = parts[1]
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 150, 60)
		light.Range = look.fire * 6
		light.Brightness = 2
		light.Parent = parts[1]
		fire = emitter
		fireLight = light
	end
	return { parts = parts, fire = fire, light = fireLight }
end

local function acquire(kind: string): Visual
	local pool = pools[kind]
	local visual = if pool then table.remove(pool) else nil
	if not visual then
		visual = newVisual(kind)
	end
	for _, part in (visual :: Visual).parts do
		part.Parent = folder
	end
	-- Apply the current graphics quality to the fire trail and light.
	local profile = Graphics.profile()
	local fire = (visual :: Visual).fire
	if fire then
		fire.Rate = FIRE_RATE * profile.fireScale
	end
	local light = (visual :: Visual).light
	if light then
		light.Enabled = profile.lights
	end
	return visual :: Visual
end

local function release(entry: Active)
	local visual = entry.visual
	for _, part in visual.parts do
		part.Parent = nil
	end
	if visual.fire then
		visual.fire.Enabled = false
		visual.fire:Clear()
	end
	local pool = pools[entry.kind]
	if not pool then
		pool = {}
		pools[entry.kind] = pool
	end
	table.insert(pool, visual)
end

-- Calls `listener(position)` when an enemy shot stops early (it hit a player or a Warding ring).
function ProjectileRenderer.onEnemyShotStopped(listener: (position: Vector3) -> ())
	table.insert(shotStoppedListeners, listener)
end

local function onSpawned(list: any)
	if typeof(list) ~= "table" then
		return
	end
	for _, info in list do
		if typeof(info) ~= "table" or active[info.id] then
			continue
		end
		local kind = if LOOKS[info.kind] then info.kind else "Arrow"
		active[info.id] = {
			info = info,
			visual = acquire(kind),
			kind = kind,
			facing = CFrame.lookAt(Vector3.zero, Vector3.new(info.dirX, 0, info.dirZ)),
			height = ArenaConfig.ORIGIN.Y + LOOKS[kind].height,
		}
	end
end

-- Where a projectile is now, from its spawn info and the game clock.
local function positionOf(entry: Active, now: number): Vector3
	local info = entry.info
	local distance = math.clamp((now - info.startedAt) * info.speed, 0, info.maxDistance)
	return Vector3.new(info.x + info.dirX * distance, entry.height, info.z + info.dirZ * distance)
end

local function onRemoved(ids: any)
	if typeof(ids) ~= "table" then
		return
	end
	local currentArena = CurrentArena.get()
	local now = if currentArena then GameClock.read(currentArena) else 0
	for _, id in ids do
		local entry = active[id]
		if entry then
			active[id] = nil
			if ENEMY_SHOTS[entry.kind] and currentArena then
				local position = positionOf(entry, now)
				for _, listener in shotStoppedListeners do
					listener(position)
				end
			end
			release(entry)
		end
	end
end

local function frostRing(center: Vector3, radius: number)
	for index = 1, FROST_RING_POINTS do
		local angle = index / FROST_RING_POINTS * 2 * math.pi
		Particles.emit("IceShards", center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * radius * 0.85, 2)
	end
	Particles.emit("IceShards", center, 6)
end

local function onExplosions(list: any)
	if typeof(list) ~= "table" then
		return
	end
	for _, info in list do
		if typeof(info) ~= "table" or typeof(info.x) ~= "number" or typeof(info.z) ~= "number" then
			continue
		end
		local radius = if typeof(info.radius) == "number" then info.radius else 1
		-- A bomb or frost burst covers a lot of screen, so it's a flat ring racing outward along the
		-- floor rather than a sphere that would swallow the camera.
		local shockwaveColor = SHOCKWAVE_COLORS[info.kind]
		local isShockwave = shockwaveColor ~= nil
		local blast = Instance.new("Part")
		blast.Name = "Explosion"
		blast.Shape = if isShockwave then Enum.PartType.Cylinder else Enum.PartType.Ball
		blast.Size = if isShockwave then Vector3.new(0.4, 1, 1) else Vector3.one
		blast.Color = shockwaveColor or EXPLOSION_COLOR
		blast.Material = Enum.Material.Neon
		blast.Transparency = 0.2
		blast.Anchored = true
		blast.CanCollide = false
		blast.CanQuery = false
		blast.CanTouch = false
		blast.CastShadow = false
		local center = Vector3.new(info.x, ArenaConfig.ORIGIN.Y + 1, info.z)
		-- A cylinder's axis is its X size; turn it upright so it lies flat as a disc.
		blast.CFrame = if isShockwave
			then CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90))
			else CFrame.new(center)
		blast.Parent = folder
		local diameter = radius * 2
		local tween = TweenService:Create(
			blast,
			TweenInfo.new(if isShockwave then SHOCKWAVE_TIME else EXPLOSION_TIME, Enum.EasingStyle.Quad),
			{
				Size = if isShockwave then Vector3.new(0.4, diameter, diameter) else Vector3.one * diameter,
				Transparency = 1,
			}
		)
		tween.Completed:Once(function()
			blast:Destroy()
		end)
		tween:Play()

		if FROST_KINDS[info.kind] then
			frostRing(center, radius)
		elseif info.kind == "Bomb" then
			Particles.emit("Smoke", center, 14)
			Particles.flash(center + Vector3.new(0, 3, 0), Color3.fromRGB(255, 230, 190), 5, radius, 0.5)
		else
			-- Fireball and Meteor: embers and a puff of smoke, scaled with the blast.
			local scale = math.clamp(radius / 5, 1, 3)
			Particles.emit("Embers", center + Vector3.new(0, 1, 0), math.round(8 * scale))
			Particles.emit("Smoke", center + Vector3.new(0, 1, 0), math.round(3 * scale))
			Particles.flash(center + Vector3.new(0, 3, 0), EXPLOSION_COLOR, 3, radius * 2, 0.35)
		end
	end
end

local function render()
	local currentArena = CurrentArena.get()
	if not currentArena then
		return
	end
	local now = GameClock.read(currentArena)
	table.clear(moveParts)
	table.clear(moveCFrames)

	for id, entry in active do
		local info = entry.info
		if (now - info.startedAt) * info.speed >= info.maxDistance then
			active[id] = nil
			release(entry)
			continue
		end
		local base = CFrame.new(positionOf(entry, now)) * entry.facing
		local look = LOOKS[entry.kind]
		for index, part in entry.visual.parts do
			local offset = look.pieces[index].offset
			table.insert(moveParts, part)
			table.insert(moveCFrames, if offset then base * offset else base)
		end
		local fire = entry.visual.fire
		if fire and not fire.Enabled then
			fire.Enabled = true -- after its first placement, so no flames are left at the origin
		end
	end

	if #moveParts > 0 then
		workspace:BulkMoveTo(moveParts, moveCFrames, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

function ProjectileRenderer.start()
	assert(not started, "ProjectileRenderer.start() was called twice")
	started = true
	-- The player moved to another world: drop every projectile.
	CurrentArena.onReset(function()
		for id, entry in active do
			active[id] = nil
			release(entry)
		end
	end)

	local newFolder = Instance.new("Folder")
	newFolder.Name = "ProjectileVisuals"
	newFolder.Parent = workspace
	folder = newFolder

	Remotes.ProjectilesSpawned.OnClientEvent:Connect(onSpawned)
	Remotes.ProjectilesRemoved.OnClientEvent:Connect(onRemoved)
	Remotes.Explosions.OnClientEvent:Connect(onExplosions)
	RunService.RenderStepped:Connect(render)
end

return ProjectileRenderer
