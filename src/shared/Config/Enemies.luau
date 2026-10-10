--!strict
-- Enemy stats and the tuning for how enemies move and replicate.

export type EnemyDef = {
	maxHealth: number,
	speed: number, -- studs per second
	radius: number, -- body size for crowding, contact, and weapon hits
	contactDamage: number,
	attackCooldown: number, -- seconds between contact hits from one enemy
	xp: number, -- XP in the gem it drops
	-- "chase" walks straight at the nearest player; "ranged" keeps a distance band and shoots.
	behavior: "chase" | "ranged",
	groupSize: number?, -- spawns this many together (bats)
	ranged: RangedDef?,
	isBoss: boolean?, -- shown on the boss health bar
	dropsChest: boolean?,
	displayName: string?, -- for the boss bar
}

export type RangedDef = {
	preferredMin: number, -- backs away when closer than this
	preferredMax: number, -- walks closer when farther than this
	shotRange: number,
	shotCooldown: number,
	shotSpeed: number,
	shotDamage: number,
}

local Enemies = {
	TYPES = table.freeze({
		Goblin = table.freeze({
			maxHealth = 30,
			speed = 9,
			radius = 1.5,
			contactDamage = 6,
			attackCooldown = 1,
			xp = 1,
			behavior = "chase",
		}),
		-- Fast and fragile, in packs. Pressures the player to keep moving.
		Bat = table.freeze({
			maxHealth = 12,
			speed = 15,
			radius = 1,
			contactDamage = 5,
			attackCooldown = 0.8,
			xp = 1,
			behavior = "chase",
			groupSize = 5,
		}),
		-- Hangs back and fires slow arrows the player has to dodge.
		SkeletonArcher = table.freeze({
			maxHealth = 25,
			speed = 8,
			radius = 1.4,
			contactDamage = 6,
			attackCooldown = 1,
			xp = 2,
			behavior = "ranged",
			ranged = table.freeze({
				preferredMin = 18,
				preferredMax = 26,
				shotRange = 34,
				shotCooldown = 2.5,
				shotSpeed = 22,
				shotDamage = 10,
			}),
		}),
		-- Mid-stage mini-boss. Slow, tanky, hits hard, drops a chest.
		GoblinGiant = table.freeze({
			maxHealth = 600,
			speed = 6,
			radius = 3.5,
			contactDamage = 20,
			attackCooldown = 1.2,
			xp = 25,
			behavior = "chase",
			isBoss = true,
			dropsChest = true,
			displayName = "Goblin Giant",
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
	-- How long an enemy flashes white when hit.
	HIT_FLASH_TIME = 0.1,
}

return table.freeze(Enemies)
