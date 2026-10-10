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

local function event(name: string): RemoteEvent
	if not IS_SERVER then
		return folder:WaitForChild(name) :: RemoteEvent
	end
	local existing = folder:FindFirstChild(name)
	if existing then
		return existing :: RemoteEvent
	end
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = folder
	return remote
end

local function func(name: string): RemoteFunction
	if not IS_SERVER then
		return folder:WaitForChild(name) :: RemoteFunction
	end
	local existing = folder:FindFirstChild(name)
	if existing then
		return existing :: RemoteFunction
	end
	local remote = Instance.new("RemoteFunction")
	remote.Name = name
	remote.Parent = folder
	return remote
end

return table.freeze({
	-- Server -> client. Payload: the player's full data snapshot (Config.PlayerData.Data).
	-- Fired once the data loads and again after each change.
	DataChanged = event("DataChanged"),

	-- Client -> server. No arguments. Returns the caller's data snapshot, or nil if it isn't
	-- available. Yields until the data has loaded.
	GetData = func("GetData"),
})
