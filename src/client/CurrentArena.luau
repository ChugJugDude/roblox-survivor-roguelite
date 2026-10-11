--!strict
-- Which world the local player is in: a match's Arena model, or nil in the lobby. Follows the
-- server's WorldReset remote. Listeners run as soon as the reset arrives, before the server's
-- catch-up events for the new world, so renderers can drop everything from the old one first.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

-- How long to wait for a new arena's model to replicate before giving up.
local ARENA_WAIT = 10

local current: Instance? = nil
local resetListeners: { () -> () } = {}
local started = false

local CurrentArena = {}

-- The local player's arena model, or nil in the lobby (or while a new arena is still arriving).
function CurrentArena.get(): Instance?
	return current
end

-- Calls `listener()` whenever the player moves to another world.
function CurrentArena.onReset(listener: () -> ())
	table.insert(resetListeners, listener)
end

function CurrentArena.start()
	assert(not started, "CurrentArena.start() was called twice")
	started = true

	Remotes.WorldReset.OnClientEvent:Connect(function(arenaName: any)
		current = nil
		for _, listener in resetListeners do
			listener()
		end
		if typeof(arenaName) ~= "string" then
			return -- the lobby
		end
		local arenas = workspace:WaitForChild("Arenas", ARENA_WAIT)
		local arena = arenas and arenas:WaitForChild(arenaName, ARENA_WAIT)
		if arena then
			current = arena
		else
			warn(`[CurrentArena] Arena {arenaName} never arrived`)
		end
	end)
end

return CurrentArena
