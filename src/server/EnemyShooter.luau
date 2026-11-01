--!strict
-- Ranged enemies (archers) shoot slow projectiles at the nearest living player in range. Each shot
-- is drawn first: the archer draws its bow for drawTime seconds (a "Draw" telegraph, so clients can
-- pose it), then the shot flies at whoever is nearest then, aimed where they are, so moving dodges
-- it. A freeze spoils the draw.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Characters = require(script.Parent.Characters)
local EnemyService = require(script.Parent.EnemyService)
local NetBatch = require(script.Parent.NetBatch)
local ProjectileService = require(script.Parent.ProjectileService)
local Config = require(ReplicatedStorage.Shared.Config.Enemies)
local EntityNet = require(ReplicatedStorage.Shared.EntityNet)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local DEFAULT_DRAW_TIME = 0.5

local EnemyShooter = {}

-- The nearest target within `range` of the enemy, and its distance.
local function nearestInRange(
	enemy: EnemyService.Enemy,
	range: number,
	targets: { Characters.Target }
): (Characters.Target?, number)
	local best: Characters.Target? = nil
	local bestDistSq = range * range
	for _, target in targets do
		local dx, dz = target.x - enemy.x, target.z - enemy.z
		local distSq = dx * dx + dz * dz
		if distSq <= bestDistSq then
			best, bestDistSq = target, distSq
		end
	end
	return best, math.sqrt(bestDistSq)
end

function EnemyShooter.step(
	enemies: EnemyService.State,
	projectiles: ProjectileService.State,
	net: NetBatch.Batch,
	now: number,
	targets: { Characters.Target }
)
	if #targets == 0 then
		return
	end
	for _, enemy in EnemyService.getAll(enemies) do
		local ranged = enemy.def.ranged
		if not ranged then
			continue
		end
		if EnemyService.isFrozen(enemy, now) then
			enemy.drawingUntil = nil
			continue
		end

		local drawingUntil = enemy.drawingUntil
		if not drawingUntil then
			-- Ready, and someone in range: start drawing.
			if now >= enemy.shotReadyAt and nearestInRange(enemy, ranged.shotRange, targets) then
				local drawTime = ranged.drawTime or DEFAULT_DRAW_TIME
				enemy.drawingUntil = now + drawTime
				enemy.shotReadyAt = now + ranged.shotCooldown
				local telegraph: EntityNet.DrawTelegraph = { shape = "Draw", id = enemy.id, duration = drawTime }
				NetBatch.push(net, Remotes.EnemyTelegraph, telegraph)
			end
			continue
		end
		if now < drawingUntil then
			continue
		end
		enemy.drawingUntil = nil

		local best, distance = nearestInRange(enemy, ranged.shotRange, targets)
		if not best then
			continue -- they got away
		end
		distance = math.max(distance, 1e-3)
		ProjectileService.spawn(projectiles, {
			kind = "EnemyArrow",
			fromEnemy = true,
			owner = enemy,
			x = enemy.x,
			z = enemy.z,
			dirX = (best.x - enemy.x) / distance,
			dirZ = (best.z - enemy.z) / distance,
			speed = ranged.shotSpeed,
			maxDistance = ranged.shotRange + Config.PLAYER_RADIUS,
			radius = 0.6,
			-- Stage scaling: shots grow with the archer's contact damage.
			damage = ranged.shotDamage * enemy.contactDamage / enemy.def.contactDamage,
			pierce = 1,
		})
	end
end

return EnemyShooter
