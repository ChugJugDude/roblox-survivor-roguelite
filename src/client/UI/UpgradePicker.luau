--!strict
-- The level-up choice: up to three cards along the bottom of the screen (so the player stays in
-- view; the game doesn't pause). Tap or click a card, press 1-3, or use a gamepad. The server sends
-- the options (Remotes.UpgradeOffered) and only takes back an index. Placeholder look; polish in M4.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Create = require(script.Parent.Create)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local FONT = Enum.Font.GothamBold
local CARD_SIZE = Vector2.new(160, 170)
local CARD_GAP = 10
local MAX_CARDS = 3
-- Below this screen height, everything shrinks to fit (phones in landscape).
local FULL_SIZE_HEIGHT = 600

local KIND_STYLE = {
	weapon = { color = Color3.fromRGB(235, 145, 60), tag = "WEAPON" },
	passive = { color = Color3.fromRGB(80, 160, 255), tag = "PASSIVE" },
	evolution = { color = Color3.fromRGB(255, 210, 60), tag = "EVOLUTION" },
	heal = { color = Color3.fromRGB(90, 200, 110), tag = "HEAL" },
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
	stroke: UIStroke,
	tag: TextLabel,
	name: TextLabel,
	level: TextLabel,
	description: TextLabel,
}

local UpgradePicker = {}

local function text(parent: Instance, name: string, size: UDim2, position: UDim2, textSize: number): TextLabel
	return Create("TextLabel", {
		Name = name,
		Size = size,
		Position = position,
		BackgroundTransparency = 1,
		Font = FONT,
		TextSize = textSize,
		TextColor3 = Color3.new(1, 1, 1),
		TextWrapped = true,
		Text = "",
		Parent = parent,
	})
end

local function createCard(parent: Instance, index: number): Card
	local button = Create("TextButton", {
		Name = `Card{index}`,
		Size = UDim2.fromOffset(CARD_SIZE.X, CARD_SIZE.Y),
		LayoutOrder = index,
		BackgroundColor3 = Color3.fromRGB(35, 32, 45),
		AutoButtonColor = true,
		Text = "",
		Parent = parent,
	})
	Create("UICorner", { CornerRadius = UDim.new(0, 10), Parent = button })
	local stroke = Create("UIStroke", { Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = button })
	local card: Card = {
		button = button,
		stroke = stroke,
		tag = text(button, "Tag", UDim2.new(1, 0, 0, 18), UDim2.fromOffset(0, 8), 13),
		name = text(button, "UpgradeName", UDim2.new(1, -12, 0, 44), UDim2.fromOffset(6, 26), 19),
		level = text(button, "LevelText", UDim2.new(1, 0, 0, 18), UDim2.fromOffset(0, 70), 15),
		description = text(button, "Description", UDim2.new(1, -16, 0, 56), UDim2.fromOffset(8, 92), 13),
	}
	card.description.TextColor3 = Color3.fromRGB(210, 210, 225)
	text(button, "Key", UDim2.new(1, 0, 0, 16), UDim2.new(0, 0, 1, -20), 12).Text = `[{index}]`
	return card
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
		Size = UDim2.fromOffset(width, CARD_SIZE.Y + 76),
		Position = UDim2.new(0.5, 0, 1, -12),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	local scale = Create("UIScale", { Parent = container })

	local title = text(container, "Title", UDim2.new(1, 0, 0, 30), UDim2.fromOffset(0, 0), 26)
	title.Text = "LEVEL UP!"
	title.TextColor3 = Color3.fromRGB(255, 225, 90)
	title.TextStrokeTransparency = 0.3
	local more = text(container, "More", UDim2.fromOffset(100, 30), UDim2.new(1, -100, 0, 0), 16)
	more.TextXAlignment = Enum.TextXAlignment.Right
	more.TextStrokeTransparency = 0.3

	local row = Create("Frame", {
		Name = "Cards",
		Size = UDim2.new(1, 0, 0, CARD_SIZE.Y),
		Position = UDim2.fromOffset(0, 34),
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

	local reroll = Create("TextButton", {
		Name = "Reroll",
		Size = UDim2.fromOffset(150, 32),
		Position = UDim2.fromScale(0.5, 1),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = Color3.fromRGB(70, 65, 90),
		Font = FONT,
		TextSize = 16,
		TextColor3 = Color3.new(1, 1, 1),
		Parent = container,
	})
	Create("UICorner", { CornerRadius = UDim.new(0, 8), Parent = reroll })

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

		optionCount = math.min(#offer.options, MAX_CARDS)
		for index, card in cards do
			local option = offer.options[index]
			card.button.Visible = option ~= nil
			if option then
				local style = KIND_STYLE[option.kind] or KIND_STYLE.passive
				card.stroke.Color = style.color
				card.tag.TextColor3 = style.color
				card.tag.Text = if option.isNew then `NEW {style.tag}` else style.tag
				card.name.Text = option.name
				card.level.Text = if option.kind == "heal"
					then ""
					elseif option.isNew then "NEW"
					else `Lv {option.level}`
				card.description.Text = option.description
			end
		end

		local pending = tonumber(offer.pending) or 1
		more.Text = if pending > 1 then `+{pending - 1} more` else ""
		local rerolls = tonumber(offer.rerolls) or 0
		reroll.Visible = rerolls > 0
		reroll.Text = `REROLL ({rerolls})`

		local wasOpen = gui.Enabled
		gui.Enabled = true
		if not wasOpen and UserInputService.GamepadEnabled then
			GuiService.SelectedObject = cards[1].button
		end
	end)
end

return UpgradePicker
