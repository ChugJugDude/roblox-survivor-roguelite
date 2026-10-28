--!strict
-- The level-up choice: up to three cards along the bottom of the screen (so the player stays in
-- view). Tap or click a card, press 1-3, or use a gamepad. The server sends the options
-- (Remotes.UpgradeOffered) and only takes back an index. Each card shows the upgrade's icon, a
-- header band in its kind's color, and level pips (the new level lit brighter).

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local CurrentArena = require(script.Parent.Parent.CurrentArena)
local Create = require(script.Parent.Create)
local Theme = require(script.Parent.Theme)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local UpgradesConfig = require(ReplicatedStorage.Shared.Config.Upgrades)

local COLORS = Theme.COLORS
local CARD_SIZE = Vector2.new(160, 200)
local CARD_GAP = 10
local MAX_CARDS = 3
local HEADER_HEIGHT = 24
local PIP_SIZE = 9
-- Below this screen height, everything shrinks to fit (phones in landscape).
local FULL_SIZE_HEIGHT = 600
-- Cards pop in one after another.
local POP_TIME = 0.18
local POP_STAGGER = 0.05

local KIND_STYLE = {
	weapon = { color = COLORS.weapon, tag = "WEAPON" },
	passive = { color = COLORS.passive, tag = "PASSIVE" },
	evolution = { color = COLORS.evolution, tag = "EVOLUTION" },
	heal = { color = COLORS.heal, tag = "HEAL" },
}

local NUMBER_KEYS: { [Enum.KeyCode]: number } = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.KeypadOne] = 1,
	[Enum.KeyCode.KeypadTwo] = 2,
	[Enum.KeyCode.KeypadThree] = 3,
}

type Card = {
	button: TextButton,
	scale: UIScale,
	stroke: UIStroke,
	header: Frame,
	tag: TextLabel,
	icon: TextLabel,
	name: TextLabel,
	pipRow: Frame,
	pips: { Frame },
	level: TextLabel,
	description: TextLabel,
	hint: TextLabel,
}

local UpgradePicker = {}

local function text(parent: Instance, name: string, size: UDim2, position: UDim2, textSize: number): TextLabel
	return Theme.label({
		Name = name,
		Size = size,
		Position = position,
		TextSize = textSize,
		TextWrapped = true,
		TextStrokeTransparency = 1,
		Parent = parent,
	})
end

local function createCard(parent: Instance, index: number): Card
	local button = Create("TextButton", {
		Name = `Card{index}`,
		Size = UDim2.fromOffset(CARD_SIZE.X, CARD_SIZE.Y),
		LayoutOrder = index,
		BackgroundColor3 = COLORS.panelLight,
		AutoButtonColor = true,
		Text = "",
		ClipsDescendants = true,
		Parent = parent,
	})
	Create("UICorner", { CornerRadius = UDim.new(0, Theme.CORNER), Parent = button })
	local stroke = Create("UIStroke", { Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = button })
	local scale = Create("UIScale", { Parent = button })
	-- A gradient multiplies the background, so this darkens it toward the bottom.
	Create("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(150, 150, 150)),
		Parent = button,
	})

	local header = Create("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, HEADER_HEIGHT),
		BorderSizePixel = 0,
		Parent = button,
	})
	local tag = text(header, "Tag", UDim2.fromScale(1, 1), UDim2.new(), 13)
	tag.Font = Theme.FONTS.heading
	tag.TextColor3 = COLORS.panel

	local icon = text(button, "Icon", UDim2.new(1, 0, 0, 40), UDim2.fromOffset(0, HEADER_HEIGHT + 4), 32)
	local name = text(button, "UpgradeName", UDim2.new(1, -12, 0, 40), UDim2.fromOffset(6, 70), 18)
	name.Font = Theme.FONTS.heading

	local pipRow = Create("Frame", {
		Name = "Pips",
		Size = UDim2.new(1, 0, 0, PIP_SIZE),
		Position = UDim2.fromOffset(0, 112),
		BackgroundTransparency = 1,
		Parent = button,
	})
	Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = pipRow,
	})
	local pips = {}
	for pipIndex = 1, UpgradesConfig.MAX_LEVEL do
		local pip = Create("Frame", {
			Size = UDim2.fromOffset(PIP_SIZE, PIP_SIZE),
			LayoutOrder = pipIndex,
			BorderSizePixel = 0,
			Parent = pipRow,
		})
		Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = pip })
		table.insert(pips, pip)
	end
	-- Shown instead of pips for evolutions and heals.
	local level = text(button, "LevelText", UDim2.new(1, 0, 0, 14), UDim2.fromOffset(0, 109), 13)
	level.Font = Theme.FONTS.heading

	local description = text(button, "Description", UDim2.new(1, -16, 0, 44), UDim2.fromOffset(8, 126), 13)
	description.Font = Theme.FONTS.light
	description.TextColor3 = COLORS.subtext
	local hint = text(button, "Hint", UDim2.new(1, -12, 0, 16), UDim2.fromOffset(6, 170), 12)
	hint.TextColor3 = COLORS.evolution
	local key = text(button, "Key", UDim2.new(1, 0, 0, 14), UDim2.new(0, 0, 1, -16), 11)
	key.TextColor3 = COLORS.dim
	key.Text = `[{index}]`

	return {
		button = button,
		scale = scale,
		stroke = stroke,
		header = header,
		tag = tag,
		icon = icon,
		name = name,
		pipRow = pipRow,
		pips = pips,
		level = level,
		description = description,
		hint = hint,
	}
end

local function fillCard(card: Card, option: any)
	local style = KIND_STYLE[option.kind] or KIND_STYLE.passive
	card.stroke.Color = style.color
	card.header.BackgroundColor3 = style.color
	card.tag.Text = if option.isNew then `NEW {style.tag}` else style.tag
	card.icon.Text = Theme.upgradeIcon(UpgradesConfig, tostring(option.id))
	card.name.Text = option.name
	card.description.Text = option.description
	card.hint.Text = if typeof(option.hint) == "string" then option.hint else ""

	-- Pips for weapon and passive levels: owned levels dim, the new level bright.
	local level = tonumber(option.level) or 0
	local showPips = option.kind == "weapon" or option.kind == "passive"
	card.pipRow.Visible = showPips
	card.level.Visible = not showPips
	card.level.Text = if option.kind == "evolution" then "EVOLVE" else ""
	card.level.TextColor3 = style.color
	for index, pip in card.pips do
		pip.BackgroundColor3 = if index == level
			then style.color
			elseif index < level then style.color:Lerp(COLORS.panel, 0.55)
			else COLORS.dim
		pip.Size = if index == level
			then UDim2.fromOffset(PIP_SIZE + 3, PIP_SIZE + 3)
			else UDim2.fromOffset(PIP_SIZE, PIP_SIZE)
	end
end

function UpgradePicker.start()
	local gui = Create("ScreenGui", {
		Name = "UpgradePicker",
		ResetOnSpawn = false,
		DisplayOrder = 5,
		Enabled = false,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
	local width = CARD_SIZE.X * MAX_CARDS + CARD_GAP * (MAX_CARDS - 1)
	local container = Create("Frame", {
		Name = "Container",
		Size = UDim2.fromOffset(width, CARD_SIZE.Y + 80),
		Position = UDim2.new(0.5, 0, 1, -12),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	local scale = Create("UIScale", { Parent = container })

	local title = Theme.label({
		Name = "Title",
		Size = UDim2.new(1, 0, 0, 32),
		Font = Theme.FONTS.heading,
		TextSize = 28,
		TextColor3 = COLORS.evolution,
		TextStrokeTransparency = 0.2,
		Parent = container,
	})
	local more = Theme.label({
		Name = "More",
		Size = UDim2.fromOffset(100, 32),
		Position = UDim2.new(1, -100, 0, 0),
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextStrokeTransparency = 0.3,
		Parent = container,
	})

	local row = Create("Frame", {
		Name = "Cards",
		Size = UDim2.new(1, 0, 0, CARD_SIZE.Y),
		Position = UDim2.fromOffset(0, 36),
		BackgroundTransparency = 1,
		Parent = container,
	})
	Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, CARD_GAP),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = row,
	})
	local cards: { Card } = {}
	for index = 1, MAX_CARDS do
		cards[index] = createCard(row, index)
	end

	local reroll = Theme.button(COLORS.panelLight, {
		Name = "Reroll",
		Size = UDim2.fromOffset(150, 32),
		Position = UDim2.fromScale(0.5, 1),
		AnchorPoint = Vector2.new(0.5, 1),
		Parent = container,
	})

	-- After sending a choice, ignore input until the server answers with the next offer (or nil).
	local optionCount = 0
	local waiting = false

	local function choose(index: number)
		if gui.Enabled and not waiting and index >= 1 and index <= optionCount then
			waiting = true
			Remotes.ChooseUpgrade:FireServer(index)
		end
	end

	for index, card in cards do
		card.button.Activated:Connect(function()
			choose(index)
		end)
	end
	reroll.Activated:Connect(function()
		if gui.Enabled and not waiting then
			waiting = true
			Remotes.RerollUpgrade:FireServer()
		end
	end)
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		local index = NUMBER_KEYS[input.KeyCode]
		if index and not gameProcessed then
			choose(index)
		end
	end)

	local function updateScale()
		local camera = workspace.CurrentCamera
		if camera then
			scale.Scale = math.min(1, camera.ViewportSize.Y / FULL_SIZE_HEIGHT)
		end
	end
	updateScale()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	end

	Remotes.UpgradeOffered.OnClientEvent:Connect(function(offer: any)
		waiting = false
		if typeof(offer) ~= "table" or typeof(offer.options) ~= "table" then
			gui.Enabled = false
			optionCount = 0
			if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(gui) then
				GuiService.SelectedObject = nil
			end
			return
		end

		-- Head Start picks come during the countdown, before any level-up; chest picks say so.
		local arena = CurrentArena.get()
		title.Text = if arena and arena:GetAttribute("Phase") == "Countdown"
			then "HEAD START"
			elseif offer.chest == true then "TREASURE!"
			else "LEVEL UP!"

		optionCount = math.min(#offer.options, MAX_CARDS)
		for index, card in cards do
			local option = offer.options[index]
			card.button.Visible = option ~= nil
			if option then
				fillCard(card, option)
			end
		end

		local pending = tonumber(offer.pending) or 1
		more.Text = if pending > 1 then `+{pending - 1} more` else ""
		local rerolls = tonumber(offer.rerolls) or 0
		reroll.Visible = rerolls > 0
		reroll.Text = `REROLL ({rerolls})`

		local wasOpen = gui.Enabled
		gui.Enabled = true
		if not wasOpen then
			for index, card in cards do
				card.scale.Scale = 0.6
				TweenService:Create(
					card.scale,
					TweenInfo.new(
						POP_TIME,
						Enum.EasingStyle.Back,
						Enum.EasingDirection.Out,
						0,
						false,
						POP_STAGGER * (index - 1)
					),
					{ Scale = 1 }
				):Play()
			end
			if UserInputService.GamepadEnabled then
				GuiService.SelectedObject = cards[1].button
			end
		end
	end)
end

return UpgradePicker
