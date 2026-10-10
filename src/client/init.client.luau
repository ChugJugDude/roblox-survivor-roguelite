--!strict
-- Client entry point.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

-- Placeholder until UI uses player data: log what the server sends.
Remotes.DataChanged.OnClientEvent:Connect(function(data)
	print("[Client] Data changed:", data)
end)
print("[Client] Initial data:", Remotes.GetData:InvokeServer())
