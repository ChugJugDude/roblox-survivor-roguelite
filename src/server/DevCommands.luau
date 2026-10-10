--!strict
--[[
	Studio-only test hooks. Does nothing in a live server.

	Set the Arena's Dev_Command attribute from the command bar or the Studio MCP, for example
		workspace.Arena:SetAttribute("Dev_Command", "skip")

		skip        end the current phase now (in overtime: fill the portal)
		stage <n>   jump to the start of stage n
		killall     kill every enemy (counts as kills)
		god         toggle invulnerability for every player

	Only the server can set attributes on server-owned instances, so clients can't trigger these.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Arena = require(script.Parent.Arena)
local EnemyService = require(script.Parent.EnemyService)
local Run = require(script.Parent.Run)

local ATTRIBUTE = "Dev_Command"

local DevCommands = {}

local function execute(command: string)
	local now = workspace:GetServerTimeNow()
	local name, argument = string.match(command, "^%s*(%S+)%s*(%S*)")
	if name == "skip" then
		Run.devSkip(now)
	elseif name == "stage" and tonumber(argument) then
		Run.devSetStage(tonumber(argument) :: number, now)
	elseif name == "killall" then
		for _, enemy in EnemyService.getAll() do
			EnemyService.damage(enemy, math.huge)
		end
	elseif name == "god" then
		for _, player in Players:GetPlayers() do
			player:SetAttribute("Dev_God", not player:GetAttribute("Dev_God"))
		end
	else
		warn(`[Dev] Unknown command "{command}"`)
		return
	end
	print(`[Dev] {command}`)
end

function DevCommands.start(arena: Arena.Arena)
	if not RunService:IsStudio() then
		return
	end
	local model = arena.model
	model:SetAttribute(ATTRIBUTE, "")
	model:GetAttributeChangedSignal(ATTRIBUTE):Connect(function()
		local command = model:GetAttribute(ATTRIBUTE)
		if typeof(command) ~= "string" or command == "" then
			return
		end
		model:SetAttribute(ATTRIBUTE, "")
		execute(command)
	end)
end

return DevCommands
