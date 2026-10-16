--!strict
-- The local player's saved data (Config.PlayerData.Data), as last sent by the server. Read-only:
-- changes go through remotes, and the server sends the new snapshot through DataChanged.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataConfig = require(ReplicatedStorage.Shared.Config.PlayerData)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

type Data = PlayerDataConfig.Data

local data: Data? = nil
local listeners: { (Data) -> () } = {}

local PlayerDataClient = {}

local function set(snapshot: any)
	if typeof(snapshot) ~= "table" then
		return
	end
	data = snapshot
	for _, listener in listeners do
		task.spawn(listener, snapshot)
	end
end

-- The latest snapshot, or nil until the data has loaded.
function PlayerDataClient.get(): Data?
	return data
end

-- Calls `listener(data)` with each new snapshot.
function PlayerDataClient.onChanged(listener: (Data) -> ())
	table.insert(listeners, listener)
end

function PlayerDataClient.start()
	Remotes.DataChanged.OnClientEvent:Connect(set)
	-- In case the first DataChanged went out before we were listening.
	task.spawn(function()
		local ok, snapshot = pcall(Remotes.GetData.InvokeServer, Remotes.GetData)
		if ok and data == nil then
			set(snapshot)
		end
	end)
end

return PlayerDataClient
