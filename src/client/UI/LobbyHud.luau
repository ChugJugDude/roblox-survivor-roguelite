--!strict
-- The lobby's HUD: the player's Shards and hero, a hint to step on the portal pad, and a Start now
-- button for whoever is on it.
-- Hidden in a match. Placeholder look; polish comes in M4.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CurrentArena = require(script.Parent.Parent.CurrentArena)
local Create = require(script.Parent.Create)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local FONT = Enum.Font.GothamBold
local PORTAL_COLOR = Color3.fromRGB(190, 120, 255)
local SHARD_COLOR = Color3.fromRGB(120, 220, 255)

local LobbyHud = {}

function LobbyHud.start()
	local player = Players.LocalPlayer
	local gui = Create("ScreenGui", {
		Name = "LobbyHud",
		ResetOnSpawn = false,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local hint = Create("TextLabel", {
		Name = "Hint",
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.new(0.5, 0, 0, 12),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		Font = FONT,
		TextSize = 22,
		TextColor3 = PORTAL_COLOR,
		TextStrokeTransparency = 0.3,
		Text = "",
		Parent = gui,
	})
	local wallet = Create("TextLabel", {
		Name = "Wallet",
		Size = UDim2.fromOffset(260, 56),
		Position = UDim2.fromOffset(16, 52),
		BackgroundTransparency = 1,
		Font = FONT,
		TextSize = 22,
		TextColor3 = SHARD_COLOR,
		TextStrokeTransparency = 0.3,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = "",
		Parent = gui,
	})
	local startButton = Create("TextButton", {
		Name = "StartNow",
		Size = UDim2.fromOffset(200, 52),
		Position = UDim2.new(0.5, 0, 1, -24),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = Color3.fromRGB(120, 70, 200),
		Font = FONT,
		TextSize = 24,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "START NOW",
		Visible = false,
		Parent = gui,
	})
	Create("UICorner", { CornerRadius = UDim.new(0, 10), Parent = startButton })
	startButton.Activated:Connect(function()
		Remotes.RequestStartParty:FireServer()
	end)

	RunService.RenderStepped:Connect(function()
		local inLobby = CurrentArena.get() == nil
		gui.Enabled = inLobby
		if not inLobby then
			return
		end
		local onPad = player:GetAttribute("OnPad") == true
		startButton.Visible = onPad
		local text = if onPad
			then "Waiting for friends to step in... or start now"
			else "Step onto the glowing portal to start a run"
		if hint.Text ~= text then
			hint.Text = text
		end
		local walletText = `SHARDS {player:GetAttribute("Shards") or 0}\nHero: {player:GetAttribute("Hero") or "-"}`
		if wallet.Text ~= walletText then
			wallet.Text = walletText
		end
	end)
end

return LobbyHud
