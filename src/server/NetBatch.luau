--!strict
-- Collects server -> client events during a frame and sends each remote's batch once, as a list,
-- when Simulation calls flush. Remotes flush in the order they were registered, so for example a
-- gem's "spawned" event always arrives before its "collected" event from the same frame.

local NetBatch = {}

local order: { RemoteEvent } = {}
local queues: { [RemoteEvent]: { any } } = {}

function NetBatch.register(remote: RemoteEvent)
	if queues[remote] then
		return
	end
	table.insert(order, remote)
	queues[remote] = {}
end

function NetBatch.push(remote: RemoteEvent, item: any)
	local queue = queues[remote]
	assert(queue, `{remote.Name} isn't registered with NetBatch`)
	table.insert(queue, item)
end

function NetBatch.flush()
	for _, remote in order do
		local queue = queues[remote]
		if #queue > 0 then
			queues[remote] = {}
			remote:FireAllClients(queue)
		end
	end
end

return NetBatch
