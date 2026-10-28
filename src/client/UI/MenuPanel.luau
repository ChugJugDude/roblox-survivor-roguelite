--!strict
-- A centered menu window for the lobby menus: a ScreenGui with a dimmed backdrop and a titled panel
-- with the Shard count and a close button. The menu fills `content`. It pops in when opened.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Create = require(script.Parent.Create)
local Theme = require(script.Parent.Theme)

export type MenuPanel = {
	gui: ScreenGui,
	content: Frame,
	shards: TextLabel,
	close: TextButton,
}

local POP_TIME = 0.18

return function(name: string, title: string, size: Vector2): MenuPanel
	local gui = Create("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		DisplayOrder = 5,
		IgnoreGuiInset = true,
		Enabled = false,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
	Create("Frame", {
		Name = "Dim",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.5,
		BorderSizePixel = 0,
		Parent = gui,
	})
	-- The window shrinks to fit small screens (phones), never grows; the panel inside it pops in.
	-- (An object takes one UIScale, so each scale gets its own frame.)
	local window = Create("Frame", {
		Name = "Window",
		Size = UDim2.fromOffset(size.X, size.Y),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	local fitScale = Create("UIScale", { Parent = window })
	local holder = Theme.panel({
		Name = "Panel",
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5), -- so it pops from the middle
		BackgroundTransparency = 0.03,
		Parent = window,
	})
	local function fit()
		local camera = workspace.CurrentCamera
		if camera then
			local viewport = camera.ViewportSize
			fitScale.Scale = math.min(1, (viewport.X - 24) / size.X, (viewport.Y - 24) / size.Y)
		end
	end
	fit()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	end

	-- A band across the top for the title.
	local header = Create("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 56),
		BackgroundColor3 = Theme.COLORS.panelLight,
		BorderSizePixel = 0,
		Parent = holder,
	})
	Create("UICorner", { CornerRadius = UDim.new(0, Theme.CORNER), Parent = header })
	Theme.label({
		Name = "Title",
		Size = UDim2.new(1, -40, 0, 40),
		Position = UDim2.fromOffset(20, 8),
		Font = Theme.FONTS.heading,
		TextSize = 28,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = title,
		Parent = header,
	})
	local shards = Theme.label({
		Name = "Shards",
		Size = UDim2.fromOffset(180, 40),
		Position = UDim2.new(1, -66, 0, 8),
		AnchorPoint = Vector2.new(1, 0),
		Font = Theme.FONTS.heading,
		TextSize = 22,
		TextColor3 = Theme.COLORS.shard,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = header,
	})
	local close = Theme.button(Theme.COLORS.bad, {
		Name = "Close",
		Size = UDim2.fromOffset(40, 40),
		Position = UDim2.new(1, -12, 0, 8),
		AnchorPoint = Vector2.new(1, 0),
		Font = Theme.FONTS.heading,
		TextSize = 20,
		Text = "X",
		Parent = header,
	})
	local content = Create("Frame", {
		Name = "Content",
		Size = UDim2.new(1, -40, 1, -84),
		Position = UDim2.fromOffset(20, 68),
		BackgroundTransparency = 1,
		Parent = holder,
	})
	close.Activated:Connect(function()
		gui.Enabled = false
	end)

	-- Pop in when opened.
	local pop = Create("UIScale", { Parent = holder })
	gui:GetPropertyChangedSignal("Enabled"):Connect(function()
		if gui.Enabled then
			pop.Scale = 0.85
			TweenService:Create(pop, TweenInfo.new(POP_TIME, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		end
	end)
	return { gui = gui, content = content, shards = shards, close = close }
end
