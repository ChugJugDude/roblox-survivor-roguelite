--!strict
--[[
	XP. Enemies drop gems where they die; walking near a gem collects it. All XP goes into one
	party-wide pool with a shared level, and every level-up notifies listeners (Upgrades gives
	each player a pick).

	Gems are server data, like enemies. Clients get spawn and collected events; a collected event
	names the player so the gem can fly to them. Party progress is published on the Arena as
	PartyLevel, PartyXP, and XPToNext.
]]

local Players = game:GetService("Players")
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

local arena: Arena.Arena? = nil
local gems: { [number]: Gem } = {}
local gemCount = 0
local nextGemId = 0
local hash = SpatialHash.new(Config.GEM_CELL_SIZE)
local xp = 0
local level = 1
local pendingXP = 0 -- collected this frame, added in one go at the end of step
local levelUpListeners: { (number) -> () } = {}
local nearby: { number } = {} -- reused for every hash query
local started = false
local xpFrozen = false -- Studio dev command: gems still collect, but give no XP

-- Replaced by Upgrades once Magnet exists; until then everyone uses the base radius.
local pickupRadiusFor: (Player) -> number = function(_player: Player)
	return Config.PICKUP_RADIUS
end

local Progression = {}

local function publish()
	local model = assert(arena, "Progression.start() must be called first").model
	model:SetAttribute("PartyLevel", level)
	model:SetAttribute("PartyXP", xp)
	model:SetAttribute("XPToNext", Progression.xpToNext(level))
end

local function collect(gem: Gem, userId: number)
	gems[gem.id] = nil
	gemCount -= 1
	SpatialHash.remove(hash, gem.id, gem.x, gem.z)
	NetBatch.push(Remotes.GemsCollected, { id = gem.id, userId = userId })
end

local function spawnGem(x: number, z: number, value: number)
	if value <= 0 then
		return -- crates and other props drop no XP
	end
	if gemCount >= Config.MAX_GEMS then
		pendingXP += value
		return
	end
	nextGemId += 1
	local gem: Gem = { id = nextGemId, x = x, z = z, value = value }
	gems[gem.id] = gem
	gemCount += 1
	SpatialHash.insert(hash, gem.id, x, z)
	NetBatch.push(Remotes.GemsSpawned, { id = gem.id, x = x, z = z, value = value })
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

function Progression.xpToNext(currentLevel: number): number
	return math.floor(Config.XP_BASE + Config.XP_GROWTH * (currentLevel - 1) ^ Config.XP_EXPONENT + 0.5)
end

function Progression.getLevel(): number
	return level
end

-- Calls `listener(newLevel)` for every level gained.
function Progression.onLevelUp(listener: (number) -> ())
	table.insert(levelUpListeners, listener)
end

function Progression.setPickupRadiusProvider(provider: (Player) -> number)
	pickupRadiusFor = provider
end

function Progression.addXP(amount: number)
	if xpFrozen then
		return
	end
	xp += amount
	while xp >= Progression.xpToNext(level) do
		xp -= Progression.xpToNext(level)
		level += 1
		for _, listener in levelUpListeners do
			task.spawn(listener, level)
		end
	end
	publish()
end

-- Studio dev command: stop XP (and so level-ups and their pauses), e.g. to benchmark a fixed build.
function Progression.devSetXPFrozen(frozen: boolean)
	xpFrozen = frozen
end

function Progression.devIsXPFrozen(): boolean
	return xpFrozen
end

-- Clears gems and XP for a new run.
function Progression.reset()
	for _, gem in gems do
		collect(gem, 0)
	end
	xp = 0
	level = 1
	pendingXP = 0
	publish()
end

-- Collects every gem on the floor, each flying to its nearest living player. For stage clears.
function Progression.vacuum(targets: { Characters.Target })
	local total = 0
	for _, gem in gems do
		local target = nearestTarget(targets, gem.x, gem.z)
		total += gem.value
		collect(gem, if target then target.player.UserId else 0)
	end
	if total > 0 then
		Progression.addXP(total)
	end
end

-- Picks up gems within each living player's pickup radius, then applies the frame's XP.
function Progression.step(targets: { Characters.Target })
	for _, target in targets do
		local radius = pickupRadiusFor(target.player)
		table.clear(nearby)
		SpatialHash.query(hash, target.x, target.z, radius, nearby)
		for _, id in nearby do
			local gem = gems[id]
			if gem then
				local dx, dz = gem.x - target.x, gem.z - target.z
				if dx * dx + dz * dz <= radius * radius then
					pendingXP += gem.value
					collect(gem, target.player.UserId)
				end
			end
		end
	end

	if pendingXP > 0 then
		local amount = pendingXP
		pendingXP = 0
		Progression.addXP(amount)
	end
end

function Progression.start(newArena: Arena.Arena)
	assert(not started, "Progression.start() was called twice")
	started = true
	arena = newArena
	NetBatch.register(Remotes.GemsSpawned)
	NetBatch.register(Remotes.GemsCollected)
	publish()

	EnemyService.onKilled(function(enemy)
		spawnGem(enemy.x, enemy.z, enemy.xp)
	end)

	-- Players who join mid-run need the gems already on the floor.
	Players.PlayerAdded:Connect(function(player)
		local current = {}
		for _, gem in gems do
			table.insert(current, { id = gem.id, x = gem.x, z = gem.z, value = gem.value })
		end
		if #current > 0 then
			Remotes.GemsSpawned:FireClient(player, current)
		end
	end)
end

return Progression
