--!strict
-- Pauses and resumes the game: stops the game clock (shared/GameClock) and holds every character in
-- place. Simulation skips its systems while paused, and clients freeze their visuals because they
-- run on the same clock. Upgrades decides when to pause (level-up picks).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Arena = require(script.Parent.Arena)
local GameClock = require(ReplicatedStorage.Shared.GameClock)

local arena: Arena.Arena? = nil
local offset = 0 -- total seconds spent paused
local pausedAt = 0 -- server time the current pause began; 0 while running
local anchored: { BasePart } = {}

local Pause = {}

local function publish()
	local model = assert(arena, "Pause.init() must be called first").model
	model:SetAttribute("ClockOffset", offset)
	model:SetAttribute("PausedAt", pausedAt)
end

function Pause.init(newArena: Arena.Arena)
	arena = newArena
	publish()
end

-- The current game time. Stands still while paused.
function Pause.now(): number
	return GameClock.compute(offset, pausedAt)
end

function Pause.isPaused(): boolean
	return pausedAt > 0
end

function Pause.pause()
	if pausedAt > 0 then
		return
	end
	pausedAt = workspace:GetServerTimeNow()
	publish()

	-- Characters are simulated by their own clients, so anchoring is what holds them still.
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") and not root.Anchored then
			root.Anchored = true
			table.insert(anchored, root)
		end
	end
end

function Pause.resume()
	if pausedAt == 0 then
		return
	end
	offset += workspace:GetServerTimeNow() - pausedAt
	pausedAt = 0
	publish()

	for _, root in anchored do
		if root.Parent then
			root.Anchored = false
		end
	end
	table.clear(anchored)
end

return Pause
