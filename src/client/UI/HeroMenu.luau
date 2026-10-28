--!strict
-- The Hero stand's menu: a card per hero with its starting weapon (icon and name), its bonus, and
-- Select or Unlock. The server decides (server/Meta); this only sends the request and redraws from
-- the data it sends back. Opened by client/UI/LobbyMenus.luau.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Create = require(script.Parent.Create)
local MenuPanel = require(script.Parent.MenuPanel)
local PlayerDataClient = require(script.Parent.Parent.PlayerDataClient)
local Theme = require(script.Parent.Theme)
local Config = require(ReplicatedStorage.Shared.Config.Meta)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local UpgradesConfig = require(ReplicatedStorage.Shared.Config.Upgrades)

local COLORS = Theme.COLORS
local CARD_WIDTH = 170
local SELECT_COLOR = Color3.fromRGB(120, 70, 200)
local UNLOCK_COLOR = Color3.fromRGB(40, 140, 190)

export type HeroMenu = {
	panel: MenuPanel.MenuPanel,
	refresh: () -> (),
}

type Card = {
	stroke: UIStroke,
	lock: TextLabel,
	button: TextButton,
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
	local panel = MenuPanel("HeroMenu", "HEROES", Vector2.new(40 + #ids * (CARD_WIDTH + 12) - 12, 340))
	Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = panel.content,
	})

	local cards: { [string]: Card } = {}
	for index, id in ids do
		local def = Config.HEROES[id]
		local weapon = UpgradesConfig.WEAPONS[def.weapon]
		local card = Theme.panel({
			Name = id,
			LayoutOrder = index,
			Size = UDim2.new(0, CARD_WIDTH, 1, 0),
			BackgroundColor3 = COLORS.panelLight,
			BackgroundTransparency = 0,
			Parent = panel.content,
		})
		local stroke = card:FindFirstChildOfClass("UIStroke") :: UIStroke
		Theme.label({
			Name = "Icon",
			Size = UDim2.new(1, 0, 0, 48),
			Position = UDim2.fromOffset(0, 10),
			TextSize = 40,
			TextStrokeTransparency = 1,
			Text = weapon.icon,
			Parent = card,
		})
		local lock = Theme.label({
			Name = "Lock",
			Size = UDim2.fromOffset(28, 28),
			Position = UDim2.new(1, -8, 0, 8),
			AnchorPoint = Vector2.new(1, 0),
			TextSize = 20,
			TextStrokeTransparency = 1,
			Text = "🔒",
			Parent = card,
		})
		Theme.label({
			Name = "HeroName",
			Size = UDim2.new(1, 0, 0, 30),
			Position = UDim2.fromOffset(0, 62),
			Font = Theme.FONTS.heading,
			TextSize = 22,
			Text = def.name,
			Parent = card,
		})
		Theme.label({
			Name = "Weapon",
			Size = UDim2.new(1, -16, 0, 36),
			Position = UDim2.fromOffset(8, 96),
			TextSize = 14,
			TextColor3 = COLORS.weapon,
			TextWrapped = true,
			TextStrokeTransparency = 1,
			Text = `Starts with\n{weapon.name}`,
			Parent = card,
		})
		Theme.label({
			Name = "Bonus",
			Size = UDim2.new(1, -16, 0, 50),
			Position = UDim2.fromOffset(8, 138),
			Font = Theme.FONTS.light,
			TextSize = 14,
			TextColor3 = COLORS.subtext,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextStrokeTransparency = 1,
			Text = def.bonusText,
			Parent = card,
		})
		local button = Theme.button(SELECT_COLOR, {
			Name = "Action",
			Size = UDim2.new(1, -20, 0, 44),
			Position = UDim2.new(0.5, 0, 1, -10),
			AnchorPoint = Vector2.new(0.5, 1),
			TextSize = 17,
			Parent = card,
		})
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
		cards[id] = { stroke = stroke, lock = lock, button = button }
	end

	local function refresh()
		local data = PlayerDataClient.get()
		local shards = if data then data.shards else 0
		panel.shards.Text = `💎 {shards}`
		local selected = Players.LocalPlayer:GetAttribute("Hero")
		for id, card in cards do
			local def = Config.HEROES[id]
			local unlocked = def.cost == 0 or (data ~= nil and data.heroes[id] == true)
			local button = card.button
			card.lock.Visible = not unlocked
			card.stroke.Color = if selected == id then COLORS.good else COLORS.stroke
			card.stroke.Thickness = if selected == id then 3 else 1.5
			if selected == id then
				button.Text = "SELECTED"
				button.BackgroundColor3 = COLORS.good
				button.AutoButtonColor = false
			elseif unlocked then
				button.Text = "SELECT"
				button.BackgroundColor3 = SELECT_COLOR
				button.AutoButtonColor = true
			else
				local affordable = shards >= def.cost
				button.Text = `UNLOCK  💎 {def.cost}`
				button.BackgroundColor3 = if affordable then UNLOCK_COLOR else COLORS.dim
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
