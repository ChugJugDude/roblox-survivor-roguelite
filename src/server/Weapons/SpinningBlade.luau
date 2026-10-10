--!strict
-- Spinning Blade: blades orbit the player and hit every enemy they sweep through. Stats come from
-- the player's build (level and passives). Blade angles come from the shared server clock
-- (shared/BladeOrbit), so client/BladeRenderer draws the same positions with no network traffic.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Characters = require(script.Parent.Parent.Characters)
local EnemyService = require(script.Parent.Parent.EnemyService)
local Upgrades = require(script.Parent.Parent.Upgrades)
local BladeOrbit = require(ReplicatedStorage.Shared.BladeOrbit)
local BuildStats = require(ReplicatedStorage.Shared.BuildStats)

local SpinningBlade = {}

local nearby: { EnemyService.Enemy } = {} -- reused every step

function SpinningBlade.step(now: number, targets: { Characters.Target })
	for _, target in targets do
		local build = Upgrades.getBuild(target.player)
		local stats = build and BuildStats.spinningBlade(build)
		if not stats then
			continue
		end

		table.clear(nearby)
		EnemyService.queryRadius(target.x, target.z, stats.outerRadius, nearby)
		if #nearby == 0 then
			continue
		end

		local halfWidth = stats.width / 2
		for index = 1, stats.bladeCount do
			local angle = BladeOrbit.angle(index, stats.bladeCount, stats.spinSpeed, now)
			local dirX, dirZ = math.cos(angle), math.sin(angle)

			for _, enemy in nearby do
				-- Distance from the enemy to the blade, treating the blade as a line segment
				-- from innerRadius to outerRadius along its direction.
				local relX, relZ = enemy.x - target.x, enemy.z - target.z
				local along = math.clamp(relX * dirX + relZ * dirZ, stats.innerRadius, stats.outerRadius)
				local offX, offZ = relX - dirX * along, relZ - dirZ * along
				local reach = halfWidth + enemy.def.radius
				if
					offX * offX + offZ * offZ <= reach * reach
					and EnemyService.tryHit(enemy, target.player, now, stats.hitCooldown)
				then
					EnemyService.damage(enemy, stats.damage)
				end
			end
		end
	end
end

return SpinningBlade
