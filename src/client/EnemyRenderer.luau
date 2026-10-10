--!strict
--[[
	Draws the server's enemies. The server sends spawn/despawn events and position snapshots (see
	server/EnemyReplicator). This keeps a pool of models and draws each enemy
	INTERPOLATION_DELAY seconds in the past, blending between the two snapshots around that time,
	so movement looks smooth at any frame rate even though snapshots arrive ~20 times a second.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EnemyModels = require(script.Parent.EnemyModels)
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

type Entry = {
	kind: string,
	visual: EnemyModels.Visual,
	samples: { Sample }, -- oldest first
	yaw: number,
	flashUntil: number, -- os.clock time
	flashing: boolean,
}

local MAX_SAMPLES = 10
local GROUND_Y = ArenaConfig.ORIGIN.Y

local entries: { [number]: Entry } = {}
local pools: { [string]: { EnemyModels.Visual } } = {}
local folder: Folder? = nil
local arena: Instance? = nil
local started = false

-- Reused every frame for BulkMoveTo.
local moveParts: { BasePart } = {}
local moveCFrames: { CFrame } = {}

local EnemyRenderer = {}

local function acquire(kind: string): EnemyModels.Visual
	local pool = pools[kind]
	local visual = if pool then table.remove(pool) else nil
	if not visual then
		visual = EnemyModels.create(kind)
	end
	visual.model.Parent = folder
	return visual
end

local function release(kind: string, visual: EnemyModels.Visual)
	visual.model.Parent = nil
	local pool = pools[kind]
	if not pool then
		pool = {}
		pools[kind] = pool
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
		entries[info.id] = {
			kind = info.kind,
			visual = acquire(info.kind),
			-- Time 0 counts as older than any snapshot, so the enemy shows at its spawn point until
			-- snapshots arrive.
			samples = { { t = 0, x = info.x, z = info.z } },
			yaw = 0,
			flashUntil = 0,
			flashing = false,
		}
	end
end

local FLASH_COLOR = Color3.new(1, 1, 1)

local function setFlash(entry: Entry, on: boolean)
	entry.flashing = on
	local visual = entry.visual
	for i, part in visual.parts do
		part.Color = if on then FLASH_COLOR else visual.colors[i]
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
			if entry.flashing then
				setFlash(entry, false) -- pooled models must go back in their normal colors
			end
			release(entry.kind, entry.visual)
		end
	end
end

local function onHit(ids: any)
	if typeof(ids) ~= "table" then
		return
	end
	local flashUntil = os.clock() + Config.HIT_FLASH_TIME
	for _, id in ids do
		local entry = entries[id]
		if entry then
			entry.flashUntil = flashUntil
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
	local currentArena = arena
	if not currentArena then
		return
	end
	local renderTime = GameClock.read(currentArena) - Config.INTERPOLATION_DELAY
	table.clear(moveParts)
	table.clear(moveCFrames)

	local clock = os.clock()
	for _, entry in entries do
		local shouldFlash = clock < entry.flashUntil
		if shouldFlash ~= entry.flashing then
			setFlash(entry, shouldFlash)
		end
		local x, z, dirX, dirZ = samplePosition(entry, renderTime)
		if dirX * dirX + dirZ * dirZ > 1e-4 then
			-- Face the direction of travel. A yaw of 0 faces -Z.
			entry.yaw = math.atan2(-dirX, -dirZ)
		end
		local root = CFrame.new(x, GROUND_Y, z) * CFrame.Angles(0, entry.yaw, 0)
		local visual = entry.visual
		for i, part in visual.parts do
			table.insert(moveParts, part)
			table.insert(moveCFrames, root * visual.offsets[i])
		end
	end

	if #moveParts > 0 then
		workspace:BulkMoveTo(moveParts, moveCFrames, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

function EnemyRenderer.start(newArena: Instance)
	assert(not started, "EnemyRenderer.start() was called twice")
	started = true
	arena = newArena

	local newFolder = Instance.new("Folder")
	newFolder.Name = "EnemyVisuals"
	newFolder.Parent = workspace
	folder = newFolder

	Remotes.EnemySpawned.OnClientEvent:Connect(onSpawned)
	Remotes.EnemyDespawned.OnClientEvent:Connect(onDespawned)
	Remotes.EnemySnapshot.OnClientEvent:Connect(onSnapshot)
	Remotes.EnemiesHit.OnClientEvent:Connect(onHit)
	RunService.RenderStepped:Connect(render)
end

return EnemyRenderer
