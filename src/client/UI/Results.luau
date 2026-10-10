--!strict
-- The end-of-run screen: victory or defeat, the run's stats, and "Play again". Shown whenever the
-- Arena's Phase is Victory or Defeat. Placeholder look; polish comes in M4.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Create = require(script.Parent.Create)
local Config = require(ReplicatedStorage.Shared.Config.Run)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local TimeFormat = require(ReplicatedStorage.Shared.TimeFormat)

local FONT = Enum.Font.GothamBold
local VICTORY_COLOR = Color3.fromRGB(255, 215, 90)
local DEFEAT_COLOR = Color3.fromRGB(255, 100, 100)

local Results = {}

function Results.start(arena: Instance)
	local gui = Create("ScreenGui", {
		Name = "Results",
		ResetOnSpawn = false,
		DisplayOrder = 10,
		IgnoreGuiInset = true,
		Enabled = false,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
	Create("Frame", {
		Name = "Dim",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		Parent = gui,
	})
	local panel = Create("Frame", {
		Name = "Panel",
		Size = UDim2.fromOffset(320, 300),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(35, 32, 45),
		BorderSizePixel = 0,
		Parent = gui,
	})
	Create("UICorner", { CornerRadius = UDim.new(0, 12), Parent = panel })

	local title = Create("TextLabel", {
		Name = "Title",
		Size = UDim2.new(1, 0, 0, 56),
		Position = UDim2.fromOffset(0, 16),
		BackgroundTransparency = 1,
		Font = FONT,
		TextSize = 40,
		Parent = panel,
	})
	local stats = Create("TextLabel", {
		Name = "Stats",
		Size = UDim2.new(1, -40, 0, 110),
		Position = UDim2.fromOffset(20, 80),
		BackgroundTransparency = 1,
		Font = FONT,
		TextSize = 22,
		TextColor3 = Color3.fromRGB(230, 230, 240),
		TextYAlignment = Enum.TextYAlignment.Top,
		LineHeight = 1.3,
		Parent = panel,
	})
	local button = Create("TextButton", {
		Name = "PlayAgain",
		Size = UDim2.fromOffset(220, 56),
		Position = UDim2.new(0.5, 0, 1, -24),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = Color3.fromRGB(80, 170, 90),
		Font = FONT,
		TextSize = 26,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "PLAY AGAIN",
		Parent = panel,
	})
	Create("UICorner", { CornerRadius = UDim.new(0, 10), Parent = button })

	button.Activated:Connect(function()
		Remotes.RequestRestart:FireServer()
	end)

	local function refresh()
		local phase = arena:GetAttribute("Phase")
		local ended = phase == "Victory" or phase == "Defeat"
		gui.Enabled = ended
		if not ended then
			if GuiService.SelectedObject == button then
				GuiService.SelectedObject = nil
			end
			return
		end

		local victory = phase == "Victory"
		title.Text = if victory then "VICTORY!" else "DEFEATED"
		title.TextColor3 = if victory then VICTORY_COLOR else DEFEAT_COLOR
		stats.Text = string.format(
			"Time  %s\nStage  %d / %d\nKills  %d",
			TimeFormat.minutesSeconds(arena:GetAttribute("ResultTime") or 0),
			arena:GetAttribute("ResultStage") or 0,
			Config.STAGE_COUNT,
			arena:GetAttribute("ResultKills") or 0
		)
		if UserInputService.GamepadEnabled then
			GuiService.SelectedObject = button
		end
	end

	arena:GetAttributeChangedSignal("Phase"):Connect(refresh)
	refresh()
end

return Results
