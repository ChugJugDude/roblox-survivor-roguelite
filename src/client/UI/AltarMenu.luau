--!strict
-- The Altar's menu: a row per permanent upgrade with its level, what each level gives, and a Buy
-- button with the next level's cost. The server decides (server/Meta); this only sends the request
-- and redraws from the data it sends back. Opened by client/UI/LobbyMenus.luau.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Create = require(script.Parent.Create)
local MenuPanel = require(script.Parent.MenuPanel)
local PlayerDataClient = require(script.Parent.Parent.PlayerDataClient)
local Config = require(ReplicatedStorage.Shared.Config.Meta)
local MetaStats = require(ReplicatedStorage.Shared.MetaStats)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local FONT = Enum.Font.GothamBold
local ROW_HEIGHT = 58
local BUY_COLOR = Color3.fromRGB(40, 140, 190)
local MAX_COLOR = Color3.fromRGB(70, 120, 80)
local DISABLED_COLOR = Color3.fromRGB(75, 75, 85)
local LEVEL_COLOR = Color3.fromRGB(120, 220, 255)

export type AltarMenu = {
	panel: MenuPanel.MenuPanel,
	refresh: () -> (),
}

type Row = {
	level: TextLabel,
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
	local panel = MenuPanel("AltarMenu", "ALTAR", Vector2.new(520, 380))
	local list = Create("ScrollingFrame", {
		Name = "List",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
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
		local row = Create("Frame", {
			Name = id,
			LayoutOrder = index,
			Size = UDim2.new(1, -12, 0, ROW_HEIGHT),
			BackgroundColor3 = Color3.fromRGB(55, 50, 70),
			BorderSizePixel = 0,
			Parent = list,
		})
		Create("UICorner", { CornerRadius = UDim.new(0, 8), Parent = row })
		Create("TextLabel", {
			Name = "UpgradeName",
			Size = UDim2.new(1, -150, 0, 26),
			Position = UDim2.fromOffset(12, 5),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBlack,
			TextSize = 19,
			TextColor3 = Color3.new(1, 1, 1),
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = def.name,
			Parent = row,
		})
		local level = Create("TextLabel", {
			Name = "Level",
			Size = UDim2.fromOffset(80, 26),
			Position = UDim2.new(1, -230, 0, 5),
			BackgroundTransparency = 1,
			Font = FONT,
			TextSize = 16,
			TextColor3 = LEVEL_COLOR,
			TextXAlignment = Enum.TextXAlignment.Right,
			Parent = row,
		})
		Create("TextLabel", {
			Name = "Description",
			Size = UDim2.new(1, -150, 0, 20),
			Position = UDim2.fromOffset(12, 31),
			BackgroundTransparency = 1,
			Font = FONT,
			TextSize = 14,
			TextColor3 = Color3.fromRGB(200, 200, 215),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Text = `{def.description} per level`,
			Parent = row,
		})
		local button = Create("TextButton", {
			Name = "Buy",
			Size = UDim2.fromOffset(120, 40),
			Position = UDim2.new(1, -10, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5),
			Font = FONT,
			TextSize = 17,
			TextColor3 = Color3.new(1, 1, 1),
			Parent = row,
		})
		Create("UICorner", { CornerRadius = UDim.new(0, 8), Parent = button })
		button.Activated:Connect(function()
			Remotes.BuyAltarUpgrade:FireServer(id)
		end)
		rows[id] = { level = level, button = button }
	end

	local function refresh()
		local data = PlayerDataClient.get()
		local shards = if data then data.shards else 0
		panel.shards.Text = `SHARDS {shards}`
		for id, row in rows do
			local def = Config.ALTAR[id]
			local owned = if data then data.altar[id] or 0 else 0
			row.level.Text = `Lv {owned}/{def.maxLevel}`
			if owned >= def.maxLevel then
				row.button.Text = "MAX"
				row.button.BackgroundColor3 = MAX_COLOR
				row.button.AutoButtonColor = false
			else
				local cost = MetaStats.altarCost(id, owned + 1)
				local affordable = shards >= cost
				row.button.Text = `BUY  {cost}`
				row.button.BackgroundColor3 = if affordable then BUY_COLOR else DISABLED_COLOR
				row.button.AutoButtonColor = affordable
			end
		end
	end

	PlayerDataClient.onChanged(refresh)
	refresh()
	return { panel = panel, refresh = refresh }
end

return AltarMenu
