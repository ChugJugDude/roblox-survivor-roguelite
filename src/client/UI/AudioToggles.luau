--!strict
-- Two small buttons at the top right that mute and unmute music and sound effects, in the lobby
-- and in runs. The choice lasts for this session.

local Players = game:GetService("Players")

local Create = require(script.Parent.Create)
local SoundPlayer = require(script.Parent.Parent.SoundPlayer)

local BUTTON_SIZE = 36
local ON_COLOR = Color3.fromRGB(35, 32, 45)
local OFF_COLOR = Color3.fromRGB(90, 40, 45)

local AudioToggles = {}

local function toggle(parent: Instance, order: number, icon: string, group: SoundPlayer.Group)
	local button = Create("TextButton", {
		Name = `Toggle{group}`,
		Size = UDim2.fromOffset(BUTTON_SIZE, BUTTON_SIZE),
		LayoutOrder = order,
		BackgroundColor3 = ON_COLOR,
		BackgroundTransparency = 0.2,
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		TextColor3 = Color3.new(1, 1, 1),
		Text = icon,
		Parent = parent,
	})
	Create("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = button })
	-- A slash across the icon while muted.
	local slash = Create("Frame", {
		Name = "Slash",
		Size = UDim2.new(0.75, 0, 0, 3),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Rotation = -45,
		BackgroundColor3 = Color3.fromRGB(255, 120, 120),
		BorderSizePixel = 0,
		Visible = false,
		Parent = button,
	})
	button.Activated:Connect(function()
		local muted = not SoundPlayer.isMuted(group)
		SoundPlayer.setMuted(group, muted)
		slash.Visible = muted
		button.BackgroundColor3 = if muted then OFF_COLOR else ON_COLOR
	end)
end

function AudioToggles.start()
	local gui = Create("ScreenGui", {
		Name = "AudioToggles",
		ResetOnSpawn = false,
		DisplayOrder = 2,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
	local row = Create("Frame", {
		Name = "Row",
		Size = UDim2.fromOffset(BUTTON_SIZE * 2 + 8, BUTTON_SIZE),
		Position = UDim2.new(1, -12, 0, 22),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = row,
	})
	toggle(row, 1, "♪", "Music")
	toggle(row, 2, "🔊", "SFX")
end

return AudioToggles
