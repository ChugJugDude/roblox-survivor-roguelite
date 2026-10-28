--!strict
-- Holy Ground: every cooldown, if an enemy is near, blesses the ground at the player's feet (plus
-- extra zones close by). Each zone burns enemies inside it once per tick until it fades, so
-- enemies chasing the player walk through it. Evolved, it's Sanctuary: bigger, longer zones that
-- also heal any player standing in them.
--
-- Zones are per match (they live in game time and outlast the cast), so this module has a state
-- object owned by WeaponService.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Characters = require(script.Parent.Parent.Characters)
local EnemyService = require(script.Parent.Parent.EnemyService)
local NetBatch = require(script.Parent.Parent.NetBatch)
local Upgrades = require(script.Parent.Parent.Upgrades)
local BuildStats = require(ReplicatedStorage.Shared.BuildStats)
local UpgradesConfig = require(ReplicatedStorage.Shared.Config.Upgrades)
local EntityNet = require(ReplicatedStorage.Shared.EntityNet)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

-- Extra zones land this far from the player (studs, as a fraction of the zone radius).
local EXTRA_ZONE_DISTANCE = 1.4

type Zone = {
	x: number,
	z: number,
	radius: number,
	damage: number,
	tick: number,
	heal: number,
	endsAt: number,
}

export type State = {
	enemies: EnemyService.State,
	zones: { Zone },
}

local random = Random.new()
local nextFireAt: { [Player]: number } = {}
local nearby: { EnemyService.Enemy } = {} -- reused every zone

local HolyGround = {}

function HolyGround.new(enemies: EnemyService.State): State
	return { enemies = enemies, zones = {} }
end

local function cast(
	state: State,
	target: Characters.Target,
	stats: UpgradesConfig.HolyGroundStats,
	evolved: boolean,
	now: number
)
	for index = 1, stats.zones do
		local x, z = target.x, target.z
		if index > 1 then
			-- Spread the extra zones evenly around the player, starting at a random angle.
			local angle = random:NextNumber(0, 2 * math.pi) + index * 2 * math.pi / stats.zones
			local distance = stats.radius * EXTRA_ZONE_DISTANCE
			x += math.cos(angle) * distance
			z += math.sin(angle) * distance
		end
		table.insert(state.zones, {
			x = x,
			z = z,
			radius = stats.radius,
			damage = stats.damage,
			tick = stats.tick,
			heal = stats.heal,
			endsAt = now + stats.duration,
		})
		local effect: EntityNet.HolyGroundEffect = {
			kind = "HolyGround",
			evolved = evolved,
			x = x,
			z = z,
			radius = stats.radius,
			startedAt = now,
			duration = stats.duration,
		}
		NetBatch.push(state.enemies.net, Remotes.WeaponEffects, effect)
	end
end

function HolyGround.step(state: State, now: number, dt: number, targets: { Characters.Target })
	-- New zones.
	for _, target in targets do
		local build = Upgrades.getBuild(target.player)
		local stats = build and BuildStats.holyGround(build)
		if not stats or now < (nextFireAt[target.player] or 0) then
			continue
		end
		if not EnemyService.nearest(state.enemies, target.x, target.z, stats.range) then
			continue -- try again next frame rather than wasting the cooldown
		end
		nextFireAt[target.player] = now + stats.cooldown
		cast(state, target, stats, BuildStats.isEvolved(build :: BuildStats.Build, "HolyGround"), now)
	end

	-- Burn enemies in every zone; Sanctuary zones heal players in them. A player in two zones heals
	-- at the stronger zone's rate, not both.
	local zones = state.zones
	local healing: { [Characters.Target]: number } = {}
	for index = #zones, 1, -1 do
		local zone = zones[index]
		if now >= zone.endsAt then
			table.remove(zones, index)
			continue
		end
		table.clear(nearby)
		EnemyService.queryRadius(state.enemies, zone.x, zone.z, zone.radius, nearby)
		for _, enemy in nearby do
			if EnemyService.tryHit(enemy, zone, now, zone.tick) then
				EnemyService.damage(state.enemies, enemy, zone.damage)
			end
		end
		if zone.heal > 0 then
			for _, target in targets do
				local dx, dz = target.x - zone.x, target.z - zone.z
				if dx * dx + dz * dz <= zone.radius * zone.radius then
					healing[target] = math.max(healing[target] or 0, zone.heal)
				end
			end
		end
	end
	for target, perSecond in healing do
		Characters.heal(target, perSecond * dt)
	end
end

function HolyGround.clear(state: State)
	table.clear(state.zones)
end

function HolyGround.forget(player: Player)
	nextFireAt[player] = nil
end

return HolyGround
