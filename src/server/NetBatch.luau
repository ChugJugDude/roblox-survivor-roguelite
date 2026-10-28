--!strict
-- Collects one match's server -> client events during a frame and sends each remote's batch once,
-- as a list, to that match's members. Every batch sends remotes in the same fixed order, so for
-- example an enemy's "spawned" event always arrives before its "despawned" event from the same
-- frame, and a gem's "spawned" before its "collected".

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

export type Batch = {
	queues: { [RemoteEvent]: { any } },
}

local ORDER: { RemoteEvent } = {
	Remotes.EnemySpawned,
	Remotes.EnemyDespawned,
	Remotes.EnemiesHit,
	Remotes.GemsSpawned,
	Remotes.GemsCollected,
	Remotes.ProjectilesSpawned,
	Remotes.ProjectilesRemoved,
	Remotes.Explosions,
	Remotes.WeaponEffects,
	Remotes.EnemyTelegraph,
}

local NetBatch = {}

function NetBatch.new(): Batch
	local queues = {}
	for _, remote in ORDER do
		queues[remote] = {}
	end
	return { queues = queues }
end

function NetBatch.push(batch: Batch, remote: RemoteEvent, item: any)
	local queue = batch.queues[remote]
	assert(queue, `{remote.Name} isn't one of NetBatch's remotes`)
	table.insert(queue, item)
end

-- Sends everything queued to `players` and empties the batch.
function NetBatch.flush(batch: Batch, players: { Player })
	for _, remote in ORDER do
		local queue = batch.queues[remote]
		if #queue > 0 then
			batch.queues[remote] = {}
			for _, player in players do
				remote:FireClient(player, queue)
			end
		end
	end
end

return NetBatch
