--!strict
-- The in-run HUD: stage and timer, kills, portal charge, and a center banner for the countdown
-- and stage transitions. Everything is read from the Arena's attributes (see server/Run.luau).
-- Placeholder look; polish comes in M4.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Create = require(script.Parent.Create)
local Config = require(ReplicatedStorage.Shared.Config.Run)
local UpgradesConfig = require(ReplicatedStorage.Shared.Config.Upgrades)
local TimeFormat = require(ReplicatedStorage.Shared.TimeFormat)

local TEXT_COLOR = Color3.fromRGB(255, 255, 255)
local OVERTIME_COLOR = Color3.fromRGB(255, 90, 90)
local PORTAL_COLOR = Color3.fromRGB(190, 120, 255)
local XP_COLOR = Color3.fromRGB(90, 180, 255)
local FONT = Enum.Font.GothamBold

local Hud = {}

local function label(parent: Instance, name: string, size: UDim2, position: UDim2, textSize: number): TextLabel
	return Create("TextLabel", {
		Name = name,
		Size = size,
		Position = position,
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		Font = FONT,
		TextSize = textSize,
		TextColor3 = TEXT_COLOR,
		TextStrokeTransparency = 0.4,
		Text = "",
		Parent = parent,
	})
end

-- Sets a property only when it changes, so per-frame updates don't churn the UI.
local function set(instance: Instance, property: string, value: any)
	if (instance :: any)[property] ~= value then
		(instance :: any)[property] = value
	end
end

function Hud.start(arena: Instance)
	local gui = Create("ScreenGui", {
		Name = "Hud",
		ResetOnSpawn = false,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})

	-- Party XP across the top of the screen, with the level at its left end.
	local xpBack = Create("Frame", {
		Name = "XP",
		Size = UDim2.new(1, -16, 0, 12),
		Position = UDim2.new(0.5, 0, 0, 2),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Color3.fromRGB(20, 30, 45),
		BorderSizePixel = 0,
		Parent = gui,
	})
	Create("UICorner", { CornerRadius = UDim.new(0, 6), Parent = xpBack })
	local xpFill = Create("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = XP_COLOR,
		BorderSizePixel = 0,
		Parent = xpBack,
	})
	Create("UICorner", { CornerRadius = UDim.new(0, 6), Parent = xpFill })
	local levelLabel = Create("TextLabel", {
		Name = "Level",
		Size = UDim2.fromOffset(80, 22),
		Position = UDim2.fromOffset(4, 14),
		BackgroundTransparency = 1,
		Font = FONT,
		TextSize = 18,
		TextColor3 = XP_COLOR,
		TextStrokeTransparency = 0.4,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = xpBack,
	})

	local top = Create("Frame", {
		Name = "Top",
		Size = UDim2.fromOffset(300, 96),
		Position = UDim2.new(0.5, 0, 0, 16),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	local stageLabel = label(top, "Stage", UDim2.new(1, 0, 0, 20), UDim2.fromScale(0.5, 0), 18)
	local timerLabel = label(top, "Timer", UDim2.new(1, 0, 0, 40), UDim2.new(0.5, 0, 0, 20), 36)
	local killsLabel = label(top, "Kills", UDim2.new(1, 0, 0, 20), UDim2.new(0.5, 0, 0, 62), 16)

	local portal = Create("Frame", {
		Name = "Portal",
		Size = UDim2.fromOffset(260, 44),
		Position = UDim2.new(0.5, 0, 0, 116),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})
	local portalLabel = label(portal, "Label", UDim2.new(1, 0, 0, 20), UDim2.fromScale(0.5, 0), 16)
	portalLabel.TextColor3 = PORTAL_COLOR
	local barBack = Create("Frame", {
		Name = "Bar",
		Size = UDim2.new(1, 0, 0, 14),
		Position = UDim2.fromOffset(0, 24),
		BackgroundColor3 = Color3.fromRGB(30, 20, 45),
		BorderSizePixel = 0,
		Parent = portal,
	})
	Create("UICorner", { CornerRadius = UDim.new(0, 7), Parent = barBack })
	local barFill = Create("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = PORTAL_COLOR,
		BorderSizePixel = 0,
		Parent = barBack,
	})
	Create("UICorner", { CornerRadius = UDim.new(0, 7), Parent = barFill })

	local banner = label(gui, "Banner", UDim2.new(1, 0, 0, 80), UDim2.fromScale(0.5, 0.3), 64)

	-- The local player's upgrades, bottom-left. Placeholder for icons in M4.
	local buildLabel = Create("TextLabel", {
		Name = "Build",
		Size = UDim2.fromOffset(220, 160),
		Position = UDim2.new(0, 12, 1, -12),
		AnchorPoint = Vector2.new(0, 1),
		BackgroundTransparency = 1,
		Font = FONT,
		TextSize = 15,
		TextColor3 = TEXT_COLOR,
		TextStrokeTransparency = 0.4,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Bottom,
		Text = "",
		Parent = gui,
	})
	local localPlayer = Players.LocalPlayer
	local function refreshBuild()
		local lines = {}
		for id, def in UpgradesConfig.WEAPONS do
			local level = localPlayer:GetAttribute("W_" .. id)
			if typeof(level) == "number" then
				table.insert(lines, `{def.name}  {level}`)
			end
		end
		for id, def in UpgradesConfig.PASSIVES do
			local level = localPlayer:GetAttribute("P_" .. id)
			if typeof(level) == "number" then
				table.insert(lines, `{def.name}  {level}`)
			end
		end
		buildLabel.Text = table.concat(lines, "\n")
	end
	localPlayer.AttributeChanged:Connect(refreshBuild)
	refreshBuild()

	RunService.RenderStepped:Connect(function()
		local now = workspace:GetServerTimeNow()
		local phase = arena:GetAttribute("Phase")
		local stage = arena:GetAttribute("Stage") or 0
		local endsAt = arena:GetAttribute("PhaseEndsAt") or 0
		local inRun = phase == "Countdown" or phase == "Stage" or phase == "Overtime" or phase == "Transition"

		set(top, "Visible", inRun)
		set(buildLabel, "Visible", inRun)
		set(xpBack, "Visible", inRun)
		local toNext = arena:GetAttribute("XPToNext") or 1
		set(xpFill, "Size", UDim2.fromScale(math.clamp((arena:GetAttribute("PartyXP") or 0) / toNext, 0, 1), 1))
		set(levelLabel, "Text", `LV {arena:GetAttribute("PartyLevel") or 1}`)
		set(stageLabel, "Text", `STAGE {stage} / {Config.STAGE_COUNT}`)
		set(killsLabel, "Text", `Kills {arena:GetAttribute("Kills") or 0}`)
		if phase == "Overtime" then
			set(timerLabel, "Text", "OVERTIME")
			set(timerLabel, "TextColor3", OVERTIME_COLOR)
		elseif phase == "Stage" then
			set(timerLabel, "Text", TimeFormat.minutesSeconds(math.ceil(endsAt - now)))
			set(timerLabel, "TextColor3", TEXT_COLOR)
		else
			set(timerLabel, "Text", "")
		end

		set(portal, "Visible", phase == "Overtime")
		if phase == "Overtime" then
			local charge = arena:GetAttribute("PortalCharge") or 0
			set(portalLabel, "Text", `CHARGE THE PORTAL  {math.floor(charge * 100)}%`)
			set(barFill, "Size", UDim2.fromScale(math.clamp(charge, 0, 1), 1))
		end

		if phase == "Countdown" then
			set(banner, "Text", tostring(math.max(1, math.ceil(endsAt - now))))
		elseif phase == "Transition" then
			set(banner, "Text", `STAGE {stage}`)
		else
			set(banner, "Text", "")
		end
	end)
end

return Hud
