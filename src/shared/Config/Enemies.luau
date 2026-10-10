--!strict
-- Enemy stats and the tuning for how enemies move and replicate.

export type EnemyDef = {
	maxHealth: number,
	speed: number, -- studs per second
	radius: number, -- body size for crowding, contact, and weapon hits
	contactDamage: number,
	attackCooldown: number, -- seconds between contact hits from one enemy
}

local Enemies = {
	TYPES = table.freeze({
		Goblin = table.freeze({
			maxHealth = 30,
			speed = 9,
			radius = 1.5,
			contactDamage = 8,
			attackCooldown = 1,
		}),
	}) :: { [string]: EnemyDef },

	-- Treat players as circles this wide for contact. Enemies stop at the edge of it.
	PLAYER_RADIUS = 1.5,
	-- Extra reach beyond touching, so lag between the server and client positions doesn't stop hits.
	CONTACT_TOLERANCE = 0.75,
	-- How quickly overlapping enemies push apart, per second. Higher is stiffer crowds.
	SEPARATION_STIFFNESS = 10,
	-- Grid cell size for neighbor lookups. Roughly a few enemy widths.
	SPATIAL_CELL_SIZE = 8,

	-- Position snapshots sent to clients per second.
	SNAPSHOT_RATE = 20,
	-- Clients draw enemies this many seconds in the past so they always have two snapshots to
	-- blend between. Keep it above 1 / SNAPSHOT_RATE.
	INTERPOLATION_DELAY = 0.1,
}

return table.freeze(Enemies)
