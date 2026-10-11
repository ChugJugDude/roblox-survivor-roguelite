--!strict
-- Volley Arrows: every cooldown, fires a fan of arrows at an enemy in range (Arrow Storm: a fan at
-- each of several enemies, spread around the player). Ranged enemies in range come first, nearest
-- first, so arrows answer the archers the blades can't reach; then the nearest of the rest. Arrows
-- pierce through a few enemies (see ProjectileService).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Characters = require(script.Parent.Parent.Characters)
local EnemyService = require(script.Parent.Parent.EnemyService)
local ProjectileService = require(script.Parent.Parent.ProjectileService)
local Upgrades = require(script.Parent.Parent.Upgrades)
local BuildStats = require(ReplicatedStorage.Shared.BuildStats)

local nextFireAt: { [Player]: number } = {}
-- Multi-target volleys prefer enemies at least this far apart in direction, so a crowd on one side
-- doesn't soak up every fan while something shoots from the other.
local MIN_TARGET_ANGLE = math.rad(45)

local inRange: { EnemyService.Enemy } = {} -- reused every volley
local candidates: { EnemyService.Enemy } = {}
local aimAt: { EnemyService.Enemy } = {}
local aimAngles: { number } = {}

local VolleyArrows = {}

local function angleBetween(a: number, b: number): number
	return math.abs((a - b + math.pi) % (2 * math.pi) - math.pi)
end

-- Fills aimAt/aimAngles with up to `count` targets in priority order (ranged enemies, then the rest;
-- nearest first within each), skipping ones too close in direction to a target already chosen,
-- then topping up in the same order.
local function chooseTargets(enemies: EnemyService.State, x: number, z: number, range: number, count: number)
	table.clear(aimAt)
	table.clear(aimAngles)
	EnemyService.nearestN(enemies, x, z, range, math.huge, inRange)
	table.clear(candidates)
	for _, enemy in inRange do
		if enemy.def.behavior == "ranged" then
			table.insert(candidates, enemy)
		end
	end
	for _, enemy in inRange do
		if enemy.def.behavior ~= "ranged" then
			table.insert(candidates, enemy)
		end
	end
	local chosen: { [EnemyService.Enemy]: boolean } = {}
	for pass = 1, 2 do
		for _, enemy in candidates do
			if #aimAt >= count then
				return
			end
			if chosen[enemy] then
				continue
			end
			local angle = math.atan2(enemy.z - z, enemy.x - x)
			local spreadOut = true
			if pass == 1 then
				for _, other in aimAngles do
					if angleBetween(angle, other) < MIN_TARGET_ANGLE then
						spreadOut = false
						break
					end
				end
			end
			if spreadOut then
				chosen[enemy] = true
				table.insert(aimAt, enemy)
				table.insert(aimAngles, angle)
			end
		end
	end
end

function VolleyArrows.step(
	enemies: EnemyService.State,
	projectiles: ProjectileService.State,
	now: number,
	targets: { Characters.Target }
)
	for _, target in targets do
		local build = Upgrades.getBuild(target.player)
		local stats = build and BuildStats.volleyArrows(build)
		if not stats or now < (nextFireAt[target.player] or 0) then
			continue
		end
		-- No enemy in range: try again next frame rather than wasting the cooldown.
		chooseTargets(enemies, target.x, target.z, stats.range, stats.targets)
		if #aimAt == 0 then
			continue
		end
		nextFireAt[target.player] = now + stats.cooldown

		for _, aim in aimAngles do
			for index = 1, stats.arrowCount do
				-- The first arrow flies straight at the target; the rest alternate to either side, one step
				-- further out each time (0, +1, -1, +2, ...). A symmetric fan with an even count has no
				-- middle arrow, and at range both halves straddle the target and miss it.
				local step = if stats.arrowCount > 1 then stats.spread / (stats.arrowCount - 1) else 0
				local k = index - 1
				local slot = if k % 2 == 1 then (k + 1) / 2 else -k / 2
				local angle = aim + slot * step
				ProjectileService.spawn(projectiles, {
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
end

function VolleyArrows.forget(player: Player)
	nextFireAt[player] = nil
end

return VolleyArrows
