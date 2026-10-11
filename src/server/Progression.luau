--!strict
--[[
	One match's XP. Enemies drop gems where they die; walking near a gem collects it. All XP goes
	into one party-wide pool with a shared level, and every level-up notifies listeners (Upgrades
	gives each member a pick).

	Gems are server data, like enemies. Clients get spawn and collected events; a collected event
	names the player so the gem can fly to them. Party progress is published on the match's Arena as
	PartyLevel, PartyXP, and XPToNext.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Arena = require(script.Parent.Arena)
local Characters = require(script.Parent.Characters)
local EnemyService = require(script.Parent.EnemyService)
local NetBatch = require(script.Parent.NetBatch)
local SpatialHash = require(script.Parent.SpatialHash)
local Config = require(ReplicatedStorage.Shared.Config.Progression)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

type Gem = {
	id: number,
	x: number,
	z: number,
	value: number,
}

export type State = {
	arena: Arena.Arena,
	net: NetBatch.Batch,
	gems: { [number]: Gem },
	gemCount: number,
	nextGemId: number,
	hash: SpatialHash.SpatialHash,
	xp: number,
	level: number,
	pendingXP: number, -- collected this frame, added in one go at the end of step
	levelUpListeners: { (number) -> () },
}

local nearby: { number } = {} -- reused for every hash query
local xpFrozen = false -- Studio dev command: gems still collect, but give no XP (all matches)

-- Replaced by Upgrades (Magnet); until then everyone uses the base radius.
local pickupRadiusFor: (Player) -> number = function(_player: Player)
	return Config.PICKUP_RADIUS
end

local Progression = {}

local function publish(state: State)
	local model = state.arena.model
	model:SetAttribute("PartyLevel", state.level)
	model:SetAttribute("PartyXP", state.xp)
	model:SetAttribute("XPToNext", Progression.xpToNext(state.level))
end

local function collect(state: State, gem: Gem, userId: number)
	state.gems[gem.id] = nil
	state.gemCount -= 1
	SpatialHash.remove(state.hash, gem.id, gem.x, gem.z)
	NetBatch.push(state.net, Remotes.GemsCollected, { id = gem.id, userId = userId })
end

local function spawnGem(state: State, x: number, z: number, value: number)
	if value <= 0 then
		return -- crates and other props drop no XP
	end
	if state.gemCount >= Config.MAX_GEMS then
		state.pendingXP += value
		return
	end
	state.nextGemId += 1
	local gem: Gem = { id = state.nextGemId, x = x, z = z, value = value }
	state.gems[gem.id] = gem
	state.gemCount += 1
	SpatialHash.insert(state.hash, gem.id, x, z)
	NetBatch.push(state.net, Remotes.GemsSpawned, { id = gem.id, x = x, z = z, value = value })
end

local function nearestTarget(targets: { Characters.Target }, x: number, z: number): Characters.Target?
	local best: Characters.Target? = nil
	local bestDistSq = math.huge
	for _, target in targets do
		local dx, dz = target.x - x, target.z - z
		local distSq = dx * dx + dz * dz
		if distSq < bestDistSq then
			best, bestDistSq = target, distSq
		end
	end
	return best
end

function Progression.new(arena: Arena.Arena, net: NetBatch.Batch, enemies: EnemyService.State): State
	local state: State = {
		arena = arena,
		net = net,
		gems = {},
		gemCount = 0,
		nextGemId = 0,
		hash = SpatialHash.new(Config.GEM_CELL_SIZE),
		xp = 0,
		level = 1,
		pendingXP = 0,
		levelUpListeners = {},
	}
	publish(state)
	EnemyService.onKilled(enemies, function(enemy)
		spawnGem(state, enemy.x, enemy.z, enemy.xp)
	end)
	return state
end

function Progression.xpToNext(currentLevel: number): number
	return math.floor(Config.XP_BASE + Config.XP_GROWTH * (currentLevel - 1) ^ Config.XP_EXPONENT + 0.5)
end

function Progression.getLevel(state: State): number
	return state.level
end

-- Calls `listener(newLevel)` for every level gained.
function Progression.onLevelUp(state: State, listener: (number) -> ())
	table.insert(state.levelUpListeners, listener)
end

function Progression.setPickupRadiusProvider(provider: (Player) -> number)
	pickupRadiusFor = provider
end

function Progression.addXP(state: State, amount: number)
	if xpFrozen then
		return
	end
	state.xp += amount
	while state.xp >= Progression.xpToNext(state.level) do
		state.xp -= Progression.xpToNext(state.level)
		state.level += 1
		for _, listener in state.levelUpListeners do
			task.spawn(listener, state.level)
		end
	end
	publish(state)
end

-- Studio dev command: stop XP (and so level-ups and their pauses), e.g. to benchmark a fixed build.
function Progression.devSetXPFrozen(frozen: boolean)
	xpFrozen = frozen
end

-- Clears gems and XP for a new run.
function Progression.reset(state: State)
	for _, gem in state.gems do
		collect(state, gem, 0)
	end
	state.xp = 0
	state.level = 1
	state.pendingXP = 0
	publish(state)
end

-- Collects every gem on the floor, each flying to its nearest player in `targets`. For stage clears
-- and magnets.
function Progression.vacuum(state: State, targets: { Characters.Target })
	local total = 0
	for _, gem in state.gems do
		local target = nearestTarget(targets, gem.x, gem.z)
		total += gem.value
		collect(state, gem, if target then target.player.UserId else 0)
	end
	if total > 0 then
		Progression.addXP(state, total)
	end
end

-- Picks up gems within each living player's pickup radius, then applies the frame's XP.
function Progression.step(state: State, targets: { Characters.Target })
	for _, target in targets do
		local radius = pickupRadiusFor(target.player)
		table.clear(nearby)
		SpatialHash.query(state.hash, target.x, target.z, radius, nearby)
		for _, id in nearby do
			local gem = state.gems[id]
			if gem then
				local dx, dz = gem.x - target.x, gem.z - target.z
				if dx * dx + dz * dz <= radius * radius then
					state.pendingXP += gem.value
					collect(state, gem, target.player.UserId)
				end
			end
		end
	end

	if state.pendingXP > 0 then
		local amount = state.pendingXP
		state.pendingXP = 0
		Progression.addXP(state, amount)
	end
end

-- Sends every gem on the floor to one player (who just entered this match's arena).
function Progression.syncTo(state: State, player: Player)
	local current = {}
	for _, gem in state.gems do
		table.insert(current, { id = gem.id, x = gem.x, z = gem.z, value = gem.value })
	end
	if #current > 0 then
		Remotes.GemsSpawned:FireClient(player, current)
	end
end

return Progression
