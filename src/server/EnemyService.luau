--!strict
--[[
	Server-side enemies for one match. They're plain data with no Parts and no Humanoids: the server
	owns their position, HP, and damage, and clients draw them from snapshots (see EnemyReplicator).

	Each frame the match calls move (chase the nearest player, or keep a distance band for ranged
	enemies; push apart from neighbors; stay inside the walls) and then attack (contact damage).
	Weapons find enemies with queryRadius; EnemyShooter fires for ranged enemies.

	A living boss is published on the match's Arena as BossName and BossHealth (0 to 1).

	Props (behavior "prop", e.g. crates) live here too so weapons hit them for free, but they never
	move or attack, aren't counted in count()/EnemiesAlive or as kills, and nearest/nearestN skip
	them so auto-aim never wastes a shot on one.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Arena = require(script.Parent.Arena)
local Characters = require(script.Parent.Characters)
local NetBatch = require(script.Parent.NetBatch)
local SpatialHash = require(script.Parent.SpatialHash)
local Config = require(ReplicatedStorage.Shared.Config.Enemies)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

type Target = Characters.Target

export type Enemy = {
	id: number,
	kind: string,
	def: Config.EnemyDef,
	x: number,
	z: number,
	health: number,
	maxHealth: number, -- after scaling
	contactDamage: number, -- after scaling
	xp: number, -- after scaling
	attackReadyAt: number,
	shotReadyAt: number, -- ranged enemies
	hitReadyAt: { [any]: number }, -- per attacker, when they can hit this enemy again
}

-- Multipliers on an enemy kind's base stats, e.g. for later stages and bigger parties.
export type Scaling = {
	health: number,
	damage: number,
	xp: number,
}

export type State = {
	arena: Arena.Arena,
	net: NetBatch.Batch,
	enemies: { [number]: Enemy },
	aliveCount: number, -- props excluded
	kindCounts: { [string]: number },
	kills: number,
	nextId: number,
	hash: SpatialHash.SpatialHash,
	killedListeners: { (Enemy) -> () },
	flashed: { [Enemy]: boolean }, -- enemies already sent a hit flash this frame
	boss: Enemy?,
}

local NO_SCALING: Scaling = table.freeze({ health = 1, damage = 1, xp = 1 })

-- Ids go over the network as u16.
local MAX_ID = 65535

-- Scratch buffers, reused by every query (the server is single-threaded).
local candidates: { number } = {}
local nearestBuffer: { Enemy } = {}
local byDistance: { { enemy: Enemy, distSq: number } } = {}

local maxRadius = 0
for _, def in Config.TYPES do
	maxRadius = math.max(maxRadius, def.radius)
end

local EnemyService = {}

local function updateCounters(state: State)
	local model = state.arena.model
	model:SetAttribute("EnemiesAlive", state.aliveCount)
	model:SetAttribute("Kills", state.kills)
end

local function publishBoss(state: State)
	local boss = state.boss
	local model = state.arena.model
	model:SetAttribute("BossName", if boss then boss.def.displayName or boss.kind else "")
	model:SetAttribute("BossHealth", if boss then math.max(0, boss.health / boss.maxHealth) else 0)
end

local function isProp(enemy: Enemy): boolean
	return enemy.def.behavior == "prop"
end

local function remove(state: State, enemy: Enemy)
	if state.enemies[enemy.id] ~= enemy then
		return
	end
	state.enemies[enemy.id] = nil
	if not isProp(enemy) then
		state.aliveCount -= 1
	end
	state.kindCounts[enemy.kind] -= 1
	NetBatch.push(state.net, Remotes.EnemyDespawned, enemy.id)
	if enemy == state.boss then
		state.boss = nil
		publishBoss(state)
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

function EnemyService.new(arena: Arena.Arena, net: NetBatch.Batch): State
	local state: State = {
		arena = arena,
		net = net,
		enemies = {},
		aliveCount = 0,
		kindCounts = {},
		kills = 0,
		nextId = 0,
		hash = SpatialHash.new(Config.SPATIAL_CELL_SIZE),
		killedListeners = {},
		flashed = {},
		boss = nil,
	}
	updateCounters(state)
	publishBoss(state)
	return state
end

-- Calls `listener(enemy)` whenever an enemy is killed (not when the field is cleared).
function EnemyService.onKilled(state: State, listener: (Enemy) -> ())
	table.insert(state.killedListeners, listener)
end

function EnemyService.spawn(state: State, kind: string, x: number, z: number, scaling: Scaling?): Enemy
	local def = Config.TYPES[kind]
	assert(def, `Unknown enemy kind "{kind}"`)
	local scale = scaling or NO_SCALING

	-- Wrap around instead of reusing freed ids right away, so a client never confuses a new enemy
	-- with one that just died.
	repeat
		state.nextId = state.nextId % MAX_ID + 1
	until state.enemies[state.nextId] == nil

	local enemy: Enemy = {
		id = state.nextId,
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
	state.enemies[enemy.id] = enemy
	if not isProp(enemy) then
		state.aliveCount += 1
	end
	state.kindCounts[kind] = (state.kindCounts[kind] or 0) + 1
	NetBatch.push(state.net, Remotes.EnemySpawned, { id = enemy.id, kind = kind, x = x, z = z })
	updateCounters(state)
	if def.isBoss then
		state.boss = enemy
		publishBoss(state)
	end
	return enemy
end

-- Returns true if this hit killed the enemy.
function EnemyService.damage(state: State, enemy: Enemy, amount: number): boolean
	if state.enemies[enemy.id] ~= enemy then
		return false
	end
	enemy.health -= amount
	if not state.flashed[enemy] then
		state.flashed[enemy] = true
		NetBatch.push(state.net, Remotes.EnemiesHit, enemy.id)
	end
	if enemy == state.boss then
		publishBoss(state)
	end
	if enemy.health > 0 then
		return false
	end
	remove(state, enemy)
	if not isProp(enemy) then
		state.kills += 1
	end
	updateCounters(state)
	for _, listener in state.killedListeners do
		listener(enemy)
	end
	return true
end

function EnemyService.isProp(enemy: Enemy): boolean
	return isProp(enemy)
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
function EnemyService.clear(state: State)
	for _, enemy in state.enemies do
		remove(state, enemy)
	end
	updateCounters(state)
end

function EnemyService.getKills(state: State): number
	return state.kills
end

-- Zeroes the kill counter, for a new run.
function EnemyService.resetKills(state: State)
	state.kills = 0
	updateCounters(state)
end

-- How many of one kind are alive.
function EnemyService.countKind(state: State, kind: string): number
	return state.kindCounts[kind] or 0
end

function EnemyService.count(state: State): number
	return state.aliveCount
end

-- All living enemies by id. Read-only.
function EnemyService.getAll(state: State): { [number]: Enemy }
	return state.enemies
end

-- Appends to `out` every enemy whose body overlaps the circle at (x, z).
function EnemyService.queryRadius(state: State, x: number, z: number, radius: number, out: { Enemy }): { Enemy }
	table.clear(candidates)
	SpatialHash.query(state.hash, x, z, radius + maxRadius, candidates)
	for _, id in candidates do
		local enemy = state.enemies[id]
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

-- The closest living enemy (not prop) within `range` of (x, z), or nil.
function EnemyService.nearest(state: State, x: number, z: number, range: number): Enemy?
	table.clear(nearestBuffer)
	EnemyService.queryRadius(state, x, z, range, nearestBuffer)
	local best: Enemy? = nil
	local bestDistSq = math.huge
	for _, enemy in nearestBuffer do
		if isProp(enemy) then
			continue
		end
		local dx, dz = enemy.x - x, enemy.z - z
		local distSq = dx * dx + dz * dz
		if distSq < bestDistSq then
			best, bestDistSq = enemy, distSq
		end
	end
	return best
end

-- Fills `out` with up to `count` living enemies (not props) within `range` of (x, z), closest first.
function EnemyService.nearestN(
	state: State,
	x: number,
	z: number,
	range: number,
	count: number,
	out: { Enemy }
): { Enemy }
	table.clear(out)
	table.clear(nearestBuffer)
	table.clear(byDistance)
	EnemyService.queryRadius(state, x, z, range, nearestBuffer)
	for _, enemy in nearestBuffer do
		if isProp(enemy) then
			continue
		end
		local dx, dz = enemy.x - x, enemy.z - z
		table.insert(byDistance, { enemy = enemy, distSq = dx * dx + dz * dz })
	end
	table.sort(byDistance, function(a, b)
		return a.distSq < b.distSq
	end)
	for index = 1, math.min(count, #byDistance) do
		table.insert(out, byDistance[index].enemy)
	end
	return out
end

function EnemyService.move(state: State, dt: number, targets: { Target })
	local enemies = state.enemies
	local separation = math.min(0.5, Config.SEPARATION_STIFFNESS * dt)
	-- A new frame: enemies can flash again.
	table.clear(state.flashed)

	for _, enemy in enemies do
		local def = enemy.def
		if def.behavior == "prop" then
			continue -- stays put; others still push away from it
		end

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
		SpatialHash.query(state.hash, enemy.x, enemy.z, def.radius + maxRadius, candidates)
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
			state.arena,
			enemy.x + moveX + pushX * separation,
			enemy.z + moveZ + pushZ * separation,
			def.radius
		)
	end

	-- Rebuild the grid from the new positions for this frame's weapon checks and next frame's
	-- separation.
	SpatialHash.clear(state.hash)
	for id, enemy in enemies do
		SpatialHash.insert(state.hash, id, enemy.x, enemy.z)
	end
end

-- Enemies touching a living player damage them, once per attackCooldown.
function EnemyService.attack(state: State, now: number, targets: { Target })
	for _, enemy in state.enemies do
		if now < enemy.attackReadyAt or isProp(enemy) then
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
