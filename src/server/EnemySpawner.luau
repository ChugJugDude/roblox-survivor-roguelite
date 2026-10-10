--!strict
-- M0 placeholder spawner: keeps enemies coming around living players. M1's wave director
-- replaces it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Arena = require(script.Parent.Arena)
local Characters = require(script.Parent.Characters)
local EnemyService = require(script.Parent.EnemyService)
local Config = require(ReplicatedStorage.Shared.Config.Spawning)

local random = Random.new()
local arena: Arena.Arena? = nil
local nextSpawnAt = 0

local EnemySpawner = {}

-- A random point on the spawn ring around `target` that's inside the walls.
local function pickSpawnPoint(currentArena: Arena.Arena, target: Characters.Target): (number, number)
	local limit = currentArena.halfSize - Config.ARENA_MARGIN
	local origin = currentArena.origin
	local x, z = target.x, target.z
	for _ = 1, 8 do
		local angle = random:NextNumber(0, 2 * math.pi)
		local distance = random:NextNumber(Config.SPAWN_DISTANCE_MIN, Config.SPAWN_DISTANCE_MAX)
		x = target.x + math.cos(angle) * distance
		z = target.z + math.sin(angle) * distance
		if math.abs(x - origin.X) <= limit and math.abs(z - origin.Z) <= limit then
			return x, z
		end
	end
	-- Unlucky picks: pull the last one inside the walls.
	return Arena.clamp(currentArena, x, z, Config.ARENA_MARGIN)
end

function EnemySpawner.init(newArena: Arena.Arena)
	arena = newArena
end

function EnemySpawner.step(now: number, targets: { Characters.Target })
	local currentArena = assert(arena, "EnemySpawner.init() must be called first")

	if #targets == 0 then
		-- Everyone is dead: clear the field so respawning players start fresh.
		if EnemyService.count() > 0 then
			EnemyService.clear()
		end
		return
	end

	if now < nextSpawnAt or EnemyService.count() >= Config.MAX_ALIVE then
		return
	end
	nextSpawnAt = now + Config.SPAWN_INTERVAL

	local target = targets[random:NextInteger(1, #targets)]
	local x, z = pickSpawnPoint(currentArena, target)
	EnemyService.spawn(Config.ENEMY_KIND, x, z)
end

return EnemySpawner
