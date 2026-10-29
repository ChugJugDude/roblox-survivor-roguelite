--!strict
-- The end-of-run screen: victory or defeat, the run's stats as tiles, the Shards it earned (the
-- player's ResultShards attribute, broken down with shared/ShardReward; the lines reveal one by one
-- while the total counts up), and "Back to lobby" (which also happens on its own after
-- Config.Party.RETURN_TO_LOBBY_AFTER seconds). Shown whenever the Arena's Phase is Victory or Defeat.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local CurrentArena = require(script.Parent.Parent.CurrentArena)
local Create = require(script.Parent.Create)
local Theme = require(script.Parent.Theme)
local Config = require(ReplicatedStorage.Shared.Config.Run)
local PartyConfig = require(ReplicatedStorage.Shared.Config.Party)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ShardReward = require(ReplicatedStorage.Shared.ShardReward)
local TimeFormat = require(ReplicatedStorage.Shared.TimeFormat)

local COLORS = Theme.COLORS
local VICTORY_COLOR = Color3.fromRGB(255, 215, 90)
local PANEL_SIZE = Vector2.new(360, 564)
local TILE_HEIGHT = 58
local LINE_HEIGHT = 24
-- The Shard lines appear this far apart, and the total counts up over COUNT_TIME.
local LINE_DELAY = 0.18
local COUNT_TIME = 0.9

type StatTile = {
	value: TextLabel,
}

local Results = {}

local function statTile(parent: Instance, order: number, icon: string, caption: string): StatTile
	local tile = Theme.panel({
		Name = caption,
		LayoutOrder = order,
		BackgroundColor3 = COLORS.panelLight,
		BackgroundTransparency = 0,
		Parent = parent,
	})
	Theme.label({
		Size = UDim2.fromOffset(36, TILE_HEIGHT),
		Position = UDim2.fromOffset(6, 0),
		TextSize = 22,
		TextStrokeTransparency = 1,
		Text = icon,
		Parent = tile,
	})
	local value = Theme.label({
		Size = UDim2.new(1, -48, 0, 28),
		Position = UDim2.fromOffset(44, 6),
		Font = Theme.FONTS.heading,
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextStrokeTransparency = 1,
		Parent = tile,
	})
	Theme.label({
		Size = UDim2.new(1, -48, 0, 16),
		Position = UDim2.fromOffset(44, 34),
		TextSize = 12,
		TextColor3 = COLORS.subtext,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextStrokeTransparency = 1,
		Text = caption,
		Parent = tile,
	})
	return { value = value }
end

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
	-- Shrinks to fit short screens (phones in landscape).
	local window = Create("Frame", {
		Name = "Window",
		Size = UDim2.fromOffset(PANEL_SIZE.X, PANEL_SIZE.Y),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	local fitScale = Create("UIScale", { Parent = window })
	local function fit()
		local camera = workspace.CurrentCamera
		if camera then
			local viewport = camera.ViewportSize
			fitScale.Scale = math.min(1, (viewport.X - 24) / PANEL_SIZE.X, (viewport.Y - 24) / PANEL_SIZE.Y)
		end
	end
	fit()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	end
	local panel = Theme.panel({
		Name = "Panel",
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 0.03,
		Parent = window,
	})
	local pop = Create("UIScale", { Parent = panel })

	local title = Theme.label({
		Name = "Title",
		Size = UDim2.new(1, 0, 0, 56),
		Position = UDim2.fromOffset(0, 14),
		Font = Theme.FONTS.heading,
		TextSize = 38,
		TextStrokeTransparency = 0.4,
		Parent = panel,
	})

	local grid = Create("Frame", {
		Name = "Stats",
		Size = UDim2.new(1, -40, 0, TILE_HEIGHT * 2 + 8),
		Position = UDim2.fromOffset(20, 80),
		BackgroundTransparency = 1,
		Parent = panel,
	})
	Create("UIGridLayout", {
		CellSize = UDim2.new(0.5, -4, 0, TILE_HEIGHT),
		CellPadding = UDim2.fromOffset(8, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = grid,
	})
	local timeTile = statTile(grid, 1, "⏱️", "Time")
	local stageTile = statTile(grid, 2, "🚩", "Stage")
	local levelTile = statTile(grid, 3, "⭐", "Level")
	local killsTile = statTile(grid, 4, "⚔️", "Kills")

	local shardsTop = 80 + TILE_HEIGHT * 2 + 24
	Theme.label({
		Name = "ShardsTitle",
		Size = UDim2.new(0.5, -20, 0, 28),
		Position = UDim2.fromOffset(20, shardsTop),
		Font = Theme.FONTS.heading,
		TextSize = 22,
		TextColor3 = COLORS.shard,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "💎 SHARDS",
		Parent = panel,
	})
	local shardsTotal = Theme.label({
		Name = "ShardsTotal",
		Size = UDim2.new(0.5, -20, 0, 28),
		Position = UDim2.new(0.5, 0, 0, shardsTop),
		Font = Theme.FONTS.heading,
		TextSize = 26,
		TextColor3 = COLORS.shard,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = panel,
	})
	local lines = Create("Frame", {
		Name = "ShardLines",
		Size = UDim2.new(1, -40, 0, LINE_HEIGHT * 7),
		Position = UDim2.fromOffset(20, shardsTop + 34),
		BackgroundTransparency = 1,
		Parent = panel,
	})
	Create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = lines })

	local unlocked = Theme.label({
		Name = "Unlocked",
		Size = UDim2.new(1, 0, 0, 22),
		Position = UDim2.new(0, 0, 1, -122),
		Font = Theme.FONTS.heading,
		TextSize = 16,
		TextColor3 = COLORS.evolution,
		Parent = panel,
	})
	local autoReturn = Theme.label({
		Name = "AutoReturn",
		Size = UDim2.new(1, 0, 0, 18),
		Position = UDim2.new(0, 0, 1, -96),
		TextSize = 13,
		TextColor3 = COLORS.subtext,
		TextStrokeTransparency = 1,
		Parent = panel,
	})
	local button = Theme.button(COLORS.good, {
		Name = "BackToLobby",
		Size = UDim2.fromOffset(240, 56),
		Position = UDim2.new(0.5, 0, 1, -22),
		AnchorPoint = Vector2.new(0.5, 1),
		Font = Theme.FONTS.heading,
		TextSize = 22,
		Text = "BACK TO LOBBY",
		Parent = panel,
	})
	button.Activated:Connect(function()
		Remotes.ReturnToLobby:FireServer()
	end)

	-- The Shard total counts up from 0 to `countTarget` starting at `countStartedAt` (os.clock).
	local countTarget = 0
	local countStartedAt = 0

	local function showShards(earned: number, arena: Instance, victory: boolean)
		lines:ClearAllChildren()
		Create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = lines })
		local player = Players.LocalPlayer
		local _, breakdown = ShardReward.compute({
			time = arena:GetAttribute("ResultTime") or 0,
			kills = arena:GetAttribute("ResultKills") or 0,
			stagesCleared = arena:GetAttribute("ResultStagesCleared") or 0,
			bosses = arena:GetAttribute("ResultBosses") or 0,
			victory = victory,
			world = arena:GetAttribute("World"),
		}, player:GetAttribute("ResultGreed") or 0)
		for index, line in breakdown do
			local row = Create("Frame", {
				Size = UDim2.new(1, 0, 0, LINE_HEIGHT),
				LayoutOrder = index,
				BackgroundTransparency = 1,
				Parent = lines,
			})
			local label = Theme.label({
				Size = UDim2.fromScale(0.75, 1),
				Font = Theme.FONTS.light,
				TextSize = 15,
				TextColor3 = COLORS.subtext,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextStrokeTransparency = 1,
				TextTransparency = 1,
				Text = line.label,
				Parent = row,
			})
			local amount = Theme.label({
				Size = UDim2.fromScale(0.25, 1),
				Position = UDim2.fromScale(0.75, 0),
				TextSize = 15,
				TextColor3 = COLORS.shard,
				TextXAlignment = Enum.TextXAlignment.Right,
				TextStrokeTransparency = 1,
				TextTransparency = 1,
				Text = `+{line.amount}`,
				Parent = row,
			})
			-- Each line fades in after the one before.
			for _, text in { label, amount } do
				TweenService:Create(
					text,
					TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, index * LINE_DELAY),
					{ TextTransparency = 0 }
				):Play()
			end
		end
		shardsTotal.Text = "+0"
		countTarget = earned
		countStartedAt = os.clock()
	end

	local function refresh(arena: Instance?)
		local phase = arena and arena:GetAttribute("Phase")
		local ended = phase == "Victory" or phase == "Defeat"
		local wasOpen = gui.Enabled
		gui.Enabled = ended
		if not ended or not arena then
			if GuiService.SelectedObject == button then
				GuiService.SelectedObject = nil
			end
			return
		end
		if not wasOpen then
			pop.Scale = 0.85
			TweenService:Create(pop, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		end

		local victory = phase == "Victory"
		local newWorld = Players.LocalPlayer:GetAttribute("ResultUnlocked")
		unlocked.Text = if typeof(newWorld) == "string" then `🔓 New world unlocked: {newWorld}!` else ""
		title.Text = if victory then "🏆 VICTORY!" else "💀 DEFEATED"
		title.TextColor3 = if victory then VICTORY_COLOR else COLORS.overtime
		timeTile.value.Text = TimeFormat.minutesSeconds(arena:GetAttribute("ResultTime") or 0)
		stageTile.value.Text = `{arena:GetAttribute("ResultStage") or 0} / {Config.STAGE_COUNT}`
		levelTile.value.Text = tostring(arena:GetAttribute("ResultLevel") or 1)
		killsTile.value.Text = tostring(arena:GetAttribute("ResultKills") or 0)

		local earned = Players.LocalPlayer:GetAttribute("ResultShards")
		if typeof(earned) ~= "number" then
			-- The server sets it in the same frame as the phase, but it can arrive a moment later.
			shardsTotal.Text = "..."
			lines:ClearAllChildren()
			countTarget = 0
		else
			showShards(earned, arena, victory)
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
			if countTarget > 0 then
				local progress = math.clamp((os.clock() - countStartedAt) / COUNT_TIME, 0, 1)
				local eased = 1 - (1 - progress) * (1 - progress)
				local text = `+{math.round(countTarget * eased)}`
				if shardsTotal.Text ~= text then
					shardsTotal.Text = text
				end
			end
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
