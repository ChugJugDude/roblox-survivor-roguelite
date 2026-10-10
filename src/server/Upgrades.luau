--!strict
--[[
	Each player's build (weapons and passives, with levels) and their level-up choice.

	Every party level-up gives each player a pick. Level-up picks wait for a pause: when anyone is
	owed one (and at least PAUSE_COOLDOWN seconds of play have passed since the last pause), the
	whole game pauses and every player chooses at once. It resumes when everyone is done; with 2+
	players, PAUSE_TIMEOUT stops one idle player from holding up the party. Chest picks are one
	player's, so they open right away without pausing, with a moment of invulnerability instead.

	One offer is open per player at a time. The server generates the options and only accepts an
	index into the open offer.

	Builds replicate as Player attributes, W_<weapon> and P_<passive> = level, so the client can
	use shared/BuildStats too (e.g. to draw the right number of blades).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Characters = require(script.Parent.Characters)
local Pause = require(script.Parent.Pause)
local Progression = require(script.Parent.Progression)
local BuildStats = require(ReplicatedStorage.Shared.BuildStats)
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
}

type State = {
	build: BuildStats.Build,
	levelPicks: number, -- owed from party level-ups; shown during a pause
	chestPicks: number, -- owed from chests; shown right away
	offer: { Option }?,
	rerolls: number,
	lastRequest: number,
}

-- Minimum seconds between choose/reroll requests from one player.
local REQUEST_COOLDOWN = 0.1

local states: { [Player]: State } = {}
local active = false
local started = false
local pauseStartedAt = 0 -- os.clock() when the current pause began
local lastResumedAt = -math.huge -- game time of the last resume
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
end

local function newState(): State
	return {
		build = { weapons = { [Config.STARTING_WEAPON] = 1 }, passives = {} },
		levelPicks = 0,
		chestPicks = 0,
		offer = nil,
		rerolls = Config.REROLLS_PER_RUN,
		lastRequest = 0,
	}
end

local function getState(player: Player): State
	local state = states[player]
	if not state then
		state = newState()
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
	}
end

local function passiveOption(id: string, level: number): Option
	local def = Config.PASSIVES[id]
	local value = def.values[level]
	return {
		id = id,
		kind = "passive",
		level = level,
		isNew = level == 1,
		name = def.name,
		description = string.format(def.description, math.floor((if def.percent then value * 100 else value) + 0.5)),
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
		})
	else
		Remotes.UpgradeOffered:FireClient(player, nil)
	end
end

-- Makes the player invulnerable for `seconds` of game time. The ForceField is the visible cue.
local function grantInvulnerability(player: Player, seconds: number)
	player:SetAttribute("InvulnerableUntil", Pause.now() + seconds)
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
	if not Pause.isPaused() then
		grantInvulnerability(player, Config.INVULNERABILITY)
	end
	sendOffer(player, state)
end

-- Opens the player's next offer if one can be shown now; otherwise closes their picker.
local function showNext(player: Player, state: State)
	if state.chestPicks > 0 or (Pause.isPaused() and state.levelPicks > 0) then
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
	elseif Pause.isPaused() then
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

local function pauseForPicks()
	Pause.pause()
	pauseStartedAt = os.clock()
	for player, state in states do
		if not state.offer and picksOwed(state) > 0 then
			openOffer(player, state)
		end
	end
end

local function resume()
	Pause.resume()
	lastResumedAt = Pause.now()
	for _, player in Players:GetPlayers() do
		grantInvulnerability(player, Config.RESUME_GRACE)
	end
end

-- Returns the player's state if they may act on their offer now (rate-limited).
local function acceptRequest(player: Player): State?
	local state = states[player]
	if not active or not state or not state.offer then
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

-- The player's build, or nil if they don't have one yet.
function Upgrades.getBuild(player: Player): BuildStats.Build?
	local state = states[player]
	return if state then state.build else nil
end

-- An extra pick for one player (from a chest), during a run.
function Upgrades.grantBonusPick(player: Player)
	if not active then
		return
	end
	local state = getState(player)
	state.chestPicks += 1
	if state.offer then
		sendOffer(player, state)
	else
		openOffer(player, state)
	end
end

-- Pauses for owed level-up picks and resumes when they're done. Call every frame, paused or not.
function Upgrades.step()
	if not active then
		return
	end
	if Pause.isPaused() then
		local waiting = false
		for _, state in states do
			if picksOwed(state) > 0 then
				waiting = true
				break
			end
		end
		if not waiting then
			resume()
		elseif #Players:GetPlayers() > 1 and os.clock() - pauseStartedAt >= Config.PAUSE_TIMEOUT then
			-- Don't let one idle player hold up the party: choose for whoever is still picking.
			for player, state in states do
				autoPick(player, state)
			end
			resume()
		end
	elseif Pause.now() - lastResumedAt >= Config.PAUSE_COOLDOWN then
		for _, state in states do
			if state.levelPicks > 0 then
				pauseForPicks()
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

-- Fresh starting builds for everyone, for a new run. Call before characters spawn.
function Upgrades.reset()
	Pause.resume()
	lastResumedAt = -math.huge
	for _, player in Players:GetPlayers() do
		local state = newState()
		states[player] = state
		publishBuild(player, state)
		sendOffer(player, state)
	end
	active = true
end

-- Closes every open choice when the run ends. Builds stay as they were.
function Upgrades.stop()
	active = false
	Pause.resume()
	for player, state in states do
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
	Progression.setPickupRadiusProvider(function(player)
		return ProgressionConfig.PICKUP_RADIUS * BuildStats.modifiers(getState(player).build).pickupRadius
	end)
	Progression.onLevelUp(function()
		if not active then
			return
		end
		for _, player in Players:GetPlayers() do
			grantLevelPick(player)
		end
	end)

	Remotes.ChooseUpgrade.OnServerEvent:Connect(onChoose)
	Remotes.RerollUpgrade.OnServerEvent:Connect(onReroll)

	-- Mid-run joiners start with the starting build.
	Players.PlayerAdded:Connect(getState)
	for _, player in Players:GetPlayers() do
		getState(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
end

return Upgrades
