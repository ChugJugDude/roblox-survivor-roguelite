--!strict
-- Draws projectiles and explosions. Projectiles fly in straight lines, so each one is placed from its
-- spawn event and the shared server clock until it reaches max distance or the server removes it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local CurrentArena = require(script.Parent.CurrentArena)
local ArenaConfig = require(ReplicatedStorage.Shared.Config.Arena)
local EntityNet = require(ReplicatedStorage.Shared.EntityNet)
local GameClock = require(ReplicatedStorage.Shared.GameClock)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

type Look = {
	size: Vector3,
	color: Color3,
	shape: Enum.PartType,
	height: number, -- above the floor
	material: Enum.Material?, -- default Neon
}

local LOOKS: { [string]: Look } = {
	Arrow = {
		size = Vector3.new(0.3, 0.3, 2.4),
		color = Color3.fromRGB(255, 235, 170),
		shape = Enum.PartType.Block,
		height = 2.5,
	},
	Fireball = {
		size = Vector3.new(1.8, 1.8, 1.8),
		color = Color3.fromRGB(255, 120, 30),
		shape = Enum.PartType.Ball,
		height = 3,
	},
	Meteor = {
		size = Vector3.new(3.4, 3.4, 3.4),
		color = Color3.fromRGB(255, 70, 20),
		shape = Enum.PartType.Ball,
		height = 4,
	},
	-- Enemy shots must read at a glance over anything the player has: a solid crimson orb (not neon,
	-- whose glow washes red toward orange next to gold) flying above the blades, so the top-down
	-- camera always draws it on top.
	EnemyArrow = {
		size = Vector3.new(1.9, 1.9, 1.9),
		color = Color3.fromRGB(190, 0, 35),
		shape = Enum.PartType.Ball,
		height = 4.5,
		material = Enum.Material.SmoothPlastic,
	},
	-- A boss's ring shot: the same crimson orb, bigger.
	BossOrb = {
		size = Vector3.new(2.6, 2.6, 2.6),
		color = Color3.fromRGB(190, 0, 35),
		shape = Enum.PartType.Ball,
		height = 4.5,
		material = Enum.Material.SmoothPlastic,
	},
}
local EXPLOSION_COLOR = Color3.fromRGB(255, 140, 40)
local EXPLOSION_TIME = 0.3
local SHOCKWAVE_COLOR = Color3.fromRGB(255, 235, 200)
local SHOCKWAVE_TIME = 0.5

type Active = {
	info: EntityNet.ProjectileInfo,
	part: BasePart,
	kind: string,
	facing: CFrame, -- rotation only
	height: number,
}

local active: { [number]: Active } = {}
local pools: { [string]: { BasePart } } = {}
local folder: Folder? = nil
local started = false

-- Reused every frame for BulkMoveTo.
local moveParts: { BasePart } = {}
local moveCFrames: { CFrame } = {}

local ProjectileRenderer = {}

local function acquire(kind: string): BasePart
	local pool = pools[kind]
	local part = if pool then table.remove(pool) else nil
	if not part then
		local look = LOOKS[kind] or LOOKS.Arrow
		local newPart = Instance.new("Part")
		newPart.Name = kind
		newPart.Shape = look.shape
		newPart.Size = look.size
		newPart.Color = look.color
		newPart.Material = look.material or Enum.Material.Neon
		newPart.Anchored = true
		newPart.CanCollide = false
		newPart.CanQuery = false
		newPart.CanTouch = false
		newPart.CastShadow = false
		part = newPart
	end
	part.Parent = folder
	return part
end

local function release(entry: Active)
	entry.part.Parent = nil
	local pool = pools[entry.kind]
	if not pool then
		pool = {}
		pools[entry.kind] = pool
	end
	table.insert(pool, entry.part)
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
			part = acquire(kind),
			kind = kind,
			facing = CFrame.lookAt(Vector3.zero, Vector3.new(info.dirX, 0, info.dirZ)),
			height = ArenaConfig.ORIGIN.Y + LOOKS[kind].height,
		}
	end
end

local function onRemoved(ids: any)
	if typeof(ids) ~= "table" then
		return
	end
	for _, id in ids do
		local entry = active[id]
		if entry then
			active[id] = nil
			release(entry)
		end
	end
end

local function onExplosions(list: any)
	if typeof(list) ~= "table" then
		return
	end
	for _, info in list do
		if typeof(info) ~= "table" then
			continue
		end
		-- A bomb covers about a screen, so it's a flat ring racing outward along the floor rather than a
		-- sphere that would swallow the camera.
		local isBomb = info.kind == "Bomb"
		local blast = Instance.new("Part")
		blast.Name = "Explosion"
		blast.Shape = if isBomb then Enum.PartType.Cylinder else Enum.PartType.Ball
		blast.Size = if isBomb then Vector3.new(0.4, 1, 1) else Vector3.one
		blast.Color = if isBomb then SHOCKWAVE_COLOR else EXPLOSION_COLOR
		blast.Material = Enum.Material.Neon
		blast.Transparency = 0.2
		blast.Anchored = true
		blast.CanCollide = false
		blast.CanQuery = false
		blast.CanTouch = false
		blast.CastShadow = false
		local center = Vector3.new(info.x, ArenaConfig.ORIGIN.Y + 1, info.z)
		-- A cylinder's axis is its X size; turn it upright so it lies flat as a disc.
		blast.CFrame = if isBomb then CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)) else CFrame.new(center)
		blast.Parent = folder
		local diameter = info.radius * 2
		local tween = TweenService:Create(
			blast,
			TweenInfo.new(if isBomb then SHOCKWAVE_TIME else EXPLOSION_TIME, Enum.EasingStyle.Quad),
			{
				Size = if isBomb then Vector3.new(0.4, diameter, diameter) else Vector3.one * diameter,
				Transparency = 1,
			}
		)
		tween.Completed:Once(function()
			blast:Destroy()
		end)
		tween:Play()
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
		local distance = (now - info.startedAt) * info.speed
		if distance >= info.maxDistance then
			active[id] = nil
			release(entry)
			continue
		end
		distance = math.max(distance, 0)
		local position = Vector3.new(info.x + info.dirX * distance, entry.height, info.z + info.dirZ * distance)
		table.insert(moveParts, entry.part)
		table.insert(moveCFrames, CFrame.new(position) * entry.facing)
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
