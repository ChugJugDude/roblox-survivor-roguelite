--!strict
--[[
	Meta progression: Shards, heroes, and the Altar. The only gameplay code that reads or writes
	player data (through server/PlayerData).

	Each player's Shards and selected Hero are mirrored as Player attributes for the HUD (and
	playtest tooling). When a run ends, awardRun grants its Shards (shared/ShardReward) and
	publishes ResultShards and ResultGreed on the player for the results screen.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerData = require(script.Parent.PlayerData)
local MetaStats = require(ReplicatedStorage.Shared.MetaStats)
local PlayerDataConfig = require(ReplicatedStorage.Shared.Config.PlayerData)
local ShardReward = require(ReplicatedStorage.Shared.ShardReward)

type Data = PlayerDataConfig.Data

local started = false

local Meta = {}

local function totalsFor(data: Data): MetaStats.Totals
	return MetaStats.totals(MetaStats.validHero(data.hero, data.heroes), data.altar)
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

function Meta.start()
	assert(not started, "Meta.start() was called twice")
	started = true

	PlayerData.onChanged(function(player, data)
		player:SetAttribute("Shards", data.shards)
		player:SetAttribute("Hero", MetaStats.validHero(data.hero, data.heroes))
	end)
end

return Meta
