--!strict
-- Draws projectiles and explosions. Projectiles fly in straight lines, so each one is placed from its
-- spawn event and the shared server clock until it reaches max distance or the server removes it.
-- A projectile is a few parts (pieces) placed at offsets from one moving CFrame, pooled by kind;
-- fireballs carry a fire trail and a light. A look can name an AI-made model (client/ModelLibrary)
-- to use instead of its pieces once it's loaded.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local CurrentArena = require(script.Parent.CurrentArena)
local Graphics = require(script.Parent.Graphics)
local ModelLibrary = require(script.Parent.ModelLibrary)
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
	transparency: number?,
	offset: CFrame?, -- from the projectile's CFrame, which faces along -Z
	spins: boolean?, -- turns with the look's `spin` (a model's parts always do)
}

-- A ribbon left behind the first piece, flat so the top-down camera sees it.
type TrailSpec = {
	color: Color3,
	width: number,
	lifetime: number,
	at: number, -- where on the first piece it starts (studs along +Z, toward the tail)
}

type Look = {
	pieces: { Piece }, -- the primitive look (and the fallback while `model` loads)
	model: string?, -- a ModelLibrary model (centered, pointing -Z) to use instead
	spin: Vector3?, -- spinning parts turn this fast about each axis (radians per second)
	height: number, -- above the floor
	fire: number?, -- a fire trail and light on the first piece, this big
	trail: TrailSpec?,
}

local ARROW_SHAFT = Color3.fromRGB(170, 120, 70)
local ARROW_HEAD = Color3.fromRGB(225, 230, 240)
local ARROW_FLETCH = Color3.fromRGB(255, 245, 225)
-- Enemy shots must read at a glance over anything the player has: solid crimson (not neon, whose
-- glow washes red toward orange next to gold, except in small cores), flying above the blades so
-- the top-down camera always draws them on top, each with a crimson trail.
local ENEMY_SHOT_COLOR = Color3.fromRGB(190, 0, 35)
local ENEMY_SHOT_DARK = Color3.fromRGB(70, 0, 15)
local ENEMY_SHOT_TRAIL = Color3.fromRGB(220, 20, 50)

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
		model = "Arrow",
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
		model = "Meteor",
		spin = Vector3.new(-5, 0, 0),
		height = 4,
		fire = 3.2,
	},
	-- An archer's bolt: a dark shaft with a big crimson head in a crimson haze, and dark fletching.
	EnemyArrow = {
		pieces = {
			{ size = Vector3.new(0.3, 0.3, 2.6), color = ENEMY_SHOT_DARK, material = Enum.Material.SmoothPlastic },
			{
				size = Vector3.new(0.95, 0.35, 0.95),
				color = ENEMY_SHOT_COLOR,
				material = Enum.Material.SmoothPlastic,
				offset = CFrame.new(0, 0, -1.35) * CFrame.Angles(0, math.rad(45), 0),
			},
			{ size = Vector3.new(0.3, 0.3, 0.5), color = ENEMY_SHOT_TRAIL, offset = CFrame.new(0, 0, -1.35) },
			{
				size = Vector3.new(1.7, 1.7, 1.7),
				color = ENEMY_SHOT_COLOR,
				shape = Enum.PartType.Ball,
				material = Enum.Material.SmoothPlastic,
				transparency = 0.6,
				offset = CFrame.new(0, 0, -1.2),
			},
			{
				size = Vector3.new(0.8, 0.06, 0.6),
				color = ENEMY_SHOT_COLOR,
				material = Enum.Material.SmoothPlastic,
				offset = CFrame.new(0, 0, 1.1),
			},
			{
				size = Vector3.new(0.06, 0.8, 0.6),
				color = ENEMY_SHOT_COLOR,
				material = Enum.Material.SmoothPlastic,
				offset = CFrame.new(0, 0, 1.1),
			},
		},
		height = 4.5,
		trail = { color = ENEMY_SHOT_TRAIL, width = 0.7, lifetime = 0.22, at = 1.3 },
	},
	-- A boss's ring shot: a bright crimson core in a crimson shell, circled by two spinning rings.
	BossOrb = {
		pieces = {
			{ size = Vector3.new(1.3, 1.3, 1.3), color = ENEMY_SHOT_TRAIL, shape = Enum.PartType.Ball },
			{
				size = Vector3.new(2.4, 2.4, 2.4),
				color = ENEMY_SHOT_COLOR,
				shape = Enum.PartType.Ball,
				material = Enum.Material.SmoothPlastic,
				transparency = 0.3,
			},
			{
				size = Vector3.new(0.14, 3.3, 3.3),
				color = ENEMY_SHOT_DARK,
				shape = Enum.PartType.Cylinder,
				material = Enum.Material.SmoothPlastic,
				transparency = 0.25,
				offset = CFrame.Angles(0, 0, math.rad(60)),
				spins = true,
			},
			{
				size = Vector3.new(0.14, 3.3, 3.3),
				color = ENEMY_SHOT_DARK,
				shape = Enum.PartType.Cylinder,
				material = Enum.Material.SmoothPlastic,
				transparency = 0.25,
				offset = CFrame.Angles(0, 0, math.rad(-60)),
				spins = true,
			},
		},
		height = 4.5,
		spin = Vector3.new(0, 7, 0),
		trail = { color = ENEMY_SHOT_TRAIL, width = 1.6, lifetime = 0.25, at = 0 },
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
	-- An enemy blast (the Infernal's eruption): red-orange, never a player color.
	Eruption = Color3.fromRGB(230, 60, 30),
}
local FROST_KINDS: { [string]: boolean } = { Frost = true, Blizzard = true }
-- Ice shards around a frost burst's edge: this many points, each with a few shards.
local FROST_RING_POINTS = 14

type Visual = {
	parts: { BasePart },
	offsets: { CFrame }, -- each part's, from the projectile's CFrame
	spins: { boolean }, -- each part's: turns with the look's spin
	fire: ParticleEmitter?,
	light: PointLight?,
	trail: Trail?,
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
	local offsets = {}
	local spins = {}
	local template = if look.model then ModelLibrary.get(look.model) else nil
	if template then
		local pivot = template:GetPivot()
		for _, source in template:GetDescendants() do
			if source:IsA("BasePart") then
				table.insert(parts, source:Clone())
				table.insert(offsets, pivot:ToObjectSpace(source.CFrame))
				table.insert(spins, true)
			end
		end
	end
	for _, spec in if template then {} else look.pieces do
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
		part.Transparency = spec.transparency or 0
		table.insert(parts, part)
		table.insert(offsets, spec.offset or CFrame.identity)
		table.insert(spins, spec.spins == true)
	end
	local ribbon: Trail? = nil
	local trailSpec = look.trail
	if trailSpec then
		local carrier = parts[1]
		local left = Instance.new("Attachment")
		left.Position = Vector3.new(-trailSpec.width / 2, 0, trailSpec.at)
		left.Parent = carrier
		local right = Instance.new("Attachment")
		right.Position = Vector3.new(trailSpec.width / 2, 0, trailSpec.at)
		right.Parent = carrier
		local newTrail = Instance.new("Trail")
		newTrail.Attachment0 = left
		newTrail.Attachment1 = right
		newTrail.Color = ColorSequence.new(trailSpec.color)
		newTrail.Transparency = NumberSequence.new(0.25, 1)
		newTrail.Lifetime = trailSpec.lifetime
		newTrail.LightEmission = 0.4
		newTrail.MinLength = 0
		newTrail.Enabled = false
		newTrail.Parent = carrier
		ribbon = newTrail
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
	return { parts = parts, offsets = offsets, spins = spins, fire = fire, light = fireLight, trail = ribbon }
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
	if visual.trail then
		visual.trail.Enabled = false
		visual.trail:Clear()
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
		elseif info.kind == "Eruption" then
			Particles.emit("Embers", center + Vector3.new(0, 1, 0), 10)
			Particles.emit("Smoke", center + Vector3.new(0, 1, 0), 4)
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
		local spin = LOOKS[entry.kind].spin
		local spun = base
		if spin then
			local age = now - info.startedAt
			spun = base * CFrame.Angles(age * spin.X, age * spin.Y, age * spin.Z)
		end
		local visual = entry.visual
		for index, part in visual.parts do
			table.insert(moveParts, part)
			table.insert(moveCFrames, (if visual.spins[index] then spun else base) * visual.offsets[index])
		end
		-- Effects start after the first placement, so nothing is left at the origin.
		local fire = visual.fire
		if fire and not fire.Enabled then
			fire.Enabled = true
		end
		local trail = visual.trail
		if trail and not trail.Enabled then
			trail.Enabled = true
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
