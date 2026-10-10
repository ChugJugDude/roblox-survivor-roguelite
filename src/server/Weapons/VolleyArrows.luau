--!strict
-- Volley Arrows: every cooldown, fires a fan of arrows at the nearest enemy in range. Arrows pierce
-- through a few enemies (see ProjectileService).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Characters = require(script.Parent.Parent.Characters)
local EnemyService = require(script.Parent.Parent.EnemyService)
local ProjectileService = require(script.Parent.Parent.ProjectileService)
local Upgrades = require(script.Parent.Parent.Upgrades)
local BuildStats = require(ReplicatedStorage.Shared.BuildStats)

local nextFireAt: { [Player]: number } = {}

local VolleyArrows = {}

function VolleyArrows.step(now: number, targets: { Characters.Target })
	for _, target in targets do
		local build = Upgrades.getBuild(target.player)
		local stats = build and BuildStats.volleyArrows(build)
		if not stats or now < (nextFireAt[target.player] or 0) then
			continue
		end
		-- No enemy in range: try again next frame rather than wasting the cooldown.
		local enemy = EnemyService.nearest(target.x, target.z, stats.range)
		if not enemy then
			continue
		end
		nextFireAt[target.player] = now + stats.cooldown

		local aim = math.atan2(enemy.z - target.z, enemy.x - target.x)
		for index = 1, stats.arrowCount do
			-- Spread the arrows evenly across the fan, centered on the aim.
			local offset = if stats.arrowCount > 1 then (index - 1) / (stats.arrowCount - 1) - 0.5 else 0
			local angle = aim + offset * stats.spread
			ProjectileService.spawn({
				kind = "Arrow",
				fromEnemy = false,
				owner = target.player,
				x = target.x,
				z = target.z,
				dirX = math.cos(angle),
				dirZ = math.sin(angle),
				speed = stats.speed,
				maxDistance = stats.range,
				radius = stats.radius,
				damage = stats.damage,
				pierce = stats.pierce,
			})
		end
	end
end

function VolleyArrows.forget(player: Player)
	nextFireAt[player] = nil
end

return VolleyArrows
