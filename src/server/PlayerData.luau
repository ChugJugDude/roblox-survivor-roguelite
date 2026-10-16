--!strict
--[[
	PlayerData: the only code that reads or writes player DataStores.

	- Session locking: a server claims a player's key on join and releases it on leave. Another
	  server waits for the lock, then takes it over if it's never released. A server that finds
	  its lock taken stops saving and kicks the player, so two servers never overwrite each other.
	- DataStore calls retry with exponential backoff.
	- Autosaves on an interval, and saves on PlayerRemoving and game:BindToClose.
	- Sends a snapshot to the owning client through Remotes.DataChanged, and tells onChanged
	  listeners on the server.

	Usage (server only):
		PlayerData.start() -- once, from the server entry script
		local data = PlayerData.waitForData(player) -- nil if the player left or loading failed
		PlayerData.update(player, function(data)
			data.shards += 10
		end)

	Treat tables returned by get/waitForData as read-only. All writes go through update so they
	replicate to the client.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config.PlayerData)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

type Data = Config.Data

type Lock = {
	jobId: string,
	time: number,
}

-- The value stored under each player's key.
type Record = {
	data: Data,
	lock: Lock?,
}

type Session = {
	player: Player,
	data: Data,
	canSave: boolean, -- false for Studio fallback data, or after another server took the lock
	saving: boolean,
	released: boolean,
	replicateQueued: boolean,
}

local IS_STUDIO = RunService:IsStudio()

local storeOk, storeResult = pcall(DataStoreService.GetDataStore, DataStoreService, Config.STORE_NAME)
local store: DataStore? = if storeOk then storeResult else nil
if not storeOk then
	warn(`[PlayerData] Couldn't open the DataStore: {storeResult}`)
end

local sessions: { [Player]: Session } = {}
local loading: { [Player]: true } = {}
local failed: { [Player]: true } = {}
local waiters: { [Player]: { thread } } = {}
local lastGetData: { [Player]: number } = {}
local changedListeners: { (Player, Data) -> () } = {}
local started = false

local PlayerData = {}

local function keyFor(player: Player): string
	return `Player_{player.UserId}`
end

local function deepCopy<T>(value: T): T
	if typeof(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, child in value :: any do
		copy[key] = deepCopy(child)
	end
	return copy :: any
end

-- Fills in fields that are missing from older saves, or that have the wrong type, recursing into
-- nested tables. Keys the defaults don't mention (like an empty map's entries) are kept.
local function fill(saved: any, defaults: any): any
	local data = if typeof(saved) == "table" then saved else {}
	for key, default in defaults do
		if typeof(data[key]) ~= typeof(default) then
			data[key] = deepCopy(default)
		elseif typeof(default) == "table" then
			data[key] = fill(data[key], default)
		end
	end
	return data
end

local function reconcile(saved: any): Data
	return fill(saved, Config.DEFAULT_DATA)
end

-- UpdateAsync with retries. The transform can run more than once, so its only side effects
-- should be setting the caller's result variables.
local function updateAsync(key: string, attempts: number, transform: (any) -> (any, { number }?)): boolean
	local dataStore = store
	if not dataStore then
		return false
	end
	local backoff = Config.RETRY_BASE_DELAY
	for attempt = 1, attempts do
		local ok, err = pcall(dataStore.UpdateAsync, dataStore, key, transform)
		if ok then
			return true
		end
		warn(`[PlayerData] UpdateAsync failed for {key} (attempt {attempt}/{attempts}): {err}`)
		if attempt < attempts then
			task.wait(backoff)
			backoff *= 2
		end
	end
	return false
end

-- Claims the session lock and returns the player's saved data. If another server holds the lock,
-- waits for it to be released and then takes it over. Returns nil if the DataStore keeps failing
-- or the player leaves while waiting.
local function claimAsync(player: Player): Data?
	-- Retrying in Studio is usually pointless (API access off), and it slows down playtests.
	local attempts = if IS_STUDIO then 1 else Config.MAX_RETRIES

	for lockAttempt = 1, Config.LOCK_WAIT_ATTEMPTS + 1 do
		local takeOver = lockAttempt > Config.LOCK_WAIT_ATTEMPTS
		local lockedElsewhere = false
		local loaded: Data? = nil

		local ok = updateAsync(keyFor(player), attempts, function(old: any)
			local record = if typeof(old) == "table" then old else {}
			local lock = record.lock
			local heldElsewhere = typeof(lock) == "table" and lock.jobId ~= game.JobId
			local stale = heldElsewhere
				and (typeof(lock.time) ~= "number" or os.time() - lock.time >= Config.LOCK_EXPIRY)
			lockedElsewhere = heldElsewhere and not stale and not takeOver
			if lockedElsewhere then
				return nil -- cancel the write and check again shortly
			end

			loaded = reconcile(record.data)
			local new: Record = {
				data = loaded :: Data,
				lock = { jobId = game.JobId, time = os.time() },
			}
			return new, { player.UserId }
		end)

		if not ok then
			return nil
		end
		if not lockedElsewhere then
			return loaded
		end

		warn(`[PlayerData] {player.Name}'s data is locked by another server; waiting for it to be released.`)
		task.wait(Config.LOCK_WAIT_DELAY)
		if player.Parent ~= Players then
			return nil
		end
	end

	return nil
end

-- Returns the player's data and whether it may be saved, or nil if it couldn't be loaded.
local function loadAsync(player: Player): (Data?, boolean)
	local data = claimAsync(player)
	if data then
		return data, true
	end
	if IS_STUDIO and player.Parent == Players then
		warn(
			`[PlayerData] Couldn't load {player.Name}'s data in Studio, so they're using unsaved defaults. `
				.. `To test saving, turn on Game Settings > Security > "Enable Studio Access to API Services".`
		)
		return deepCopy(Config.DEFAULT_DATA), false
	end
	return nil, false
end

local function writeAsync(session: Session, release: boolean)
	local player = session.player
	local lostLock = false

	updateAsync(keyFor(player), Config.MAX_RETRIES, function(old: any)
		local lock = if typeof(old) == "table" then old.lock else nil
		lostLock = typeof(lock) ~= "table" or lock.jobId ~= game.JobId
		if lostLock then
			return nil
		end

		local new: Record = {
			data = session.data,
			lock = if release then nil else { jobId = game.JobId, time = os.time() },
		}
		return new, { player.UserId }
	end)

	if lostLock then
		-- Another server took over this player's data, so its copy is the one that counts.
		session.canSave = false
		warn(`[PlayerData] Lost the session lock for {player.Name}; this server will stop saving their data.`)
		if player.Parent == Players then
			player:Kick("Your data was loaded on another server. Please rejoin.")
		end
	end
end

-- Saves one session. Writes for a player run one at a time, and nothing is written after release.
local function saveAsync(session: Session, release: boolean)
	while session.saving do
		task.wait()
	end
	if session.released then
		return
	end

	session.saving = true
	if session.canSave then
		writeAsync(session, release)
	end
	session.released = release
	session.saving = false
end

-- Batches changes made in the same frame into one DataChanged send.
local function queueReplicate(session: Session)
	if session.replicateQueued then
		return
	end
	session.replicateQueued = true
	task.defer(function()
		session.replicateQueued = false
		if session.player.Parent == Players then
			Remotes.DataChanged:FireClient(session.player, session.data)
			for _, listener in changedListeners do
				task.spawn(listener, session.player, session.data)
			end
		end
	end)
end

local function finishLoading(player: Player)
	loading[player] = nil
	local threads = waiters[player]
	waiters[player] = nil
	if threads then
		for _, thread in threads do
			task.spawn(thread)
		end
	end
end

-- If the player left this server and rejoined it, the old session might still be saving. Wait
-- for it to finish so we don't load data that's older than what it's about to write.
local function waitForPreviousSession(userId: number)
	while true do
		local found = false
		for player in sessions do
			if player.UserId == userId then
				found = true
				break
			end
		end
		if not found then
			return
		end
		task.wait(0.5)
	end
end

local function onPlayerAdded(player: Player)
	if loading[player] or sessions[player] then
		return
	end
	loading[player] = true
	waitForPreviousSession(player.UserId)

	local data, canSave = loadAsync(player)
	if data then
		local session: Session = {
			player = player,
			data = data,
			canSave = canSave,
			saving = false,
			released = false,
			replicateQueued = false,
		}
		if player.Parent == Players then
			sessions[player] = session
			queueReplicate(session)
		else
			-- They left while loading. Release the lock we just took.
			saveAsync(session, true)
		end
	elseif player.Parent == Players then
		failed[player] = true
		player:Kick("We couldn't load your data. Please rejoin in a few minutes.")
	end

	finishLoading(player)
end

local function onPlayerRemoving(player: Player)
	failed[player] = nil
	lastGetData[player] = nil
	local session = sessions[player]
	if session then
		saveAsync(session, true)
		sessions[player] = nil
	end
end

-- Returns the player's data if it's loaded, without yielding.
function PlayerData.get(player: Player): Data?
	local session = sessions[player]
	return if session then session.data else nil
end

-- Yields until the player's data has loaded. Returns nil if the player left or loading failed.
function PlayerData.waitForData(player: Player): Data?
	assert(started, "PlayerData.start() must be called before waitForData")
	local session = sessions[player]
	if session then
		return session.data
	end
	if failed[player] or player.Parent ~= Players then
		return nil
	end

	-- Still loading, or PlayerAdded hasn't reached us yet. finishLoading resumes this thread.
	local threads = waiters[player]
	if not threads then
		threads = {}
		waiters[player] = threads
	end
	table.insert(threads, coroutine.running())
	coroutine.yield()

	local loaded = sessions[player]
	return if loaded then loaded.data else nil
end

-- Applies `mutate` to the player's data and replicates the result. `mutate` must not yield.
-- Returns false if the player's data isn't loaded or the player has left.
function PlayerData.update(player: Player, mutate: (Data) -> ()): boolean
	local session = sessions[player]
	if not session or session.released or player.Parent ~= Players then
		return false
	end
	mutate(session.data)
	queueReplicate(session)
	return true
end

-- Calls `listener(player, data)` after a player's data loads and after each batch of changes.
-- `data` is read-only.
function PlayerData.onChanged(listener: (Player, Data) -> ())
	table.insert(changedListeners, listener)
end

function PlayerData.start()
	assert(not started, "PlayerData.start() was called twice")
	started = true

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	Remotes.GetData.OnServerInvoke = function(player: Player): Data?
		-- There are no arguments to validate. Rate-limit anyway, since each call can hold a
		-- server thread until the data loads.
		local now = os.clock()
		local last = lastGetData[player]
		if last and now - last < Config.GET_DATA_COOLDOWN then
			return nil
		end
		lastGetData[player] = now
		return PlayerData.waitForData(player)
	end

	task.spawn(function()
		while true do
			task.wait(Config.AUTOSAVE_INTERVAL)
			for _, session in sessions do
				task.spawn(saveAsync, session, false)
			end
		end
	end)

	game:BindToClose(function()
		-- PlayerRemoving isn't guaranteed to finish (or fire) during shutdown, so release every
		-- session here. Loads still in progress release their own lock when they finish.
		local pending = 0
		for _, session in sessions do
			pending += 1
			task.spawn(function()
				saveAsync(session, true)
				pending -= 1
			end)
		end
		while pending > 0 or next(loading) ~= nil do
			task.wait()
		end
	end)
end

return PlayerData
