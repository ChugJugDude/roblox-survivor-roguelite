--!strict
--[[
	Every RemoteEvent and RemoteFunction in the game is declared here. The server creates them
	under ReplicatedStorage.Remotes the first time this module is required; clients wait for them
	to replicate.

	Each remote notes its direction and payload. Server handlers must validate argument types and
	ranges and rate-limit the caller: assume every client is an exploiter. Don't invoke
	RemoteFunctions from the server to a client.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "Remotes"
local IS_SERVER = RunService:IsServer()

local folder: Instance
if IS_SERVER then
	local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if existing then
		folder = existing
	else
		local created = Instance.new("Folder")
		created.Name = FOLDER_NAME
		created.Parent = ReplicatedStorage
		folder = created
	end
else
	folder = ReplicatedStorage:WaitForChild(FOLDER_NAME)
end

local function remote(className: string, name: string): Instance
	if not IS_SERVER then
		return folder:WaitForChild(name)
	end
	local existing = folder:FindFirstChild(name)
	if existing then
		return existing
	end
	local created = Instance.new(className)
	created.Name = name
	created.Parent = folder
	return created
end

return table.freeze({
	-- Server -> client. Payload: the player's full data snapshot (Config.PlayerData.Data).
	-- Fired once the data loads and again after each change.
	DataChanged = remote("RemoteEvent", "DataChanged") :: RemoteEvent,

	-- Client -> server. No arguments. Returns the caller's data snapshot, or nil if it isn't
	-- available. Yields until the data has loaded.
	GetData = remote("RemoteFunction", "GetData") :: RemoteFunction,

	-- Server -> client. Payload: { EnemySnapshot.SpawnInfo }, batched per frame. A client can get
	-- the same id twice (when it joins mid-fight); ignore the repeat.
	EnemySpawned = remote("RemoteEvent", "EnemySpawned") :: RemoteEvent,

	-- Server -> client. Payload: { number } of enemy ids that died or were removed, batched per frame.
	EnemyDespawned = remote("RemoteEvent", "EnemyDespawned") :: RemoteEvent,

	-- Server -> client, unreliable. Payload: a position buffer from EnemySnapshot. Packets can be
	-- dropped or arrive out of order.
	EnemySnapshot = remote("UnreliableRemoteEvent", "EnemySnapshot") :: UnreliableRemoteEvent,

	-- Client -> server. No arguments. Asks to start a new run from the results screen. Ignored
	-- unless the run has ended; rate-limited per player.
	RequestRestart = remote("RemoteEvent", "RequestRestart") :: RemoteEvent,
})
