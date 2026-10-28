--!strict
--[[
	Each player's build (weapons and passives, with levels) and their level-up choice.

	Builds are per player. Picks and pauses are per party (one match): every level-up of the
	party's shared XP gives each member a pick. Level-up picks wait for a pause: when any member is
	owed one (and at least PAUSE_COOLDOWN seconds of play have passed since the party's last
	pause), the match pauses and every member chooses at once. It resumes when they're all done;
	with 2+ members, PAUSE_TIMEOUT stops one idle player from holding up the party. A chest pick
	pauses right away (no cooldown), so nobody gets hit while reading cards they didn't expect; in
	co-op the others wait, as with level-ups. Head Start picks open during the countdown without a
	pause, with a moment of invulnerability.

	One offer is open per player at a time. The server generates the options and only accepts an
	index into the open offer.

	Builds replicate as Player attributes, W_<weapon> and P_<passive> = level, and B_<bonus> for
	the permanent bonuses, so the client can use shared/BuildStats too (e.g. to draw the right
	number of blades). A fresh build starts from the player's loadout (server/Meta): their hero's
	weapon plus hero and Altar bonuses.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Characters = require(script.Parent.Characters)
local Meta = require(script.Parent.Meta)
local Pause = require(script.Parent.Pause)
local Progression = require(script.Parent.Progression)
local BuildStats = require(ReplicatedStorage.Shared.BuildStats)
local MetaStats = require(ReplicatedStorage.Shared.MetaStats)
local Config = require(ReplicatedStorage.Shared.Config.Upgrades)
local PlayerConfig = require(ReplicatedStorage.Shared.Config.Player)
local ProgressionConfig = require(ReplicatedStorage.Shared.Config.Progression)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

export type Option = {
	id: string, -- weapon or passive id, or "Heal"
	kind: "weapon" | "passive" | "evolution" | "heal",
	level: number, -- the level this option gives (MAX_LEVEL + 1 for an evolution, 0 for heal)
	isNew: boolean,
	name: string,
	description: string,
	hint: string?, -- the evolution pairing, e.g. "Evolves with Reach", so players can plan for it
}

-- One match's party, as far as upgrades are concerned. `members` is the match's own list.
export type Party = {
	clock: Pause.Clock,
	members: { Player },
	active: boolean, -- a run is in progress
	pauseStartedAt: number, -- os.clock() when the current pause began
	lastResumedAt: number, -- game time of the last resume
}

type State = {
	build: BuildStats.Build,
	party: Party?, -- nil in the lobby
	levelPicks: number, -- owed from party level-ups; shown during a pause
	chestPicks: number, -- owed from chests; shown right away
	offer: { Option }?,
	rerolls: number,
	lastRequest: number,
}

-- Minimum seconds between choose/reroll requests from one player.
local REQUEST_COOLDOWN = 0.1

local states: { [Player]: State } = {}
local started = false
local random = Random.new()

local Upgrades = {}

local function count(levels: { [string]: number }): number
	local total = 0
	for _ in levels do
		total += 1
	end
	return total
end

local function picksOwed(state: State): number
	return state.levelPicks + state.chestPicks
end

local function publishBuild(player: Player, state: State)
	for id in Config.WEAPONS do
		player:SetAttribute("W_" .. id, state.build.weapons[id])
	end
	for id in Config.PASSIVES do
		player:SetAttribute("P_" .. id, state.build.passives[id])
	end
	local bonus = state.build.bonus or MetaStats.NONE
	for _, field in MetaStats.FIELDS do
		local value = (bonus :: any)[field]
		player:SetAttribute("B_" .. field, if value ~= 0 then value else nil)
	end
end

local function newState(party: Party?, loadout: Meta.Loadout): State
	return {
		build = { weapons = { [loadout.weapon] = 1 }, passives = {}, bonus = loadout.bonus },
		party = party,
		levelPicks = 0,
		chestPicks = 0,
		offer = nil,
		rerolls = Config.REROLLS_PER_RUN + loadout.bonus.rerolls,
		lastRequest = 0,
	}
end

local function getState(player: Player): State
	local state = states[player]
	if not state then
		state = newState(nil, Meta.loadout(player))
		states[player] = state
		publishBuild(player, state)
	end
	return state
end

local function statsFor(player: Player): (number, number)
	local modifiers = BuildStats.modifiers(getState(player).build)
	return PlayerConfig.MAX_HEALTH + modifiers.maxHealthBonus, PlayerConfig.WALK_SPEED * modifiers.moveSpeed
end

-- Updates a living character's max health and speed after the build changes. Extra max health is
-- also added to current health.
local function applyStats(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	local maxHealth, walkSpeed = statsFor(player)
	local gained = maxHealth - humanoid.MaxHealth
	humanoid.MaxHealth = maxHealth
	if gained > 0 then
		humanoid.Health = math.min(maxHealth, humanoid.Health + gained)
	end
	humanoid.WalkSpeed = walkSpeed
end

local function weaponOption(id: string, level: number): Option
	local def = Config.WEAPONS[id]
	return {
		id = id,
		kind = "weapon",
		level = level,
		isNew = level == 1,
		name = def.name,
		description = def.descriptions[level],
		hint = `Evolves with {Config.PASSIVES[def.evolution.passive].name}`,
	}
end

local function passiveOption(id: string, level: number): Option
	local def = Config.PASSIVES[id]
	local value = def.values[level]
	local evolves = BuildStats.weaponEvolvedBy(id)
	return {
		id = id,
		kind = "passive",
		level = level,
		isNew = level == 1,
		name = def.name,
		description = string.format(def.description, math.floor((if def.percent then value * 100 else value) + 0.5)),
		hint = if evolves then `Evolves {Config.WEAPONS[evolves].name}` else nil,
	}
end

local function evolutionOption(id: string): Option
	local evolution = Config.WEAPONS[id].evolution
	return {
		id = id,
		kind = "evolution",
		level = Config.MAX_LEVEL + 1,
		isNew = false,
		name = evolution.name,
		description = evolution.description,
	}
end

local function healOption(): Option
	return {
		id = "Heal",
		kind = "heal",
		level = 0,
		isNew = false,
		name = "Heal",
		description = `Restore {math.floor(Config.HEAL_FRACTION * 100)}% of max health.`,
	}
end

-- Up to OPTION_COUNT distinct options: every evolution the player qualifies for first, then
-- picks by weight; Heal fills any empty slots.
local function generateOptions(state: State): { Option }
	local build = state.build
	local options: { Option } = {}
	for id, def in Config.WEAPONS do
		if
			build.weapons[id] == Config.MAX_LEVEL
			and build.passives[def.evolution.passive]
			and #options < Config.OPTION_COUNT
		then
			table.insert(options, evolutionOption(id))
		end
	end

	local candidates: { { option: Option, weight: number } } = {}

	local weaponCount = count(build.weapons)
	for id in Config.WEAPONS do
		local level = build.weapons[id]
		if level then
			if level < Config.MAX_LEVEL then
				table.insert(candidates, { option = weaponOption(id, level + 1), weight = Config.WEIGHTS.weaponLevel })
			end
		elseif weaponCount < Config.MAX_WEAPONS then
			table.insert(candidates, { option = weaponOption(id, 1), weight = Config.WEIGHTS.newWeapon })
		end
	end

	local passiveCount = count(build.passives)
	for id in Config.PASSIVES do
		local level = build.passives[id]
		if level then
			if level < Config.MAX_LEVEL then
				table.insert(
					candidates,
					{ option = passiveOption(id, level + 1), weight = Config.WEIGHTS.passiveLevel }
				)
			end
		elseif passiveCount < Config.MAX_PASSIVES then
			table.insert(candidates, { option = passiveOption(id, 1), weight = Config.WEIGHTS.newPassive })
		end
	end

	while #options < Config.OPTION_COUNT and #candidates > 0 do
		local total = 0
		for _, candidate in candidates do
			total += candidate.weight
		end
		local roll = random:NextNumber(0, total)
		local chosen = #candidates
		for index, candidate in candidates do
			roll -= candidate.weight
			if roll <= 0 then
				chosen = index
				break
			end
		end
		table.insert(options, table.remove(candidates, chosen).option)
	end
	if #options < Config.OPTION_COUNT then
		table.insert(options, healOption())
	end
	return options
end

local function sendOffer(player: Player, state: State)
	local offer = state.offer
	if offer then
		Remotes.UpgradeOffered:FireClient(player, {
			options = offer,
			pending = picksOwed(state),
			rerolls = state.rerolls,
			-- Chest picks are taken first, so this pick is from a chest while any are owed.
			chest = state.chestPicks > 0,
		})
	else
		Remotes.UpgradeOffered:FireClient(player, nil)
	end
end

local function isPaused(state: State): boolean
	local party = state.party
	return party ~= nil and Pause.isPaused(party.clock)
end

-- Makes the player invulnerable for `seconds` of their match's game time. The ForceField is the
-- visible cue.
local function grantInvulnerability(player: Player, clock: Pause.Clock, seconds: number)
	player:SetAttribute("InvulnerableUntil", Pause.now(clock) + seconds)
	local character = player.Character
	if character then
		local shield = Instance.new("ForceField")
		shield.Parent = character
		task.delay(seconds, function()
			shield:Destroy()
		end)
	end
end

local function openOffer(player: Player, state: State)
	state.offer = generateOptions(state)
	-- Nothing can hurt them during a pause. Outside one (a chest pick), give a moment of safety.
	local party = state.party
	if party and not Pause.isPaused(party.clock) then
		grantInvulnerability(player, party.clock, Config.INVULNERABILITY)
	end
	sendOffer(player, state)
end

-- Opens the player's next offer if one can be shown now; otherwise closes their picker.
local function showNext(player: Player, state: State)
	if state.chestPicks > 0 or (isPaused(state) and state.levelPicks > 0) then
		openOffer(player, state)
	else
		state.offer = nil
		sendOffer(player, state)
	end
end

local function consumePick(state: State)
	if state.chestPicks > 0 then
		state.chestPicks -= 1
	else
		state.levelPicks = math.max(0, state.levelPicks - 1)
	end
end

local function apply(player: Player, state: State, option: Option)
	if option.kind == "weapon" or option.kind == "evolution" then
		state.build.weapons[option.id] = option.level
	elseif option.kind == "passive" then
		state.build.passives[option.id] = option.level
	else
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + humanoid.MaxHealth * Config.HEAL_FRACTION)
		end
	end
	publishBuild(player, state)
	applyStats(player)
end

local function grantLevelPick(player: Player)
	local state = getState(player)
	state.levelPicks += 1
	if state.offer then
		sendOffer(player, state) -- just updates the "+N more" count
	elseif isPaused(state) then
		openOffer(player, state)
	end
	-- Otherwise Upgrades.step pauses the game for it once the cooldown allows.
end

-- Resolves all of a player's owed picks at random (for a player holding up the party).
local function autoPick(player: Player, state: State)
	while picksOwed(state) > 0 do
		local options = state.offer or generateOptions(state)
		state.offer = nil
		consumePick(state)
		apply(player, state, options[random:NextInteger(1, #options)])
	end
	sendOffer(player, state)
end

local function pauseForPicks(party: Party)
	Pause.pause(party.clock, party.members)
	party.pauseStartedAt = os.clock()
	for _, player in party.members do
		local state = states[player]
		if state and not state.offer and picksOwed(state) > 0 then
			openOffer(player, state)
		end
	end
end

local function resume(party: Party)
	Pause.resume(party.clock)
	party.lastResumedAt = Pause.now(party.clock)
	for _, player in party.members do
		grantInvulnerability(player, party.clock, Config.RESUME_GRACE)
	end
end

-- Returns the player's state if they may act on their offer now (rate-limited).
local function acceptRequest(player: Player): State?
	local state = states[player]
	local party = state and state.party
	if not party or not party.active or not state or not state.offer then
		return nil
	end
	local clock = os.clock()
	if clock - state.lastRequest < REQUEST_COOLDOWN then
		return nil
	end
	state.lastRequest = clock
	return state
end

local function onChoose(player: Player, index: unknown)
	if typeof(index) ~= "number" or index ~= math.floor(index) then
		return
	end
	local state = acceptRequest(player)
	local offer = state and state.offer
	if not state or not offer or index < 1 or index > #offer then
		return
	end

	local option = offer[index]
	state.offer = nil
	consumePick(state)
	apply(player, state, option)
	showNext(player, state)
end

local function onReroll(player: Player)
	local state = acceptRequest(player)
	if not state or state.rerolls <= 0 then
		return
	end
	state.rerolls -= 1
	state.offer = generateOptions(state)
	sendOffer(player, state)
end

-- Takes a player out of their party (they went back to the lobby): closes any open choice and
-- puts them back on their starting build.
function Upgrades.leaveParty(player: Player)
	if states[player] then
		local state = newState(nil, Meta.loadout(player))
		states[player] = state
		publishBuild(player, state)
		sendOffer(player, state)
	end
end

-- The player's build, or nil if they don't have one yet.
function Upgrades.getBuild(player: Player): BuildStats.Build?
	local state = states[player]
	return if state then state.build else nil
end

-- An extra pick for one player (from a chest), during their party's run. Pauses the party now,
-- like a level-up but without waiting for the cooldown.
function Upgrades.grantBonusPick(party: Party, player: Player)
	local state = states[player]
	if not party.active or not state or state.party ~= party then
		return
	end
	state.chestPicks += 1
	if state.offer then
		sendOffer(player, state) -- just updates the "+N more" count
	elseif Pause.isPaused(party.clock) then
		openOffer(player, state)
	else
		pauseForPicks(party)
	end
end

-- Pauses the party's match for owed level-up picks and resumes it when they're done. Call every
-- frame, paused or not.
function Upgrades.step(party: Party)
	if not party.active then
		return
	end
	if Pause.isPaused(party.clock) then
		local waiting = false
		for _, player in party.members do
			local state = states[player]
			if state and picksOwed(state) > 0 then
				waiting = true
				break
			end
		end
		if not waiting then
			resume(party)
		elseif #party.members > 1 and os.clock() - party.pauseStartedAt >= Config.PAUSE_TIMEOUT then
			-- Don't let one idle player hold up the party: choose for whoever is still picking.
			for _, player in party.members do
				local state = states[player]
				if state then
					autoPick(player, state)
				end
			end
			resume(party)
		end
	elseif Pause.now(party.clock) - party.lastResumedAt >= Config.PAUSE_COOLDOWN then
		for _, player in party.members do
			local state = states[player]
			if state and state.levelPicks > 0 then
				pauseForPicks(party)
				break
			end
		end
	end
end

-- Studio dev command: set a weapon or passive to `level` (0 removes it; MAX_LEVEL + 1 evolves a
-- weapon). Returns false for an unknown id.
function Upgrades.devSet(player: Player, id: string, level: number): boolean
	local state = getState(player)
	local slot = if Config.WEAPONS[id]
		then state.build.weapons
		elseif Config.PASSIVES[id] then state.build.passives
		else nil
	if not slot then
		return false
	end
	-- Weapons go one past MAX_LEVEL: that's the evolution.
	local maxLevel = if slot == state.build.weapons then Config.MAX_LEVEL + 1 else Config.MAX_LEVEL
	slot[id] = if level > 0 then math.clamp(math.floor(level), 1, maxLevel) else nil
	publishBuild(player, state)
	applyStats(player)
	return true
end

-- A party for one match. Level-ups of `progression` give each member a pick.
function Upgrades.newParty(clock: Pause.Clock, members: { Player }, progression: Progression.State): Party
	local party: Party = {
		clock = clock,
		members = members,
		active = false,
		pauseStartedAt = 0,
		lastResumedAt = -math.huge,
	}
	Progression.onLevelUp(progression, function()
		if not party.active then
			return
		end
		for _, player in party.members do
			grantLevelPick(player)
		end
	end)
	return party
end

-- Fresh starting builds for the party's members, for a new run. Call before characters spawn.
-- Head Start (an Altar upgrade) opens its free picks right away, like chest picks.
function Upgrades.reset(party: Party)
	Pause.resume(party.clock)
	party.lastResumedAt = -math.huge
	for _, player in party.members do
		local loadout = Meta.loadout(player)
		local state = newState(party, loadout)
		states[player] = state
		publishBuild(player, state)
		state.chestPicks = loadout.bonus.headStart
		if state.chestPicks > 0 then
			openOffer(player, state)
		else
			sendOffer(player, state)
		end
	end
	party.active = true
end

-- Closes the party's open choices when its run ends. Builds stay as they were.
function Upgrades.stop(party: Party)
	party.active = false
	Pause.resume(party.clock)
	for _, player in party.members do
		local state = states[player]
		if not state then
			continue
		end
		state.offer = nil
		state.levelPicks = 0
		state.chestPicks = 0
		sendOffer(player, state)
	end
end

function Upgrades.start()
	assert(not started, "Upgrades.start() was called twice")
	started = true

	Characters.setStatsProvider(statsFor)
	Characters.setDamageTakenProvider(function(player)
		return BuildStats.modifiers(getState(player).build).damageTaken
	end)
	Characters.setRegenProvider(function(player)
		return BuildStats.modifiers(getState(player).build).regen
	end)
	Progression.setPickupRadiusProvider(function(player)
		return ProgressionConfig.PICKUP_RADIUS * BuildStats.modifiers(getState(player).build).pickupRadius
	end)
	Remotes.ChooseUpgrade.OnServerEvent:Connect(onChoose)
	Remotes.RerollUpgrade.OnServerEvent:Connect(onReroll)

	-- A new hero or Altar upgrade changes a lobby player's starting build right away. Mid-run
	-- builds keep the loadout they started with.
	Meta.onLoadoutChanged(function(player)
		local old = states[player]
		if old and old.party then
			return
		end
		local state = newState(nil, Meta.loadout(player))
		states[player] = state
		publishBuild(player, state)
		applyStats(player)
	end)

	-- Everyone has a build (the starting one) from the moment they join.
	Players.PlayerAdded:Connect(getState)
	for _, player in Players:GetPlayers() do
		getState(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
end

return Upgrades
