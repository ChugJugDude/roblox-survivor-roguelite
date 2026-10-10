--!strict
-- Spawns enemies during stages and overtime, following the current stage's timeline in
-- Config.Waves, with Config.Run's overtime ramp on top.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Arena = require(script.Parent.Arena)
local Characters = require(script.Parent.Characters)
local EnemyService = require(script.Parent.EnemyService)
local Run = require(script.Parent.Run)
local Config = require(ReplicatedStorage.Shared.Config.Waves)
local RunConfig = require(ReplicatedStorage.Shared.Config.Run)

local random = Random.new()
local arena: Arena.Arena? = nil
local nextSpawnAt = 0

local WaveDirector = {}

-- The latest segment whose start time has passed.
local function currentSegment(stageDef: Config.Stage, elapsed: number): Config.Segment
	local current = stageDef.segments[1]
	for _, segment in stageDef.segments do
		if segment.at <= elapsed then
			current = segment
		end
	end
	return current
end

local function pickKind(mix: { [string]: number }): string
	local total = 0
	for _, weight in mix do
		total += weight
	end
	local roll = random:NextNumber(0, total)
	local last = ""
	for kind, weight in mix do
		last = kind
		roll -= weight
		if roll <= 0 then
			return kind
		end
	end
	return last
end

-- A random point on the spawn ring around `target` that's inside the walls.
local function pickSpawnPoint(currentArena: Arena.Arena, target: Characters.Target): (number, number)
	local x, z = target.x, target.z
	for _ = 1, 8 do
		local angle = random:NextNumber(0, 2 * math.pi)
		local distance = random:NextNumber(Config.SPAWN_DISTANCE_MIN, Config.SPAWN_DISTANCE_MAX)
		x = target.x + math.cos(angle) * distance
		z = target.z + math.sin(angle) * distance
		local clampedX, clampedZ = Arena.clamp(currentArena, x, z, Config.ARENA_MARGIN)
		if clampedX == x and clampedZ == z then
			return x, z
		end
	end
	-- Unlucky picks: pull the last one inside the walls.
	return Arena.clamp(currentArena, x, z, Config.ARENA_MARGIN)
end

function WaveDirector.init(newArena: Arena.Arena)
	arena = newArena
end

function WaveDirector.step(now: number, targets: { Characters.Target })
	local currentArena = assert(arena, "WaveDirector.init() must be called first")
	if not Run.isFighting() or #targets == 0 then
		return
	end

	local stageDef = Config.STAGES[Run.getStage()]
	local segment = currentSegment(stageDef, Run.stageElapsed(now))
	local interval, maxAlive = segment.interval, segment.maxAlive
	if Run.getPhase() == "Overtime" then
		interval /= 1 + RunConfig.OVERTIME_RAMP * Run.overtimeElapsed(now)
		maxAlive = math.floor(maxAlive * RunConfig.OVERTIME_MAX_ALIVE_MULTIPLIER)
	end
	maxAlive = math.min(maxAlive, Config.HARD_CAP)

	if now < nextSpawnAt or EnemyService.count() >= maxAlive then
		return
	end
	nextSpawnAt = now + interval

	local target = targets[random:NextInteger(1, #targets)]
	local x, z = pickSpawnPoint(currentArena, target)
	EnemyService.spawn(pickKind(segment.mix), x, z, {
		health = stageDef.healthMultiplier,
		damage = stageDef.damageMultiplier,
		xp = stageDef.xpMultiplier,
	})
end

return WaveDirector
