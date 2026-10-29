--!strict
-- The in-run HUD: the party XP bar and level, the local player's health, a stage/timer/kills
-- panel with the boss bar under it, a portal-charge objective on the right, a center banner for the
-- countdown and stage transitions, and the local player's build as icon tiles. Everything is read from the Arena's attributes (see server/Match.luau) and the
-- player's W_ / P_ attributes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CurrentArena = require(script.Parent.Parent.CurrentArena)
local Create = require(script.Parent.Create)
local Theme = require(script.Parent.Theme)
local Config = require(ReplicatedStorage.Shared.Config.Run)
local GameClock = require(ReplicatedStorage.Shared.GameClock)
local UpgradesConfig = require(ReplicatedStorage.Shared.Config.Upgrades)
local TimeFormat = require(ReplicatedStorage.Shared.TimeFormat)

local COLORS = Theme.COLORS
-- The stage panel, with the boss bar under it.
local TOP_PANEL_Y = 24
local TOP_PANEL_HEIGHT = 80
local BOSS_BAR_Y = TOP_PANEL_Y + TOP_PANEL_HEIGHT + 8
-- Health, then the build tiles, top left (the bottom left is the mobile thumbstick).
local HEALTH_Y = 24
local HEALTH_WIDTH = 190
local TILE_SIZE = 40
local TILE_GAP = 4
local TILES_TOP = 26
-- The objective tracker, top right under the audio buttons.
local OBJECTIVE_Y = 68
local OBJECTIVE_WIDTH = 220

local Hud = {}

-- Sets a property only when it changes, so per-frame updates don't churn the UI.
local function set(instance: Instance, property: string, value: any)
	if (instance :: any)[property] ~= value then
		(instance :: any)[property] = value
	end
end

type Tile = {
	frame: Frame,
	stroke: UIStroke,
	icon: TextLabel,
	pips: { Frame },
	evo: TextLabel,
}

local function createTile(parent: Instance, order: number): Tile
	local frame = Theme.panel({
		Name = `Tile{order}`,
		Size = UDim2.fromOffset(TILE_SIZE, TILE_SIZE),
		LayoutOrder = order,
		Parent = parent,
	})
	local stroke = frame:FindFirstChildOfClass("UIStroke") :: UIStroke
	local icon = Theme.label({
		Name = "Icon",
		Size = UDim2.new(1, 0, 1, -8),
		TextSize = 22,
		TextStrokeTransparency = 1,
		Parent = frame,
	})
	local pipRow = Create("Frame", {
		Name = "Pips",
		Size = UDim2.new(1, -8, 0, 5),
		Position = UDim2.new(0.5, 0, 1, -7),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		Parent = frame,
	})
	Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 2),
		Parent = pipRow,
	})
	local pips = {}
	for index = 1, UpgradesConfig.MAX_LEVEL do
		local pip = Create("Frame", {
			Size = UDim2.fromOffset(5, 5),
			LayoutOrder = index,
			BorderSizePixel = 0,
			Parent = pipRow,
		})
		Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = pip })
		table.insert(pips, pip)
	end
	local evo = Theme.label({
		Name = "Evo",
		Size = UDim2.new(1, 0, 0, 10),
		Position = UDim2.new(0, 0, 1, -11),
		Font = Theme.FONTS.heading,
		TextSize = 9,
		TextColor3 = COLORS.evolution,
		Text = "EVO",
		Visible = false,
		Parent = frame,
	})
	return { frame = frame, stroke = stroke, icon = icon, pips = pips, evo = evo }
end

-- Shows `icon` at `level` (nil for an empty slot) in `color`.
local function setTile(tile: Tile, icon: string?, level: number?, color: Color3)
	local evolved = level ~= nil and level > UpgradesConfig.MAX_LEVEL
	tile.icon.Text = icon or ""
	tile.frame.BackgroundTransparency = if icon then Theme.PANEL_TRANSPARENCY else 0.6
	tile.stroke.Color = if evolved then COLORS.evolution elseif icon then color else COLORS.stroke
	tile.stroke.Thickness = if evolved then 2.5 else 1.5
	tile.evo.Visible = evolved
	for index, pip in tile.pips do
		pip.Visible = icon ~= nil and not evolved
		pip.BackgroundColor3 = if level and index <= level then color else COLORS.dim
	end
end

-- Ids sorted by display name, so tiles keep a stable order.
local function sortedIds(defs: { [string]: { name: string } }): { string }
	local ids = {}
	for id in defs do
		table.insert(ids, id)
	end
	table.sort(ids, function(a, b)
		return defs[a].name < defs[b].name
	end)
	return ids
end

local function tileRow(parent: Instance, name: string, y: number): { Tile }
	local row = Create("Frame", {
		Name = name,
		Size = UDim2.fromOffset((TILE_SIZE + TILE_GAP) * 4, TILE_SIZE),
		Position = UDim2.fromOffset(10, y),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, TILE_GAP),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = row,
	})
	local tiles = {}
	for index = 1, 4 do
		table.insert(tiles, createTile(row, index))
	end
	return tiles
end

-- A framed bar with a caption above it (portal charge, boss health).
local function captionedBar(gui: Instance, name: string, width: number, color: Color3): (Frame, TextLabel, Frame)
	local frame = Theme.panel({
		Name = name,
		Size = UDim2.fromOffset(width, 42),
		Position = UDim2.new(0.5, 0, 0, BOSS_BAR_Y),
		AnchorPoint = Vector2.new(0.5, 0),
		Visible = false,
		Parent = gui,
	})
	local caption = Theme.label({
		Name = "Caption",
		Size = UDim2.new(1, -16, 0, 18),
		Position = UDim2.fromOffset(8, 3),
		TextSize = 14,
		TextColor3 = color,
		Parent = frame,
	})
	local bar = Theme.bar(frame, UDim2.new(1, -16, 0, 12), UDim2.fromOffset(8, 24), color)
	return frame, caption, bar.fill
end

function Hud.start()
	local gui = Create("ScreenGui", {
		Name = "Hud",
		ResetOnSpawn = false,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})

	-- Party XP across the top of the screen, with the level in a badge at its left end.
	local xpBar = Theme.bar(gui, UDim2.new(1, -60, 0, 14), UDim2.fromOffset(46, 4), COLORS.xp)
	xpBar.back.Name = "XP"
	local levelBadge = Create("Frame", {
		Name = "Level",
		Size = UDim2.fromOffset(34, 34),
		Position = UDim2.fromOffset(10, 0),
		BackgroundColor3 = COLORS.xp,
		BorderSizePixel = 0,
		Parent = gui,
	})
	Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = levelBadge })
	Create("UIStroke", { Color = Color3.fromRGB(20, 40, 70), Thickness = 2, Parent = levelBadge })
	local levelLabel = Theme.label({
		Size = UDim2.fromScale(1, 1),
		Font = Theme.FONTS.heading,
		TextSize = 16,
		TextStrokeTransparency = 0.3,
		Parent = levelBadge,
	})

	local top = Theme.panel({
		Name = "Top",
		Size = UDim2.fromOffset(240, TOP_PANEL_HEIGHT),
		Position = UDim2.new(0.5, 0, 0, TOP_PANEL_Y),
		AnchorPoint = Vector2.new(0.5, 0),
		Parent = gui,
	})
	local stageLabel = Theme.label({
		Name = "Stage",
		Size = UDim2.new(1, 0, 0, 18),
		Position = UDim2.fromOffset(0, 5),
		TextSize = 14,
		TextColor3 = COLORS.subtext,
		Parent = top,
	})
	local timerLabel = Theme.label({
		Name = "Timer",
		Size = UDim2.new(1, -16, 0, 34),
		Position = UDim2.fromOffset(8, 22),
		Font = Theme.FONTS.heading,
		TextScaled = true,
		Parent = top,
	})
	Create("UITextSizeConstraint", { MaxTextSize = 32, Parent = timerLabel })
	local killsLabel = Theme.label({
		Name = "Kills",
		Size = UDim2.new(1, 0, 0, 18),
		Position = UDim2.fromOffset(0, 57),
		TextSize = 14,
		TextColor3 = COLORS.subtext,
		Parent = top,
	})

	local boss, bossLabel, bossFill = captionedBar(gui, "Boss", 380, COLORS.boss)

	-- The local player's health, right under the XP bar next to the level badge. (The bar under the
	-- character gets lost in a crowd.)
	local health = Theme.bar(gui, UDim2.fromOffset(HEALTH_WIDTH, 16), UDim2.fromOffset(50, HEALTH_Y), COLORS.health)
	health.back.Name = "Health"
	local healthLabel = Theme.label({
		Name = "Amount",
		Size = UDim2.fromScale(1, 1),
		Font = Theme.FONTS.heading,
		TextSize = 12,
		TextStrokeTransparency = 0.3,
		ZIndex = 2,
		Parent = health.back,
	})

	-- Objectives (charging the portal) sit on the right, like a quest tracker, so the top middle
	-- doesn't stack into a list.
	local objective = Theme.panel({
		Name = "Objective",
		Size = UDim2.fromOffset(OBJECTIVE_WIDTH, 62),
		Position = UDim2.new(1, -12, 0, OBJECTIVE_Y),
		AnchorPoint = Vector2.new(1, 0),
		Visible = false,
		Parent = gui,
	})
	Theme.label({
		Name = "Header",
		Size = UDim2.new(1, -16, 0, 14),
		Position = UDim2.fromOffset(8, 4),
		Font = Theme.FONTS.heading,
		TextSize = 11,
		TextColor3 = COLORS.dim,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "OBJECTIVE",
		Parent = objective,
	})
	local portalLabel = Theme.label({
		Name = "Task",
		Size = UDim2.new(1, -16, 0, 18),
		Position = UDim2.fromOffset(8, 18),
		TextSize = 15,
		TextColor3 = COLORS.portal,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = objective,
	})
	local portalFill = Theme.bar(objective, UDim2.new(1, -16, 0, 10), UDim2.fromOffset(8, 42), COLORS.portal).fill

	local banner = Theme.label({
		Name = "Banner",
		Size = UDim2.new(1, 0, 0, 80),
		Position = UDim2.fromScale(0.5, 0.3),
		AnchorPoint = Vector2.new(0.5, 0),
		Font = Theme.FONTS.heading,
		TextSize = 64,
		TextStrokeTransparency = 0.2,
		Parent = gui,
	})

	-- The local player's build: weapons on the first row, passives on the second.
	local build = Create("Frame", {
		Name = "Build",
		Size = UDim2.fromOffset((TILE_SIZE + TILE_GAP) * 4 + 10, TILE_SIZE * 2 + TILE_GAP + TILES_TOP + 20),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	local weaponTiles = tileRow(build, "Weapons", TILES_TOP + 22)
	local passiveTiles = tileRow(build, "Passives", TILES_TOP + 22 + TILE_SIZE + TILE_GAP)
	local weaponIds = sortedIds(UpgradesConfig.WEAPONS)
	local passiveIds = sortedIds(UpgradesConfig.PASSIVES)
	local localPlayer = Players.LocalPlayer
	local function refreshBuild()
		local slot = 1
		for _, id in weaponIds do
			local level = localPlayer:GetAttribute("W_" .. id)
			if typeof(level) == "number" and slot <= #weaponTiles then
				setTile(weaponTiles[slot], UpgradesConfig.WEAPONS[id].icon, level, COLORS.weapon)
				slot += 1
			end
		end
		for index = slot, #weaponTiles do
			setTile(weaponTiles[index], nil, nil, COLORS.weapon)
		end
		slot = 1
		for _, id in passiveIds do
			local level = localPlayer:GetAttribute("P_" .. id)
			if typeof(level) == "number" and slot <= #passiveTiles then
				setTile(passiveTiles[slot], UpgradesConfig.PASSIVES[id].icon, level, COLORS.passive)
				slot += 1
			end
		end
		for index = slot, #passiveTiles do
			setTile(passiveTiles[index], nil, nil, COLORS.passive)
		end
	end
	localPlayer.AttributeChanged:Connect(refreshBuild)
	refreshBuild()

	local picker: ScreenGui? = nil
	local pauseMenu: ScreenGui? = nil
	RunService.RenderStepped:Connect(function()
		if not picker then
			picker = localPlayer.PlayerGui:FindFirstChild("UpgradePicker") :: ScreenGui?
		end
		if not pauseMenu then
			pauseMenu = localPlayer.PlayerGui:FindFirstChild("PauseMenu") :: ScreenGui?
		end
		local arena = CurrentArena.get()
		gui.Enabled = arena ~= nil
		if not arena then
			return -- the lobby
		end
		local now = GameClock.read(arena)
		local phase = arena:GetAttribute("Phase")
		local stage = arena:GetAttribute("Stage") or 0
		local endsAt = arena:GetAttribute("PhaseEndsAt") or 0
		local inRun = phase == "Countdown"
			or phase == "Stage"
			or phase == "Overtime"
			or phase == "Boss"
			or phase == "Transition"

		set(top, "Visible", inRun)
		set(build, "Visible", inRun)
		set(xpBar.back, "Visible", inRun)
		set(levelBadge, "Visible", inRun)
		set(health.back, "Visible", inRun)
		local character = localPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			local maxHealth = math.max(humanoid.MaxHealth, 1)
			local fraction = math.clamp(humanoid.Health / maxHealth, 0, 1)
			set(health.fill, "Size", UDim2.fromScale(fraction, 1))
			set(health.fill, "BackgroundColor3", if fraction < 0.3 then COLORS.lowHealth else COLORS.health)
			set(healthLabel, "Text", `{math.ceil(humanoid.Health)} / {math.ceil(maxHealth)}`)
		end
		local toNext = arena:GetAttribute("XPToNext") or 1
		set(xpBar.fill, "Size", UDim2.fromScale(math.clamp((arena:GetAttribute("PartyXP") or 0) / toNext, 0, 1), 1))
		set(levelLabel, "Text", tostring(arena:GetAttribute("PartyLevel") or 1))
		set(stageLabel, "Text", `STAGE {stage} / {Config.STAGE_COUNT}`)
		set(killsLabel, "Text", `⚔ {arena:GetAttribute("Kills") or 0}`)
		if phase == "Overtime" then
			set(timerLabel, "Text", "OVERTIME")
			set(timerLabel, "TextColor3", COLORS.overtime)
		elseif phase == "Boss" then
			local name = arena:GetAttribute("BossName") or ""
			set(timerLabel, "Text", if name ~= "" then `DEFEAT THE {string.upper(name)}` else "")
			set(timerLabel, "TextColor3", COLORS.overtime)
		elseif phase == "Stage" then
			set(timerLabel, "Text", TimeFormat.minutesSeconds(math.ceil(endsAt - now)))
			set(timerLabel, "TextColor3", COLORS.text)
		elseif phase == "Countdown" then
			set(timerLabel, "Text", "GET READY")
			set(timerLabel, "TextColor3", COLORS.text)
		else
			set(timerLabel, "Text", "")
		end

		local bossName = arena:GetAttribute("BossName") or ""
		set(boss, "Visible", inRun and bossName ~= "")
		if bossName ~= "" then
			set(bossLabel, "Text", `☠ {string.upper(bossName)}`)
			set(bossFill, "Size", UDim2.fromScale(math.clamp(arena:GetAttribute("BossHealth") or 0, 0, 1), 1))
		end

		set(objective, "Visible", phase == "Overtime")
		if phase == "Overtime" then
			local charge = arena:GetAttribute("PortalCharge") or 0
			set(portalLabel, "Text", `Charge the portal  {math.floor(charge * 100)}%`)
			set(portalFill, "Size", UDim2.fromScale(math.clamp(charge, 0, 1), 1))
		end

		if phase == "Countdown" then
			set(banner, "Text", tostring(math.max(1, math.ceil(endsAt - now))))
		elseif phase == "Transition" then
			set(banner, "Text", `STAGE {stage}`)
		elseif
			GameClock.isPaused(arena)
			and not (picker and picker.Enabled)
			and not (pauseMenu and pauseMenu.Enabled)
		then
			-- Paused for level-ups, and this player has already chosen.
			set(banner, "Text", "WAITING FOR OTHERS")
		else
			set(banner, "Text", "")
		end
	end)
end

return Hud
