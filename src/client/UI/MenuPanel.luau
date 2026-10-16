--!strict
-- A centered menu window for the lobby menus: a ScreenGui with a titled panel, the Shard count, and
-- a close button. The menu fills `content`. Placeholder look; polish comes in M4.

local Players = game:GetService("Players")

local Create = require(script.Parent.Create)

export type MenuPanel = {
	gui: ScreenGui,
	content: Frame,
	shards: TextLabel,
	close: TextButton,
}

local FONT = Enum.Font.GothamBold
local SHARD_COLOR = Color3.fromRGB(120, 220, 255)

return function(name: string, title: string, size: Vector2): MenuPanel
	local gui = Create("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		DisplayOrder = 5,
		Enabled = false,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
	local panel = Create("Frame", {
		Name = "Panel",
		Size = UDim2.fromOffset(size.X, size.Y),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(35, 32, 45),
		BorderSizePixel = 0,
		Parent = gui,
	})
	Create("UICorner", { CornerRadius = UDim.new(0, 12), Parent = panel })
	-- Shrinks the whole panel on screens too small for it (phones), never grows it.
	local scale = Create("UIScale", { Parent = panel })
	local function fit()
		local camera = workspace.CurrentCamera
		if camera then
			local viewport = camera.ViewportSize
			scale.Scale = math.min(1, (viewport.X - 24) / size.X, (viewport.Y - 24) / size.Y)
		end
	end
	fit()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	end

	Create("TextLabel", {
		Name = "Title",
		Size = UDim2.new(1, -40, 0, 40),
		Position = UDim2.fromOffset(20, 10),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		TextSize = 30,
		TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = title,
		Parent = panel,
	})
	local shards = Create("TextLabel", {
		Name = "Shards",
		Size = UDim2.fromOffset(180, 40),
		Position = UDim2.new(1, -70, 0, 10),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundTransparency = 1,
		Font = FONT,
		TextSize = 22,
		TextColor3 = SHARD_COLOR,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "",
		Parent = panel,
	})
	local close = Create("TextButton", {
		Name = "Close",
		Size = UDim2.fromOffset(40, 40),
		Position = UDim2.new(1, -12, 0, 10),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = Color3.fromRGB(80, 70, 95),
		Font = FONT,
		TextSize = 22,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "X",
		Parent = panel,
	})
	Create("UICorner", { CornerRadius = UDim.new(0, 8), Parent = close })
	local content = Create("Frame", {
		Name = "Content",
		Size = UDim2.new(1, -40, 1, -76),
		Position = UDim2.fromOffset(20, 60),
		BackgroundTransparency = 1,
		Parent = panel,
	})
	close.Activated:Connect(function()
		gui.Enabled = false
	end)
	return { gui = gui, content = content, shards = shards, close = close }
end
