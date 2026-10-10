--!strict
-- The shape of a run (server/Run.luau): timed stages, each ending in overtime, where a portal
-- has to be charged to move on.

return table.freeze({
	STAGE_COUNT = 3,
	-- Seconds per stage before overtime starts.
	STAGE_DURATION = 180,
	-- Seconds of "3, 2, 1" before stage 1.
	COUNTDOWN = 3,
	-- Seconds of breather between stages.
	STAGE_TRANSITION = 3,

	-- Seconds a player has to stand in the portal to charge it. Charge doesn't drain when they
	-- step out.
	PORTAL_CHARGE_TIME = 8,
	PORTAL_RADIUS = 7,
	-- The portal opens this far from a random living player.
	PORTAL_DISTANCE_MIN = 25,
	PORTAL_DISTANCE_MAX = 45,

	-- Overtime pressure: the spawn interval is divided by (1 + OVERTIME_RAMP * seconds into
	-- overtime), and the stage's max alive is multiplied by OVERTIME_MAX_ALIVE_MULTIPLIER.
	OVERTIME_RAMP = 0.15,
	OVERTIME_MAX_ALIVE_MULTIPLIER = 2,
})
