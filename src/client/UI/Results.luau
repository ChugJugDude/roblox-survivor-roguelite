--!strict
-- The end-of-run screen: victory or defeat, the run's stats, the Shards it earned (the player's
-- ResultShards attribute, broken down with shared/ShardReward), and "Back to lobby" (which also
-- happens on its own after Config.Party.RETURN_TO_LOBBY_AFTER seconds). Shown whenever the
-- Arena's Phase is Victory or Defeat. Placeholder look; polish comes in M4.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local CurrentArena = require(script.Parent.Parent.CurrentArena)
local Create = require(script.Parent.Create)
local Config = require(ReplicatedStorage.Shared.Config.Run)
local PartyConfig = require(ReplicatedStorage.Shared.Config.Party)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ShardReward = require(ReplicatedStorage.Shared.ShardReward)
local TimeFormat = require(ReplicatedStorage.Shared.TimeFormat)

local FONT = Enum.Font.GothamBold
local VICTORY_COLOR = Color3.fromRGB(255, 215, 90)
local DEFEAT_COLOR = Color3.fromRGB(255, 100, 100)
local SHARD_COLOR = Color3.fromRGB(120, 220, 255)

local Results = {}

function Results.start()
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
		Size = UDim2.fromOffset(340, 500),
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
		Size = UDim2.new(1, -40, 0, 140),
		Position = UDim2.fromOffset(20, 80),
		BackgroundTransparency = 1,
		Font = FONT,
		TextSize = 22,
		TextColor3 = Color3.fromRGB(230, 230, 240),
		TextYAlignment = Enum.TextYAlignment.Top,
		LineHeight = 1.3,
		Parent = panel,
	})
	local shardsTitle = Create("TextLabel", {
		Name = "ShardsTitle",
		Size = UDim2.new(1, -40, 0, 28),
		Position = UDim2.fromOffset(20, 215),
		BackgroundTransparency = 1,
		Font = FONT,
		TextSize = 24,
		TextColor3 = SHARD_COLOR,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = panel,
	})
	-- The breakdown: labels on the left, amounts right-aligned in a second label on top.
	local shardLabels = Create("TextLabel", {
		Name = "ShardLines",
		Size = UDim2.new(1, -40, 0, 130),
		Position = UDim2.fromOffset(20, 248),
		BackgroundTransparency = 1,
		Font = FONT,
		TextSize = 17,
		TextColor3 = Color3.fromRGB(190, 190, 205),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		LineHeight = 1.2,
		Parent = panel,
	})
	local shardAmounts = Create("TextLabel", {
		Name = "ShardAmounts",
		Size = UDim2.new(1, -40, 0, 130),
		Position = UDim2.fromOffset(20, 248),
		BackgroundTransparency = 1,
		Font = FONT,
		TextSize = 17,
		TextColor3 = SHARD_COLOR,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextYAlignment = Enum.TextYAlignment.Top,
		LineHeight = 1.2,
		Parent = panel,
	})
	local button = Create("TextButton", {
		Name = "BackToLobby",
		Size = UDim2.fromOffset(220, 56),
		Position = UDim2.new(0.5, 0, 1, -24),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = Color3.fromRGB(80, 170, 90),
		Font = FONT,
		TextSize = 26,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "BACK TO LOBBY",
		Parent = panel,
	})
	Create("UICorner", { CornerRadius = UDim.new(0, 10), Parent = button })
	local autoReturn = Create("TextLabel", {
		Name = "AutoReturn",
		Size = UDim2.new(1, 0, 0, 18),
		Position = UDim2.new(0, 0, 1, -100),
		BackgroundTransparency = 1,
		Font = FONT,
		TextSize = 14,
		TextColor3 = Color3.fromRGB(170, 170, 185),
		Text = "",
		Parent = panel,
	})

	button.Activated:Connect(function()
		Remotes.ReturnToLobby:FireServer()
	end)

	local function refresh(arena: Instance?)
		local phase = arena and arena:GetAttribute("Phase")
		local ended = phase == "Victory" or phase == "Defeat"
		gui.Enabled = ended
		if not ended or not arena then
			if GuiService.SelectedObject == button then
				GuiService.SelectedObject = nil
			end
			return
		end

		local victory = phase == "Victory"
		title.Text = if victory then "VICTORY!" else "DEFEATED"
		title.TextColor3 = if victory then VICTORY_COLOR else DEFEAT_COLOR
		stats.Text = string.format(
			"Time  %s\nStage  %d / %d\nLevel  %d\nKills  %d",
			TimeFormat.minutesSeconds(arena:GetAttribute("ResultTime") or 0),
			arena:GetAttribute("ResultStage") or 0,
			Config.STAGE_COUNT,
			arena:GetAttribute("ResultLevel") or 1,
			arena:GetAttribute("ResultKills") or 0
		)

		local player = Players.LocalPlayer
		local earned = player:GetAttribute("ResultShards")
		if typeof(earned) ~= "number" then
			-- The server sets it in the same frame as the phase, but it can arrive a moment later.
			shardsTitle.Text = "SHARDS ..."
			shardLabels.Text = ""
			shardAmounts.Text = ""
		else
			local _, lines = ShardReward.compute({
				time = arena:GetAttribute("ResultTime") or 0,
				kills = arena:GetAttribute("ResultKills") or 0,
				stagesCleared = arena:GetAttribute("ResultStagesCleared") or 0,
				bosses = arena:GetAttribute("ResultBosses") or 0,
				victory = victory,
			}, player:GetAttribute("ResultGreed") or 0)
			local labels: { string } = {}
			local amounts: { string } = {}
			for _, line in lines do
				table.insert(labels, line.label)
				table.insert(amounts, `+{line.amount}`)
			end
			shardsTitle.Text = `SHARDS  +{earned}`
			shardLabels.Text = table.concat(labels, "\n")
			shardAmounts.Text = table.concat(amounts, "\n")
		end

		if UserInputService.GamepadEnabled then
			GuiService.SelectedObject = button
		end
	end

	-- Follow whichever arena the player is in; refresh when it, its phase, or the reward changes.
	local shownArena: Instance? = nil
	local shownPhase: any = nil
	local shownShards: any = nil
	RunService.RenderStepped:Connect(function()
		local arena = CurrentArena.get()
		local phase = arena and arena:GetAttribute("Phase")
		local shards = Players.LocalPlayer:GetAttribute("ResultShards")
		if arena ~= shownArena or phase ~= shownPhase or shards ~= shownShards then
			shownArena, shownPhase, shownShards = arena, phase, shards
			refresh(arena)
		end
		if gui.Enabled and arena then
			local endedAt = arena:GetAttribute("EndedAt") or 0
			local left =
				math.max(0, math.ceil(endedAt + PartyConfig.RETURN_TO_LOBBY_AFTER - workspace:GetServerTimeNow()))
			local text = `Back to the lobby in {left}`
			if autoReturn.Text ~= text then
				autoReturn.Text = text
			end
		end
	end)
end

return Results
