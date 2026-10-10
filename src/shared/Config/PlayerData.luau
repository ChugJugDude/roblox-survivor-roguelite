--!strict
-- Tuning for the server's PlayerData module. It lives in shared so clients can use the Data type;
-- nothing in it is secret.

-- Everything that's saved for a player. Values must be DataStore-safe: numbers, strings, booleans,
-- and plain tables (arrays or string-keyed). No Instances, Vector3s, or mixed tables.
export type Data = {
	coins: number,
}

local PlayerDataConfig = {
	-- Changing this name starts every player fresh. Old data stays in the old store.
	STORE_NAME = "PlayerData_v1",

	-- Starting data for new players. Saves that are missing a field (or have the wrong type for
	-- it) get it filled in from here, so new fields can be added without a migration.
	DEFAULT_DATA = table.freeze({
		coins = 0,
	}) :: Data,

	-- Seconds between autosaves. This also refreshes the session lock.
	AUTOSAVE_INTERVAL = 120,

	-- Attempts per DataStore call, with exponential backoff starting at RETRY_BASE_DELAY seconds.
	MAX_RETRIES = 5,
	RETRY_BASE_DELAY = 1,

	-- When another server holds a player's lock, re-check this many times, LOCK_WAIT_DELAY seconds
	-- apart, before taking it over. That gives the other server time to finish saving.
	LOCK_WAIT_ATTEMPTS = 5,
	LOCK_WAIT_DELAY = 6,
	-- A lock that hasn't been refreshed for this many seconds came from a server that crashed,
	-- so it's taken over right away. Keep this well above AUTOSAVE_INTERVAL.
	LOCK_EXPIRY = 600,

	-- Minimum seconds between GetData requests from one client.
	GET_DATA_COOLDOWN = 1,
}

return table.freeze(PlayerDataConfig)
