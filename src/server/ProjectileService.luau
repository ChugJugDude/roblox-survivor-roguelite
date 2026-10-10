--!strict
--[[
	Projectiles: straight-line shots simulated on the server. Player shots hit enemies (arrows pierce,
	fireballs explode); enemy shots hit players through Characters.damage.

	Clients get one spawn event per projectile and work out its position themselves, since it flies
	in a straight line. Removal is only sent when a projectile stops early; at max distance it just
	expires on both sides. Explosions are sent for their visuals.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Characters = require(script.Parent.Characters)
local EnemyService = require(script.Parent.EnemyService)
local NetBatch = require(script.Parent.NetBatch)
local Pause = require(script.Parent.Pause)
local EnemyConfig = require(ReplicatedStorage.Shared.Config.Enemies)
local EntityNet = require(ReplicatedStorage.Shared.EntityNet)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

-- Longest distance a projectile moves between hit checks, so fast shots can't skip over enemies.
local MAX_SUBSTEP = 1

export type Spec = {
	kind: EntityNet.ProjectileKind,
	fromEnemy: boolean, -- enemy shots hit players; player shots hit enemies
	owner: any, -- who gets credit, for per-attacker hit cooldowns
	x: number,
	z: number,
	dirX: number, -- unit direction
	dirZ: number,
	speed: number,
	maxDistance: number,
	radius: number,
	damage: number,
	pierce: number, -- enemies it can hit before stopping (player shots)
	blastRadius: number?, -- explodes on impact or at max distance when set
}

type Projectile = Spec & {
	id: number,
	traveled: number,
	hits: { [EnemyService.Enemy]: boolean },
}

local projectiles: { [number]: Projectile } = {}
local nextId = 0
local nearby: { EnemyService.Enemy } = {} -- reused for every query
local started = false

local ProjectileService = {}

local function remove(projectile: Projectile, notify: boolean)
	projectiles[projectile.id] = nil
	if notify then
		NetBatch.push(Remotes.ProjectilesRemoved, projectile.id)
	end
end

local function explode(projectile: Projectile, x: number, z: number)
	local radius = projectile.blastRadius or 0
	table.clear(nearby)
	EnemyService.queryRadius(x, z, radius, nearby)
	for _, enemy in nearby do
		EnemyService.damage(enemy, projectile.damage)
	end
	NetBatch.push(Remotes.Explosions, { x = x, z = z, radius = radius })
end

-- Checks a player shot at (x, z). Returns true if the projectile is used up.
local function hitEnemies(projectile: Projectile, x: number, z: number): boolean
	table.clear(nearby)
	EnemyService.queryRadius(x, z, projectile.radius, nearby)
	for _, enemy in nearby do
		if projectile.hits[enemy] then
			continue
		end
		if projectile.blastRadius then
			explode(projectile, x, z)
			return true
		end
		projectile.hits[enemy] = true
		EnemyService.damage(enemy, projectile.damage)
		projectile.pierce -= 1
		if projectile.pierce <= 0 then
			return true
		end
	end
	return false
end

-- Checks an enemy shot at (x, z). Returns true if it hit a player.
local function hitPlayers(
	projectile: Projectile,
	x: number,
	z: number,
	now: number,
	targets: { Characters.Target }
): boolean
	local reach = projectile.radius + EnemyConfig.PLAYER_RADIUS
	for _, target in targets do
		local dx, dz = target.x - x, target.z - z
		if dx * dx + dz * dz <= reach * reach then
			Characters.damage(target, projectile.damage, now)
			return true
		end
	end
	return false
end

function ProjectileService.spawn(spec: Spec)
	nextId += 1
	-- The spec table becomes the projectile; callers pass a fresh table each time.
	local projectile = (spec :: any) :: Projectile
	projectile.id = nextId
	projectile.traveled = 0
	projectile.hits = {}
	projectiles[projectile.id] = projectile

	local info: EntityNet.ProjectileInfo = {
		id = projectile.id,
		kind = spec.kind,
		x = spec.x,
		z = spec.z,
		dirX = spec.dirX,
		dirZ = spec.dirZ,
		speed = spec.speed,
		maxDistance = spec.maxDistance,
		startedAt = Pause.now(),
	}
	NetBatch.push(Remotes.ProjectilesSpawned, info)
end

-- Removes every projectile (clients expire them on their own or get removal events).
function ProjectileService.clear()
	for _, projectile in projectiles do
		remove(projectile, true)
	end
end

function ProjectileService.step(dt: number, now: number, targets: { Characters.Target })
	for _, projectile in projectiles do
		local remaining = math.min(projectile.speed * dt, projectile.maxDistance - projectile.traveled)
		local done = false
		while remaining > 0 and not done do
			local step = math.min(remaining, MAX_SUBSTEP)
			remaining -= step
			projectile.x += projectile.dirX * step
			projectile.z += projectile.dirZ * step
			projectile.traveled += step
			if projectile.fromEnemy then
				done = hitPlayers(projectile, projectile.x, projectile.z, now, targets)
			else
				done = hitEnemies(projectile, projectile.x, projectile.z)
			end
		end

		if done then
			remove(projectile, true)
		elseif projectile.traveled >= projectile.maxDistance then
			if projectile.blastRadius then
				explode(projectile, projectile.x, projectile.z)
				remove(projectile, true)
			else
				remove(projectile, false)
			end
		end
	end
end

function ProjectileService.start()
	assert(not started, "ProjectileService.start() was called twice")
	started = true
	NetBatch.register(Remotes.ProjectilesSpawned)
	NetBatch.register(Remotes.ProjectilesRemoved)
	NetBatch.register(Remotes.Explosions)
end

return ProjectileService
