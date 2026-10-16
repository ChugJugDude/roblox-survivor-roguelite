--!strict
-- Opens the lobby stands' menus when the player triggers a stand's prompt (server/LobbyStands.luau
-- tags each prompt with a Menu attribute), and closes them when the player walks away or leaves
-- the lobby. One menu is open at a time.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CurrentArena = require(script.Parent.Parent.CurrentArena)
local HeroMenu = require(script.Parent.HeroMenu)
local LobbyConfig = require(ReplicatedStorage.Shared.Config.Lobby)

local LobbyMenus = {}

function LobbyMenus.start()
	local player = Players.LocalPlayer
	local menus: { [string]: ScreenGui } = {
		Heroes = HeroMenu.create().panel.gui,
	}
	local openPrompt: ProximityPrompt? = nil

	local function closeAll()
		for _, gui in menus do
			gui.Enabled = false
		end
		openPrompt = nil
	end

	ProximityPromptService.PromptTriggered:Connect(function(prompt, triggeredBy)
		local name = prompt:GetAttribute("Menu")
		local gui = if typeof(name) == "string" then menus[name] else nil
		if triggeredBy ~= player or not gui then
			return
		end
		closeAll()
		gui.Enabled = true
		openPrompt = prompt
	end)

	RunService.RenderStepped:Connect(function()
		local prompt = openPrompt
		if not prompt then
			return
		end
		local stand = prompt.Parent
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local anyOpen = false
		for _, gui in menus do
			anyOpen = anyOpen or gui.Enabled
		end
		local tooFar = not (stand and stand:IsA("BasePart") and root and root:IsA("BasePart"))
			or ((root :: BasePart).Position - (stand :: BasePart).Position).Magnitude
				> LobbyConfig.MENU_CLOSE_DISTANCE
		if not anyOpen or tooFar or CurrentArena.get() ~= nil then
			closeAll()
		end
	end)
end

return LobbyMenus
