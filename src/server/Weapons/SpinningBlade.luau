--!strict
-- Spinning Blade: blades orbit each living player and hit every enemy they sweep through.
-- Blade angles come from the shared server clock (shared/BladeOrbit), so client/BladeRenderer
-- draws the same positions without any network traffic.
-- M0 gives every living player this weapon. M1 will make weapons per-player upgrades.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Characters = require(script.Parent.Parent.Characters)
local EnemyService = require(script.Parent.Parent.EnemyService)
local BladeOrbit = require(ReplicatedStorage.Shared.BladeOrbit)
local Config = require(ReplicatedStorage.Shared.Config.Weapons).SpinningBlade

local SpinningBlade = {}

local nearby: { EnemyService.Enemy } = {} -- reused every step

function SpinningBlade.step(now: number, targets: { Characters.Target })
	local halfWidth = Config.width / 2

	for _, target in targets do
		table.clear(nearby)
		EnemyService.queryRadius(target.x, target.z, Config.outerRadius, nearby)
		if #nearby == 0 then
			continue
		end

		for index = 1, Config.bladeCount do
			local angle = BladeOrbit.angle(index, now)
			local dirX, dirZ = math.cos(angle), math.sin(angle)

			for _, enemy in nearby do
				-- Distance from the enemy to the blade, treating the blade as a line segment
				-- from innerRadius to outerRadius along its direction.
				local relX, relZ = enemy.x - target.x, enemy.z - target.z
				local along = math.clamp(relX * dirX + relZ * dirZ, Config.innerRadius, Config.outerRadius)
				local offX, offZ = relX - dirX * along, relZ - dirZ * along
				local reach = halfWidth + enemy.def.radius
				if
					offX * offX + offZ * offZ <= reach * reach
					and EnemyService.tryHit(enemy, target.player, now, Config.hitCooldown)
				then
					EnemyService.damage(enemy, Config.damage)
				end
			end
		end
	end
end

return SpinningBlade
