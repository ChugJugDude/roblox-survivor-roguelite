--!strict
-- Fireball: every cooldown, hurls fireballs at random enemies in range. Each explodes on the first
-- enemy it touches (or where its target stood), hurting everything in the blast. Evolved, it's
-- Meteor: same behavior with bigger numbers and a bigger look.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Characters = require(script.Parent.Parent.Characters)
local EnemyService = require(script.Parent.Parent.EnemyService)
local ProjectileService = require(script.Parent.Parent.ProjectileService)
local Upgrades = require(script.Parent.Parent.Upgrades)
local BuildStats = require(ReplicatedStorage.Shared.BuildStats)

local random = Random.new()
local nextFireAt: { [Player]: number } = {}
local candidates: { EnemyService.Enemy } = {} -- reused every cast

local Fireball = {}

function Fireball.step(
	enemies: EnemyService.State,
	projectiles: ProjectileService.State,
	now: number,
	targets: { Characters.Target }
)
	for _, target in targets do
		local build = Upgrades.getBuild(target.player)
		local stats = build and BuildStats.fireball(build)
		if not stats or now < (nextFireAt[target.player] or 0) then
			continue
		end
		table.clear(candidates)
		EnemyService.queryRadius(enemies, target.x, target.z, stats.range, candidates)
		-- Don't waste fireballs on crates.
		for index = #candidates, 1, -1 do
			if EnemyService.isProp(candidates[index]) then
				table.remove(candidates, index)
			end
		end
		if #candidates == 0 then
			continue -- try again next frame rather than wasting the cooldown
		end
		nextFireAt[target.player] = now + stats.cooldown
		local kind = if BuildStats.isEvolved(build :: BuildStats.Build, "Fireball") then "Meteor" else "Fireball"

		for _ = 1, math.min(stats.count, #candidates) do
			local enemy = table.remove(candidates, random:NextInteger(1, #candidates)) :: EnemyService.Enemy
			local dx, dz = enemy.x - target.x, enemy.z - target.z
			local distance = math.max(math.sqrt(dx * dx + dz * dz), 1e-3)
			ProjectileService.spawn(projectiles, {
				kind = kind,
				fromEnemy = false,
				owner = target.player,
				x = target.x,
				z = target.z,
				dirX = dx / distance,
				dirZ = dz / distance,
				speed = stats.speed,
				maxDistance = distance,
				radius = stats.radius,
				damage = stats.damage,
				pierce = 1,
				blastRadius = stats.blastRadius,
			})
		end
	end
end

function Fireball.forget(player: Player)
	nextFireAt[player] = nil
end

return Fireball
