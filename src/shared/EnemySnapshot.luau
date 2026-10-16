--!strict
--[[
	Wire format for enemy replication (server/EnemyReplicator -> client/EnemyRenderer).

	Spawns go out reliably as a list of SpawnInfo. Positions go out as compact buffers over an
	UnreliableRemoteEvent:
		header: f64 server time, u16 entry count
		entry:  u16 enemy id, f32 x, f32 z
	Unreliable payloads are capped at about 900 bytes, so a big crowd is split across packets of
	MAX_ENTRIES_PER_PACKET.
]]

export type SpawnInfo = {
	id: number,
	kind: string,
	x: number,
	z: number,
	elite: boolean?, -- drawn bigger, with a glow
}

local HEADER_SIZE = 10
local ENTRY_SIZE = 10

local EnemySnapshot = {
	MAX_ENTRIES_PER_PACKET = 80,
}

function EnemySnapshot.create(serverTime: number, count: number): buffer
	local packet = buffer.create(HEADER_SIZE + count * ENTRY_SIZE)
	buffer.writef64(packet, 0, serverTime)
	buffer.writeu16(packet, 8, count)
	return packet
end

-- `index` is 0-based.
function EnemySnapshot.write(packet: buffer, index: number, id: number, x: number, z: number)
	local offset = HEADER_SIZE + index * ENTRY_SIZE
	buffer.writeu16(packet, offset, id)
	buffer.writef32(packet, offset + 2, x)
	buffer.writef32(packet, offset + 6, z)
end

-- Returns the packet's server time and entry count, or nil if the packet is malformed.
function EnemySnapshot.readHeader(packet: buffer): (number?, number)
	local length = buffer.len(packet)
	if length < HEADER_SIZE then
		return nil, 0
	end
	local count = buffer.readu16(packet, 8)
	if length < HEADER_SIZE + count * ENTRY_SIZE then
		return nil, 0
	end
	return buffer.readf64(packet, 0), count
end

-- Returns id, x, z for entry `index` (0-based). Call readHeader first to validate the packet.
function EnemySnapshot.readEntry(packet: buffer, index: number): (number, number, number)
	local offset = HEADER_SIZE + index * ENTRY_SIZE
	return buffer.readu16(packet, offset), buffer.readf32(packet, offset + 2), buffer.readf32(packet, offset + 6)
end

return EnemySnapshot
