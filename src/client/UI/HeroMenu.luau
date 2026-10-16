--!strict
-- The Hero stand's menu: a card per hero with its starting weapon and bonus, and Select or Unlock.
-- The server decides (server/Meta); this only sends the request and redraws from the data it sends
-- back. Opened by client/UI/LobbyMenus.luau.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Create = require(script.Parent.Create)
local MenuPanel = require(script.Parent.MenuPanel)
local PlayerDataClient = require(script.Parent.Parent.PlayerDataClient)
local Config = require(ReplicatedStorage.Shared.Config.Meta)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local UpgradesConfig = require(ReplicatedStorage.Shared.Config.Upgrades)

local FONT = Enum.Font.GothamBold
local CARD_WIDTH = 170
local SELECTED_COLOR = Color3.fromRGB(70, 120, 80)
local SELECT_COLOR = Color3.fromRGB(120, 70, 200)
local UNLOCK_COLOR = Color3.fromRGB(40, 140, 190)
local DISABLED_COLOR = Color3.fromRGB(75, 75, 85)

export type HeroMenu = {
	panel: MenuPanel.MenuPanel,
	refresh: () -> (),
}

local HeroMenu = {}

local function sortedIds(): { string }
	local ids: { string } = {}
	for id in Config.HEROES do
		table.insert(ids, id)
	end
	table.sort(ids, function(a, b)
		return Config.HEROES[a].order < Config.HEROES[b].order
	end)
	return ids
end

function HeroMenu.create(): HeroMenu
	local ids = sortedIds()
	local panel = MenuPanel("HeroMenu", "HEROES", Vector2.new(40 + #ids * (CARD_WIDTH + 12) - 12, 320))
	Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = panel.content,
	})

	local buttons: { [string]: TextButton } = {}
	for index, id in ids do
		local def = Config.HEROES[id]
		local card = Create("Frame", {
			Name = id,
			LayoutOrder = index,
			Size = UDim2.new(0, CARD_WIDTH, 1, 0),
			BackgroundColor3 = Color3.fromRGB(55, 50, 70),
			BorderSizePixel = 0,
			Parent = panel.content,
		})
		Create("UICorner", { CornerRadius = UDim.new(0, 10), Parent = card })
		Create("TextLabel", {
			Name = "HeroName",
			Size = UDim2.new(1, 0, 0, 34),
			Position = UDim2.fromOffset(0, 10),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBlack,
			TextSize = 22,
			TextColor3 = Color3.new(1, 1, 1),
			Text = def.name,
			Parent = card,
		})
		Create("TextLabel", {
			Name = "Details",
			Size = UDim2.new(1, -16, 0, 100),
			Position = UDim2.fromOffset(8, 50),
			BackgroundTransparency = 1,
			Font = FONT,
			TextSize = 16,
			TextColor3 = Color3.fromRGB(210, 210, 225),
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			LineHeight = 1.15,
			Text = `Starts with\n{UpgradesConfig.WEAPONS[def.weapon].name}\n\n{def.bonusText}`,
			Parent = card,
		})
		local button = Create("TextButton", {
			Name = "Action",
			Size = UDim2.new(1, -20, 0, 44),
			Position = UDim2.new(0.5, 0, 1, -10),
			AnchorPoint = Vector2.new(0.5, 1),
			Font = FONT,
			TextSize = 18,
			TextColor3 = Color3.new(1, 1, 1),
			Parent = card,
		})
		Create("UICorner", { CornerRadius = UDim.new(0, 8), Parent = button })
		button.Activated:Connect(function()
			local data = PlayerDataClient.get()
			if not data then
				return
			end
			if def.cost == 0 or data.heroes[id] then
				Remotes.SelectHero:FireServer(id)
			else
				Remotes.UnlockHero:FireServer(id)
			end
		end)
		buttons[id] = button
	end

	local function refresh()
		local data = PlayerDataClient.get()
		local shards = if data then data.shards else 0
		panel.shards.Text = `SHARDS {shards}`
		local selected = Players.LocalPlayer:GetAttribute("Hero")
		for id, button in buttons do
			local def = Config.HEROES[id]
			local unlocked = def.cost == 0 or (data ~= nil and data.heroes[id] == true)
			if selected == id then
				button.Text = "SELECTED"
				button.BackgroundColor3 = SELECTED_COLOR
				button.AutoButtonColor = false
			elseif unlocked then
				button.Text = "SELECT"
				button.BackgroundColor3 = SELECT_COLOR
				button.AutoButtonColor = true
			else
				local affordable = shards >= def.cost
				button.Text = `UNLOCK  {def.cost}`
				button.BackgroundColor3 = if affordable then UNLOCK_COLOR else DISABLED_COLOR
				button.AutoButtonColor = affordable
			end
		end
	end

	PlayerDataClient.onChanged(refresh)
	Players.LocalPlayer:GetAttributeChangedSignal("Hero"):Connect(refresh)
	refresh()
	return { panel = panel, refresh = refresh }
end

return HeroMenu
