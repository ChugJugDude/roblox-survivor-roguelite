--!strict
-- What spawns when (server/WaveDirector.luau). Each stage is a timeline of segments; the latest
-- segment whose `at` has passed is in effect, and overtime keeps using the last one with
-- Config.Run's overtime ramp on top.

export type Segment = {
	at: number, -- seconds into the stage
	interval: number, -- seconds between spawns
	maxAlive: number,
	mix: { [string]: number }, -- enemy kind -> relative weight
}

export type Stage = {
	healthMultiplier: number,
	damageMultiplier: number,
	segments: { Segment },
}

return table.freeze({
	STAGES = {
		{
			healthMultiplier = 1,
			damageMultiplier = 1,
			segments = {
				{ at = 0, interval = 0.8, maxAlive = 25, mix = { Goblin = 1 } },
				{ at = 60, interval = 0.55, maxAlive = 40, mix = { Goblin = 1 } },
				{ at = 120, interval = 0.4, maxAlive = 55, mix = { Goblin = 1 } },
			},
		},
		{
			healthMultiplier = 1.8,
			damageMultiplier = 1.25,
			segments = {
				{ at = 0, interval = 0.6, maxAlive = 40, mix = { Goblin = 1 } },
				{ at = 60, interval = 0.45, maxAlive = 60, mix = { Goblin = 1 } },
				{ at = 120, interval = 0.35, maxAlive = 75, mix = { Goblin = 1 } },
			},
		},
		{
			healthMultiplier = 3,
			damageMultiplier = 1.5,
			segments = {
				{ at = 0, interval = 0.45, maxAlive = 60, mix = { Goblin = 1 } },
				{ at = 60, interval = 0.35, maxAlive = 80, mix = { Goblin = 1 } },
				{ at = 120, interval = 0.28, maxAlive = 100, mix = { Goblin = 1 } },
			},
		},
	} :: { Stage },

	-- Never more than this many enemies alive, whatever a stage or overtime asks for.
	HARD_CAP = 200,

	-- Enemies appear on a ring around a random living player, near the edge of the screen.
	SPAWN_DISTANCE_MIN = 35,
	SPAWN_DISTANCE_MAX = 50,
	-- Keep spawns at least this far inside the walls.
	ARENA_MARGIN = 4,
})
