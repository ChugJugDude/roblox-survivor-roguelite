--!strict
-- The Altar's menu: a row per permanent upgrade with its level (as pips), what each level gives, and
-- a Buy button with the next level's cost. The server decides (server/Meta); this only sends the
-- request and redraws from the data it sends back. Opened by client/UI/LobbyMenus.luau.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Create = require(script.Parent.Create)
local MenuPanel = require(script.Parent.MenuPanel)
local PlayerDataClient = require(script.Parent.Parent.PlayerDataClient)
local Theme = require(script.Parent.Theme)
local Config = require(ReplicatedStorage.Shared.Config.Meta)
local MetaStats = require(ReplicatedStorage.Shared.MetaStats)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local COLORS = Theme.COLORS
local ROW_HEIGHT = 60
local PIP_SIZE = 10
local BUY_COLOR = Color3.fromRGB(40, 140, 190)

export type AltarMenu = {
	panel: MenuPanel.MenuPanel,
	refresh: () -> (),
}

type Row = {
	pips: { Frame },
	button: TextButton,
}

local AltarMenu = {}

local function sortedIds(): { string }
	local ids: { string } = {}
	for id in Config.ALTAR do
		table.insert(ids, id)
	end
	table.sort(ids, function(a, b)
		return Config.ALTAR[a].order < Config.ALTAR[b].order
	end)
	return ids
end

function AltarMenu.create(): AltarMenu
	local ids = sortedIds()
	local panel = MenuPanel("AltarMenu", "ALTAR", Vector2.new(540, 420))
	local list = Create("ScrollingFrame", {
		Name = "List",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = COLORS.stroke,
		CanvasSize = UDim2.fromOffset(0, #ids * (ROW_HEIGHT + 6)),
		Parent = panel.content,
	})
	Create("UIListLayout", {
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = list,
	})

	local rows: { [string]: Row } = {}
	for index, id in ids do
		local def = Config.ALTAR[id]
		local row = Theme.panel({
			Name = id,
			LayoutOrder = index,
			Size = UDim2.new(1, -12, 0, ROW_HEIGHT),
			BackgroundColor3 = COLORS.panelLight,
			BackgroundTransparency = 0,
			Parent = list,
		})
		Theme.label({
			Name = "UpgradeName",
			Size = UDim2.new(1, -150, 0, 24),
			Position = UDim2.fromOffset(12, 6),
			Font = Theme.FONTS.heading,
			TextSize = 18,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextStrokeTransparency = 1,
			Text = def.name,
			Parent = row,
		})
		Theme.label({
			Name = "Description",
			Size = UDim2.new(1, -150, 0, 18),
			Position = UDim2.fromOffset(12, 32),
			Font = Theme.FONTS.light,
			TextSize = 13,
			TextColor3 = COLORS.subtext,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextStrokeTransparency = 1,
			Text = `{def.description} per level`,
			Parent = row,
		})
		-- One pip per level, lit for levels owned.
		local pipRow = Create("Frame", {
			Name = "Pips",
			Size = UDim2.fromOffset(def.maxLevel * (PIP_SIZE + 4), PIP_SIZE),
			Position = UDim2.new(1, -140, 0, 13),
			AnchorPoint = Vector2.new(1, 0),
			BackgroundTransparency = 1,
			Parent = row,
		})
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = pipRow,
		})
		local pips = {}
		for level = 1, def.maxLevel do
			local pip = Create("Frame", {
				Size = UDim2.fromOffset(PIP_SIZE, PIP_SIZE),
				LayoutOrder = level,
				BorderSizePixel = 0,
				Parent = pipRow,
			})
			Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = pip })
			table.insert(pips, pip)
		end
		local button = Theme.button(BUY_COLOR, {
			Name = "Buy",
			Size = UDim2.fromOffset(120, 40),
			Position = UDim2.new(1, -10, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5),
			TextSize = 16,
			Parent = row,
		})
		button.Activated:Connect(function()
			Remotes.BuyAltarUpgrade:FireServer(id)
		end)
		rows[id] = { pips = pips, button = button }
	end

	local function refresh()
		local data = PlayerDataClient.get()
		local shards = if data then data.shards else 0
		panel.shards.Text = `💎 {shards}`
		for id, row in rows do
			local def = Config.ALTAR[id]
			local owned = if data then data.altar[id] or 0 else 0
			for level, pip in row.pips do
				pip.BackgroundColor3 = if level <= owned then COLORS.shard else COLORS.dim
			end
			if owned >= def.maxLevel then
				row.button.Text = "MAX"
				row.button.BackgroundColor3 = COLORS.good
				row.button.AutoButtonColor = false
			else
				local cost = MetaStats.altarCost(id, owned + 1)
				local affordable = shards >= cost
				row.button.Text = `💎 {cost}`
				row.button.BackgroundColor3 = if affordable then BUY_COLOR else COLORS.dim
				row.button.AutoButtonColor = affordable
			end
		end
	end

	PlayerDataClient.onChanged(refresh)
	refresh()
	return { panel = panel, refresh = refresh }
end

return AltarMenu
