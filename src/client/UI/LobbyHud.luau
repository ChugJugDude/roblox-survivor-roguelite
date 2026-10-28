--!strict
-- The lobby's HUD: the player's Shards and hero in a panel at the top left, a hint to step on the
-- portal pad, and a Start now button for whoever is on it. Hidden in a match.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CurrentArena = require(script.Parent.Parent.CurrentArena)
local Theme = require(script.Parent.Theme)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local MetaConfig = require(ReplicatedStorage.Shared.Config.Meta)
local UpgradesConfig = require(ReplicatedStorage.Shared.Config.Upgrades)

local COLORS = Theme.COLORS

local LobbyHud = {}

function LobbyHud.start()
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "LobbyHud"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local hintPanel = Theme.panel({
		Name = "Hint",
		Size = UDim2.fromOffset(440, 40),
		Position = UDim2.new(0.5, 0, 0, 12),
		AnchorPoint = Vector2.new(0.5, 0),
		Parent = gui,
	})
	local hint = Theme.label({
		Size = UDim2.fromScale(1, 1),
		TextSize = 18,
		TextColor3 = COLORS.portal,
		TextStrokeTransparency = 1,
		Parent = hintPanel,
	})

	local wallet = Theme.panel({
		Name = "Wallet",
		Size = UDim2.fromOffset(200, 64),
		Position = UDim2.fromOffset(12, 12),
		Parent = gui,
	})
	local shards = Theme.label({
		Name = "Shards",
		Size = UDim2.new(1, -24, 0, 30),
		Position = UDim2.fromOffset(12, 6),
		Font = Theme.FONTS.heading,
		TextSize = 24,
		TextColor3 = COLORS.shard,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextStrokeTransparency = 1,
		Parent = wallet,
	})
	local hero = Theme.label({
		Name = "Hero",
		Size = UDim2.new(1, -24, 0, 20),
		Position = UDim2.fromOffset(12, 36),
		TextSize = 14,
		TextColor3 = COLORS.subtext,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextStrokeTransparency = 1,
		Parent = wallet,
	})

	local startButton = Theme.button(COLORS.portal, {
		Name = "StartNow",
		Size = UDim2.fromOffset(220, 56),
		Position = UDim2.new(0.5, 0, 1, -24),
		AnchorPoint = Vector2.new(0.5, 1),
		Font = Theme.FONTS.heading,
		TextSize = 24,
		Text = "START NOW",
		Visible = false,
		Parent = gui,
	})
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
		local shardsText = `💎 {player:GetAttribute("Shards") or 0}`
		if shards.Text ~= shardsText then
			shards.Text = shardsText
		end
		-- The hero's name with their starting weapon's icon.
		local heroId = player:GetAttribute("Hero")
		local def = if typeof(heroId) == "string" then MetaConfig.HEROES[heroId] else nil
		local weapon = def and UpgradesConfig.WEAPONS[def.weapon]
		local heroText = if def and weapon then `{weapon.icon} {def.name}` else "-"
		if hero.Text ~= heroText then
			hero.Text = heroText
		end
	end)
end

return LobbyHud
