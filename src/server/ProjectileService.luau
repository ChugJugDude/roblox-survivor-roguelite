--!strict
--[[
	One match's projectiles: straight-line shots simulated on the server. Player shots hit enemies
	(arrows pierce, fireballs explode); enemy shots hit players through Characters.damage.

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

export type State = {
	enemies: EnemyService.State,
	net: NetBatch.Batch,
	clock: Pause.Clock,
	projectiles: { [number]: Projectile },
	nextId: number,
}

local nearby: { EnemyService.Enemy } = {} -- reused for every query

local ProjectileService = {}

local function remove(state: State, projectile: Projectile, notify: boolean)
	state.projectiles[projectile.id] = nil
	if notify then
		NetBatch.push(state.net, Remotes.ProjectilesRemoved, projectile.id)
	end
end

local function explode(state: State, projectile: Projectile, x: number, z: number)
	local radius = projectile.blastRadius or 0
	table.clear(nearby)
	EnemyService.queryRadius(state.enemies, x, z, radius, nearby)
	for _, enemy in nearby do
		EnemyService.damage(state.enemies, enemy, projectile.damage)
	end
	NetBatch.push(state.net, Remotes.Explosions, { x = x, z = z, radius = radius })
end

-- Checks a player shot at (x, z). Returns true if the projectile is used up.
local function hitEnemies(state: State, projectile: Projectile, x: number, z: number): boolean
	table.clear(nearby)
	EnemyService.queryRadius(state.enemies, x, z, projectile.radius, nearby)
	for _, enemy in nearby do
		if projectile.hits[enemy] then
			continue
		end
		if projectile.blastRadius then
			explode(state, projectile, x, z)
			return true
		end
		projectile.hits[enemy] = true
		EnemyService.damage(state.enemies, enemy, projectile.damage)
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

function ProjectileService.new(enemies: EnemyService.State, net: NetBatch.Batch, clock: Pause.Clock): State
	return { enemies = enemies, net = net, clock = clock, projectiles = {}, nextId = 0 }
end

function ProjectileService.spawn(state: State, spec: Spec)
	state.nextId += 1
	-- The spec table becomes the projectile; callers pass a fresh table each time.
	local projectile = (spec :: any) :: Projectile
	projectile.id = state.nextId
	projectile.traveled = 0
	projectile.hits = {}
	state.projectiles[projectile.id] = projectile

	local info: EntityNet.ProjectileInfo = {
		id = projectile.id,
		kind = spec.kind,
		x = spec.x,
		z = spec.z,
		dirX = spec.dirX,
		dirZ = spec.dirZ,
		speed = spec.speed,
		maxDistance = spec.maxDistance,
		startedAt = Pause.now(state.clock),
	}
	NetBatch.push(state.net, Remotes.ProjectilesSpawned, info)
end

-- Destroys every enemy shot touching the circle at (x, z). Returns how many.
function ProjectileService.blockEnemyShots(state: State, x: number, z: number, radius: number): number
	local blocked = 0
	for _, projectile in state.projectiles do
		if not projectile.fromEnemy then
			continue
		end
		local dx, dz = projectile.x - x, projectile.z - z
		local reach = radius + projectile.radius
		if dx * dx + dz * dz <= reach * reach then
			remove(state, projectile, true)
			blocked += 1
		end
	end
	return blocked
end

-- Removes every projectile (clients expire them on their own or get removal events).
function ProjectileService.clear(state: State)
	for _, projectile in state.projectiles do
		remove(state, projectile, true)
	end
end

function ProjectileService.step(state: State, dt: number, now: number, targets: { Characters.Target })
	for _, projectile in state.projectiles do
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
				done = hitEnemies(state, projectile, projectile.x, projectile.z)
			end
		end

		if done then
			remove(state, projectile, true)
		elseif projectile.traveled >= projectile.maxDistance then
			if projectile.blastRadius then
				explode(state, projectile, projectile.x, projectile.z)
				remove(state, projectile, true)
			else
				remove(state, projectile, false)
			end
		end
	end
end

return ProjectileService
