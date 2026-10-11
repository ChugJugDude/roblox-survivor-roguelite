--!strict
-- Volley Arrows: every cooldown, fires a fan of arrows at the nearest enemy in range (Arrow Storm:
-- a fan at each of several nearby enemies, spread around the player). Arrows pierce through a few
-- enemies (see ProjectileService).

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
-- How many of the closest enemies to consider when spreading targets out.
local TARGET_CANDIDATES = 24

local candidates: { EnemyService.Enemy } = {} -- reused every volley
local aimAt: { EnemyService.Enemy } = {}
local aimAngles: { number } = {}

local VolleyArrows = {}

local function angleBetween(a: number, b: number): number
	return math.abs((a - b + math.pi) % (2 * math.pi) - math.pi)
end

-- Fills aimAt/aimAngles with up to `count` targets: closest first, skipping ones too close in
-- direction to a target already chosen, then topping up with the closest remaining.
local function chooseTargets(x: number, z: number, range: number, count: number)
	table.clear(aimAt)
	table.clear(aimAngles)
	EnemyService.nearestN(x, z, range, if count > 1 then TARGET_CANDIDATES else 1, candidates)
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

function VolleyArrows.step(now: number, targets: { Characters.Target })
	for _, target in targets do
		local build = Upgrades.getBuild(target.player)
		local stats = build and BuildStats.volleyArrows(build)
		if not stats or now < (nextFireAt[target.player] or 0) then
			continue
		end
		-- No enemy in range: try again next frame rather than wasting the cooldown.
		chooseTargets(target.x, target.z, stats.range, stats.targets)
		if #aimAt == 0 then
			continue
		end
		nextFireAt[target.player] = now + stats.cooldown

		for _, aim in aimAngles do
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
end

function VolleyArrows.forget(player: Player)
	nextFireAt[player] = nil
end

return VolleyArrows
