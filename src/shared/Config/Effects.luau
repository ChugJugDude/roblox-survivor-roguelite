--!strict
-- Hit feedback and player feedback visuals (client/HitEffects, client/PlayerFeedback). The caps keep
-- crowds of 200 enemies from flooding the screen or the frame budget; lower them if phones struggle.

return table.freeze({
	-- Sparks: hit enemies per network batch that get a spark burst, and particles per burst.
	SPARK_ENEMIES_PER_BATCH = 8,
	SPARKS_PER_HIT = 4,
	-- Death puffs: removals per batch that get a puff (a stage clear removes everything at once).
	PUFFS_PER_BATCH = 10,
	PUFF_PARTICLES = 6,
	ELITE_PUFF_PARTICLES = 16, -- elites and bosses also get a gold burst and a flash of light

	-- Damage numbers.
	NUMBER_POOL = 30, -- most on screen at once
	NUMBER_LIFETIME = 0.7, -- seconds
	NUMBER_RISE = 3, -- studs over its lifetime
	NUMBER_MERGE_TIME = 0.25, -- hits on the same enemy within this many seconds add into one number
	BIG_HIT = 50, -- at or above this, the number is bigger and gold
	-- When every number is in use, hits below this are skipped instead of taking the oldest number.
	NUMBER_STEAL_MIN = 20,

	-- Taking damage: a red screen-edge flash and a short camera shake, both scaled by the hit's share
	-- of max health (a hit of HURT_FULL_FRACTION or more gets the full effect).
	HURT_FULL_FRACTION = 0.2,
	HURT_FLASH_TIME = 0.45,
	HURT_SHAKE = 0.6, -- studs
	HURT_SHAKE_TIME = 0.25,

	-- Level-ups and evolutions: a ring racing out across the floor from each player, plus sparkles.
	LEVEL_RING_RADIUS = 10,
	EVOLVE_RING_RADIUS = 16,
	RING_TIME = 0.5,
	EVOLVE_FLASH_TIME = 0.5,
})
