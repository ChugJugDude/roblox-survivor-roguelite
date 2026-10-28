--!strict
-- Ranged enemies (skeleton archers) shoot slow projectiles at the nearest living player in range.
-- Shots aim where the player is now, so moving dodges them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Characters = require(script.Parent.Characters)
local EnemyService = require(script.Parent.EnemyService)
local ProjectileService = require(script.Parent.ProjectileService)
local Config = require(ReplicatedStorage.Shared.Config.Enemies)

local EnemyShooter = {}

function EnemyShooter.step(
	enemies: EnemyService.State,
	projectiles: ProjectileService.State,
	now: number,
	targets: { Characters.Target }
)
	if #targets == 0 then
		return
	end
	for _, enemy in EnemyService.getAll(enemies) do
		local ranged = enemy.def.ranged
		if not ranged or now < enemy.shotReadyAt or EnemyService.isFrozen(enemy, now) then
			continue
		end

		local best: Characters.Target? = nil
		local bestDistSq = ranged.shotRange * ranged.shotRange
		for _, target in targets do
			local dx, dz = target.x - enemy.x, target.z - enemy.z
			local distSq = dx * dx + dz * dz
			if distSq <= bestDistSq then
				best, bestDistSq = target, distSq
			end
		end
		if not best then
			continue
		end

		enemy.shotReadyAt = now + ranged.shotCooldown
		local distance = math.max(math.sqrt(bestDistSq), 1e-3)
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
