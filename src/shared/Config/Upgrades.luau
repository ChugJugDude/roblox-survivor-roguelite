--!strict
-- Weapons, passives, and the level-up choice (server/Upgrades.luau, shared/BuildStats.luau).
-- Weapon stats are listed in full for each level so a level reads at a glance.

export type SpinningBladeStats = {
	bladeCount: number,
	-- Each blade covers this band of distance from the player's center. The inner edge is close
	-- enough to hit enemies pressed up against the player.
	innerRadius: number,
	outerRadius: number,
	width: number,
	spinSpeed: number, -- radians per second
	damage: number,
	hitCooldown: number, -- seconds before one player's blades can hit the same enemy again
}

export type VolleyArrowsStats = {
	cooldown: number, -- seconds between volleys
	arrowCount: number,
	spread: number, -- total fan angle in radians across all arrows
	speed: number, -- studs per second
	damage: number,
	pierce: number, -- enemies one arrow can hit before it stops
	range: number, -- only fires at enemies this close; arrows fly this far
	radius: number, -- hit radius
	targets: number, -- volleys fire one fan at each of this many nearest enemies
}

export type FireballStats = {
	cooldown: number,
	count: number, -- fireballs per cast, each at a different enemy
	speed: number,
	damage: number, -- dealt to every enemy in the blast
	blastRadius: number,
	range: number,
	radius: number, -- hit radius of the fireball itself
}

export type ChainLightningStats = {
	cooldown: number,
	bolts: number, -- bolts per cast, each starting on a different enemy
	chains: number, -- enemies one bolt hits, jumping to the nearest one it hasn't hit yet
	jumpRange: number, -- farthest a bolt jumps between enemies
	damage: number, -- dealt to every enemy in the chain
	range: number, -- only casts at enemies this close
}

export type FrostNovaStats = {
	cooldown: number,
	radius: number, -- around the player
	damage: number, -- dealt to every enemy in the radius
	slow: number, -- fraction of move speed taken away (bosses take half)
	slowDuration: number, -- seconds
}

-- A max-level weapon plus its paired passive (any level) unlocks the evolution, offered as a
-- level-up choice. An evolved weapon is stored as level MAX_LEVEL + 1.
export type EvolutionDef = {
	name: string,
	passive: string,
	description: string,
	stats: any, -- same shape as the weapon's level stats
}

export type WeaponDef = {
	name: string,
	descriptions: { string }, -- what each level adds, shown on the card
	levels: { any }, -- full stats per level; the type depends on the weapon
	evolution: EvolutionDef,
}

export type PassiveDef = {
	name: string,
	-- Shown on the card with this level's total, e.g. "+40% weapon damage".
	description: string,
	percent: boolean, -- show values as percentages
	values: { number }, -- total bonus at each level
}

-- One level per row so levels can be compared at a glance; StyLua would wrap the longer rows.
-- stylua: ignore
local SPINNING_BLADE_LEVELS: { SpinningBladeStats } = {
	{ bladeCount = 3, innerRadius = 2.5, outerRadius = 10, width = 1.3, spinSpeed = 4, damage = 15, hitCooldown = 0.4 },
	{ bladeCount = 4, innerRadius = 2.5, outerRadius = 10, width = 1.3, spinSpeed = 4, damage = 15, hitCooldown = 0.4 },
	{ bladeCount = 4, innerRadius = 2.5, outerRadius = 11, width = 1.4, spinSpeed = 4.5, damage = 20, hitCooldown = 0.4 },
	{ bladeCount = 5, innerRadius = 2.5, outerRadius = 11, width = 1.4, spinSpeed = 4.5, damage = 20, hitCooldown = 0.4 },
	{ bladeCount = 6, innerRadius = 2.5, outerRadius = 12, width = 1.5, spinSpeed = 5, damage = 25, hitCooldown = 0.4 },
}

-- Same one-row-per-level layout.
-- stylua: ignore
local VOLLEY_ARROWS_LEVELS: { VolleyArrowsStats } = {
	{ cooldown = 1.4, arrowCount = 1, spread = 0, speed = 70, damage = 12, pierce = 1, range = 55, radius = 0.6, targets = 1 },
	{ cooldown = 1.4, arrowCount = 2, spread = 0.25, speed = 70, damage = 12, pierce = 1, range = 55, radius = 0.6, targets = 1 },
	{ cooldown = 1.4, arrowCount = 2, spread = 0.25, speed = 70, damage = 16, pierce = 2, range = 55, radius = 0.6, targets = 1 },
	{ cooldown = 1.15, arrowCount = 3, spread = 0.35, speed = 70, damage = 16, pierce = 2, range = 55, radius = 0.6, targets = 1 },
	{ cooldown = 1.15, arrowCount = 4, spread = 0.45, speed = 70, damage = 20, pierce = 3, range = 55, radius = 0.6, targets = 1 },
}

-- Same one-row-per-level layout.
-- stylua: ignore
local FIREBALL_LEVELS: { FireballStats } = {
	{ cooldown = 2.2, count = 1, speed = 40, damage = 20, blastRadius = 5, range = 45, radius = 1 },
	{ cooldown = 2.2, count = 1, speed = 40, damage = 26, blastRadius = 6, range = 45, radius = 1 },
	{ cooldown = 2.2, count = 2, speed = 40, damage = 26, blastRadius = 6, range = 45, radius = 1 },
	{ cooldown = 2.2, count = 2, speed = 40, damage = 34, blastRadius = 7, range = 45, radius = 1 },
	{ cooldown = 1.8, count = 3, speed = 40, damage = 34, blastRadius = 7, range = 45, radius = 1 },
}

-- Same one-row-per-level layout.
-- stylua: ignore
local CHAIN_LIGHTNING_LEVELS: { ChainLightningStats } = {
	{ cooldown = 1.6, bolts = 1, chains = 3, jumpRange = 12, damage = 18, range = 40 },
	{ cooldown = 1.6, bolts = 1, chains = 4, jumpRange = 12, damage = 18, range = 40 },
	{ cooldown = 1.6, bolts = 1, chains = 4, jumpRange = 13, damage = 24, range = 40 },
	{ cooldown = 1.6, bolts = 2, chains = 5, jumpRange = 13, damage = 24, range = 40 },
	{ cooldown = 1.3, bolts = 2, chains = 6, jumpRange = 14, damage = 28, range = 40 },
}

-- Same one-row-per-level layout.
-- stylua: ignore
local FROST_NOVA_LEVELS: { FrostNovaStats } = {
	{ cooldown = 3, radius = 9, damage = 14, slow = 0.4, slowDuration = 1.5 },
	{ cooldown = 3, radius = 10, damage = 18, slow = 0.4, slowDuration = 1.5 },
	{ cooldown = 3, radius = 11, damage = 18, slow = 0.5, slowDuration = 2 },
	{ cooldown = 2.7, radius = 12, damage = 22, slow = 0.5, slowDuration = 2 },
	{ cooldown = 2.4, radius = 13, damage = 26, slow = 0.55, slowDuration = 2.5 },
}

return table.freeze({
	MAX_LEVEL = 5,
	MAX_WEAPONS = 4,
	MAX_PASSIVES = 4,
	OPTION_COUNT = 3,
	REROLLS_PER_RUN = 1,
	-- Seconds of invulnerability when a chest's choice opens (chest picks don't pause the game).
	INVULNERABILITY = 2,
	-- Level-up picks pause the whole game. After a pause ends, the next one waits at least this many
	-- seconds of play; picks earned meanwhile come up together in that next pause.
	PAUSE_COOLDOWN = 5,
	-- With 2+ players, a pause lasts at most this many seconds; anyone still choosing gets random
	-- picks. Solo has no limit.
	PAUSE_TIMEOUT = 15,
	-- Seconds of invulnerability for everyone when the game resumes, to get their bearings.
	RESUME_GRACE = 1.5,
	-- The filler option when there aren't enough upgrades left: heal this fraction of max health.
	HEAL_FRACTION = 0.3,
	-- (Starting weapons come from the hero: Config.Meta.HEROES.)

	-- Relative chance of each kind of option. Levels for weapons you own come up often, so a build can
	-- reach an evolution even with six passives competing for the cards.
	WEIGHTS = table.freeze({
		newWeapon = 3,
		weaponLevel = 3.5,
		newPassive = 1.5,
		passiveLevel = 1.5,
	}),

	WEAPONS = table.freeze({
		SpinningBlade = table.freeze({
			name = "Spinning Blade",
			descriptions = {
				"Blades orbit you, cutting through enemies.",
				"+1 blade.",
				"+33% damage. Longer, faster blades.",
				"+1 blade.",
				"+1 blade. +25% damage. Longer, faster blades.",
			},
			levels = SPINNING_BLADE_LEVELS,
			evolution = table.freeze({
				name = "Bladestorm",
				passive = "Might",
				description = "Eight huge blades that shred everything around you.",
				stats = table.freeze({
					bladeCount = 8,
					innerRadius = 2,
					outerRadius = 14,
					width = 2,
					spinSpeed = 6,
					damage = 34,
					hitCooldown = 0.3,
				}) :: SpinningBladeStats,
			}),
		}),
		VolleyArrows = table.freeze({
			name = "Volley Arrows",
			descriptions = {
				"Fires arrows at the nearest enemy.",
				"+1 arrow.",
				"+33% damage. Arrows pierce 1 more enemy.",
				"+1 arrow. Fires faster.",
				"+1 arrow. +25% damage. Pierces 1 more.",
			},
			levels = VOLLEY_ARROWS_LEVELS,
			evolution = table.freeze({
				name = "Arrow Storm",
				passive = "Swiftness",
				description = "Rapid fans of piercing arrows at the three nearest enemies.",
				stats = table.freeze({
					cooldown = 0.6,
					arrowCount = 4,
					spread = 0.45,
					speed = 85,
					damage = 22,
					pierce = 5,
					range = 60,
					radius = 0.7,
					targets = 3,
				}) :: VolleyArrowsStats,
			}),
		}),
		Fireball = table.freeze({
			name = "Fireball",
			descriptions = {
				"Hurls a fireball that explodes on impact.",
				"+30% damage. Bigger blast.",
				"+1 fireball.",
				"+30% damage. Bigger blast.",
				"+1 fireball. Casts faster.",
			},
			levels = FIREBALL_LEVELS,
			evolution = table.freeze({
				name = "Meteor",
				passive = "Reach",
				description = "Calls down meteors with huge, devastating blasts.",
				stats = table.freeze({
					cooldown = 1.6,
					count = 4,
					speed = 55,
					damage = 60,
					blastRadius = 11,
					range = 50,
					radius = 1.5,
				}) :: FireballStats,
			}),
		}),
		ChainLightning = table.freeze({
			name = "Chain Lightning",
			descriptions = {
				"Lightning strikes the nearest enemy and jumps to others.",
				"Jumps to 1 more enemy.",
				"+33% damage. Jumps farther.",
				"+1 bolt. Jumps to 1 more enemy.",
				"+17% damage. Jumps to 1 more. Casts faster.",
			},
			levels = CHAIN_LIGHTNING_LEVELS,
			evolution = table.freeze({
				name = "Thunderstorm",
				passive = "Haste",
				description = "Four rapid bolts that arc through whole crowds.",
				stats = table.freeze({
					cooldown = 0.9,
					bolts = 4,
					chains = 8,
					jumpRange = 16,
					damage = 34,
					range = 45,
				}) :: ChainLightningStats,
			}),
		}),
		FrostNova = table.freeze({
			name = "Frost Nova",
			descriptions = {
				"A freezing burst around you that slows enemies.",
				"+29% damage. Bigger burst.",
				"Stronger, longer slow. Bigger burst.",
				"+22% damage. Bigger burst. Bursts faster.",
				"+18% damage. Stronger, longer slow. Bursts faster.",
			},
			levels = FROST_NOVA_LEVELS,
			evolution = table.freeze({
				name = "Blizzard",
				passive = "Armor",
				description = "A huge, rapid freeze that nearly stops enemies in their tracks.",
				stats = table.freeze({
					cooldown = 2,
					radius = 18,
					damage = 40,
					slow = 0.8,
					slowDuration = 3,
				}) :: FrostNovaStats,
			}),
		}),
	}) :: { [string]: WeaponDef },

	PASSIVES = table.freeze({
		Might = table.freeze({
			name = "Might",
			description = "+%d%% weapon damage",
			percent = true,
			values = { 0.2, 0.4, 0.6, 0.8, 1 },
		}),
		Haste = table.freeze({
			name = "Haste",
			description = "%d%% shorter cooldowns, faster blades",
			percent = true,
			values = { 0.08, 0.16, 0.24, 0.32, 0.4 },
		}),
		Swiftness = table.freeze({
			name = "Swiftness",
			description = "+%d%% move speed",
			percent = true,
			values = { 0.08, 0.16, 0.24, 0.32, 0.4 },
		}),
		Reach = table.freeze({
			name = "Reach",
			description = "+%d%% weapon area",
			percent = true,
			values = { 0.15, 0.3, 0.45, 0.6, 0.75 },
		}),
		Vitality = table.freeze({
			name = "Vitality",
			description = "+%d max health",
			percent = false,
			values = { 20, 40, 60, 80, 100 },
		}),
		Magnet = table.freeze({
			name = "Magnet",
			description = "+%d%% pickup range",
			percent = true,
			values = { 0.4, 0.8, 1.2, 1.6, 2 },
		}),
		Armor = table.freeze({
			name = "Armor",
			description = "%d%% less damage taken",
			percent = true,
			values = { 0.06, 0.12, 0.18, 0.24, 0.3 },
		}),
	}) :: { [string]: PassiveDef },
})
