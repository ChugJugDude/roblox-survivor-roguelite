--!strict
-- Game time: the shared server clock minus all the time the game has spent paused, so it stands
-- still during a pause. Everything gameplay-related (stage timers, cooldowns, projectile flight,
-- blade spin, enemy snapshots) runs on it, which is what makes a pause freeze the whole game.
--
-- server/Pause.luau owns the clock and publishes it on the Arena as ClockOffset (total seconds
-- paused so far) and PausedAt (server time the current pause began, 0 when running).

local GameClock = {}

-- Game time from the clock's two values.
function GameClock.compute(offset: number, pausedAt: number): number
	local serverTime = if pausedAt > 0 then pausedAt else workspace:GetServerTimeNow()
	return serverTime - offset
end

-- Game time as clients see it, from the Arena's attributes.
function GameClock.read(arena: Instance): number
	return GameClock.compute(arena:GetAttribute("ClockOffset") or 0, arena:GetAttribute("PausedAt") or 0)
end

function GameClock.isPaused(arena: Instance): boolean
	return (arena:GetAttribute("PausedAt") or 0) > 0
end

return GameClock
