--!strict
-- Meta progression math shared by the server (what's granted and charged) and the client (what the
-- menus show): Altar costs, and the permanent bonuses from a hero plus Altar levels.

local Config = require(script.Parent.Config.Meta)

-- Every permanent bonus, summed. Fractions are 0.05 for +5%.
export type Totals = {
	damage: number,
	area: number,
	moveSpeed: number,
	pickupRadius: number,
	maxHealth: number,
	greed: number,
	rerolls: number,
	reviveSpeed: number,
	headStart: number,
}

local MetaStats = {}

-- Shards to buy `level` of an Altar upgrade (level 1 costs baseCost), rounded to a multiple of 5.
function MetaStats.altarCost(id: string, level: number): number
	local def = Config.ALTAR[id]
	local raw = def.baseCost * Config.COST_GROWTH ^ (level - 1)
	return math.floor(raw / 5 + 0.5) * 5
end

-- The hero to use: `hero` if it's known and unlocked, otherwise the default.
function MetaStats.validHero(hero: string?, unlocked: { [string]: boolean }): string
	local def = if hero then Config.HEROES[hero] else nil
	if def and (def.cost == 0 or unlocked[hero :: string]) then
		return hero :: string
	end
	return Config.DEFAULT_HERO
end

-- The bonuses from `hero`'s innate stat plus every Altar level.
function MetaStats.totals(hero: string, altar: { [string]: number }): Totals
	local sums: { [string]: number } = {}
	local heroDef = Config.HEROES[hero]
	if heroDef then
		sums[heroDef.stat] = (sums[heroDef.stat] or 0) + heroDef.amount
	end
	for id, level in altar do
		local def = Config.ALTAR[id]
		if def and typeof(level) == "number" then
			local levels = math.clamp(math.floor(level), 0, def.maxLevel)
			sums[def.stat] = (sums[def.stat] or 0) + def.perLevel * levels
		end
	end
	return {
		damage = sums.damage or 0,
		area = sums.area or 0,
		moveSpeed = sums.moveSpeed or 0,
		pickupRadius = sums.pickupRadius or 0,
		maxHealth = sums.maxHealth or 0,
		greed = sums.greed or 0,
		rerolls = sums.rerolls or 0,
		reviveSpeed = sums.reviveSpeed or 0,
		headStart = sums.headStart or 0,
	}
end

return MetaStats
