--!strict
--[[
	Meta progression: Shards, heroes, and the Altar. The only gameplay code that reads or writes
	player data (through server/PlayerData).

	Each player's Shards and selected Hero are mirrored as Player attributes for the HUD (and
	playtest tooling). When a run ends, awardRun grants its Shards (shared/ShardReward) and
	publishes ResultShards and ResultGreed on the player for the results screen.

	loadout() is what a player brings into a run: their hero's starting weapon and the permanent
	bonuses (shared/MetaStats). Heroes and Altar upgrades are chosen and bought in the lobby only
	(SelectHero, UnlockHero, BuyAltarUpgrade); a purchase checks and spends Shards inside one
	PlayerData.update.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerData = require(script.Parent.PlayerData)
local Config = require(ReplicatedStorage.Shared.Config.Meta)
local MetaStats = require(ReplicatedStorage.Shared.MetaStats)
local PlayerDataConfig = require(ReplicatedStorage.Shared.Config.PlayerData)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ShardReward = require(ReplicatedStorage.Shared.ShardReward)

type Data = PlayerDataConfig.Data

export type Loadout = {
	hero: string,
	weapon: string, -- starting weapon id
	bonus: MetaStats.Totals,
}

-- Minimum seconds between menu requests (select, unlock, buy) from one player.
local REQUEST_COOLDOWN = 0.25

local lastRequest: { [Player]: number } = {}
local loadoutListeners: { (Player) -> () } = {}
local started = false

local Meta = {}

local function totalsFor(data: Data): MetaStats.Totals
	return MetaStats.totals(MetaStats.validHero(data.hero, data.heroes), data.altar)
end

-- What `player` brings into a run. Before their data loads, the default hero with no Altar.
function Meta.loadout(player: Player): Loadout
	local data = PlayerData.get(player)
	local hero = if data then MetaStats.validHero(data.hero, data.heroes) else Config.DEFAULT_HERO
	return {
		hero = hero,
		weapon = Config.HEROES[hero].weapon,
		bonus = MetaStats.totals(hero, if data then data.altar else {}),
	}
end

-- Calls `listener(player)` whenever a player's loadout may have changed (data loaded, hero
-- picked, Altar upgrade bought).
function Meta.onLoadoutChanged(listener: (Player) -> ())
	table.insert(loadoutListeners, listener)
end

-- Grants the Shards `result` earned (with the player's Greed) and counts the run in their stats.
function Meta.awardRun(player: Player, result: ShardReward.RunResult)
	local data = PlayerData.get(player)
	local greed = if data then totalsFor(data).greed else 0
	local shards = ShardReward.compute(result, greed)
	local granted = PlayerData.update(player, function(saved)
		saved.shards += shards
		saved.stats.runs += 1
		if result.victory then
			saved.stats.wins += 1
		end
	end)
	player:SetAttribute("ResultGreed", greed)
	player:SetAttribute("ResultShards", if granted then shards else 0)
end

-- Clears last run's reward, so the results screen never shows a stale one.
function Meta.clearResult(player: Player)
	player:SetAttribute("ResultGreed", nil)
	player:SetAttribute("ResultShards", nil)
end

-- Studio dev command: add (or with a negative number, remove) Shards.
function Meta.devAddShards(player: Player, amount: number)
	PlayerData.update(player, function(data)
		data.shards = math.max(0, data.shards + math.floor(amount))
	end)
end

-- Studio dev command: back to new-player progress (Shards, heroes, Altar, stats).
function Meta.devReset(player: Player)
	PlayerData.update(player, function(data)
		local defaults = PlayerDataConfig.DEFAULT_DATA
		data.shards = defaults.shards
		data.hero = defaults.hero
		data.heroes = {}
		data.altar = {}
		data.stats = { runs = 0, wins = 0 }
	end)
end

-- Checks the common rules for a menu request: a string id, sent from the lobby (not a run), and
-- not too soon after the last one. Returns the id if the request may go ahead.
local function acceptRequest(player: Player, id: unknown): string?
	if typeof(id) ~= "string" or player:GetAttribute("ArenaName") ~= nil then
		return nil
	end
	local clock = os.clock()
	local last = lastRequest[player]
	if last and clock - last < REQUEST_COOLDOWN then
		return nil
	end
	lastRequest[player] = clock
	return id
end

local function onSelectHero(player: Player, rawId: unknown)
	local id = acceptRequest(player, rawId)
	if not id or not Config.HEROES[id] then
		return
	end
	PlayerData.update(player, function(data)
		if MetaStats.validHero(id, data.heroes) == id then
			data.hero = id
		end
	end)
end

local function onUnlockHero(player: Player, rawId: unknown)
	local id = acceptRequest(player, rawId)
	local def = if id then Config.HEROES[id] else nil
	if not id or not def or def.cost <= 0 then
		return
	end
	PlayerData.update(player, function(data)
		if data.heroes[id] or data.shards < def.cost then
			return
		end
		data.shards -= def.cost
		data.heroes[id] = true
		data.hero = id
	end)
end

local function onBuyAltarUpgrade(player: Player, rawId: unknown)
	local id = acceptRequest(player, rawId)
	local def = if id then Config.ALTAR[id] else nil
	if not id or not def then
		return
	end
	PlayerData.update(player, function(data)
		local level = data.altar[id] or 0
		if level >= def.maxLevel then
			return
		end
		local cost = MetaStats.altarCost(id, level + 1)
		if data.shards < cost then
			return
		end
		data.shards -= cost
		data.altar[id] = level + 1
	end)
end

function Meta.start()
	assert(not started, "Meta.start() was called twice")
	started = true

	PlayerData.onChanged(function(player, data)
		player:SetAttribute("Shards", data.shards)
		player:SetAttribute("Hero", MetaStats.validHero(data.hero, data.heroes))
		for _, listener in loadoutListeners do
			task.spawn(listener, player)
		end
	end)

	Remotes.SelectHero.OnServerEvent:Connect(onSelectHero)
	Remotes.UnlockHero.OnServerEvent:Connect(onUnlockHero)
	Remotes.BuyAltarUpgrade.OnServerEvent:Connect(onBuyAltarUpgrade)
	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
	end)
end

return Meta
