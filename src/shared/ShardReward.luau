--!strict
-- The Shards a run earns, with a line-by-line breakdown. The server grants the total; the results
-- screen shows the same lines, so they always agree.

local Config = require(script.Parent.Config.Meta)
local TimeFormat = require(script.Parent.TimeFormat)

export type RunResult = {
	time: number, -- seconds from the end of the countdown to the end of the run
	kills: number,
	stagesCleared: number,
	bosses: number,
	victory: boolean,
}

export type Line = {
	label: string,
	amount: number,
}

local ShardReward = {}

-- Returns the total and its breakdown. `greed` is the player's Greed bonus (0.1 = +10%).
function ShardReward.compute(result: RunResult, greed: number): (number, { Line })
	local lines: { Line } = {
		{
			label = `Survived {TimeFormat.minutesSeconds(result.time)}`,
			amount = math.floor(math.max(0, result.time) / 60 * Config.SHARDS_PER_MINUTE),
		},
		{ label = `{result.kills} kills`, amount = math.floor(math.max(0, result.kills) / Config.KILLS_PER_SHARD) },
		{
			label = `{result.stagesCleared} stages cleared`,
			amount = math.max(0, result.stagesCleared) * Config.SHARDS_PER_STAGE_CLEARED,
		},
		{ label = `{result.bosses} giants slain`, amount = math.max(0, result.bosses) * Config.SHARDS_PER_BOSS },
	}
	if result.victory then
		table.insert(lines, { label = "Victory", amount = Config.SHARDS_FOR_VICTORY })
	end
	local subtotal = 0
	for _, line in lines do
		subtotal += line.amount
	end
	local bonus = math.floor(subtotal * math.max(0, greed))
	if bonus > 0 then
		table.insert(lines, { label = `Greed +{math.floor(greed * 100 + 0.5)}%`, amount = bonus })
	end
	return subtotal + bonus, lines
end

return ShardReward
