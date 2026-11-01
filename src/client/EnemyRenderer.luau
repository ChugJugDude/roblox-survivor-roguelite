--!strict
--[[
	Draws the server's enemies. The server sends spawn/despawn events and position snapshots (see
	server/EnemyReplicator). This keeps a pool of models and draws each enemy
	INTERPOLATION_DELAY seconds in the past, blending between the two snapshots around that time,
	so movement looks smooth at any frame rate even though snapshots arrive ~20 times a second.

	Enemies face where they're going, except ranged ones, which face the nearest player in the
	arena so they visibly aim at their target.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CurrentArena = require(script.Parent.CurrentArena)
local EnemyAnimation = require(script.Parent.EnemyAnimation)
local Graphics = require(script.Parent.Graphics)
local EnemyModels = require(script.Parent.EnemyModels)
local Particles = require(script.Parent.Particles)
local ArenaConfig = require(ReplicatedStorage.Shared.Config.Arena)
local Config = require(ReplicatedStorage.Shared.Config.Enemies)
local EnemySnapshot = require(ReplicatedStorage.Shared.EnemySnapshot)
local GameClock = require(ReplicatedStorage.Shared.GameClock)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

type Sample = {
	t: number,
	x: number,
	z: number,
}

type Look = "Normal" | "Flash" | "Chill" | "Frozen"

type Entry = {
	kind: string,
	poolKey: string, -- kind, or kind + "#Elite"
	elite: boolean,
	x: number, -- where it was last drawn
	z: number,
	facesTarget: boolean, -- ranged enemies aim at the nearest player
	visual: EnemyModels.Visual,
	samples: { Sample }, -- oldest first
	yaw: number,
	flashUntil: number, -- os.clock time
	chillUntil: number, -- os.clock time; slowed by Frost Nova
	frozenUntil: number, -- os.clock time; frozen by Blizzard
	ice: BasePart?, -- an ice block around it while frozen
	look: Look, -- the colors the model has now
	animation: EnemyAnimation.Profile,
	phase: number, -- offsets its idle motion from other enemies'
	walk: number, -- walk-cycle angle, advanced by distance moved
	motion: number, -- 0 standing still to 1 walking, eased
	attackedAt: number, -- os.clock time its last contact attack landed
	windUpShape: string?, -- a boss winding up: its telegraph's shape, shown from windUpFrom to windUpTo
	windUpFrom: number,
	windUpTo: number,
}

local MAX_SAMPLES = 10
-- Moving this fast (studs/s) or faster counts as fully walking.
local FULL_WALK_SPEED = 5
-- How quickly the walk eases in and out (per second).
local WALK_EASE = 8
local GROUND_Y = ArenaConfig.ORIGIN.Y

local entries: { [number]: Entry } = {}
local pools: { [string]: { EnemyModels.Visual } } = {}
local folder: Folder? = nil
local started = false

-- Reused every frame for BulkMoveTo.
local moveParts: { BasePart } = {}
local moveCFrames: { CFrame } = {}
-- Ground positions of the players in the current arena, refreshed every frame.
local playerXs: { number } = {}
local playerZs: { number } = {}
local lastRender = os.clock()

-- Called when an enemy dies or is removed (not when the whole world resets), with where it was
-- last drawn. HitEffects uses this for death puffs.
local removedListeners: { (id: number, position: Vector3, kind: string, elite: boolean) -> () } = {}

local EnemyRenderer = {}

-- Where an enemy is drawn right now (on the floor), or nil if it isn't known.
function EnemyRenderer.getPosition(id: number): Vector3?
	local entry = entries[id]
	return if entry then Vector3.new(entry.x, GROUND_Y, entry.z) else nil
end

-- The enemy's kind and whether it's an elite, or nil if it isn't known.
function EnemyRenderer.getKind(id: number): (string?, boolean)
	local entry = entries[id]
	return if entry then entry.kind else nil, if entry then entry.elite else false
end

function EnemyRenderer.onRemoved(listener: (id: number, position: Vector3, kind: string, elite: boolean) -> ())
	table.insert(removedListeners, listener)
end

-- Applies the graphics quality to a visual's effects (emitter rates and lights).
local function applyQuality(visual: EnemyModels.Visual)
	local profile = Graphics.profile()
	for index, emitter in visual.emitters do
		emitter.Rate = visual.emitterRates[index] * profile.fireScale
	end
	for _, light in visual.lights do
		light.Enabled = profile.lights
	end
end

local function acquire(poolKey: string, kind: string, elite: boolean): EnemyModels.Visual
	local pool = pools[poolKey]
	local visual = if pool then table.remove(pool) else nil
	if not visual then
		visual = EnemyModels.create(kind, elite)
	end
	applyQuality(visual)
	visual.model.Parent = folder
	return visual
end

local function release(poolKey: string, visual: EnemyModels.Visual)
	visual.model.Parent = nil
	local pool = pools[poolKey]
	if not pool then
		pool = {}
		pools[poolKey] = pool
	end
	table.insert(pool, visual)
end

local function onSpawned(list: any)
	if typeof(list) ~= "table" then
		return
	end
	for _, info in list do
		if typeof(info) ~= "table" or entries[info.id] then
			continue
		end
		local elite = info.elite == true
		local poolKey = if elite then info.kind .. "#Elite" else info.kind
		local def = Config.TYPES[info.kind]
		entries[info.id] = {
			kind = info.kind,
			poolKey = poolKey,
			elite = elite,
			x = info.x,
			z = info.z,
			facesTarget = def ~= nil and def.behavior == "ranged",
			visual = acquire(poolKey, info.kind, elite),
			-- Time 0 counts as older than any snapshot, so the enemy shows at its spawn point until
			-- snapshots arrive.
			samples = { { t = 0, x = info.x, z = info.z } },
			yaw = 0,
			flashUntil = 0,
			chillUntil = 0,
			frozenUntil = 0,
			ice = nil,
			look = "Normal",
			animation = EnemyAnimation.profile(info.kind),
			phase = math.random() * 2 * math.pi,
			walk = math.random() * 2 * math.pi,
			motion = 0,
			attackedAt = -math.huge,
			windUpShape = nil,
			windUpFrom = 0,
			windUpTo = 0,
		}
	end
end

local FLASH_COLOR = Color3.new(1, 1, 1)
local CHILL_COLOR = Color3.fromRGB(150, 215, 255)
local CHILL_TINT = 0.55 -- how far a chilled enemy's colors blend toward CHILL_COLOR
local FROZEN_TINT = 0.85 -- frozen solid: nearly all ice
local ICE_COLOR = Color3.fromRGB(185, 225, 255)
local ICE_TRANSPARENCY = 0.4

local freeIce: { BasePart } = {}

-- An enemy's body size (bigger for elites).
local function radiusOf(entry: Entry): number
	local def = Config.TYPES[entry.kind]
	local radius = if def then def.radius else 1.5
	return if entry.elite then radius * Config.ELITE.scale else radius
end

-- The ice block's size for an enemy: a little wider than its body and about as tall as it.
local function iceSize(entry: Entry): Vector3
	local radius = radiusOf(entry)
	return Vector3.new(radius * 2.3, radius * 2 + 1.2, radius * 2.3)
end

local function addIce(entry: Entry)
	local ice = table.remove(freeIce)
	if not ice then
		local part = Instance.new("Part")
		part.Name = "Ice"
		part.Material = Enum.Material.Ice
		part.Color = ICE_COLOR
		part.Transparency = ICE_TRANSPARENCY
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		ice = part
	end
	local block = ice :: BasePart
	block.Size = iceSize(entry)
	block.Parent = folder
	entry.ice = block
	Particles.emit("IceShards", Vector3.new(entry.x, GROUND_Y + block.Size.Y / 2, entry.z), 6)
end

local function removeIce(entry: Entry)
	local ice = entry.ice
	if ice then
		entry.ice = nil
		ice.Parent = nil
		table.insert(freeIce, ice)
	end
end

local function setLook(entry: Entry, look: Look)
	entry.look = look
	local visual = entry.visual
	for i, part in visual.parts do
		local texture = visual.textures[i]
		if texture then
			-- Textured meshes ignore Color: show the flat color by taking the texture off.
			(part :: MeshPart).TextureID = if look == "Normal" then texture else ""
		end
		part.Color = if look == "Flash"
			then FLASH_COLOR
			elseif look == "Chill" then visual.colors[i]:Lerp(CHILL_COLOR, CHILL_TINT)
			elseif look == "Frozen" then visual.colors[i]:Lerp(CHILL_COLOR, FROZEN_TINT)
			else visual.colors[i]
	end
end

local function onDespawned(ids: any)
	if typeof(ids) ~= "table" then
		return
	end
	for _, id in ids do
		local entry = entries[id]
		if entry then
			entries[id] = nil
			if entry.look ~= "Normal" then
				setLook(entry, "Normal") -- pooled models must go back in their normal colors
			end
			local position = Vector3.new(entry.x, GROUND_Y, entry.z)
			for _, listener in removedListeners do
				listener(id, position, entry.kind, entry.elite)
			end
			removeIce(entry)
			release(entry.poolKey, entry.visual)
		end
	end
end

local function onHit(ids: any)
	if typeof(ids) ~= "table" then
		return
	end
	local flashUntil = os.clock() + Config.HIT_FLASH_TIME
	-- Pairs of id, damage.
	for index = 1, #ids - 1, 2 do
		local entry = entries[ids[index]]
		if entry then
			entry.flashUntil = flashUntil
		end
	end
end

local function onAttacked(ids: any)
	if typeof(ids) ~= "table" then
		return
	end
	local now = os.clock()
	for _, id in ids do
		local entry = entries[id]
		if entry then
			entry.attackedAt = now
		end
	end
end

-- Crimson like the shots themselves.
local RING_BURST_COLOR = Color3.fromRGB(230, 40, 50)

-- The burst from a boss's chest as its ring of shots flies.
local function ringBurst(entry: Entry)
	local parts = entry.visual.parts
	local chest = parts[1]
	for index, part in parts do
		if entry.visual.groups[index] == "Body" or part.Name == "Body" then
			chest = part
			break
		end
	end
	if chest then
		Particles.emit("Sparks", chest.Position, 24, RING_BURST_COLOR)
		Particles.emit("Puff", chest.Position, 8)
	end
end

-- A boss's telegraph: hold a wind-up pose until it lands. An eruption ends in a slam; a ring ends
-- with a burst as the arms fling out.
local function onTelegraph(list: any)
	if typeof(list) ~= "table" then
		return
	end
	local now = os.clock()
	for _, info in list do
		local entry = if typeof(info) == "table" then entries[info.id] else nil
		if entry and typeof(info.duration) == "number" then
			local shape = if info.shape == "Circle" or info.shape == "Ring" then info.shape else "Lane"
			entry.windUpShape = shape
			entry.windUpFrom = now
			entry.windUpTo = now + info.duration
			if shape == "Circle" then
				entry.attackedAt = entry.windUpTo
			elseif shape == "Ring" then
				local id = info.id
				task.delay(info.duration, function()
					if entries[id] == entry then
						ringBurst(entry)
					end
				end)
			end
		end
	end
end

local function onEffects(list: any)
	if typeof(list) ~= "table" then
		return
	end
	for _, info in list do
		if typeof(info) ~= "table" or info.kind ~= "Chill" or typeof(info.ids) ~= "table" then
			continue
		end
		local duration = if typeof(info.duration) == "number" then info.duration else 0
		local untilTime = os.clock() + duration
		local frozen = info.frozen == true
		for _, id in info.ids do
			local entry = entries[id]
			if entry and frozen then
				entry.frozenUntil = math.max(entry.frozenUntil, untilTime)
			elseif entry then
				entry.chillUntil = math.max(entry.chillUntil, untilTime)
			end
		end
	end
end

local function onSnapshot(packet: any)
	if typeof(packet) ~= "buffer" then
		return
	end
	local serverTime, count = EnemySnapshot.readHeader(packet)
	if not serverTime then
		return
	end
	for index = 0, count - 1 do
		local id, x, z = EnemySnapshot.readEntry(packet, index)
		local entry = entries[id]
		if not entry then
			continue
		end
		local samples = entry.samples
		if serverTime <= samples[#samples].t then
			continue -- unreliable packets can arrive late or out of order
		end
		table.insert(samples, { t = serverTime, x = x, z = z })
		if #samples > MAX_SAMPLES then
			table.remove(samples, 1)
		end
	end
end

-- Position at `renderTime` plus the direction of travel (unnormalized; zero when not moving).
local function samplePosition(entry: Entry, renderTime: number): (number, number, number, number)
	local samples = entry.samples
	-- Drop samples we've moved past, keeping the one at or just before renderTime.
	while #samples >= 2 and samples[2].t <= renderTime do
		table.remove(samples, 1)
	end

	local a = samples[1]
	local b = samples[2]
	if not b then
		return a.x, a.z, 0, 0 -- no newer snapshot yet: hold still
	end
	local alpha = math.clamp((renderTime - a.t) / (b.t - a.t), 0, 1)
	return a.x + (b.x - a.x) * alpha, a.z + (b.z - a.z) * alpha, b.x - a.x, b.z - a.z
end

local function render()
	local currentArena = CurrentArena.get()
	if not currentArena then
		return
	end
	local renderTime = GameClock.read(currentArena) - Config.INTERPOLATION_DELAY
	table.clear(moveParts)
	table.clear(moveCFrames)
	table.clear(playerXs)
	table.clear(playerZs)
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") and player:GetAttribute("ArenaName") == currentArena.Name then
			table.insert(playerXs, root.Position.X)
			table.insert(playerZs, root.Position.Z)
		end
	end

	local clock = os.clock()
	local dt = math.clamp(clock - lastRender, 0, 0.1)
	lastRender = clock
	for _, entry in entries do
		local look: Look = if clock < entry.flashUntil
			then "Flash"
			elseif clock < entry.frozenUntil then "Frozen"
			elseif clock < entry.chillUntil then "Chill"
			else "Normal"
		if look ~= entry.look then
			setLook(entry, look)
		end
		local x, z, dirX, dirZ = samplePosition(entry, renderTime)
		-- A long jump (a respawned pool visual) isn't a walk.
		local moved = math.min(2, math.sqrt((x - entry.x) ^ 2 + (z - entry.z) ^ 2))
		entry.x, entry.z = x, z
		entry.walk += moved * entry.animation.stride
		local walking = if dt > 0 then math.clamp(moved / dt / FULL_WALK_SPEED, 0, 1) else entry.motion
		entry.motion += (walking - entry.motion) * math.min(1, dt * WALK_EASE)
		-- The ice block follows the freeze itself, not the colors (a hit flash shouldn't melt it).
		local frozen = clock < entry.frozenUntil
		if frozen and not entry.ice then
			addIce(entry)
		elseif not frozen and entry.ice then
			removeIce(entry)
		end
		local ice = entry.ice
		if ice then
			table.insert(moveParts, ice)
			table.insert(moveCFrames, CFrame.new(x, GROUND_Y + ice.Size.Y / 2, z))
		end
		if entry.facesTarget and #playerXs > 0 then
			-- Aim at the nearest player.
			local bestDistSq = math.huge
			for i, px in playerXs do
				local dx, dz = px - x, playerZs[i] - z
				local distSq = dx * dx + dz * dz
				if distSq < bestDistSq then
					bestDistSq, dirX, dirZ = distSq, dx, dz
				end
			end
		end
		if dirX * dirX + dirZ * dirZ > 1e-4 then
			-- Face the direction of travel. A yaw of 0 faces -Z.
			entry.yaw = math.atan2(-dirX, -dirZ)
		end
		local root = CFrame.new(x, GROUND_Y, z) * CFrame.Angles(0, entry.yaw, 0)
		local visual = entry.visual
		-- Frozen enemies hold still.
		local body, swing, flap, strike, raise, spread = CFrame.identity, 0, 0, 0, 0, 0
		if not frozen then
			local tilt = 0
			local shape = entry.windUpShape
			if shape then
				raise, spread, tilt = EnemyAnimation.windUp(shape, entry.windUpFrom, entry.windUpTo, clock)
			end
			body, swing, flap, strike = EnemyAnimation.pose(
				entry.animation,
				entry.walk,
				entry.motion,
				clock + entry.phase,
				clock - entry.attackedAt,
				tilt
			)
		end
		local groups, joints, offsets = visual.groups, visual.joints, visual.offsets
		for i, part in visual.parts do
			table.insert(moveParts, part)
			table.insert(
				moveCFrames,
				root * EnemyAnimation.place(groups, joints, offsets[i], i, body, swing, flap, strike, raise, spread)
			)
		end
	end

	if #moveParts > 0 then
		workspace:BulkMoveTo(moveParts, moveCFrames, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

-- Drops every enemy (the player moved to another world).
local function reset()
	for id, entry in entries do
		if entry.look ~= "Normal" then
			setLook(entry, "Normal")
		end
		removeIce(entry)
		release(entry.poolKey, entry.visual)
		entries[id] = nil
	end
end

function EnemyRenderer.start()
	assert(not started, "EnemyRenderer.start() was called twice")
	started = true
	CurrentArena.onReset(reset)

	local newFolder = Instance.new("Folder")
	newFolder.Name = "EnemyVisuals"
	newFolder.Parent = workspace
	folder = newFolder

	Remotes.EnemySpawned.OnClientEvent:Connect(onSpawned)
	Remotes.EnemyDespawned.OnClientEvent:Connect(onDespawned)
	Remotes.EnemySnapshot.OnClientEvent:Connect(onSnapshot)
	Remotes.EnemiesHit.OnClientEvent:Connect(onHit)
	Remotes.EnemyAttacked.OnClientEvent:Connect(onAttacked)
	Remotes.EnemyTelegraph.OnClientEvent:Connect(onTelegraph)
	Remotes.WeaponEffects.OnClientEvent:Connect(onEffects)
	RunService.RenderStepped:Connect(render)
end

return EnemyRenderer
