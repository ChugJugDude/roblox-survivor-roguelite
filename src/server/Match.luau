--!strict
--[[
	A match: one party's run in its own arena. It owns the arena, its members, one state object from
	each run system, and the run itself: a countdown, then Config.Run.STAGE_COUNT timed stages. When a
	stage's timer runs out, overtime starts: a portal opens and has to be charged to move on.
	Charging it after the last stage wins; if no member is left standing, the run is lost.

	Each frame Simulation calls Match.step for every match, which runs the systems in a fixed order.

	Run state is published as attributes on the match's Arena model for its members' HUD (and
	playtest tooling):
		Phase        "Countdown" | "Stage" | "Overtime" | "Transition" | "Victory" | "Defeat"
		Stage        current stage number
		PhaseEndsAt  game time (shared/GameClock) the timed phases end (0 when not timed)
		ResultTime, ResultStage, ResultKills, ResultLevel   set when the run ends
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Arena = require(script.Parent.Arena)
local Characters = require(script.Parent.Characters)
local EnemyReplicator = require(script.Parent.EnemyReplicator)
local EnemyService = require(script.Parent.EnemyService)
local EnemyShooter = require(script.Parent.EnemyShooter)
local NetBatch = require(script.Parent.NetBatch)
local Pause = require(script.Parent.Pause)
local Pickups = require(script.Parent.Pickups)
local Portal = require(script.Parent.Portal)
local Progression = require(script.Parent.Progression)
local ProjectileService = require(script.Parent.ProjectileService)
local Upgrades = require(script.Parent.Upgrades)
local WaveDirector = require(script.Parent.WaveDirector)
local WeaponService = require(script.Parent.Weapons.WeaponService)
local ArenaConfig = require(ReplicatedStorage.Shared.Config.Arena)
local Config = require(ReplicatedStorage.Shared.Config.Run)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

export type Phase = "Countdown" | "Stage" | "Overtime" | "Transition" | "Victory" | "Defeat"

export type Match = {
	slot: number,
	arena: Arena.Arena,
	members: { Player },
	net: NetBatch.Batch,
	clock: Pause.Clock,
	enemies: EnemyService.State,
	replicator: EnemyReplicator.State,
	progression: Progression.State,
	party: Upgrades.Party,
	projectiles: ProjectileService.State,
	pickups: Pickups.State,
	waves: WaveDirector.State,
	portal: Portal.State,
	phase: Phase,
	stage: number,
	phaseStartedAt: number,
	phaseEndsAt: number,
	runStartedAt: number,
}

-- Arenas are built this far apart along X, one slot per match.
local SLOT_SPACING = 1000
-- After a server hitch, simulate at most this much time in one step so enemies don't teleport.
local MAX_STEP = 0.1

local matches: { Match } = {}
local matchOf: { [Player]: Match } = {}

local Match = {}

local function model(match: Match): Model
	return match.arena.model
end

local function setPhase(match: Match, phase: Phase, now: number, duration: number?)
	match.phase = phase
	match.phaseStartedAt = now
	match.phaseEndsAt = if duration then now + duration else 0
	local arenaModel = model(match)
	arenaModel:SetAttribute("Stage", match.stage)
	arenaModel:SetAttribute("PhaseEndsAt", match.phaseEndsAt)
	arenaModel:SetAttribute("Phase", phase)
end

local function isLive(match: Match): boolean
	local phase = match.phase
	return phase == "Countdown" or phase == "Stage" or phase == "Overtime" or phase == "Transition"
end

local function clearField(match: Match)
	EnemyService.clear(match.enemies)
	ProjectileService.clear(match.projectiles)
end

local function startStage(match: Match, now: number)
	setPhase(match, "Stage", now, Config.STAGE_DURATION)
end

local function endRun(match: Match, result: Phase, now: number)
	Upgrades.stop(match.party)
	clearField(match)
	Portal.close(match.portal)
	local arenaModel = model(match)
	arenaModel:SetAttribute("ResultTime", math.max(0, now - match.runStartedAt))
	arenaModel:SetAttribute("ResultStage", match.stage)
	arenaModel:SetAttribute("ResultKills", EnemyService.getKills(match.enemies))
	arenaModel:SetAttribute("ResultLevel", Progression.getLevel(match.progression))
	setPhase(match, result, now)
end

-- The wave director's view of the run this frame.
local function runView(match: Match, now: number): WaveDirector.RunView
	local phase = match.phase
	local sinceStart = now - match.phaseStartedAt
	return {
		fighting = phase == "Stage" or phase == "Overtime",
		stage = match.stage,
		stageElapsed = if phase == "Stage"
			then sinceStart
			elseif phase == "Overtime" then Config.STAGE_DURATION + sinceStart
			else 0,
		overtime = phase == "Overtime",
		overtimeElapsed = if phase == "Overtime" then sinceStart else 0,
	}
end

local function stepRun(match: Match, now: number, dt: number, targets: { Characters.Target })
	local phase = match.phase
	if phase == "Countdown" or phase == "Transition" then
		if now >= match.phaseEndsAt then
			startStage(match, now)
		end
	elseif phase == "Stage" or phase == "Overtime" then
		if #targets == 0 then
			endRun(match, "Defeat", now)
		elseif phase == "Stage" then
			if now >= match.phaseEndsAt then
				setPhase(match, "Overtime", now)
				Portal.open(match.portal, targets)
			end
		elseif Portal.step(match.portal, dt, targets) then
			Portal.close(match.portal)
			-- Stage cleared: every gem on the floor flies to its nearest player.
			Progression.vacuum(match.progression, targets)
			if match.stage >= Config.STAGE_COUNT then
				endRun(match, "Victory", now)
			else
				clearField(match)
				match.stage += 1
				setPhase(match, "Transition", now, Config.STAGE_TRANSITION)
			end
		end
	end
end

-- Creates a match in arena slot `slot` (not started; add members, then start).
function Match.create(slot: number): Match
	local arena = Arena.build(ArenaConfig.ORIGIN + Vector3.new(slot * SLOT_SPACING, 0, 0), `Arena{slot}`)
	local members: { Player } = {}
	local net = NetBatch.new()
	local clock = Pause.new(arena)
	local enemies = EnemyService.new(arena, net)
	local progression = Progression.new(arena, net, enemies)
	local party = Upgrades.newParty(clock, members, progression)
	local match: Match = {
		slot = slot,
		arena = arena,
		members = members,
		net = net,
		clock = clock,
		enemies = enemies,
		replicator = EnemyReplicator.new(enemies),
		progression = progression,
		party = party,
		projectiles = ProjectileService.new(enemies, net, clock),
		pickups = Pickups.new(arena, enemies, progression, party, net),
		waves = WaveDirector.new(arena, enemies),
		portal = Portal.new(arena),
		phase = "Countdown",
		stage = 0,
		phaseStartedAt = 0,
		phaseEndsAt = 0,
		runStartedAt = 0,
	}
	table.insert(matches, match)
	return match
end

-- Puts `player` in the match: their client switches to its arena and catches up on what's there.
function Match.addMember(match: Match, player: Player)
	if matchOf[player] == match then
		return
	end
	table.insert(match.members, player)
	matchOf[player] = match
	player:SetAttribute("ArenaName", model(match).Name)
	Remotes.WorldReset:FireClient(player, model(match).Name)
	EnemyReplicator.syncTo(match.replicator, player)
	Progression.syncTo(match.progression, player)
end

-- Takes `player` out of the match (they left the server or went back to the lobby).
function Match.removeMember(match: Match, player: Player)
	local index = table.find(match.members, player)
	if index then
		table.remove(match.members, index)
	end
	if matchOf[player] == match then
		matchOf[player] = nil
	end
	Upgrades.leaveParty(player)
end

-- Starts (or restarts) the run for the current members, spawning them in the arena.
function Match.startRun(match: Match)
	local now = Pause.now(match.clock)
	clearField(match)
	EnemyService.resetKills(match.enemies)
	Progression.reset(match.progression)
	Upgrades.reset(match.party)
	Pickups.clear(match.pickups)
	Portal.close(match.portal)
	match.stage = 1
	match.runStartedAt = now + Config.COUNTDOWN
	for _, player in match.members do
		Characters.spawn(player, Arena.spawnCFrame(match.arena))
	end
	setPhase(match, "Countdown", now, Config.COUNTDOWN)
end

function Match.step(match: Match, dt: number)
	-- Level-up picks can pause the match; while paused, nothing else moves.
	Upgrades.step(match.party)
	if Pause.isPaused(match.clock) then
		NetBatch.flush(match.net, match.members)
		return
	end

	local now = Pause.now(match.clock)
	local step = math.min(dt, MAX_STEP)
	local targets = Characters.getTargets(match.members)

	stepRun(match, now, step, targets)
	WaveDirector.step(match.waves, now, targets, runView(match, now))
	EnemyService.move(match.enemies, step, targets)
	WeaponService.step(match.enemies, match.projectiles, now, targets)
	ProjectileService.step(match.projectiles, step, now, targets)
	EnemyService.attack(match.enemies, now, targets)
	EnemyShooter.step(match.enemies, match.projectiles, now, targets)
	Progression.step(match.progression, targets)
	Pickups.step(match.pickups, targets)
	EnemyReplicator.step(match.replicator, now, match.members)
	NetBatch.flush(match.net, match.members)
end

function Match.destroy(match: Match)
	Upgrades.stop(match.party)
	for _, player in table.clone(match.members) do
		Match.removeMember(match, player)
	end
	local index = table.find(matches, match)
	if index then
		table.remove(matches, index)
	end
	Arena.destroy(match.arena)
end

function Match.all(): { Match }
	return matches
end

function Match.forPlayer(player: Player): Match?
	return matchOf[player]
end

function Match.getPhase(match: Match): Phase
	return match.phase
end

function Match.hasEnded(match: Match): boolean
	return not isLive(match)
end

-- Studio dev command: end the current phase now (in overtime, fill the portal).
function Match.devSkip(match: Match)
	local now = Pause.now(match.clock)
	if match.phase == "Overtime" then
		Portal.fill(match.portal)
	elseif match.phaseEndsAt > 0 then
		match.phaseEndsAt = now
		model(match):SetAttribute("PhaseEndsAt", now)
	end
end

-- Studio dev command: jump to the start of stage `n`.
function Match.devSetStage(match: Match, n: number)
	if not isLive(match) then
		return
	end
	clearField(match)
	Portal.close(match.portal)
	match.stage = math.clamp(math.floor(n), 1, Config.STAGE_COUNT)
	startStage(match, Pause.now(match.clock))
end

return Match
