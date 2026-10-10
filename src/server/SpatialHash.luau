--!strict
-- A uniform grid for "what's near this point" lookups on the ground plane. It stores numeric ids;
-- callers keep the actual objects and do the exact distance checks.

export type SpatialHash = {
	cellSize: number,
	cells: { [number]: { number } },
}

local SpatialHash = {}

-- Packs two cell coordinates into one table key. Fine while |cell| < 32768.
local function cellKey(cellX: number, cellZ: number): number
	return (cellX + 32768) * 65536 + (cellZ + 32768)
end

function SpatialHash.new(cellSize: number): SpatialHash
	return {
		cellSize = cellSize,
		cells = {},
	}
end

function SpatialHash.clear(hash: SpatialHash)
	table.clear(hash.cells)
end

function SpatialHash.insert(hash: SpatialHash, id: number, x: number, z: number)
	local key = cellKey(math.floor(x / hash.cellSize), math.floor(z / hash.cellSize))
	local cell = hash.cells[key]
	if cell then
		table.insert(cell, id)
	else
		hash.cells[key] = { id }
	end
end

-- Removes an id that was inserted at (x, z). For grids that aren't rebuilt every frame.
function SpatialHash.remove(hash: SpatialHash, id: number, x: number, z: number)
	local key = cellKey(math.floor(x / hash.cellSize), math.floor(z / hash.cellSize))
	local cell = hash.cells[key]
	if not cell then
		return
	end
	local index = table.find(cell, id)
	if index then
		cell[index] = cell[#cell]
		cell[#cell] = nil
	end
	if #cell == 0 then
		hash.cells[key] = nil
	end
end

-- Appends to `out` the ids in every cell touching the square around (x, z). The results can
-- include ids farther away than `radius`, so check the real distance.
function SpatialHash.query(hash: SpatialHash, x: number, z: number, radius: number, out: { number })
	local size = hash.cellSize
	for cellX = math.floor((x - radius) / size), math.floor((x + radius) / size) do
		for cellZ = math.floor((z - radius) / size), math.floor((z + radius) / size) do
			local cell = hash.cells[cellKey(cellX, cellZ)]
			if cell then
				table.move(cell, 1, #cell, #out + 1, out)
			end
		end
	end
end

return SpatialHash
