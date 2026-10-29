--!strict
-- The lobby's HUD: the player's Shards and hero in a panel at the top left, a hint to step on the
-- portal pad, and, for whoever is on it, a Start now button and the world picker (the party leader,
-- the first on the pad, chooses from worlds they've unlocked; everyone else sees their choice).
-- Hidden in a match.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CurrentArena = require(script.Parent.Parent.CurrentArena)
local PlayerDataClient = require(script.Parent.Parent.PlayerDataClient)
local Theme = require(script.Parent.Theme)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local MetaConfig = require(ReplicatedStorage.Shared.Config.Meta)
local UpgradesConfig = require(ReplicatedStorage.Shared.Config.Upgrades)
local Worlds = require(ReplicatedStorage.Shared.Config.Worlds)

local COLORS = Theme.COLORS

local LobbyHud = {}

function LobbyHud.start()
	local player = Players.LocalPlayer
	local screen = Instance.new("ScreenGui")
	screen.Name = "LobbyHud"
	screen.ResetOnSpawn = false
	screen.Parent = player:WaitForChild("PlayerGui")
	-- Everything goes in a root that scales down on small screens.
	local gui = Theme.fitRoot(screen)

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

	-- The world picker, above Start now.
	local picker = Theme.panel({
		Name = "WorldPicker",
		Size = UDim2.fromOffset(340, 64),
		Position = UDim2.new(0.5, 0, 1, -92),
		AnchorPoint = Vector2.new(0.5, 1),
		Visible = false,
		Parent = gui,
	})
	local worldName = Theme.label({
		Name = "World",
		Size = UDim2.new(1, -100, 0, 28),
		Position = UDim2.fromOffset(50, 6),
		Font = Theme.FONTS.heading,
		TextSize = 20,
		TextStrokeTransparency = 1,
		Parent = picker,
	})
	local worldNote = Theme.label({
		Name = "Note",
		Size = UDim2.new(1, -100, 0, 18),
		Position = UDim2.fromOffset(50, 36),
		TextSize = 12,
		TextColor3 = COLORS.subtext,
		TextStrokeTransparency = 1,
		Parent = picker,
	})
	local previous = Theme.button(COLORS.panelLight, {
		Name = "Previous",
		Size = UDim2.fromOffset(38, 48),
		Position = UDim2.fromOffset(8, 8),
		Font = Theme.FONTS.heading,
		TextSize = 22,
		Text = "<",
		Parent = picker,
	})
	local nextButton = Theme.button(COLORS.panelLight, {
		Name = "Next",
		Size = UDim2.fromOffset(38, 48),
		Position = UDim2.new(1, -46, 0, 8),
		Font = Theme.FONTS.heading,
		TextSize = 22,
		Text = ">",
		Parent = picker,
	})
	-- Which world the arrows are showing (the leader browses locked ones too, to see what's next).
	local browsing = 1
	local function hasWorld(id: string): boolean
		local data = PlayerDataClient.get()
		return id == Worlds.DEFAULT or (data ~= nil and data.worlds ~= nil and data.worlds[id] == true)
	end
	local function step(delta: number)
		browsing = (browsing - 1 + delta) % #Worlds.LIST + 1
		local world = Worlds.LIST[browsing]
		if hasWorld(world.id) then
			Remotes.SelectWorld:FireServer(world.id)
		end
	end
	previous.Activated:Connect(function()
		step(-1)
	end)
	nextButton.Activated:Connect(function()
		step(1)
	end)

	RunService.RenderStepped:Connect(function()
		local inLobby = CurrentArena.get() == nil
		screen.Enabled = inLobby
		if not inLobby then
			return
		end
		local onPad = player:GetAttribute("OnPad") == true
		startButton.Visible = onPad
		picker.Visible = onPad
		if onPad then
			local lobbyModel = workspace:FindFirstChild("Lobby")
			local leading = lobbyModel ~= nil and lobbyModel:GetAttribute("PadLeader") == player.UserId
			local chosen = Worlds.get(if lobbyModel then lobbyModel:GetAttribute("PadWorld") :: string? else nil)
			previous.Visible = leading
			nextButton.Visible = leading
			local shown = if leading then Worlds.LIST[browsing] else chosen
			local locked = leading and not hasWorld(shown.id)
			local bonus = if shown.shardMultiplier > 1 then `  ·  x{shown.shardMultiplier} Shards` else ""
			worldName.Text = if locked then `🔒 {shown.name}` else shown.name
			worldName.TextColor3 = if locked then COLORS.dim else COLORS.text
			if locked then
				local before = Worlds.LIST[math.max(1, browsing - 1)]
				worldNote.Text = `Beat {before.name} to unlock`
			elseif leading then
				worldNote.Text = `You choose the world{bonus}`
			else
				worldNote.Text = `The party leader chose this world{bonus}`
			end
		end
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
