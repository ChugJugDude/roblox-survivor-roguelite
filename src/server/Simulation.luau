--!strict
-- The server's per-frame tick. Runs each system in a fixed order so results don't depend on
-- connection order.

local RunService = game:GetService("RunService")

local Characters = require(script.Parent.Characters)
local EnemyReplicator = require(script.Parent.EnemyReplicator)
local EnemyService = require(script.Parent.EnemyService)
local NetBatch = require(script.Parent.NetBatch)
local Progression = require(script.Parent.Progression)
local Run = require(script.Parent.Run)
local SpinningBlade = require(script.Parent.Weapons.SpinningBlade)
local WaveDirector = require(script.Parent.WaveDirector)

-- After a server hitch, simulate at most this much time in one step so enemies don't teleport.
local MAX_STEP = 0.1

local started = false

local Simulation = {}

function Simulation.start()
	assert(not started, "Simulation.start() was called twice")
	started = true

	RunService.Heartbeat:Connect(function(dt)
		local now = workspace:GetServerTimeNow()
		local step = math.min(dt, MAX_STEP)
		local targets = Characters.getTargets()

		Run.step(now, step, targets)
		WaveDirector.step(now, targets)
		EnemyService.move(step, targets)
		SpinningBlade.step(now, targets)
		EnemyService.attack(now, targets)
		Progression.step(targets)
		EnemyReplicator.step(now)
		NetBatch.flush()
	end)
end

return Simulation
