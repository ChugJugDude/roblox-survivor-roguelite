--!strict
-- Sends enemies to clients: spawns and despawns reliably, positions as unreliable snapshots at
-- Config.Enemies.SNAPSHOT_RATE.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EnemyService = require(script.Parent.EnemyService)
local Config = require(ReplicatedStorage.Shared.Config.Enemies)
local EnemySnapshot = require(ReplicatedStorage.Shared.EnemySnapshot)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local SNAPSHOT_INTERVAL = 1 / Config.SNAPSHOT_RATE

local nextSnapshotAt = 0
local started = false

local EnemyReplicator = {}

local function sendSnapshots(now: number)
	local list: { EnemyService.Enemy } = {}
	for _, enemy in EnemyService.getAll() do
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
		Remotes.EnemySnapshot:FireAllClients(packet)
	end
end

function EnemyReplicator.start()
	assert(not started, "EnemyReplicator.start() was called twice")
	started = true

	-- Players who join mid-fight need every enemy that's already alive. Remote events queue on the
	-- client until a listener connects, so sending right away is safe.
	Players.PlayerAdded:Connect(function(player)
		local current: { EnemySnapshot.SpawnInfo } = {}
		for id, enemy in EnemyService.getAll() do
			table.insert(current, { id = id, kind = enemy.kind, x = enemy.x, z = enemy.z })
		end
		if #current > 0 then
			Remotes.EnemySpawned:FireClient(player, current)
		end
	end)
end

function EnemyReplicator.step(now: number)
	-- Spawns before despawns, so an enemy that spawned and died in the same frame is gone on the
	-- client too.
	local spawned, despawned = EnemyService.takeChanges()
	if #spawned > 0 then
		Remotes.EnemySpawned:FireAllClients(spawned)
	end
	if #despawned > 0 then
		Remotes.EnemyDespawned:FireAllClients(despawned)
	end

	if now >= nextSnapshotAt then
		nextSnapshotAt = now + SNAPSHOT_INTERVAL
		sendSnapshots(now)
	end
end

return EnemyReplicator
