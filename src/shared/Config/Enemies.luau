--!strict
-- Enemy stats and the tuning for how enemies move and replicate.

export type EnemyDef = {
	maxHealth: number,
	speed: number, -- studs per second
	radius: number, -- body size for crowding, contact, and weapon hits
	contactDamage: number,
	attackCooldown: number, -- seconds between contact hits from one enemy
	xp: number, -- XP in the gem it drops
	-- "chase" walks straight at the nearest player; "ranged" keeps a distance band and shoots;
	-- "prop" is a breakable object (crates): never moves or attacks, isn't counted as an enemy or a
	-- kill, and auto-aim ignores it. "boss" chases like "chase" between the attacks in `boss`
	-- (server/BossBrain.luau).
	behavior: "chase" | "ranged" | "prop" | "boss",
	groupSize: number?, -- spawns this many together (bats)
	ranged: RangedDef?,
	boss: BossDef?,
	isBoss: boolean?, -- shown on the boss health bar
	dropsChest: boolean?,
	displayName: string?, -- for the boss bar
	codex: CodexEntry?, -- its page in the lobby's Codex (shared/Codex.luau)
}

export type CodexEntry = {
	order: number,
	name: string,
	icon: string, -- an emoji until there's art
	description: string,
}

-- A boss's attacks (server/BossBrain.luau). Every attackInterval seconds it does the next attack
-- in `pattern`. Below enrageAt of its health it attacks every enragedInterval seconds and its
-- rings come in pairs. Damage values are scaled by the stage like contact damage.
export type BossDef = {
	pattern: { "Ring" | "Charge" | "Summon" | "Eruption" },
	firstAttackDelay: number,
	attackInterval: number,
	enragedInterval: number,
	enrageAt: number, -- health fraction
	-- Ring: shots in every direction at once.
	ringShots: number,
	ringSpeed: number,
	ringDamage: number,
	ringRange: number,
	-- Summon: a circle of adds around the boss.
	summonKind: string,
	summonCount: number,
	summonRadius: number,
	-- Charge: stops, shows a red lane for chargeWindup seconds, then dashes down it.
	chargeWindup: number,
	chargeSpeed: number,
	chargeDistance: number,
	chargeDamage: number,
	-- Eruption (the Infernal's signature): red circles under and around players that burst after
	-- eruptionWindup seconds, hurting anyone inside. Enraged, it makes half again as many.
	eruptionCount: number?,
	eruptionRadius: number?,
	eruptionWindup: number?,
	eruptionDamage: number?,
	eruptionSpread: number?, -- the extra circles land within this many studs of a player
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
			codex = table.freeze({
				order = 1,
				name = "Goblin",
				icon = "👺",
				description = "Runs straight at the nearest player. Weak alone, dangerous in a crowd.",
			}),
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
			codex = table.freeze({
				order = 2,
				name = "Bat swarm",
				icon = "🦇",
				description = "Fast and fragile, and always comes in a group.",
			}),
			maxHealth = 12,
			speed = 15,
			radius = 1,
			contactDamage = 5,
			attackCooldown = 0.8,
			xp = 1,
			behavior = "chase",
			groupSize = 5,
		}),
		-- Hangs back and fires slow arrows the player has to dodge. Each hit stings less than a goblin's:
		-- archers are dangerous because several shoot at once, not per shot.
		SkeletonArcher = table.freeze({
			codex = table.freeze({
				order = 3,
				name = "Skeleton archer",
				icon = "💀",
				description = "Keeps its distance and shoots slow crimson orbs. Dodge them.",
			}),
			maxHealth = 25,
			speed = 8,
			radius = 1.4,
			contactDamage = 4,
			attackCooldown = 1,
			xp = 2,
			behavior = "ranged",
			ranged = table.freeze({
				preferredMin = 18,
				preferredMax = 26,
				shotRange = 34,
				shotCooldown = 2.5,
				shotSpeed = 22,
				shotDamage = 4,
			}),
		}),
		-- Mid-stage mini-boss. Slow, tanky, hits hard, drops a chest.
		GoblinGiant = table.freeze({
			codex = table.freeze({
				order = 4,
				name = "Goblin Giant",
				icon = "🗿",
				description = "A slow, tanky mini-boss that hits hard. Drops a chest.",
			}),
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
		-- The final boss, guarding the end of the run (Config.Waves finalBoss). Slow, huge, and
		-- dangerous through its attacks rather than its walk.
		Ogre = table.freeze({
			codex = table.freeze({
				order = 5,
				name = "Ogre",
				icon = "👹",
				description = "Guards the end of the run. Fires rings of shots, summons goblins, and charges down a red lane. Enrages when hurt.",
			}),
			-- x3 on stage 3. A maxed triple-evolution build kills it in ~25s; a typical one takes longer.
			maxHealth = 4000,
			speed = 5,
			radius = 4.5,
			contactDamage = 20,
			attackCooldown = 1.2,
			xp = 0,
			behavior = "boss",
			isBoss = true,
			displayName = "Ogre",
			boss = table.freeze({
				pattern = { "Ring", "Charge", "Summon", "Ring", "Charge" },
				firstAttackDelay = 2.5,
				attackInterval = 4,
				enragedInterval = 2.6,
				enrageAt = 0.33,
				ringShots = 16,
				ringSpeed = 16,
				ringDamage = 6,
				ringRange = 60,
				summonKind = "Goblin",
				summonCount = 6,
				summonRadius = 8,
				chargeWindup = 1.1,
				chargeSpeed = 45,
				chargeDistance = 45,
				chargeDamage = 22,
			}),
		}),
		-- The Volcano (Config.Worlds): tougher reskins of the Meadow's enemies.
		FireImp = table.freeze({
			codex = table.freeze({
				order = 6,
				name = "Fire imp",
				icon = "😈",
				description = "A goblin's nastier cousin from the Volcano: quicker, tougher, and it hits harder.",
			}),
			maxHealth = 45,
			speed = 10,
			radius = 1.5,
			contactDamage = 8,
			attackCooldown = 1,
			xp = 2,
			behavior = "chase",
		}),
		MagmaHound = table.freeze({
			codex = table.freeze({
				order = 7,
				name = "Magma hound",
				icon = "🐺",
				description = "Hunts in packs of three. Fast, hot, and hard to outrun.",
			}),
			maxHealth = 30,
			speed = 14,
			radius = 1.3,
			contactDamage = 7,
			attackCooldown = 0.8,
			xp = 2,
			behavior = "chase",
			groupSize = 3,
		}),
		EmberArcher = table.freeze({
			codex = table.freeze({
				order = 8,
				name = "Ember archer",
				icon = "🔥",
				description = "Shoots crimson orbs faster and from farther away than a skeleton archer.",
			}),
			maxHealth = 40,
			speed = 8,
			radius = 1.4,
			contactDamage = 5,
			attackCooldown = 1,
			xp = 3,
			behavior = "ranged",
			ranged = table.freeze({
				preferredMin = 20,
				preferredMax = 28,
				shotRange = 38,
				shotCooldown = 2.2,
				shotSpeed = 24,
				shotDamage = 6,
			}),
		}),
		MagmaGolem = table.freeze({
			codex = table.freeze({
				order = 9,
				name = "Magma Golem",
				icon = "🪨",
				description = "The Volcano's mini-boss: a walking slab of cooling lava. Slow, huge, and tough. Drops a chest.",
			}),
			maxHealth = 900,
			speed = 6,
			radius = 3.8,
			contactDamage = 26,
			attackCooldown = 1.2,
			xp = 35,
			behavior = "chase",
			isBoss = true,
			dropsChest = true,
			displayName = "Magma Golem",
		}),
		-- The Volcano's final boss: a horned demon whose signature attack bursts the ground under
		-- players.
		Infernal = table.freeze({
			codex = table.freeze({
				order = 10,
				name = "Infernal",
				icon = "👿",
				description = "The Volcano's boss. Fires rings of shots, calls fire imps, charges, and makes the ground erupt under you: get out of the red circles.",
			}),
			-- x4.6 on Volcano stage 3. Two evolutions + Might 3 + Haste 3 kill it in ~70s (the Ogre: 49s).
			maxHealth = 4200,
			speed = 5.5,
			radius = 4.5,
			contactDamage = 24,
			attackCooldown = 1.2,
			xp = 0,
			behavior = "boss",
			isBoss = true,
			displayName = "Infernal",
			boss = table.freeze({
				pattern = { "Ring", "Eruption", "Charge", "Summon", "Eruption", "Ring", "Charge" },
				firstAttackDelay = 2.5,
				attackInterval = 3.6,
				enragedInterval = 2.4,
				enrageAt = 0.33,
				ringShots = 18,
				ringSpeed = 17,
				ringDamage = 7,
				ringRange = 60,
				summonKind = "FireImp",
				summonCount = 6,
				summonRadius = 8,
				chargeWindup = 1,
				chargeSpeed = 48,
				chargeDistance = 48,
				chargeDamage = 26,
				eruptionCount = 6,
				eruptionRadius = 5,
				eruptionWindup = 1.2,
				eruptionDamage = 20,
				eruptionSpread = 14,
			}),
		}),
		-- Breakable supply crate. Weapons that touch it break it; it always drops an item.
		Crate = table.freeze({
			maxHealth = 40,
			speed = 0,
			radius = 1.6,
			contactDamage = 0,
			attackCooldown = 1,
			xp = 0,
			behavior = "prop",
		}),
	}) :: { [string]: EnemyDef },

	-- Elites: a tougher, bigger, glowing version of a regular enemy that drops a chest. Multipliers
	-- apply on top of stage scaling. When they appear: Config.Waves ELITE_*.
	ELITE_DESCRIPTION = "A bigger, golden version of a regular enemy: much tougher, hits harder, and drops a chest.",
	ELITE = table.freeze({
		health = 8,
		damage = 1.5,
		xp = 5,
		scale = 1.6, -- body size (hit radius and model)
	}),

	-- Bosses and mini-bosses take this fraction of any slow (Frost Nova), so they can't be pinned.
	BOSS_SLOW_MULTIPLIER = 0.5,

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
