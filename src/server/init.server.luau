--!strict
-- Server entry point. Start services here, in dependency order.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Arena = require(script.Arena)
local Characters = require(script.Characters)
local DevCommands = require(script.DevCommands)
local Match = require(script.Match)
local PlayerData = require(script.PlayerData)
local Simulation = require(script.Simulation)
local Upgrades = require(script.Upgrades)
local WeaponService = require(script.Weapons.WeaponService)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

PlayerData.start()
Characters.start()
Upgrades.start()
WeaponService.start()
DevCommands.start()
Simulation.start()

-- Until the lobby exists (M2 step 2): everyone shares one match, which starts as soon as someone
-- joins and restarts from the results screen.
local RESTART_COOLDOWN = 1
local lastRestartRequest: { [Player]: number } = {}

local function sharedMatch(): Match.Match
	return Match.all()[1] or Match.create(0)
end

local function onPlayerAdded(player: Player)
	local match = sharedMatch()
	local fresh = #match.members == 0
	Match.addMember(match, player)
	if fresh then
		Match.startRun(match)
	elseif not Match.hasEnded(match) then
		Characters.spawn(player, Arena.spawnCFrame(match.arena))
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	lastRestartRequest[player] = nil
	local match = Match.forPlayer(player)
	if match then
		Match.removeMember(match, player)
		if #match.members == 0 then
			Match.destroy(match)
		end
	end
end)

Remotes.RequestRestart.OnServerEvent:Connect(function(player)
	local clock = os.clock()
	local last = lastRestartRequest[player]
	if last and clock - last < RESTART_COOLDOWN then
		return
	end
	lastRestartRequest[player] = clock
	local match = Match.forPlayer(player)
	if match and Match.hasEnded(match) then
		Match.startRun(match)
	end
end)
