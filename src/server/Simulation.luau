--!strict
-- The server's per-frame tick. Runs each system in a fixed order so results don't depend on
-- connection order.

local RunService = game:GetService("RunService")

local Characters = require(script.Parent.Characters)
local EnemyReplicator = require(script.Parent.EnemyReplicator)
local EnemyService = require(script.Parent.EnemyService)
local EnemyShooter = require(script.Parent.EnemyShooter)
local NetBatch = require(script.Parent.NetBatch)
local Pause = require(script.Parent.Pause)
local Pickups = require(script.Parent.Pickups)
local Progression = require(script.Parent.Progression)
local ProjectileService = require(script.Parent.ProjectileService)
local Run = require(script.Parent.Run)
local Upgrades = require(script.Parent.Upgrades)
local WaveDirector = require(script.Parent.WaveDirector)
local WeaponService = require(script.Parent.Weapons.WeaponService)

-- After a server hitch, simulate at most this much time in one step so enemies don't teleport.
local MAX_STEP = 0.1

local started = false

local Simulation = {}

function Simulation.start()
	assert(not started, "Simulation.start() was called twice")
	started = true

	RunService.Heartbeat:Connect(function(dt)
		-- Level-up picks can pause the game; while paused, nothing else moves.
		Upgrades.step()
		if Pause.isPaused() then
			NetBatch.flush()
			return
		end

		local now = Pause.now()
		local step = math.min(dt, MAX_STEP)
		local targets = Characters.getTargets()

		Run.step(now, step, targets)
		WaveDirector.step(now, targets)
		EnemyService.move(step, targets)
		WeaponService.step(now, targets)
		ProjectileService.step(step, now, targets)
		EnemyService.attack(now, targets)
		EnemyShooter.step(now, targets)
		Progression.step(targets)
		Pickups.step(targets)
		EnemyReplicator.step(now)
		NetBatch.flush()
	end)
end

return Simulation
