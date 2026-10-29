--!strict
--[[
	A match: one party's run in its own arena. It owns the arena, its members, one state object from
	each run system, and the run itself: a countdown, then Config.Run.STAGE_COUNT timed stages. When a
	stage's timer runs out, overtime starts: a portal opens and has to be charged to move on. The
	last stage instead ends in a Boss phase: its final boss (Config.Waves finalBoss) arrives, and
	killing it wins. If no member is left standing, the run is lost.

	Each frame Simulation calls Match.step for every match, which runs the systems in a fixed order.

	Run state is published as attributes on the match's Arena model for its members' HUD (and
	playtest tooling):
		Phase        "Countdown" | "Stage" | "Overtime" | "Boss" | "Transition" | "Victory" | "Defeat"
		Stage        current stage number
		PhaseEndsAt  game time (shared/GameClock) the timed phases end (0 when not timed)
		ResultTime, ResultStage, ResultKills, ResultLevel, ResultStagesCleared, ResultBosses
		             set when the run ends (each member's Shards go on the player; see server/Meta)
		EndedAt      server time the run ended (the lobby sends everyone back a while after)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Arena = require(script.Parent.Arena)
local BossBrain = require(script.Parent.BossBrain)
local Characters = require(script.Parent.Characters)
local EnemyReplicator = require(script.Parent.EnemyReplicator)
local EnemyService = require(script.Parent.EnemyService)
local EnemyShooter = require(script.Parent.EnemyShooter)
local Meta = require(script.Parent.Meta)
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
local Worlds = require(ReplicatedStorage.Shared.Config.Worlds)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ShardReward = require(ReplicatedStorage.Shared.ShardReward)

export type Phase = "Countdown" | "Stage" | "Overtime" | "Boss" | "Transition" | "Victory" | "Defeat"

export type Match = {
	slot: number,
	world: string, -- Config.Worlds id
	arena: Arena.Arena,
	members: { Player },
	net: NetBatch.Batch,
	clock: Pause.Clock,
	enemies: EnemyService.State,
	replicator: EnemyReplicator.State,
	progression: Progression.State,
	party: Upgrades.Party,
	projectiles: ProjectileService.State,
	weapons: WeaponService.State,
	pickups: Pickups.State,
	waves: WaveDirector.State,
	portal: Portal.State,
	bosses: BossBrain.State,
	finalBoss: EnemyService.Enemy?, -- alive during the Boss phase
	partySize: number, -- members when the run started, for scaling
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
	return phase == "Countdown" or phase == "Stage" or phase == "Overtime" or phase == "Boss" or phase == "Transition"
end

-- Stage, overtime, or the boss fight: enemies spawn and the party can lose.
local function isFighting(phase: Phase): boolean
	return phase == "Stage" or phase == "Overtime" or phase == "Boss"
end

local function clearField(match: Match)
	EnemyService.clear(match.enemies)
	ProjectileService.clear(match.projectiles)
	WeaponService.clear(match.weapons)
end

local function startStage(match: Match, now: number)
	setPhase(match, "Stage", now, Config.STAGE_DURATION)
end

local function endRun(match: Match, result: Phase, now: number)
	match.finalBoss = nil
	Upgrades.stop(match.party)
	clearField(match)
	Portal.close(match.portal)
	local victory = result == "Victory"
	local runResult: ShardReward.RunResult = {
		time = math.max(0, now - match.runStartedAt),
		kills = EnemyService.getKills(match.enemies),
		stagesCleared = if victory then Config.STAGE_COUNT else match.stage - 1,
		bosses = EnemyService.getBossKills(match.enemies),
		victory = victory,
		world = match.world,
	}
	local arenaModel = model(match)
	arenaModel:SetAttribute("ResultTime", runResult.time)
	arenaModel:SetAttribute("ResultStage", match.stage)
	arenaModel:SetAttribute("ResultKills", runResult.kills)
	arenaModel:SetAttribute("ResultLevel", Progression.getLevel(match.progression))
	arenaModel:SetAttribute("ResultStagesCleared", runResult.stagesCleared)
	arenaModel:SetAttribute("ResultBosses", runResult.bosses)
	arenaModel:SetAttribute("EndedAt", workspace:GetServerTimeNow())
	-- Everyone still in the match is paid; leaving mid-run forfeits the reward.
	for _, player in match.members do
		Meta.awardRun(player, runResult)
	end
	setPhase(match, result, now)
end

-- The wave director's view of the run this frame.
local function runView(match: Match, now: number): WaveDirector.RunView
	local phase = match.phase
	local sinceStart = now - match.phaseStartedAt
	return {
		fighting = isFighting(phase),
		stage = match.stage,
		stageElapsed = if phase == "Stage"
			then sinceStart
			elseif phase == "Overtime" or phase == "Boss" then Config.STAGE_DURATION + sinceStart
			else 0,
		overtime = phase == "Overtime",
		overtimeElapsed = if phase == "Overtime" then sinceStart else 0,
		partySize = match.partySize,
		world = Worlds.get(match.world),
	}
end

local function stepRun(match: Match, now: number, dt: number, targets: { Characters.Target })
	local phase = match.phase
	if phase == "Countdown" or phase == "Transition" then
		if now >= match.phaseEndsAt then
			startStage(match, now)
		end
	elseif phase == "Boss" then
		local boss = match.finalBoss
		if not boss or EnemyService.getAll(match.enemies)[boss.id] ~= boss then
			match.finalBoss = nil
			endRun(match, "Victory", now)
		end
	elseif phase == "Stage" or phase == "Overtime" then
		if phase == "Stage" then
			if now >= match.phaseEndsAt then
				local finalBoss = if match.stage >= Config.STAGE_COUNT
					then Worlds.get(match.world).stages[match.stage].finalBoss
					else nil
				if finalBoss then
					setPhase(match, "Boss", now)
					match.finalBoss = WaveDirector.spawnBoss(match.waves, finalBoss, targets, runView(match, now))
				else
					setPhase(match, "Overtime", now)
					Portal.open(match.portal, targets)
				end
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

-- Creates a match in arena slot `slot`, set in world `worldId` (not started; add members, then
-- start). Slot 0 is the lobby's spot, so use 1 and up.
function Match.create(slot: number, worldId: string): Match
	local world = Worlds.get(worldId)
	local arena = Arena.build(ArenaConfig.ORIGIN + Vector3.new(slot * SLOT_SPACING, 0, 0), `Arena{slot}`, world)
	local members: { Player } = {}
	local net = NetBatch.new()
	local clock = Pause.new(arena)
	local enemies = EnemyService.new(arena, net)
	-- Every member sees what the party kills: Codex entries for each enemy kind (and elites).
	EnemyService.onKilled(enemies, function(enemy)
		if EnemyService.isProp(enemy) then
			return
		end
		for _, player in members do
			Meta.discover(player, `E:{enemy.kind}`)
			if enemy.elite then
				Meta.discover(player, "E:Elite")
			end
		end
	end)
	local progression = Progression.new(arena, net, enemies)
	local party = Upgrades.newParty(clock, members, progression)
	local projectiles = ProjectileService.new(enemies, net, clock)
	local match: Match = {
		slot = slot,
		world = world.id,
		arena = arena,
		members = members,
		net = net,
		clock = clock,
		enemies = enemies,
		replicator = EnemyReplicator.new(enemies),
		progression = progression,
		party = party,
		projectiles = projectiles,
		weapons = WeaponService.new(enemies, projectiles),
		pickups = Pickups.new(arena, enemies, progression, party, net),
		waves = WaveDirector.new(arena, enemies),
		portal = Portal.new(arena),
		bosses = BossBrain.new(arena, enemies, projectiles, net),
		finalBoss = nil,
		partySize = 1,
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
	match.partySize = math.max(1, #match.members)
	match.runStartedAt = now + Config.COUNTDOWN
	for _, player in match.members do
		Meta.clearResult(player)
		Characters.spawn(player, Arena.spawnCFrame(match.arena))
	end
	setPhase(match, "Countdown", now, Config.COUNTDOWN)
end

function Match.step(match: Match, dt: number)
	local now = Pause.now(match.clock)
	local targets = Characters.getTargets(match.members)

	-- Nobody left standing (everyone downed or gone) ends the run, even mid-pause (e.g. the last player went down on the same
	-- frame as a level-up): the party shouldn't be left choosing upgrades for a lost run.
	if isFighting(match.phase) and #targets == 0 then
		endRun(match, "Defeat", now)
	end

	-- Level-up picks can pause the match; while paused, nothing else moves.
	Upgrades.step(match.party)
	if Pause.isPaused(match.clock) then
		NetBatch.flush(match.net, match.members)
		return
	end

	local step = math.min(dt, MAX_STEP)

	Characters.stepRevives(match.members, targets, step, now)
	Characters.stepRegen(targets, step)
	stepRun(match, now, step, targets)
	WaveDirector.step(match.waves, now, targets, runView(match, now))
	BossBrain.step(match.bosses, now, step, targets)
	EnemyService.move(match.enemies, now, step, targets)
	WeaponService.step(match.weapons, now, step, targets)
	ProjectileService.step(match.projectiles, step, now, targets)
	EnemyService.attack(match.enemies, now, targets)
	EnemyShooter.step(match.enemies, match.projectiles, now, targets)
	Progression.step(match.progression, targets)
	Pickups.step(match.pickups, targets)
	EnemyReplicator.step(match.replicator, now, match.members)
	EnemyService.flushHits(match.enemies)
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

-- Studio dev command: end the current phase now (in overtime, fill the portal; in the boss fight,
-- kill the boss).
function Match.devSkip(match: Match)
	local now = Pause.now(match.clock)
	local boss = match.finalBoss
	if match.phase == "Overtime" then
		Portal.fill(match.portal)
	elseif match.phase == "Boss" and boss then
		EnemyService.damage(match.enemies, boss, math.huge)
	elseif match.phaseEndsAt > 0 then
		match.phaseEndsAt = now
		model(match):SetAttribute("PhaseEndsAt", now)
	end
end

-- Studio dev command: jump to the last stage's boss fight.
function Match.devBoss(match: Match)
	Match.devSetStage(match, Config.STAGE_COUNT)
	local now = Pause.now(match.clock)
	match.phaseEndsAt = now
	model(match):SetAttribute("PhaseEndsAt", now)
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
