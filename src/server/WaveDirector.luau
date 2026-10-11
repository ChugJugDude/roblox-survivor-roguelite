--!strict
-- Spawns one match's enemies during stages and overtime, following the current stage's timeline in
-- Config.Waves, with Config.Run's overtime ramp on top, plus each stage's mini-boss and supply
-- crates.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Arena = require(script.Parent.Arena)
local Characters = require(script.Parent.Characters)
local EnemyService = require(script.Parent.EnemyService)
local EnemyConfig = require(ReplicatedStorage.Shared.Config.Enemies)
local Config = require(ReplicatedStorage.Shared.Config.Waves)
local RunConfig = require(ReplicatedStorage.Shared.Config.Run)

-- What the wave director needs to know about the run this frame (the match fills it in).
export type RunView = {
	fighting: boolean, -- in a stage or its overtime
	stage: number,
	stageElapsed: number, -- seconds since the stage started, counting on through overtime
	overtime: boolean,
	overtimeElapsed: number, -- 0 outside overtime
}

export type State = {
	arena: Arena.Arena,
	enemies: EnemyService.State,
	nextSpawnAt: number,
	miniBossSpawned: boolean,
	cratesSpawned: number, -- crates due so far this stage
}

local random = Random.new()

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

local function atCap(enemies: EnemyService.State, kind: string): boolean
	local cap = Config.KIND_CAPS[kind]
	return cap ~= nil and EnemyService.countKind(enemies, kind) >= cap
end

-- A weighted pick from the mix, leaving out kinds at their cap. Nil if every kind is capped.
local function pickKind(enemies: EnemyService.State, mix: { [string]: number }): string?
	local total = 0
	for kind, weight in mix do
		if not atCap(enemies, kind) then
			total += weight
		end
	end
	if total <= 0 then
		return nil
	end
	local roll = random:NextNumber(0, total)
	local last: string? = nil
	for kind, weight in mix do
		if atCap(enemies, kind) then
			continue
		end
		last = kind
		roll -= weight
		if roll <= 0 then
			return kind
		end
	end
	return last
end

-- A random point on a ring around `target` that's inside the walls. Defaults to the enemy spawn
-- ring.
local function pickSpawnPoint(
	currentArena: Arena.Arena,
	target: Characters.Target,
	minDistance: number?,
	maxDistance: number?
): (number, number)
	local x, z = target.x, target.z
	for _ = 1, 8 do
		local angle = random:NextNumber(0, 2 * math.pi)
		local distance =
			random:NextNumber(minDistance or Config.SPAWN_DISTANCE_MIN, maxDistance or Config.SPAWN_DISTANCE_MAX)
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

function WaveDirector.new(arena: Arena.Arena, enemies: EnemyService.State): State
	return { arena = arena, enemies = enemies, nextSpawnAt = 0, miniBossSpawned = false, cratesSpawned = 0 }
end

function WaveDirector.step(state: State, now: number, targets: { Characters.Target }, run: RunView)
	if not run.fighting or #targets == 0 then
		return
	end
	local currentArena = state.arena
	local enemies = state.enemies

	local stageDef = Config.STAGES[run.stage]
	local segment = currentSegment(stageDef, run.stageElapsed)
	local interval, maxAlive = segment.interval, segment.maxAlive
	if run.overtime then
		interval /= 1 + RunConfig.OVERTIME_RAMP * run.overtimeElapsed
		maxAlive = math.floor(maxAlive * RunConfig.OVERTIME_MAX_ALIVE_MULTIPLIER)
	end
	maxAlive = math.min(maxAlive, Config.HARD_CAP)

	local scaling: EnemyService.Scaling = {
		health = stageDef.healthMultiplier,
		damage = stageDef.damageMultiplier,
		xp = stageDef.xpMultiplier,
	}

	-- The mini-boss arrives once per stage. Before its time comes around (including after a stage
	-- restarts), it's due again.
	local miniBossAt = stageDef.miniBossAt
	if stageDef.miniBoss and miniBossAt then
		if run.stageElapsed < miniBossAt then
			state.miniBossSpawned = false
		elseif not state.miniBossSpawned then
			state.miniBossSpawned = true
			local target = targets[random:NextInteger(1, #targets)]
			local x, z = pickSpawnPoint(currentArena, target)
			EnemyService.spawn(enemies, stageDef.miniBoss, x, z, scaling)
		end
	end

	-- A supply crate every CRATE_INTERVAL seconds of the stage (counting resets each stage).
	local cratesDue = math.floor(run.stageElapsed / Config.CRATE_INTERVAL)
	if cratesDue < state.cratesSpawned then
		state.cratesSpawned = cratesDue -- a new stage started
	elseif cratesDue > state.cratesSpawned then
		state.cratesSpawned = cratesDue
		if EnemyService.countKind(enemies, "Crate") < Config.CRATE_MAX then
			local target = targets[random:NextInteger(1, #targets)]
			local x, z = pickSpawnPoint(currentArena, target, Config.CRATE_DISTANCE_MIN, Config.CRATE_DISTANCE_MAX)
			EnemyService.spawn(enemies, "Crate", x, z)
		end
	end

	if now < state.nextSpawnAt or EnemyService.count(enemies) >= maxAlive then
		return
	end
	state.nextSpawnAt = now + interval

	local kind = pickKind(enemies, segment.mix)
	if not kind then
		return
	end
	local target = targets[random:NextInteger(1, #targets)]
	local x, z = pickSpawnPoint(currentArena, target)
	local groupSize = EnemyConfig.TYPES[kind].groupSize or 1
	for _ = 1, groupSize do
		local scatterX = if groupSize > 1 then random:NextNumber(-1, 1) * Config.GROUP_SCATTER else 0
		local scatterZ = if groupSize > 1 then random:NextNumber(-1, 1) * Config.GROUP_SCATTER else 0
		local spawnX, spawnZ = Arena.clamp(currentArena, x + scatterX, z + scatterZ, Config.ARENA_MARGIN)
		EnemyService.spawn(enemies, kind, spawnX, spawnZ, scaling)
	end
end

return WaveDirector
