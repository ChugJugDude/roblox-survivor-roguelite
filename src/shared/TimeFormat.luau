--!strict
-- Formats durations for the HUD and results screen.

local TimeFormat = {}

-- 75.2 -> "1:15". Negative values show as "0:00".
function TimeFormat.minutesSeconds(seconds: number): string
	local whole = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", whole // 60, whole % 60)
end

return TimeFormat
