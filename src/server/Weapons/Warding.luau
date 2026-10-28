--!strict
-- Warding (a passive): rings orbit the player, destroying any enemy shot they touch and nicking
-- enemies they pass through, so ranged enemies can't wear down a player holding still (charging
-- the portal). Ring angles come from the shared server clock (shared/BladeOrbit), so
-- client/BladeRenderer draws them where the server checks them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Characters = require(script.Parent.Parent.Characters)
local EnemyService = require(script.Parent.Parent.EnemyService)
local ProjectileService = require(script.Parent.Parent.ProjectileService)
local Upgrades = require(script.Parent.Parent.Upgrades)
local BladeOrbit = require(ReplicatedStorage.Shared.BladeOrbit)
local BuildStats = require(ReplicatedStorage.Shared.BuildStats)

-- Each player's rings hit enemies on their own cooldown, separate from that player's blades.
local attackerKeys: { [Player]: {} } = {}
local nearby: { EnemyService.Enemy } = {} -- reused for every ring

local Warding = {}

function Warding.step(
	enemies: EnemyService.State,
	projectiles: ProjectileService.State,
	now: number,
	targets: { Characters.Target }
)
	for _, target in targets do
		local build = Upgrades.getBuild(target.player)
		local stats = build and BuildStats.warding(build)
		if not stats then
			continue
		end
		local key = attackerKeys[target.player]
		if not key then
			key = {}
			attackerKeys[target.player] = key
		end

		for index = 1, stats.count do
			local angle = BladeOrbit.angle(index, stats.count, stats.spinSpeed, now)
			local x = target.x + math.cos(angle) * stats.orbitRadius
			local z = target.z + math.sin(angle) * stats.orbitRadius
			ProjectileService.blockEnemyShots(projectiles, x, z, stats.ringRadius)

			table.clear(nearby)
			EnemyService.queryRadius(enemies, x, z, stats.ringRadius, nearby)
			for _, enemy in nearby do
				if EnemyService.tryHit(enemy, key, now, stats.hitCooldown) then
					EnemyService.damage(enemies, enemy, stats.damage)
				end
			end
		end
	end
end

function Warding.forget(player: Player)
	attackerKeys[player] = nil
end

return Warding
