--!strict
-- Chests dropped by mini-bosses. Walking onto one gives that player a bonus upgrade pick. Chests
-- are rare and never move, so each is an ordinary anchored model in the Arena (no custom
-- replication needed).

local Arena = require(script.Parent.Arena)
local Characters = require(script.Parent.Characters)
local EnemyService = require(script.Parent.EnemyService)
local Upgrades = require(script.Parent.Upgrades)

local PICKUP_RADIUS = 4
local WOOD = Color3.fromRGB(140, 90, 45)
local GOLD = Color3.fromRGB(255, 200, 60)

type Chest = {
	model: Model,
	x: number,
	z: number,
}

local arena: Arena.Arena? = nil
local chests: { Chest } = {}
local started = false

local Chests = {}

local function makePart(parent: Instance, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material)
	local part = Instance.new("Part")
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Parent = parent
end

local function spawnChest(x: number, z: number)
	local currentArena = assert(arena, "Chests.start() must be called first")
	local base = Vector3.new(x, currentArena.origin.Y, z)
	local model = Instance.new("Model")
	model.Name = "Chest"
	makePart(model, Vector3.new(3, 1.6, 2.2), CFrame.new(base + Vector3.new(0, 0.8, 0)), WOOD, Enum.Material.Wood)
	makePart(model, Vector3.new(3.1, 0.7, 2.3), CFrame.new(base + Vector3.new(0, 1.95, 0)), WOOD, Enum.Material.Wood)
	makePart(model, Vector3.new(3.2, 0.3, 2.4), CFrame.new(base + Vector3.new(0, 1.6, 0)), GOLD, Enum.Material.Neon)
	-- A tall faint beam so the chest is easy to spot from across the arena.
	makePart(model, Vector3.new(0.6, 30, 0.6), CFrame.new(base + Vector3.new(0, 15, 0)), GOLD, Enum.Material.Neon)
	model.Parent = currentArena.model
	table.insert(chests, { model = model, x = x, z = z })
end

-- Hands out chests that a living player is standing on.
function Chests.step(targets: { Characters.Target })
	for index = #chests, 1, -1 do
		local chest = chests[index]
		for _, target in targets do
			local dx, dz = target.x - chest.x, target.z - chest.z
			if dx * dx + dz * dz <= PICKUP_RADIUS * PICKUP_RADIUS then
				chest.model:Destroy()
				table.remove(chests, index)
				Upgrades.grantBonusPick(target.player)
				break
			end
		end
	end
end

function Chests.clear()
	for _, chest in chests do
		chest.model:Destroy()
	end
	table.clear(chests)
end

function Chests.start(newArena: Arena.Arena)
	assert(not started, "Chests.start() was called twice")
	started = true
	arena = newArena
	EnemyService.onKilled(function(enemy)
		if enemy.def.dropsChest then
			spawnChest(enemy.x, enemy.z)
		end
	end)
end

return Chests
