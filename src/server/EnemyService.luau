--!strict
--[[
	Server-side enemies. They're plain data with no Parts and no Humanoids: the server owns their
	position, HP, and damage, and clients draw them from snapshots (see EnemyReplicator).

	Each frame Simulation calls move (chase the nearest player, or keep a distance band for ranged
	enemies; push apart from neighbors; stay inside the walls) and then attack (contact damage).
	Weapons find enemies with queryRadius; EnemyShooter fires for ranged enemies.

	A living boss is published on the Arena as BossName and BossHealth (0 to 1) for the boss bar.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Arena = require(script.Parent.Arena)
local Characters = require(script.Parent.Characters)
local NetBatch = require(script.Parent.NetBatch)
local SpatialHash = require(script.Parent.SpatialHash)
local Config = require(ReplicatedStorage.Shared.Config.Enemies)
local EnemySnapshot = require(ReplicatedStorage.Shared.EnemySnapshot)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

type Target = Characters.Target

export type Enemy = {
	id: number,
	kind: string,
	def: Config.EnemyDef,
	x: number,
	z: number,
	health: number,
	maxHealth: number, -- after stage scaling
	contactDamage: number, -- after stage scaling
	xp: number, -- after stage scaling
	attackReadyAt: number,
	shotReadyAt: number, -- ranged enemies
	hitReadyAt: { [any]: number }, -- per attacker, when they can hit this enemy again
}

-- Multipliers on an enemy kind's base stats, e.g. for later stages.
export type Scaling = {
	health: number,
	damage: number,
	xp: number,
}

local NO_SCALING: Scaling = table.freeze({ health = 1, damage = 1, xp = 1 })

-- Ids go over the network as u16.
local MAX_ID = 65535

local arena: Arena.Arena? = nil
local enemies: { [number]: Enemy } = {}
local aliveCount = 0
local kills = 0
local nextId = 0
local hash = SpatialHash.new(Config.SPATIAL_CELL_SIZE)
local spawned: { EnemySnapshot.SpawnInfo } = {}
local despawned: { number } = {}
local candidates: { number } = {} -- reused for every hash query
local killedListeners: { (Enemy) -> () } = {}
local flashed: { [Enemy]: boolean } = {} -- enemies already sent a hit flash this frame
local boss: Enemy? = nil

local maxRadius = 0
for _, def in Config.TYPES do
	maxRadius = math.max(maxRadius, def.radius)
end

local EnemyService = {}

local function getArena(): Arena.Arena
	return assert(arena, "EnemyService.init() must be called first")
end

local function updateCounters()
	local model = getArena().model
	model:SetAttribute("EnemiesAlive", aliveCount)
	model:SetAttribute("Kills", kills)
end

local function publishBoss()
	local model = getArena().model
	model:SetAttribute("BossName", if boss then boss.def.displayName or boss.kind else "")
	model:SetAttribute("BossHealth", if boss then math.max(0, boss.health / boss.maxHealth) else 0)
end

local function remove(enemy: Enemy)
	if enemies[enemy.id] ~= enemy then
		return
	end
	enemies[enemy.id] = nil
	aliveCount -= 1
	table.insert(despawned, enemy.id)
	if enemy == boss then
		boss = nil
		publishBoss()
	end
end

local function nearestTarget(targets: { Target }, x: number, z: number): (Target?, number)
	local best: Target? = nil
	local bestDistSq = math.huge
	for _, target in targets do
		local dx, dz = target.x - x, target.z - z
		local distSq = dx * dx + dz * dz
		if distSq < bestDistSq then
			best, bestDistSq = target, distSq
		end
	end
	return best, bestDistSq
end

function EnemyService.init(newArena: Arena.Arena)
	arena = newArena
	NetBatch.register(Remotes.EnemiesHit)
	publishBoss()
end

-- Calls `listener(enemy)` whenever an enemy is killed (not when the field is cleared).
function EnemyService.onKilled(listener: (Enemy) -> ())
	table.insert(killedListeners, listener)
end

function EnemyService.spawn(kind: string, x: number, z: number, scaling: Scaling?): Enemy
	local def = Config.TYPES[kind]
	assert(def, `Unknown enemy kind "{kind}"`)
	local scale = scaling or NO_SCALING

	-- Wrap around instead of reusing freed ids right away, so a client never confuses a new enemy
	-- with one that just died.
	repeat
		nextId = nextId % MAX_ID + 1
	until enemies[nextId] == nil

	local enemy: Enemy = {
		id = nextId,
		kind = kind,
		def = def,
		x = x,
		z = z,
		health = def.maxHealth * scale.health,
		maxHealth = def.maxHealth * scale.health,
		contactDamage = def.contactDamage * scale.damage,
		xp = def.xp * scale.xp,
		attackReadyAt = 0,
		shotReadyAt = 0,
		hitReadyAt = {},
	}
	enemies[enemy.id] = enemy
	aliveCount += 1
	table.insert(spawned, { id = enemy.id, kind = kind, x = x, z = z })
	updateCounters()
	if def.isBoss then
		boss = enemy
		publishBoss()
	end
	return enemy
end

-- Returns true if this hit killed the enemy.
function EnemyService.damage(enemy: Enemy, amount: number): boolean
	if enemies[enemy.id] ~= enemy then
		return false
	end
	enemy.health -= amount
	if not flashed[enemy] then
		flashed[enemy] = true
		NetBatch.push(Remotes.EnemiesHit, enemy.id)
	end
	if enemy == boss then
		publishBoss()
	end
	if enemy.health > 0 then
		return false
	end
	remove(enemy)
	kills += 1
	updateCounters()
	for _, listener in killedListeners do
		listener(enemy)
	end
	return true
end

-- Whether `attacker` can hit this enemy now. If so, starts that attacker's cooldown on it.
function EnemyService.tryHit(enemy: Enemy, attacker: any, now: number, cooldown: number): boolean
	local readyAt = enemy.hitReadyAt[attacker]
	if readyAt and now < readyAt then
		return false
	end
	enemy.hitReadyAt[attacker] = now + cooldown
	return true
end

-- Removes every enemy without counting kills.
function EnemyService.clear()
	for _, enemy in enemies do
		remove(enemy)
	end
	updateCounters()
end

function EnemyService.getKills(): number
	return kills
end

-- Zeroes the kill counter, for a new run.
function EnemyService.resetKills()
	kills = 0
	updateCounters()
end

function EnemyService.count(): number
	return aliveCount
end

-- All living enemies by id. Read-only.
function EnemyService.getAll(): { [number]: Enemy }
	return enemies
end

-- Spawns and despawns since the last call, for EnemyReplicator.
function EnemyService.takeChanges(): ({ EnemySnapshot.SpawnInfo }, { number })
	local spawnedNow, despawnedNow = spawned, despawned
	spawned, despawned = {}, {}
	return spawnedNow, despawnedNow
end

-- Appends to `out` every enemy whose body overlaps the circle at (x, z).
function EnemyService.queryRadius(x: number, z: number, radius: number, out: { Enemy }): { Enemy }
	table.clear(candidates)
	SpatialHash.query(hash, x, z, radius + maxRadius, candidates)
	for _, id in candidates do
		local enemy = enemies[id]
		if enemy then
			local dx, dz = enemy.x - x, enemy.z - z
			local reach = radius + enemy.def.radius
			if dx * dx + dz * dz <= reach * reach then
				table.insert(out, enemy)
			end
		end
	end
	return out
end

local nearestBuffer: { Enemy } = {}

-- The closest living enemy within `range` of (x, z), or nil.
function EnemyService.nearest(x: number, z: number, range: number): Enemy?
	table.clear(nearestBuffer)
	EnemyService.queryRadius(x, z, range, nearestBuffer)
	local best: Enemy? = nil
	local bestDistSq = math.huge
	for _, enemy in nearestBuffer do
		local dx, dz = enemy.x - x, enemy.z - z
		local distSq = dx * dx + dz * dz
		if distSq < bestDistSq then
			best, bestDistSq = enemy, distSq
		end
	end
	return best
end

function EnemyService.move(dt: number, targets: { Target })
	local currentArena = getArena()
	local separation = math.min(0.5, Config.SEPARATION_STIFFNESS * dt)
	-- A new frame: enemies can flash again.
	table.clear(flashed)

	for _, enemy in enemies do
		local def = enemy.def

		local moveX, moveZ = 0, 0
		local target, distSq = nearestTarget(targets, enemy.x, enemy.z)
		if target then
			local dist = math.sqrt(distSq)
			local ranged = def.ranged
			if def.behavior == "ranged" and ranged and dist > 1e-3 then
				-- Keep within the preferred distance band: close in when far, back off when near.
				local direction = if dist > ranged.preferredMax then 1 elseif dist < ranged.preferredMin then -1 else 0
				local step = def.speed * dt * direction
				moveX = (target.x - enemy.x) / dist * step
				moveZ = (target.z - enemy.z) / dist * step
			else
				-- Chase, stopping when touching.
				local stopAt = def.radius + Config.PLAYER_RADIUS
				if dist > stopAt then
					local step = math.min(def.speed * dt, dist - stopAt)
					moveX = (target.x - enemy.x) / dist * step
					moveZ = (target.z - enemy.z) / dist * step
				end
			end
		end

		-- Push away from overlapping neighbors so crowds spread out instead of stacking. Each enemy
		-- in a pair moves itself, so each takes up to half the overlap.
		local pushX, pushZ = 0, 0
		table.clear(candidates)
		SpatialHash.query(hash, enemy.x, enemy.z, def.radius + maxRadius, candidates)
		for _, otherId in candidates do
			local other = enemies[otherId]
			if not other or other == enemy then
				continue
			end
			local dx, dz = enemy.x - other.x, enemy.z - other.z
			local minDist = def.radius + other.def.radius
			local distSqToOther = dx * dx + dz * dz
			if distSqToOther < minDist * minDist then
				local d = math.sqrt(distSqToOther)
				local overlap = minDist - d
				if d > 1e-3 then
					dx, dz = dx / d, dz / d
				else
					-- Exactly on top of each other: split along a direction that differs per id.
					dx, dz = math.cos(enemy.id), math.sin(enemy.id)
				end
				pushX += dx * overlap
				pushZ += dz * overlap
			end
		end

		enemy.x, enemy.z = Arena.clamp(
			currentArena,
			enemy.x + moveX + pushX * separation,
			enemy.z + moveZ + pushZ * separation,
			def.radius
		)
	end

	-- Rebuild the grid from the new positions for this frame's weapon checks and next frame's
	-- separation.
	SpatialHash.clear(hash)
	for id, enemy in enemies do
		SpatialHash.insert(hash, id, enemy.x, enemy.z)
	end
end

-- Enemies touching a living player damage them, once per attackCooldown.
function EnemyService.attack(now: number, targets: { Target })
	for _, enemy in enemies do
		if now < enemy.attackReadyAt then
			continue
		end
		local def = enemy.def
		local reach = def.radius + Config.PLAYER_RADIUS + Config.CONTACT_TOLERANCE
		for _, target in targets do
			local dx, dz = target.x - enemy.x, target.z - enemy.z
			if dx * dx + dz * dz <= reach * reach and target.humanoid.Health > 0 then
				Characters.damage(target, enemy.contactDamage, now)
				enemy.attackReadyAt = now + def.attackCooldown
				break
			end
		end
	end
end

return EnemyService
