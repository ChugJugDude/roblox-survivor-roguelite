--!strict
--[[
	Attacks for one match's bosses (enemies whose def has a `boss` table, like the Ogre). Between
	attacks a boss chases like any enemy (EnemyService.move). Every attackInterval it does the next
	attack in its pattern:

		Ring    a circle of crimson shots in every direction (two rings when enraged)
		Summon  a circle of adds around it
		Charge  it stops and the client draws a red lane (EnemyTelegraph) for chargeWindup seconds,
		        then it dashes down that lane, hitting every player it passes once

	While charging, the boss is `locked`, so EnemyService.move leaves its position to us. Call step
	before EnemyService.move so the spatial hash sees the new position the same frame.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Arena = require(script.Parent.Arena)
local Characters = require(script.Parent.Characters)
local EnemyService = require(script.Parent.EnemyService)
local NetBatch = require(script.Parent.NetBatch)
local ProjectileService = require(script.Parent.ProjectileService)
local Config = require(ReplicatedStorage.Shared.Config.Enemies)
local EntityNet = require(ReplicatedStorage.Shared.EntityNet)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local WavesConfig = require(ReplicatedStorage.Shared.Config.Waves)

type Charge = {
	dashAt: number, -- game time the wind-up ends
	dirX: number,
	dirZ: number,
	traveled: number,
	hit: { [Player]: boolean },
}

type Brain = {
	nextAttackAt: number,
	patternIndex: number,
	charge: Charge?,
}

export type State = {
	arena: Arena.Arena,
	enemies: EnemyService.State,
	projectiles: ProjectileService.State,
	net: NetBatch.Batch,
	brains: { [EnemyService.Enemy]: Brain },
}

local BossBrain = {}

local function nearest(targets: { Characters.Target }, x: number, z: number): Characters.Target?
	local best: Characters.Target? = nil
	local bestDistSq = math.huge
	for _, target in targets do
		local dx, dz = target.x - x, target.z - z
		local distSq = dx * dx + dz * dz
		if distSq < bestDistSq then
			best, bestDistSq = target, distSq
		end
	end
	return best
end

-- How much this boss's attacks are scaled (by stage and party), from its contact damage.
local function damageScale(enemy: EnemyService.Enemy): number
	return enemy.contactDamage / enemy.def.contactDamage
end

local function isEnraged(enemy: EnemyService.Enemy, boss: Config.BossDef): boolean
	return enemy.health <= enemy.maxHealth * boss.enrageAt
end

local function ring(state: State, enemy: EnemyService.Enemy, boss: Config.BossDef, offset: number, speed: number)
	for i = 1, boss.ringShots do
		local angle = offset + (i - 1) / boss.ringShots * 2 * math.pi
		ProjectileService.spawn(state.projectiles, {
			kind = "BossOrb",
			fromEnemy = true,
			owner = enemy,
			x = enemy.x,
			z = enemy.z,
			dirX = math.cos(angle),
			dirZ = math.sin(angle),
			speed = speed,
			maxDistance = boss.ringRange,
			radius = 1,
			damage = boss.ringDamage * damageScale(enemy),
			pierce = 1,
		})
	end
end

local function summon(state: State, enemy: EnemyService.Enemy, boss: Config.BossDef)
	local room = WavesConfig.HARD_CAP - EnemyService.count(state.enemies)
	local count = math.min(boss.summonCount, room)
	local start = math.random() * 2 * math.pi
	for i = 1, count do
		local angle = start + (i - 1) / count * 2 * math.pi
		local x, z = Arena.clamp(
			state.arena,
			enemy.x + math.cos(angle) * boss.summonRadius,
			enemy.z + math.sin(angle) * boss.summonRadius,
			WavesConfig.ARENA_MARGIN
		)
		EnemyService.spawn(state.enemies, boss.summonKind, x, z, enemy.scaling)
	end
end

local function startCharge(
	state: State,
	enemy: EnemyService.Enemy,
	brain: Brain,
	boss: Config.BossDef,
	now: number,
	target: Characters.Target
)
	local dx, dz = target.x - enemy.x, target.z - enemy.z
	local distance = math.sqrt(dx * dx + dz * dz)
	if distance < 1e-3 then
		dx, dz, distance = 0, -1, 1
	end
	local dirX, dirZ = dx / distance, dz / distance
	enemy.locked = true
	brain.charge = { dashAt = now + boss.chargeWindup, dirX = dirX, dirZ = dirZ, traveled = 0, hit = {} }
	local telegraph: EntityNet.TelegraphInfo = {
		x = enemy.x,
		z = enemy.z,
		dirX = dirX,
		dirZ = dirZ,
		length = boss.chargeDistance + enemy.radius,
		width = enemy.radius * 2,
		duration = boss.chargeWindup,
	}
	NetBatch.push(state.net, Remotes.EnemyTelegraph, telegraph)
end

-- Moves a charging boss along its lane; true when the charge is over.
local function stepCharge(
	enemy: EnemyService.Enemy,
	charge: Charge,
	boss: Config.BossDef,
	state: State,
	now: number,
	dt: number,
	targets: { Characters.Target }
): boolean
	if now < charge.dashAt then
		return false -- still winding up
	end
	local step = math.min(boss.chargeSpeed * dt, boss.chargeDistance - charge.traveled)
	local x, z = Arena.clamp(state.arena, enemy.x + charge.dirX * step, enemy.z + charge.dirZ * step, enemy.radius)
	local moved = math.abs(x - enemy.x) + math.abs(z - enemy.z)
	enemy.x, enemy.z = x, z
	charge.traveled += step

	local reach = enemy.radius + Config.PLAYER_RADIUS + Config.CONTACT_TOLERANCE
	for _, target in targets do
		local dx, dz = target.x - x, target.z - z
		if not charge.hit[target.player] and dx * dx + dz * dz <= reach * reach then
			charge.hit[target.player] = true
			Characters.damage(target, boss.chargeDamage * damageScale(enemy), now)
		end
	end
	-- Done at full distance, or when a wall stops it.
	return charge.traveled >= boss.chargeDistance or moved < step * 0.25
end

function BossBrain.new(
	arena: Arena.Arena,
	enemies: EnemyService.State,
	projectiles: ProjectileService.State,
	net: NetBatch.Batch
): State
	return { arena = arena, enemies = enemies, projectiles = projectiles, net = net, brains = {} }
end

function BossBrain.step(state: State, now: number, dt: number, targets: { Characters.Target })
	local all = EnemyService.getAll(state.enemies)
	-- Forget bosses that died or were cleared.
	for enemy in state.brains do
		if all[enemy.id] ~= enemy then
			state.brains[enemy] = nil
		end
	end

	for _, enemy in all do
		local boss = enemy.def.boss
		if not boss then
			continue
		end
		local brain = state.brains[enemy]
		if not brain then
			brain = { nextAttackAt = now + boss.firstAttackDelay, patternIndex = 0, charge = nil }
			state.brains[enemy] = brain
		end
		local interval = if isEnraged(enemy, boss) then boss.enragedInterval else boss.attackInterval

		local charge = brain.charge
		if charge then
			if stepCharge(enemy, charge, boss, state, now, dt, targets) then
				brain.charge = nil
				enemy.locked = false
				brain.nextAttackAt = now + interval
			end
			continue
		end

		local target = nearest(targets, enemy.x, enemy.z)
		if not target or now < brain.nextAttackAt then
			continue
		end
		brain.patternIndex = brain.patternIndex % #boss.pattern + 1
		local attack = boss.pattern[brain.patternIndex]
		if attack == "Ring" then
			local offset = math.random() * math.pi
			ring(state, enemy, boss, offset, boss.ringSpeed)
			if isEnraged(enemy, boss) then
				-- A second, slower ring aimed into the first one's gaps.
				ring(state, enemy, boss, offset + math.pi / boss.ringShots, boss.ringSpeed * 0.65)
			end
			brain.nextAttackAt = now + interval
		elseif attack == "Summon" then
			summon(state, enemy, boss)
			brain.nextAttackAt = now + interval
		else
			startCharge(state, enemy, brain, boss, now, target)
		end
	end
end

return BossBrain
