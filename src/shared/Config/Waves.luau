--!strict
-- How waves work (server/WaveDirector.luau): the shared tuning here, and the Stage shape each
-- world's stages use (Config.Worlds). Each stage is a timeline of segments; the latest segment whose
-- `at` has passed is in effect, and overtime keeps using the last one with Config.Run's overtime
-- ramp on top.

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
	-- When this stage's timer runs out, this boss arrives instead of the portal, and killing it
	-- wins the run (server/Match.luau "Boss" phase). Only used on the last stage.
	finalBoss: string?,
}

return table.freeze({

	-- Never more than this many enemies alive, whatever a stage or overtime asks for.
	HARD_CAP = 200,
	-- Per-kind limits on how many can be alive at once. Archers are capped so overtime can't ring the
	-- player with shooters they can't reach.
	KIND_CAPS = {
		SkeletonArcher = 8,
		EmberArcher = 8,
	} :: { [string]: number },

	-- Elites (Config.Enemies.ELITE): one every ELITE_INTERVAL seconds of a stage, of a random kind
	-- from the world's eliteKinds (Config.Worlds, respecting KIND_CAPS), on the enemy spawn ring.
	ELITE_INTERVAL = 45,

	-- Supply crates: one every CRATE_INTERVAL seconds of a stage, at most CRATE_MAX on the floor,
	-- placed on a ring around a random living player so they're on or near the screen.
	CRATE_INTERVAL = 35,
	CRATE_MAX = 3,
	CRATE_DISTANCE_MIN = 20,
	CRATE_DISTANCE_MAX = 35,

	-- The final boss appears this far from a random living player.
	BOSS_DISTANCE_MIN = 28,
	BOSS_DISTANCE_MAX = 34,

	-- Enemies appear on a ring around a random living player, near the edge of the screen.
	SPAWN_DISTANCE_MIN = 35,
	SPAWN_DISTANCE_MAX = 50,
	-- Group members (bats) scatter this far around the group's spawn point.
	GROUP_SCATTER = 3,
	-- Keep spawns at least this far inside the walls.
	ARENA_MARGIN = 4,
})
