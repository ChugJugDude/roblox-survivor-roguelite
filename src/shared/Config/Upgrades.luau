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
	{ cooldown = 1.4, arrowCount = 1, spread = 0, speed = 70, damage = 12, pierce = 1, range = 55, radius = 0.6 },
	{ cooldown = 1.4, arrowCount = 2, spread = 0.25, speed = 70, damage = 12, pierce = 1, range = 55, radius = 0.6 },
	{ cooldown = 1.4, arrowCount = 2, spread = 0.25, speed = 70, damage = 16, pierce = 2, range = 55, radius = 0.6 },
	{ cooldown = 1.15, arrowCount = 3, spread = 0.35, speed = 70, damage = 16, pierce = 2, range = 55, radius = 0.6 },
	{ cooldown = 1.15, arrowCount = 4, spread = 0.45, speed = 70, damage = 20, pierce = 3, range = 55, radius = 0.6 },
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

return table.freeze({
	MAX_LEVEL = 5,
	MAX_WEAPONS = 4,
	MAX_PASSIVES = 4,
	OPTION_COUNT = 3,
	REROLLS_PER_RUN = 1,
	-- Seconds of invulnerability when a level-up choice opens (the game doesn't pause).
	INVULNERABILITY = 2,
	-- The filler option when there aren't enough upgrades left: heal this fraction of max health.
	HEAL_FRACTION = 0.3,
	STARTING_WEAPON = "SpinningBlade",

	-- Relative chance of each kind of option. New weapons come up more while there's room for them.
	WEIGHTS = table.freeze({
		newWeapon = 3,
		weaponLevel = 2,
		newPassive = 2,
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
				description = "A rapid, wide fan of arrows that pierce through crowds.",
				stats = table.freeze({
					cooldown = 0.6,
					arrowCount = 7,
					spread = 1.2,
					speed = 85,
					damage = 22,
					pierce = 5,
					range = 60,
					radius = 0.7,
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
	}) :: { [string]: PassiveDef },
})
