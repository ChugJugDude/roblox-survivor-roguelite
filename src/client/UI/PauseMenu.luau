--!strict
-- The pause menu: a ⏸ button (or the P key; Escape is Roblox's own menu) that opens the local
-- player's build. Solo, it pauses the run (Remotes.RequestPause); in co-op it only shows the build,
-- since one player can't freeze the shared world. Hovering or tapping a tile shows what it does,
-- its level, and its evolution pair.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local AudioSettings = require(script.Parent.AudioSettings)
local CurrentArena = require(script.Parent.Parent.CurrentArena)
local Create = require(script.Parent.Create)
local Theme = require(script.Parent.Theme)
local BuildStats = require(ReplicatedStorage.Shared.BuildStats)
local Config = require(ReplicatedStorage.Shared.Config.Upgrades)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local COLORS = Theme.COLORS
local PANEL_SIZE = Vector2.new(600, 360)
local TILE_SIZE = 60
local TILE_GAP = 8
local BUTTON_SIZE = 36
local IN_RUN: { [string]: boolean } =
	{ Countdown = true, Stage = true, Overtime = true, Boss = true, Transition = true }

type Tile = {
	button: TextButton,
	stroke: UIStroke,
	icon: TextLabel,
	pips: { Frame },
	evo: TextLabel,
	id: string?, -- what it shows, or nil for an empty slot
	kind: "weapon" | "passive",
}

local gui: ScreenGui? = nil

local PauseMenu = {}

-- Ids sorted by display name, matching the HUD's tile order.
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

-- How many players are in the local player's arena (the pause only works solo).
local function partySize(arena: Instance): number
	local count = 0
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("ArenaName") == arena.Name then
			count += 1
		end
	end
	return count
end

-- The detail text for a weapon or passive the local player owns.
local function describe(kind: "weapon" | "passive", id: string, level: number): (string, string, string)
	local player = Players.LocalPlayer
	if kind == "weapon" then
		local def = Config.WEAPONS[id]
		if level > Config.MAX_LEVEL then
			return def.evolution.name, "EVOLVED", def.evolution.description
		end
		local pair = Config.PASSIVES[def.evolution.passive]
		local owned = typeof(player:GetAttribute("P_" .. def.evolution.passive)) == "number"
		local text = def.descriptions[1]
		if level > 1 then
			text ..= `\nLevel {level}: {def.descriptions[level]}`
		end
		text ..= `\n\nEvolves into {def.evolution.name} with {pair.name} at level {Config.MAX_LEVEL}`
		text ..= if owned then " (you have it)." else "."
		return def.name, `LEVEL {level} / {Config.MAX_LEVEL}`, text
	end
	local def = Config.PASSIVES[id]
	local text = BuildStats.passiveText(id, level)
	local weaponId = BuildStats.weaponEvolvedBy(id)
	if weaponId then
		text ..= `\n\nEvolves {Config.WEAPONS[weaponId].name} at level {Config.MAX_LEVEL}.`
	end
	return def.name, `LEVEL {level} / {Config.MAX_LEVEL}`, text
end

local function createTile(parent: Instance, order: number, kind: "weapon" | "passive"): Tile
	local button = Create("TextButton", {
		Name = `Tile{order}`,
		Size = UDim2.fromOffset(TILE_SIZE, TILE_SIZE),
		LayoutOrder = order,
		BackgroundColor3 = COLORS.panelLight,
		AutoButtonColor = true,
		Text = "",
		Parent = parent,
	})
	Create("UICorner", { CornerRadius = UDim.new(0, 8), Parent = button })
	local stroke = Create("UIStroke", {
		Thickness = 1.5,
		Color = COLORS.stroke,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = button,
	})
	local icon = Theme.label({
		Size = UDim2.new(1, 0, 1, -12),
		TextSize = 32,
		TextStrokeTransparency = 1,
		Parent = button,
	})
	local pipRow = Create("Frame", {
		Size = UDim2.new(1, -10, 0, 7),
		Position = UDim2.new(0.5, 0, 1, -11),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		Parent = button,
	})
	Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 3),
		Parent = pipRow,
	})
	local pips = {}
	for index = 1, Config.MAX_LEVEL do
		local pip = Create(
			"Frame",
			{ Size = UDim2.fromOffset(7, 7), LayoutOrder = index, BorderSizePixel = 0, Parent = pipRow }
		)
		Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = pip })
		table.insert(pips, pip)
	end
	local evo = Theme.label({
		Size = UDim2.new(1, 0, 0, 12),
		Position = UDim2.new(0, 0, 1, -14),
		Font = Theme.FONTS.heading,
		TextSize = 11,
		TextColor3 = COLORS.evolution,
		Text = "EVO",
		Visible = false,
		Parent = button,
	})
	return { button = button, stroke = stroke, icon = icon, pips = pips, evo = evo, id = nil, kind = kind }
end

function PauseMenu.toggle()
	local menu = gui
	if not menu then
		return
	end
	local arena = CurrentArena.get()
	local opening = not menu.Enabled
	if opening and (not arena or not IN_RUN[arena:GetAttribute("Phase") :: string]) then
		return
	end
	-- Don't open over the upgrade picker; it has the floor.
	local picker = Players.LocalPlayer.PlayerGui:FindFirstChild("UpgradePicker")
	if opening and picker and (picker :: ScreenGui).Enabled then
		return
	end
	menu.Enabled = opening
	if arena and partySize(arena) == 1 then
		Remotes.RequestPause:FireServer(opening)
	end
end

function PauseMenu.isOpen(): boolean
	return gui ~= nil and (gui :: ScreenGui).Enabled
end

function PauseMenu.start()
	local player = Players.LocalPlayer
	local newGui = Create("ScreenGui", {
		Name = "PauseMenu",
		ResetOnSpawn = false,
		DisplayOrder = 4, -- under the upgrade picker
		IgnoreGuiInset = true,
		Enabled = false,
		Parent = player:WaitForChild("PlayerGui"),
	})
	gui = newGui
	Create("Frame", {
		Name = "Dim",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.5,
		BorderSizePixel = 0,
		Parent = newGui,
	})
	local window = Create("Frame", {
		Name = "Window",
		Size = UDim2.fromOffset(PANEL_SIZE.X, PANEL_SIZE.Y),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Parent = newGui,
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
	local panel =
		Theme.panel({ Name = "Panel", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0.03, Parent = window })

	local title = Theme.label({
		Name = "Title",
		Size = UDim2.new(1, -40, 0, 44),
		Position = UDim2.fromOffset(20, 10),
		Font = Theme.FONTS.heading,
		TextSize = 28,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = panel,
	})

	-- The build, on the left: weapons, then passives.
	local tiles: { Tile } = {}
	local function tileRow(name: string, y: number, kind: "weapon" | "passive")
		Theme.label({
			Size = UDim2.fromOffset(200, 16),
			Position = UDim2.fromOffset(20, y),
			TextSize = 12,
			TextColor3 = COLORS.subtext,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextStrokeTransparency = 1,
			Text = name,
			Parent = panel,
		})
		local row = Create("Frame", {
			Size = UDim2.fromOffset((TILE_SIZE + TILE_GAP) * 4, TILE_SIZE),
			Position = UDim2.fromOffset(20, y + 18),
			BackgroundTransparency = 1,
			Parent = panel,
		})
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, TILE_GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = row,
		})
		for index = 1, 4 do
			table.insert(tiles, createTile(row, index, kind))
		end
	end
	tileRow("WEAPONS", 64, "weapon")
	tileRow("PASSIVES", 64 + TILE_SIZE + 30, "passive")

	-- The detail box, on the right.
	local detail = Theme.panel({
		Name = "Detail",
		Size = UDim2.new(1, -330, 0, 206),
		Position = UDim2.fromOffset(310, 64),
		BackgroundColor3 = COLORS.panelLight,
		BackgroundTransparency = 0,
		Parent = panel,
	})
	local detailName = Theme.label({
		Size = UDim2.new(1, -20, 0, 26),
		Position = UDim2.fromOffset(10, 8),
		Font = Theme.FONTS.heading,
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextStrokeTransparency = 1,
		Parent = detail,
	})
	local detailLevel = Theme.label({
		Size = UDim2.new(1, -20, 0, 16),
		Position = UDim2.fromOffset(10, 34),
		TextSize = 12,
		TextColor3 = COLORS.evolution,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextStrokeTransparency = 1,
		Parent = detail,
	})
	local detailText = Theme.label({
		Size = UDim2.new(1, -20, 1, -60),
		Position = UDim2.fromOffset(10, 54),
		Font = Theme.FONTS.light,
		TextSize = 14,
		TextColor3 = COLORS.subtext,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextStrokeTransparency = 1,
		Text = "Hover or tap an upgrade to see what it does.",
		Parent = detail,
	})

	local function showDetail(tile: Tile)
		local id = tile.id
		if not id then
			return
		end
		local level = player:GetAttribute((if tile.kind == "weapon" then "W_" else "P_") .. id)
		if typeof(level) ~= "number" then
			return
		end
		local name, levelText, text = describe(tile.kind, id, level)
		local icon = if tile.kind == "weapon" then Config.WEAPONS[id].icon else Config.PASSIVES[id].icon
		detailName.Text = `{icon} {name}`
		detailLevel.Text = levelText
		detailText.Text = text
	end
	for _, tile in tiles do
		tile.button.MouseEnter:Connect(function()
			showDetail(tile)
		end)
		tile.button.Activated:Connect(function()
			showDetail(tile)
		end)
		tile.button.SelectionGained:Connect(function()
			showDetail(tile)
		end)
	end

	local function refresh()
		local weaponSlots, passiveSlots = {}, {}
		for _, tile in tiles do
			table.insert(if tile.kind == "weapon" then weaponSlots else passiveSlots, tile)
		end
		local function fill(slots: { Tile }, ids: { string }, prefix: string, color: Color3)
			local slot = 1
			for _, id in ids do
				local level = player:GetAttribute(prefix .. id)
				if typeof(level) == "number" and slot <= #slots then
					local tile = slots[slot]
					local evolved = level > Config.MAX_LEVEL
					tile.id = id
					tile.icon.Text = if prefix == "W_" then Config.WEAPONS[id].icon else Config.PASSIVES[id].icon
					tile.stroke.Color = if evolved then COLORS.evolution else color
					tile.stroke.Thickness = if evolved then 2.5 else 1.5
					tile.evo.Visible = evolved
					for index, pip in tile.pips do
						pip.Visible = not evolved
						pip.BackgroundColor3 = if index <= level then color else COLORS.dim
					end
					slot += 1
				end
			end
			for index = slot, #slots do
				local tile = slots[index]
				tile.id = nil
				tile.icon.Text = ""
				tile.stroke.Color = COLORS.stroke
				tile.evo.Visible = false
				for _, pip in tile.pips do
					pip.Visible = false
				end
			end
		end
		fill(weaponSlots, sortedIds(Config.WEAPONS), "W_", COLORS.weapon)
		fill(passiveSlots, sortedIds(Config.PASSIVES), "P_", COLORS.passive)
	end
	player.AttributeChanged:Connect(refresh)
	refresh()

	local resume = Theme.button(COLORS.good, {
		Name = "Resume",
		Size = UDim2.fromOffset(180, 46),
		Position = UDim2.new(1, -20, 1, -18),
		AnchorPoint = Vector2.new(1, 1),
		Font = Theme.FONTS.heading,
		TextSize = 18,
		Parent = panel,
	})
	resume.Activated:Connect(PauseMenu.toggle)
	local settings = Theme.button(COLORS.panelLight, {
		Name = "Settings",
		Size = UDim2.fromOffset(140, 46),
		Position = UDim2.new(1, -212, 1, -18),
		AnchorPoint = Vector2.new(1, 1),
		Text = "⚙ SETTINGS",
		Parent = panel,
	})
	settings.Activated:Connect(AudioSettings.toggle)

	-- The ⏸ button, left of the audio buttons in the top-right row; only during a run.
	local buttonScreen = Create("ScreenGui", {
		Name = "PauseButton",
		ResetOnSpawn = false,
		DisplayOrder = 2,
		Parent = player:WaitForChild("PlayerGui"),
	})
	-- Scales with the top-right buttons on small screens.
	local buttonGui = Theme.fitRoot(buttonScreen)
	local pauseButton = Create("TextButton", {
		Name = "Pause",
		Size = UDim2.fromOffset(BUTTON_SIZE, BUTTON_SIZE),
		Position = UDim2.new(1, -12 - (BUTTON_SIZE * 3 + 16) - 8, 0, 22),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = Color3.fromRGB(35, 32, 45),
		BackgroundTransparency = 0.2,
		Font = Theme.FONTS.heading,
		TextSize = 16,
		TextColor3 = COLORS.text,
		Text = "II",
		Parent = buttonGui,
	})
	Create("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = pauseButton })
	pauseButton.Activated:Connect(PauseMenu.toggle)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not gameProcessed and (input.KeyCode == Enum.KeyCode.P or input.KeyCode == Enum.KeyCode.ButtonY) then
			PauseMenu.toggle()
		end
	end)

	RunService.RenderStepped:Connect(function()
		local arena = CurrentArena.get()
		local inRun = arena ~= nil and IN_RUN[arena:GetAttribute("Phase") :: string] == true
		pauseButton.Visible = inRun
		if newGui.Enabled then
			if not inRun then
				-- The run ended (or the player left) with the menu open.
				newGui.Enabled = false
				return
			end
			local solo = partySize(arena :: Instance) == 1
			local text = if solo then "PAUSED" else "YOUR BUILD"
			if title.Text ~= text then
				title.Text = text
				resume.Text = if solo then "RESUME" else "CLOSE"
			end
		end
	end)
end

return PauseMenu
