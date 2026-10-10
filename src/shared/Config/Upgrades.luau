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

export type WeaponDef = {
	name: string,
	descriptions: { string }, -- what each level adds, shown on the card
	levels: { any }, -- full stats per level; the type depends on the weapon
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
	{ bladeCount = 2, innerRadius = 2.5, outerRadius = 8, width = 1.2, spinSpeed = 3.5, damage = 10, hitCooldown = 0.4 },
	{ bladeCount = 3, innerRadius = 2.5, outerRadius = 8, width = 1.2, spinSpeed = 3.5, damage = 10, hitCooldown = 0.4 },
	{ bladeCount = 3, innerRadius = 2.5, outerRadius = 9, width = 1.3, spinSpeed = 4, damage = 14, hitCooldown = 0.4 },
	{ bladeCount = 4, innerRadius = 2.5, outerRadius = 9, width = 1.3, spinSpeed = 4, damage = 14, hitCooldown = 0.4 },
	{ bladeCount = 5, innerRadius = 2.5, outerRadius = 10, width = 1.4, spinSpeed = 4.5, damage = 18, hitCooldown = 0.4 },
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
				"+40% damage. Longer, faster blades.",
				"+1 blade.",
				"+1 blade. +30% damage. Longer blades.",
			},
			levels = SPINNING_BLADE_LEVELS,
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
