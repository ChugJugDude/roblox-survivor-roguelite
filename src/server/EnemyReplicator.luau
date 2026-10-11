--!strict
-- Sends one match's enemy positions to its members as unreliable snapshots at
-- Config.Enemies.SNAPSHOT_RATE. Spawns and despawns go through the match's NetBatch (EnemyService
-- pushes them), and syncTo catches up a player who just entered the arena.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EnemyService = require(script.Parent.EnemyService)
local Config = require(ReplicatedStorage.Shared.Config.Enemies)
local EnemySnapshot = require(ReplicatedStorage.Shared.EnemySnapshot)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local SNAPSHOT_INTERVAL = 1 / Config.SNAPSHOT_RATE

export type State = {
	enemies: EnemyService.State,
	nextSnapshotAt: number,
}

local list: { EnemyService.Enemy } = {} -- reused every snapshot

local EnemyReplicator = {}

function EnemyReplicator.new(enemies: EnemyService.State): State
	return { enemies = enemies, nextSnapshotAt = 0 }
end

function EnemyReplicator.step(state: State, now: number, members: { Player })
	if now < state.nextSnapshotAt then
		return
	end
	state.nextSnapshotAt = now + SNAPSHOT_INTERVAL

	table.clear(list)
	for _, enemy in EnemyService.getAll(state.enemies) do
		table.insert(list, enemy)
	end
	local maxPerPacket = EnemySnapshot.MAX_ENTRIES_PER_PACKET
	for first = 1, #list, maxPerPacket do
		local count = math.min(maxPerPacket, #list - first + 1)
		local packet = EnemySnapshot.create(now, count)
		for i = 0, count - 1 do
			local enemy = list[first + i]
			EnemySnapshot.write(packet, i, enemy.id, enemy.x, enemy.z)
		end
		for _, player in members do
			Remotes.EnemySnapshot:FireClient(player, packet)
		end
	end
end

-- Sends every living enemy to one player (who just entered this match's arena).
function EnemyReplicator.syncTo(state: State, player: Player)
	local current: { EnemySnapshot.SpawnInfo } = {}
	for id, enemy in EnemyService.getAll(state.enemies) do
		table.insert(current, { id = id, kind = enemy.kind, x = enemy.x, z = enemy.z })
	end
	if #current > 0 then
		Remotes.EnemySpawned:FireClient(player, current)
	end
end

return EnemyReplicator
