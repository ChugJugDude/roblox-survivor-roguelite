--!strict
-- The Codex stand's menu: the collection log. Tabs for weapons (and evolutions), passives, and
-- enemies, each a grid of tiles that stay a dark "?" until the player discovers them (saved data's
-- `collection`, see shared/Codex.luau and server/Meta.discover). Tapping or hovering a found tile
-- shows what it is. Opened by client/UI/LobbyMenus.luau.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Create = require(script.Parent.Create)
local MenuPanel = require(script.Parent.MenuPanel)
local PlayerDataClient = require(script.Parent.Parent.PlayerDataClient)
local Theme = require(script.Parent.Theme)
local Codex = require(ReplicatedStorage.Shared.Codex)

local COLORS = Theme.COLORS
local TILE = Vector2.new(84, 92)
local TAB_HEIGHT = 34
local DETAIL_HEIGHT = 74

export type CodexMenu = {
	panel: MenuPanel.MenuPanel,
	refresh: () -> (),
}

type Tile = {
	entry: Codex.Entry,
	button: TextButton,
	stroke: UIStroke,
	icon: TextLabel,
	name: TextLabel,
}

local CodexMenu = {}

function CodexMenu.create(): CodexMenu
	local panel = MenuPanel("CodexMenu", "CODEX", Vector2.new(620, 470))
	local content = panel.content

	-- Tabs across the top.
	local tabRow = Create("Frame", {
		Name = "Tabs",
		Size = UDim2.new(1, 0, 0, TAB_HEIGHT),
		BackgroundTransparency = 1,
		Parent = content,
	})
	Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = tabRow,
	})

	local grid = Create("ScrollingFrame", {
		Name = "Grid",
		Size = UDim2.new(1, 0, 1, -(TAB_HEIGHT + DETAIL_HEIGHT + 20)),
		Position = UDim2.fromOffset(0, TAB_HEIGHT + 10),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = COLORS.stroke,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = content,
	})
	-- Room for the tiles' outlines, which the scrolling frame would clip.
	Create("UIPadding", {
		PaddingTop = UDim.new(0, 3),
		PaddingLeft = UDim.new(0, 3),
		Parent = grid,
	})
	Create("UIGridLayout", {
		CellSize = UDim2.fromOffset(TILE.X, TILE.Y),
		CellPadding = UDim2.fromOffset(8, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = grid,
	})

	local detail = Theme.panel({
		Name = "Detail",
		Size = UDim2.new(1, 0, 0, DETAIL_HEIGHT),
		Position = UDim2.new(0, 0, 1, -DETAIL_HEIGHT),
		BackgroundColor3 = COLORS.panelLight,
		BackgroundTransparency = 0,
		Parent = content,
	})
	local detailName = Theme.label({
		Size = UDim2.new(1, -20, 0, 24),
		Position = UDim2.fromOffset(10, 6),
		Font = Theme.FONTS.heading,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextStrokeTransparency = 1,
		Text = "Collection",
		Parent = detail,
	})
	local detailText = Theme.label({
		Size = UDim2.new(1, -20, 1, -34),
		Position = UDim2.fromOffset(10, 30),
		Font = Theme.FONTS.light,
		TextSize = 13,
		TextColor3 = COLORS.subtext,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextStrokeTransparency = 1,
		Text = "Everything you find in runs is recorded here. Tap a page to read it.",
		Parent = detail,
	})

	local function isFound(key: string): boolean
		local data = PlayerDataClient.get()
		return data ~= nil and data.collection ~= nil and data.collection[key] == true
	end

	-- One tile per entry; tabs just show and hide them.
	local tiles: { Tile } = {}
	for index, entry in Codex.ENTRIES do
		local button = Create("TextButton", {
			Name = entry.key,
			LayoutOrder = index,
			BackgroundColor3 = COLORS.panelLight,
			AutoButtonColor = true,
			Text = "",
			Parent = grid,
		})
		Create("UICorner", { CornerRadius = UDim.new(0, 8), Parent = button })
		local stroke = Create("UIStroke", {
			Thickness = 1.5,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Parent = button,
		})
		local icon = Theme.label({
			Size = UDim2.new(1, 0, 0, 52),
			Position = UDim2.fromOffset(0, 6),
			TextSize = 34,
			TextStrokeTransparency = 1,
			Parent = button,
		})
		local name = Theme.label({
			Size = UDim2.new(1, -6, 0, 28),
			Position = UDim2.fromOffset(3, 60),
			TextSize = 11,
			TextWrapped = true,
			TextStrokeTransparency = 1,
			Parent = button,
		})
		local tile: Tile = { entry = entry, button = button, stroke = stroke, icon = icon, name = name }
		local function show()
			if isFound(entry.key) then
				detailName.Text = `{entry.icon} {entry.name}`
				detailText.Text = entry.description
			else
				detailName.Text = "???"
				detailText.Text = "Not discovered yet. Keep playing to find it."
			end
		end
		button.Activated:Connect(show)
		button.MouseEnter:Connect(show)
		button.SelectionGained:Connect(show)
		table.insert(tiles, tile)
	end

	local tabButtons: { [string]: TextButton } = {}
	local currentTab: Codex.Tab = "Weapons"
	local function refresh()
		local data = PlayerDataClient.get()
		panel.shards.Text = `💎 {if data then data.shards else 0}`
		local found: { [string]: number } = {}
		local total: { [string]: number } = {}
		for _, tile in tiles do
			local entry = tile.entry
			local discovered = isFound(entry.key)
			total[entry.tab] = (total[entry.tab] or 0) + 1
			if discovered then
				found[entry.tab] = (found[entry.tab] or 0) + 1
			end
			tile.button.Visible = entry.tab == currentTab
			tile.icon.Text = if discovered then entry.icon else "?"
			tile.icon.TextColor3 = if discovered then COLORS.text else COLORS.dim
			tile.name.Text = if discovered then entry.name else "???"
			tile.name.TextColor3 = if discovered then COLORS.text else COLORS.dim
			tile.button.BackgroundColor3 = if discovered then COLORS.panelLight else COLORS.panel
			tile.stroke.Color = if discovered and entry.golden then COLORS.evolution else COLORS.stroke
			tile.stroke.Thickness = if discovered and entry.golden then 2.5 else 1.5
		end
		for tab, button in tabButtons do
			button.Text = `{string.upper(tab)}  {found[tab] or 0}/{total[tab] or 0}`
			button.BackgroundColor3 = if tab == currentTab then COLORS.passive else COLORS.panelLight
		end
	end

	for index, tab in Codex.TABS do
		local button = Theme.button(COLORS.panelLight, {
			Name = tab,
			Size = UDim2.fromOffset(176, TAB_HEIGHT),
			LayoutOrder = index,
			TextSize = 14,
			Parent = tabRow,
		})
		button.Activated:Connect(function()
			currentTab = tab
			refresh()
		end)
		tabButtons[tab] = button
	end

	PlayerDataClient.onChanged(refresh)
	refresh()
	return { panel = panel, refresh = refresh }
end

return CodexMenu
