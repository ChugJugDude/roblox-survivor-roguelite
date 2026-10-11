--!strict
-- One match's game clock (shared/GameClock): it stops while the match is paused, and pausing holds
-- the match's characters in place. The match skips its systems while paused, and its players'
-- clients freeze their visuals because they run on the same clock. Upgrades decides when to pause
-- (level-up picks).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Arena = require(script.Parent.Arena)
local GameClock = require(ReplicatedStorage.Shared.GameClock)

export type Clock = {
	arena: Arena.Arena,
	offset: number, -- total seconds spent paused
	pausedAt: number, -- server time the current pause began; 0 while running
	anchored: { BasePart },
}

local Pause = {}

local function publish(clock: Clock)
	local model = clock.arena.model
	model:SetAttribute("ClockOffset", clock.offset)
	model:SetAttribute("PausedAt", clock.pausedAt)
end

function Pause.new(arena: Arena.Arena): Clock
	local clock: Clock = { arena = arena, offset = 0, pausedAt = 0, anchored = {} }
	publish(clock)
	return clock
end

-- The current game time. Stands still while paused.
function Pause.now(clock: Clock): number
	return GameClock.compute(clock.offset, clock.pausedAt)
end

function Pause.isPaused(clock: Clock): boolean
	return clock.pausedAt > 0
end

-- Stops the clock and anchors `players`' characters (they're simulated by their own clients, so
-- anchoring is what holds them still).
function Pause.pause(clock: Clock, players: { Player })
	if clock.pausedAt > 0 then
		return
	end
	clock.pausedAt = workspace:GetServerTimeNow()
	publish(clock)

	for _, player in players do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") and not root.Anchored then
			root.Anchored = true
			table.insert(clock.anchored, root)
		end
	end
end

function Pause.resume(clock: Clock)
	if clock.pausedAt == 0 then
		return
	end
	clock.offset += workspace:GetServerTimeNow() - clock.pausedAt
	clock.pausedAt = 0
	publish(clock)

	for _, root in clock.anchored do
		if root.Parent then
			root.Anchored = false
		end
	end
	table.clear(clock.anchored)
end

return Pause
