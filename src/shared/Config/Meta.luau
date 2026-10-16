--!strict
-- Meta progression (server/Meta.luau): Shards earned per run, heroes, and the Altar's permanent
-- upgrades. Shared so the client can show costs, effects, and the Shard breakdown.

-- A permanent stat bonus. Fractions add to the matching BuildStats modifier (0.05 = +5%).
export type Stat =
	"damage" -- weapon damage, fraction
	| "area" -- weapon area, fraction
	| "moveSpeed" -- fraction
	| "pickupRadius" -- fraction
	| "maxHealth" -- flat HP
	| "greed" -- Shards from runs, fraction
	| "rerolls" -- extra rerolls per run
	| "reviveSpeed" -- fraction of revive time saved when this player revives someone
	| "headStart" -- free upgrade picks at the start of a run

export type HeroDef = {
	order: number,
	name: string,
	weapon: string, -- starting weapon id in Config.Upgrades.WEAPONS
	stat: Stat, -- the innate bonus
	amount: number,
	bonusText: string,
	cost: number, -- Shards to unlock; 0 = unlocked from the start
}

export type AltarDef = {
	order: number,
	name: string,
	stat: Stat,
	perLevel: number, -- added to `stat` per level
	maxLevel: number,
	baseCost: number, -- cost of level 1; each later level costs COST_GROWTH times the last
	description: string, -- per level, e.g. "+5% weapon damage"
}

return table.freeze({
	-- Shards per run, win or lose (shared/ShardReward.luau). Party size doesn't change them.
	SHARDS_PER_MINUTE = 6,
	KILLS_PER_SHARD = 25,
	SHARDS_PER_STAGE_CLEARED = 20,
	SHARDS_PER_BOSS = 15, -- each boss (Goblin Giant, Ogre: any isBoss enemy) the party killed
	SHARDS_FOR_VICTORY = 40,

	DEFAULT_HERO = "Knight",
	HEROES = table.freeze({
		Knight = table.freeze({
			order = 1,
			name = "Knight",
			weapon = "SpinningBlade",
			stat = "maxHealth",
			amount = 20,
			bonusText = "+20 max HP",
			cost = 0,
		}),
		Ranger = table.freeze({
			order = 2,
			name = "Ranger",
			weapon = "VolleyArrows",
			stat = "moveSpeed",
			amount = 0.1,
			bonusText = "+10% move speed",
			cost = 0,
		}),
		Pyromancer = table.freeze({
			order = 3,
			name = "Pyromancer",
			weapon = "Fireball",
			stat = "area",
			amount = 0.15,
			bonusText = "+15% weapon area",
			cost = 400,
		}),
	}) :: { [string]: HeroDef },

	COST_GROWTH = 1.5,
	ALTAR = table.freeze({
		Might = table.freeze({
			order = 1,
			name = "Might",
			stat = "damage",
			perLevel = 0.05,
			maxLevel = 5,
			baseCost = 60,
			description = "+5% weapon damage",
		}),
		Vitality = table.freeze({
			order = 2,
			name = "Vitality",
			stat = "maxHealth",
			perLevel = 8,
			maxLevel = 5,
			baseCost = 50,
			description = "+8 max HP",
		}),
		Swiftness = table.freeze({
			order = 3,
			name = "Swiftness",
			stat = "moveSpeed",
			perLevel = 0.03,
			maxLevel = 5,
			baseCost = 50,
			description = "+3% move speed",
		}),
		Magnet = table.freeze({
			order = 4,
			name = "Magnet",
			stat = "pickupRadius",
			perLevel = 0.1,
			maxLevel = 5,
			baseCost = 40,
			description = "+10% pickup radius",
		}),
		Greed = table.freeze({
			order = 5,
			name = "Greed",
			stat = "greed",
			perLevel = 0.1,
			maxLevel = 5,
			baseCost = 80,
			description = "+10% Shards from runs",
		}),
		Reroll = table.freeze({
			order = 6,
			name = "Reroll",
			stat = "rerolls",
			perLevel = 1,
			maxLevel = 2,
			baseCost = 150,
			description = "+1 reroll per run",
		}),
		Rescue = table.freeze({
			order = 7,
			name = "Rescue",
			stat = "reviveSpeed",
			perLevel = 0.15,
			maxLevel = 3,
			baseCost = 70,
			description = "Revive teammates 15% faster",
		}),
		HeadStart = table.freeze({
			order = 8,
			name = "Head Start",
			stat = "headStart",
			perLevel = 1,
			maxLevel = 2,
			baseCost = 200,
			description = "+1 free upgrade pick at the start of a run",
		}),
	}) :: { [string]: AltarDef },
})
