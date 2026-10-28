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

type Look = "Normal" | "Flash" | "Chill" | "Frozen"

type Entry = {
	kind: string,
	poolKey: string, -- kind, or kind + "#Elite"
	facesTarget: boolean, -- ranged enemies aim at the nearest player
	visual: EnemyModels.Visual,
	samples: { Sample }, -- oldest first
	yaw: number,
	flashUntil: number, -- os.clock time
	chillUntil: number, -- os.clock time; slowed by Frost Nova
	frozenUntil: number, -- os.clock time; frozen by Blizzard
	look: Look, -- the colors the model has now
}

local MAX_SAMPLES = 10
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

local EnemyRenderer = {}

local function acquire(poolKey: string, kind: string, elite: boolean): EnemyModels.Visual
	local pool = pools[poolKey]
	local visual = if pool then table.remove(pool) else nil
	if not visual then
		visual = EnemyModels.create(kind, elite)
	end
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
			facesTarget = def ~= nil and def.behavior == "ranged",
			visual = acquire(poolKey, info.kind, elite),
			-- Time 0 counts as older than any snapshot, so the enemy shows at its spawn point until
			-- snapshots arrive.
			samples = { { t = 0, x = info.x, z = info.z } },
			yaw = 0,
			flashUntil = 0,
			chillUntil = 0,
			frozenUntil = 0,
			look = "Normal",
		}
	end
end

local FLASH_COLOR = Color3.new(1, 1, 1)
local CHILL_COLOR = Color3.fromRGB(150, 215, 255)
local CHILL_TINT = 0.55 -- how far a chilled enemy's colors blend toward CHILL_COLOR
local FROZEN_TINT = 0.85 -- frozen solid: nearly all ice

local function setLook(entry: Entry, look: Look)
	entry.look = look
	local visual = entry.visual
	for i, part in visual.parts do
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
			release(entry.poolKey, entry.visual)
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
		for i, part in visual.parts do
			table.insert(moveParts, part)
			table.insert(moveCFrames, root * visual.offsets[i])
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
	Remotes.WeaponEffects.OnClientEvent:Connect(onEffects)
	RunService.RenderStepped:Connect(render)
end

return EnemyRenderer
