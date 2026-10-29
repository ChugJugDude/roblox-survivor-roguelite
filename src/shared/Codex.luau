--!strict
-- Everything the collection log (the lobby's Codex) can list, in display order, built from the
-- upgrade and enemy configs. A player's discoveries are saved as `collection[key] = true`
-- (server/Meta.discover); the keys are "W:<weapon>", "V:<weapon>" (its evolution), "P:<passive>",
-- and "E:<enemy kind>" (plus "E:Elite").

local BuildStats = require(script.Parent.BuildStats)
local EnemiesConfig = require(script.Parent.Config.Enemies)
local UpgradesConfig = require(script.Parent.Config.Upgrades)

export type Tab = "Weapons" | "Passives" | "Enemies"

export type Entry = {
	key: string,
	tab: Tab,
	name: string,
	icon: string,
	description: string,
	golden: boolean, -- evolutions and bosses get a gold frame
}

local Codex = {}

Codex.TABS = table.freeze({ "Weapons", "Passives", "Enemies" }) :: { Tab }

local function byName(defs: { [string]: { name: string } }): { string }
	local ids = {}
	for id in defs do
		table.insert(ids, id)
	end
	table.sort(ids, function(a, b)
		return defs[a].name < defs[b].name
	end)
	return ids
end

local entries: { Entry } = {}

-- Weapons, then their evolutions.
for _, id in byName(UpgradesConfig.WEAPONS) do
	local def = UpgradesConfig.WEAPONS[id]
	table.insert(entries, {
		key = `W:{id}`,
		tab = "Weapons",
		name = def.name,
		icon = def.icon,
		description = def.descriptions[1],
		golden = false,
	})
end
for _, id in byName(UpgradesConfig.WEAPONS) do
	local def = UpgradesConfig.WEAPONS[id]
	local pair = UpgradesConfig.PASSIVES[def.evolution.passive]
	table.insert(entries, {
		key = `V:{id}`,
		tab = "Weapons",
		name = def.evolution.name,
		icon = def.icon,
		description = `{def.evolution.description}\nEvolves from {def.name} (level {UpgradesConfig.MAX_LEVEL}) with {pair.name}.`,
		golden = true,
	})
end
for _, id in byName(UpgradesConfig.PASSIVES) do
	local def = UpgradesConfig.PASSIVES[id]
	table.insert(entries, {
		key = `P:{id}`,
		tab = "Passives",
		name = def.name,
		icon = def.icon,
		description = `At max level: {BuildStats.passiveText(id, UpgradesConfig.MAX_LEVEL)}`,
		golden = false,
	})
end

-- Enemies with a codex entry, in their codex order (crates have none).
local enemyKinds = {}
for kind, def in EnemiesConfig.TYPES do
	if def.codex then
		table.insert(enemyKinds, kind)
	end
end
table.sort(enemyKinds, function(a, b)
	return (EnemiesConfig.TYPES[a].codex :: any).order < (EnemiesConfig.TYPES[b].codex :: any).order
end)
for _, kind in enemyKinds do
	local def = EnemiesConfig.TYPES[kind]
	local codex = def.codex :: EnemiesConfig.CodexEntry
	table.insert(entries, {
		key = `E:{kind}`,
		tab = "Enemies",
		name = codex.name,
		icon = codex.icon,
		description = codex.description,
		golden = def.isBoss == true,
	})
	if codex.order == 3 then
		-- Elites come after the regular enemies (any kind can be one).
		table.insert(entries, {
			key = "E:Elite",
			tab = "Enemies",
			name = "Elite",
			icon = "🌟",
			description = EnemiesConfig.ELITE_DESCRIPTION,
			golden = false,
		})
	end
end

Codex.ENTRIES = table.freeze(entries)

-- Whether `key` is something the Codex lists (the server only saves known keys).
function Codex.isKey(key: string): boolean
	for _, entry in entries do
		if entry.key == key then
			return true
		end
	end
	return false
end

return Codex
