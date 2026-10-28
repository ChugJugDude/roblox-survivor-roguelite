--!strict
-- The sound settings panel (opened from the gear next to the mute buttons): volume sliders for music,
-- all sound effects, and each kind of effect (Config.Audio.CATEGORIES), so a loud weapon can be
-- turned down on its own. Settings last for this session.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Create = require(script.Parent.Create)
local SoundPlayer = require(script.Parent.Parent.SoundPlayer)
local Theme = require(script.Parent.Theme)
local Config = require(ReplicatedStorage.Shared.Config.Audio)

local COLORS = Theme.COLORS
local PANEL_WIDTH = 360
local ROW_HEIGHT = 36
local HEADER_HEIGHT = 48
local TRACK_WIDTH = 140
-- Below this screen height the panel shrinks to fit (phones in landscape).
local FULL_SIZE_HEIGHT = 560

local gui: ScreenGui? = nil

local AudioSettings = {}

-- One labelled slider row. `get` and `set` read and write the 0-to-1 value.
local function slider(parent: Instance, order: number, text: string, get: () -> number, set: (number) -> ())
	local row = Create("Frame", {
		Name = text,
		Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
		LayoutOrder = order,
		BackgroundTransparency = 1,
		Parent = parent,
	})
	Theme.label({
		Size = UDim2.new(1, -(TRACK_WIDTH + 70), 1, 0),
		Position = UDim2.fromOffset(16, 0),
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextStrokeTransparency = 1,
		Text = text,
		Parent = row,
	})
	local value = Theme.label({
		Size = UDim2.fromOffset(44, ROW_HEIGHT),
		Position = UDim2.new(1, -54, 0, 0),
		TextSize = 13,
		TextColor3 = COLORS.subtext,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextStrokeTransparency = 1,
		Parent = row,
	})
	-- The whole track is a button so a tap anywhere on it jumps there.
	local track = Create("TextButton", {
		Name = "Track",
		Size = UDim2.fromOffset(TRACK_WIDTH, 8),
		Position = UDim2.new(1, -(TRACK_WIDTH + 62), 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = Color3.fromRGB(15, 14, 22),
		AutoButtonColor = false,
		Text = "",
		Parent = row,
	})
	Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = track })
	local fill = Create("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = COLORS.xp,
		BorderSizePixel = 0,
		Parent = track,
	})
	Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = fill })
	local knob = Create("Frame", {
		Size = UDim2.fromOffset(18, 18),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		BackgroundColor3 = COLORS.text,
		BorderSizePixel = 0,
		Parent = track,
	})
	Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = knob })

	local function show(fraction: number)
		fill.Size = UDim2.fromScale(fraction, 1)
		knob.Position = UDim2.fromScale(fraction, 0.5)
		value.Text = `{math.round(fraction * 100)}%`
	end
	local function setFromX(x: number)
		local fraction = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
		set(fraction)
		show(fraction)
	end
	show(get())

	local dragging = false
	track.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = true
			setFromX(input.Position.X)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if
			dragging
			and (
				input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch
			)
		then
			setFromX(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = false
		end
	end)
end

function AudioSettings.toggle()
	if gui then
		gui.Enabled = not gui.Enabled
	end
end

function AudioSettings.start()
	local rows = 2 + #Config.CATEGORIES
	local newGui = Create("ScreenGui", {
		Name = "AudioSettings",
		ResetOnSpawn = false,
		DisplayOrder = 6,
		Enabled = false,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
	gui = newGui
	local panel = Theme.panel({
		Name = "Panel",
		Size = UDim2.fromOffset(PANEL_WIDTH, HEADER_HEIGHT + rows * ROW_HEIGHT + 30),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 0.05,
		Parent = newGui,
	})
	local scale = Create("UIScale", { Parent = panel })
	local function fit()
		local camera = workspace.CurrentCamera
		if camera then
			scale.Scale = math.min(1, camera.ViewportSize.Y / FULL_SIZE_HEIGHT)
		end
	end
	fit()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	end

	Theme.label({
		Size = UDim2.new(1, 0, 0, HEADER_HEIGHT),
		Font = Theme.FONTS.heading,
		TextSize = 22,
		Text = "SOUND",
		Parent = panel,
	})
	local close = Theme.button(COLORS.bad, {
		Name = "Close",
		Size = UDim2.fromOffset(30, 30),
		Position = UDim2.new(1, -40, 0, 9),
		Text = "X",
		Font = Theme.FONTS.heading,
		Parent = panel,
	})
	close.Activated:Connect(function()
		newGui.Enabled = false
	end)

	local list = Create("Frame", {
		Name = "Sliders",
		Size = UDim2.new(1, 0, 1, -HEADER_HEIGHT),
		Position = UDim2.fromOffset(0, HEADER_HEIGHT),
		BackgroundTransparency = 1,
		Parent = panel,
	})
	Create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })

	slider(list, 1, "Music", function()
		return SoundPlayer.getGroupVolume("Music")
	end, function(volume)
		SoundPlayer.setGroupVolume("Music", volume)
	end)
	slider(list, 2, "All sound effects", function()
		return SoundPlayer.getGroupVolume("SFX")
	end, function(volume)
		SoundPlayer.setGroupVolume("SFX", volume)
	end)
	for index, category in Config.CATEGORIES do
		slider(list, 2 + index, category.name, function()
			return SoundPlayer.getCategoryVolume(category.id)
		end, function(volume)
			SoundPlayer.setCategoryVolume(category.id, volume)
		end)
	end
end

return AudioSettings
