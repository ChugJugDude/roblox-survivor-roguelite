--!strict
--[[
	Studio-only test hooks. Does nothing in a live server.

	Set Workspace's Dev_Command attribute from the command bar or the Studio MCP, for example
		workspace:SetAttribute("Dev_Command", "skip")
	Commands act on the match of the first player in the server (in Studio solo, that's you).

		skip        end the current phase now (in overtime: fill the portal)
		stage <n>   jump to the start of stage n
		killall     kill every enemy and crate (counts as kills)
		god         toggle invulnerability for every player
		xp <n>      add n XP to the party
		freezexp on|off   stop or restart XP gain everywhere (no level-ups or pauses; for benchmarks).
		                  Lasts across runs until turned off.
		spawn <kind>   spawn one enemy 25 studs from the first living player, e.g. "spawn GoblinGiant"
		drop <kind>    put a Chest, Meat, Bomb, or Magnet 6 studs from the first living player
		give <id> <level>   set a weapon or passive for every player, e.g. "give Fireball 3" (0 removes)
		party       start the party on the lobby's portal pad now
		down        down the first player (as if a hit would have killed them)
		lobby       send every player back to the lobby
		shards <n>  give the first player n Shards (negative takes them away)
		resetmeta   reset the first player's Shards, heroes, Altar, and stats. With Studio API access
		            on, this overwrites their real saved data.

	A client can set the attribute on its own copy of Workspace, but that never reaches the server,
	so clients can't trigger these.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Characters = require(script.Parent.Characters)
local EnemyService = require(script.Parent.EnemyService)
local Lobby = require(script.Parent.Lobby)
local Match = require(script.Parent.Match)
local Meta = require(script.Parent.Meta)
local Pickups = require(script.Parent.Pickups)
local Progression = require(script.Parent.Progression)
local Upgrades = require(script.Parent.Upgrades)

local ATTRIBUTE = "Dev_Command"

local DevCommands = {}

local function execute(command: string)
	local name, argument, extra = string.match(command, "^%s*(%S+)%s*(%S*)%s*(%S*)")

	-- Commands that don't need a match.
	if name == "god" then
		for _, player in Players:GetPlayers() do
			player:SetAttribute("Dev_God", not player:GetAttribute("Dev_God"))
		end
		print(`[Dev] {command}`)
		return
	elseif name == "freezexp" and (argument == "on" or argument == "off") then
		Progression.devSetXPFrozen(argument == "on")
		print(`[Dev] {command}`)
		return
	elseif name == "down" then
		local first = Players:GetPlayers()[1]
		if first then
			Characters.down(first)
		end
		print(`[Dev] {command}`)
		return
	elseif name == "shards" and tonumber(argument) then
		local first = Players:GetPlayers()[1]
		if first then
			Meta.devAddShards(first, tonumber(argument) :: number)
		end
		print(`[Dev] {command}`)
		return
	elseif name == "resetmeta" then
		local first = Players:GetPlayers()[1]
		if first then
			Meta.devReset(first)
		end
		print(`[Dev] {command}`)
		return
	elseif name == "party" then
		Lobby.devStartParty()
		print(`[Dev] {command}`)
		return
	elseif name == "lobby" then
		for _, player in Players:GetPlayers() do
			Lobby.returnPlayer(player)
		end
		print(`[Dev] {command}`)
		return
	elseif name == "give" and tonumber(extra) then
		for _, player in Players:GetPlayers() do
			if not Upgrades.devSet(player, argument, tonumber(extra) :: number) then
				warn(`[Dev] Unknown upgrade "{argument}"`)
				return
			end
		end
		print(`[Dev] {command}`)
		return
	end

	local first = Players:GetPlayers()[1]
	local match = first and Match.forPlayer(first)
	if not match then
		warn(`[Dev] "{command}" needs a match, and the first player isn't in one`)
		return
	end
	local target = Characters.getTargets(match.members)[1]

	if name == "skip" then
		Match.devSkip(match)
	elseif name == "stage" and tonumber(argument) then
		Match.devSetStage(match, tonumber(argument) :: number)
	elseif name == "killall" then
		for _, enemy in EnemyService.getAll(match.enemies) do
			EnemyService.damage(match.enemies, enemy, math.huge)
		end
	elseif name == "xp" and tonumber(argument) then
		Progression.addXP(match.progression, tonumber(argument) :: number)
	elseif name == "spawn" and argument ~= "" then
		if not target then
			warn("[Dev] No living player to spawn near")
			return
		end
		local ok, err = pcall(EnemyService.spawn, match.enemies, argument, target.x + 25, target.z)
		if not ok then
			warn(`[Dev] {err}`)
			return
		end
	elseif name == "drop" and table.find({ "Chest", "Meat", "Bomb", "Magnet" }, argument) then
		if not target then
			warn("[Dev] No living player to drop near")
			return
		end
		Pickups.drop(match.pickups, argument :: Pickups.Kind, target.x + 6, target.z)
	else
		warn(`[Dev] Unknown command "{command}"`)
		return
	end
	print(`[Dev] {command}`)
end

function DevCommands.start()
	if not RunService:IsStudio() then
		return
	end
	workspace:SetAttribute(ATTRIBUTE, "")
	workspace:GetAttributeChangedSignal(ATTRIBUTE):Connect(function()
		local command = workspace:GetAttribute(ATTRIBUTE)
		if typeof(command) ~= "string" or command == "" then
			return
		end
		workspace:SetAttribute(ATTRIBUTE, "")
		execute(command)
	end)
end

return DevCommands
