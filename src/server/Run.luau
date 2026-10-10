--!strict
--[[
	The run: a countdown, then Config.Run.STAGE_COUNT timed stages. When a stage's timer runs out,
	overtime starts: a portal opens and has to be charged to move on. Charging it after the last
	stage wins. If every player is dead, the run ends in defeat. Results stay up until someone
	asks for a restart.

	State is published as attributes on the Arena model for the HUD (and playtest tooling):
		Phase        "Waiting" | "Countdown" | "Stage" | "Overtime" | "Transition" | "Victory" | "Defeat"
		Stage        current stage number
		PhaseEndsAt  server time the timed phases end (0 when not timed)
		ResultTime, ResultStage, ResultKills, ResultLevel   set when the run ends
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Arena = require(script.Parent.Arena)
local Characters = require(script.Parent.Characters)
local EnemyService = require(script.Parent.EnemyService)
local Portal = require(script.Parent.Portal)
local Progression = require(script.Parent.Progression)
local Config = require(ReplicatedStorage.Shared.Config.Run)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

export type Phase = "Waiting" | "Countdown" | "Stage" | "Overtime" | "Transition" | "Victory" | "Defeat"

local RESTART_COOLDOWN = 1

local arena: Arena.Arena? = nil
local phase: Phase = "Waiting"
local stage = 0
local phaseStartedAt = 0
local phaseEndsAt = 0
local runStartedAt = 0
local lastRestartRequest: { [Player]: number } = {}
local started = false

local Run = {}

local function getArena(): Arena.Arena
	return assert(arena, "Run.start() must be called first")
end

local function setPhase(newPhase: Phase, now: number, duration: number?)
	phase = newPhase
	phaseStartedAt = now
	phaseEndsAt = if duration then now + duration else 0
	local model = getArena().model
	model:SetAttribute("Stage", stage)
	model:SetAttribute("PhaseEndsAt", phaseEndsAt)
	model:SetAttribute("Phase", phase)
end

local function isLive(): boolean
	return phase == "Countdown" or phase == "Stage" or phase == "Overtime" or phase == "Transition"
end

local function startRun(now: number)
	EnemyService.clear()
	EnemyService.resetKills()
	Progression.reset()
	Portal.close()
	stage = 1
	runStartedAt = now + Config.COUNTDOWN
	for _, player in Players:GetPlayers() do
		Characters.spawn(player)
	end
	setPhase("Countdown", now, Config.COUNTDOWN)
end

local function endRun(result: Phase, now: number)
	EnemyService.clear()
	Portal.close()
	local model = getArena().model
	model:SetAttribute("ResultTime", math.max(0, now - runStartedAt))
	model:SetAttribute("ResultStage", stage)
	model:SetAttribute("ResultKills", EnemyService.getKills())
	model:SetAttribute("ResultLevel", Progression.getLevel())
	setPhase(result, now)
end

local function startStage(now: number)
	setPhase("Stage", now, Config.STAGE_DURATION)
end

function Run.start(newArena: Arena.Arena)
	assert(not started, "Run.start() was called twice")
	started = true
	arena = newArena
	setPhase("Waiting", workspace:GetServerTimeNow())

	-- Players who join mid-run play from where the run is. Joining after it ended, they see the
	-- results like everyone else.
	Players.PlayerAdded:Connect(function(player)
		if isLive() then
			Characters.spawn(player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastRestartRequest[player] = nil
	end)

	Remotes.RequestRestart.OnServerEvent:Connect(function(player)
		local clock = os.clock()
		local last = lastRestartRequest[player]
		if last and clock - last < RESTART_COOLDOWN then
			return
		end
		lastRestartRequest[player] = clock
		if phase == "Victory" or phase == "Defeat" then
			startRun(workspace:GetServerTimeNow())
		end
	end)
end

function Run.step(now: number, dt: number, targets: { Characters.Target })
	if phase == "Waiting" then
		if #Players:GetPlayers() > 0 then
			startRun(now)
		end
	elseif phase == "Countdown" or phase == "Transition" then
		if now >= phaseEndsAt then
			startStage(now)
		end
	elseif phase == "Stage" or phase == "Overtime" then
		if #targets == 0 then
			endRun("Defeat", now)
		elseif phase == "Stage" then
			if now >= phaseEndsAt then
				setPhase("Overtime", now)
				Portal.open(targets)
			end
		elseif Portal.step(dt, targets) then
			Portal.close()
			-- Stage cleared: every gem on the floor flies to its nearest player.
			Progression.vacuum(targets)
			if stage >= Config.STAGE_COUNT then
				endRun("Victory", now)
			else
				EnemyService.clear()
				stage += 1
				setPhase("Transition", now, Config.STAGE_TRANSITION)
			end
		end
	elseif #Players:GetPlayers() == 0 then
		-- Results are up but everyone left: reset so the next player starts a fresh run.
		setPhase("Waiting", now)
	end
end

function Run.getPhase(): Phase
	return phase
end

function Run.getStage(): number
	return stage
end

-- Whether enemies should be spawning.
function Run.isFighting(): boolean
	return phase == "Stage" or phase == "Overtime"
end

-- Seconds since the current stage started, continuing to count through its overtime.
function Run.stageElapsed(now: number): number
	if phase == "Stage" then
		return now - phaseStartedAt
	elseif phase == "Overtime" then
		return Config.STAGE_DURATION + now - phaseStartedAt
	end
	return 0
end

-- Seconds into overtime, or 0 when not in overtime.
function Run.overtimeElapsed(now: number): number
	return if phase == "Overtime" then now - phaseStartedAt else 0
end

-- Studio dev command: end the current phase now (in overtime, fill the portal).
function Run.devSkip(now: number)
	if phase == "Overtime" then
		Portal.fill()
	elseif phaseEndsAt > 0 then
		phaseEndsAt = now
		getArena().model:SetAttribute("PhaseEndsAt", phaseEndsAt)
	end
end

-- Studio dev command: jump to the start of stage `n`.
function Run.devSetStage(n: number, now: number)
	if not isLive() then
		return
	end
	EnemyService.clear()
	Portal.close()
	stage = math.clamp(math.floor(n), 1, Config.STAGE_COUNT)
	startStage(now)
end

return Run
