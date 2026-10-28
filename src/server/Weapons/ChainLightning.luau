--!strict
-- Chain Lightning: every cooldown, each bolt strikes the nearest enemy not yet hit, then jumps to the
-- nearest enemy no bolt has hit this cast, until it has hit `chains` enemies or finds nothing in
-- jump range. Hits land instantly; clients get each bolt's path to draw. Evolved, it's
-- Thunderstorm: more bolts, longer chains, faster casts.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Characters = require(script.Parent.Parent.Characters)
local EnemyService = require(script.Parent.Parent.EnemyService)
local NetBatch = require(script.Parent.Parent.NetBatch)
local Upgrades = require(script.Parent.Parent.Upgrades)
local BuildStats = require(ReplicatedStorage.Shared.BuildStats)
local EntityNet = require(ReplicatedStorage.Shared.EntityNet)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local nextFireAt: { [Player]: number } = {}
-- Reused every cast.
local nearby: { EnemyService.Enemy } = {}
local struck: { [EnemyService.Enemy]: boolean } = {}

local ChainLightning = {}

-- The closest enemy to (x, z) within `range` that isn't a prop and hasn't been struck this cast.
local function nextJump(enemies: EnemyService.State, x: number, z: number, range: number): EnemyService.Enemy?
	table.clear(nearby)
	EnemyService.queryRadius(enemies, x, z, range, nearby)
	local best: EnemyService.Enemy? = nil
	local bestDistSq = math.huge
	for _, enemy in nearby do
		if struck[enemy] or EnemyService.isProp(enemy) then
			continue
		end
		local dx, dz = enemy.x - x, enemy.z - z
		local distSq = dx * dx + dz * dz
		if distSq < bestDistSq then
			best, bestDistSq = enemy, distSq
		end
	end
	return best
end

function ChainLightning.step(enemies: EnemyService.State, now: number, targets: { Characters.Target })
	for _, target in targets do
		local build = Upgrades.getBuild(target.player)
		local stats = build and BuildStats.chainLightning(build)
		if not stats or now < (nextFireAt[target.player] or 0) then
			continue
		end
		table.clear(struck)
		if not nextJump(enemies, target.x, target.z, stats.range) then
			continue -- try again next frame rather than wasting the cooldown
		end
		nextFireAt[target.player] = now + stats.cooldown
		local evolved = BuildStats.isEvolved(build :: BuildStats.Build, "ChainLightning")

		for _ = 1, stats.bolts do
			-- Each bolt starts on the nearest enemy no earlier bolt has hit.
			local start = nextJump(enemies, target.x, target.z, stats.range)
			if not start then
				break
			end
			local points = { target.x, target.z }
			local enemy: EnemyService.Enemy? = start
			local hits = 0
			while enemy and hits < stats.chains do
				struck[enemy] = true
				hits += 1
				-- Read the position first: a killing hit removes the enemy.
				local x, z = enemy.x, enemy.z
				table.insert(points, x)
				table.insert(points, z)
				EnemyService.damage(enemies, enemy, stats.damage)
				enemy = if hits < stats.chains then nextJump(enemies, x, z, stats.jumpRange) else nil
			end
			local effect: EntityNet.LightningEffect = { kind = "Lightning", evolved = evolved, points = points }
			NetBatch.push(enemies.net, Remotes.WeaponEffects, effect)
		end
	end
end

function ChainLightning.forget(player: Player)
	nextFireAt[player] = nil
end

return ChainLightning
