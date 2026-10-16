--!strict
-- What spawns when (server/WaveDirector.luau). Each stage is a timeline of segments; the latest
-- segment whose `at` has passed is in effect, and overtime keeps using the last one with
-- Config.Run's overtime ramp on top.

export type Segment = {
	at: number, -- seconds into the stage
	interval: number, -- seconds between spawns
	maxAlive: number,
	-- Enemy kind -> relative weight. A pick of a group kind (bats) spawns the whole group, so
	-- those weights stay low.
	mix: { [string]: number },
}

export type Stage = {
	healthMultiplier: number,
	damageMultiplier: number,
	xpMultiplier: number,
	segments: { Segment },
	miniBoss: string?, -- enemy kind spawned once, at miniBossAt seconds into the stage
	miniBossAt: number?,
}

return table.freeze({
	STAGES = {
		{
			healthMultiplier = 1,
			damageMultiplier = 1,
			xpMultiplier = 1,
			segments = {
				{ at = 0, interval = 0.8, maxAlive = 25, mix = { Goblin = 1 } },
				{ at = 45, interval = 0.6, maxAlive = 35, mix = { Goblin = 1, Bat = 0.15 } },
				{ at = 100, interval = 0.45, maxAlive = 50, mix = { Goblin = 1, Bat = 0.15, SkeletonArcher = 0.25 } },
			},
			miniBoss = "GoblinGiant",
			miniBossAt = 90,
		},
		{
			healthMultiplier = 1.8,
			damageMultiplier = 1.25,
			xpMultiplier = 2,
			segments = {
				{ at = 0, interval = 0.6, maxAlive = 40, mix = { Goblin = 1, Bat = 0.15, SkeletonArcher = 0.25 } },
				{ at = 60, interval = 0.45, maxAlive = 60, mix = { Goblin = 1, Bat = 0.2, SkeletonArcher = 0.35 } },
				{ at = 120, interval = 0.35, maxAlive = 75, mix = { Goblin = 1, Bat = 0.25, SkeletonArcher = 0.4 } },
			},
			miniBoss = "GoblinGiant",
			miniBossAt = 90,
		},
		{
			healthMultiplier = 3,
			damageMultiplier = 1.5,
			xpMultiplier = 3,
			segments = {
				{ at = 0, interval = 0.45, maxAlive = 60, mix = { Goblin = 1, Bat = 0.25, SkeletonArcher = 0.4 } },
				{ at = 60, interval = 0.35, maxAlive = 80, mix = { Goblin = 1, Bat = 0.3, SkeletonArcher = 0.5 } },
				{ at = 120, interval = 0.28, maxAlive = 100, mix = { Goblin = 1, Bat = 0.3, SkeletonArcher = 0.5 } },
			},
			miniBoss = "GoblinGiant",
			miniBossAt = 90,
		},
	} :: { Stage },

	-- Never more than this many enemies alive, whatever a stage or overtime asks for.
	HARD_CAP = 200,
	-- Per-kind limits on how many can be alive at once. Archers are capped so overtime can't ring the
	-- player with shooters they can't reach.
	KIND_CAPS = {
		SkeletonArcher = 8,
	} :: { [string]: number },

	-- Elites (Config.Enemies.ELITE): one every ELITE_INTERVAL seconds of a stage, of a random kind
	-- from ELITE_KINDS (respecting KIND_CAPS), on the enemy spawn ring.
	ELITE_INTERVAL = 45,
	ELITE_KINDS = { "Goblin", "SkeletonArcher" },

	-- Supply crates: one every CRATE_INTERVAL seconds of a stage, at most CRATE_MAX on the floor,
	-- placed on a ring around a random living player so they're on or near the screen.
	CRATE_INTERVAL = 35,
	CRATE_MAX = 3,
	CRATE_DISTANCE_MIN = 20,
	CRATE_DISTANCE_MAX = 35,

	-- Enemies appear on a ring around a random living player, near the edge of the screen.
	SPAWN_DISTANCE_MIN = 35,
	SPAWN_DISTANCE_MAX = 50,
	-- Group members (bats) scatter this far around the group's spawn point.
	GROUP_SCATTER = 3,
	-- Keep spawns at least this far inside the walls.
	ARENA_MARGIN = 4,
})
