--!strict
-- Frost Nova: every cooldown, if an enemy is close, a freezing burst hits everything in a radius
-- around the player and slows it (EnemyService.slow). Evolved, it's Blizzard: a huge burst that
-- freezes enemies solid (bosses are only slowed).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Characters = require(script.Parent.Parent.Characters)
local EnemyService = require(script.Parent.Parent.EnemyService)
local NetBatch = require(script.Parent.Parent.NetBatch)
local Upgrades = require(script.Parent.Parent.Upgrades)
local BuildStats = require(ReplicatedStorage.Shared.BuildStats)
local EntityNet = require(ReplicatedStorage.Shared.EntityNet)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local nextFireAt: { [Player]: number } = {}
local nearby: { EnemyService.Enemy } = {} -- reused every burst

local FrostNova = {}

function FrostNova.step(enemies: EnemyService.State, now: number, targets: { Characters.Target })
	for _, target in targets do
		local build = Upgrades.getBuild(target.player)
		local stats = build and BuildStats.frostNova(build)
		if not stats or now < (nextFireAt[target.player] or 0) then
			continue
		end
		-- Wait for a real enemy in range rather than wasting the cooldown on empty air or a crate.
		if not EnemyService.nearest(enemies, target.x, target.z, stats.radius) then
			continue
		end
		nextFireAt[target.player] = now + stats.cooldown
		local evolved = BuildStats.isEvolved(build :: BuildStats.Build, "FrostNova")

		table.clear(nearby)
		EnemyService.queryRadius(enemies, target.x, target.z, stats.radius, nearby)
		local chilled: { number } = {}
		local frozen: { number } = {}
		for _, enemy in nearby do
			if not EnemyService.isProp(enemy) then
				EnemyService.slow(enemy, stats.slow, now, stats.slowDuration)
				table.insert(if EnemyService.isFrozen(enemy, now) then frozen else chilled, enemy.id)
			end
			EnemyService.damage(enemies, enemy, stats.damage)
		end

		local explosion: EntityNet.ExplosionInfo = {
			x = target.x,
			z = target.z,
			radius = stats.radius,
			kind = if evolved then "Blizzard" else "Frost",
		}
		NetBatch.push(enemies.net, Remotes.Explosions, explosion)
		for _, ids in { chilled, frozen } do
			if #ids > 0 then
				local chill: EntityNet.ChillEffect = {
					kind = "Chill",
					ids = ids,
					duration = stats.slowDuration,
					frozen = ids == frozen,
				}
				NetBatch.push(enemies.net, Remotes.WeaponEffects, chill)
			end
		end
	end
end

function FrostNova.forget(player: Player)
	nextFireAt[player] = nil
end

return FrostNova
