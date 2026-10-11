--!strict
-- The server's per-frame tick: steps every match (each runs its own systems in a fixed order).

local RunService = game:GetService("RunService")

local Match = require(script.Parent.Match)

local started = false

local Simulation = {}

function Simulation.start()
	assert(not started, "Simulation.start() was called twice")
	started = true

	RunService.Heartbeat:Connect(function(dt)
		-- Clone: a step can end a match, which removes it from the list.
		for _, match in table.clone(Match.all()) do
			Match.step(match, dt)
		end
	end)
end

return Simulation
