--!strict
-- The shared look for every screen: colors, fonts, and helpers for the common pieces (panels, labels,
-- bars, buttons), built on Create. Change the palette here and every screen follows.

local Create = require(script.Parent.Create)

local Theme = {}

Theme.COLORS = table.freeze({
	panel = Color3.fromRGB(24, 22, 34),
	panelLight = Color3.fromRGB(40, 36, 56),
	stroke = Color3.fromRGB(80, 72, 110),
	text = Color3.fromRGB(255, 255, 255),
	subtext = Color3.fromRGB(200, 196, 220),
	dim = Color3.fromRGB(110, 104, 140),
	xp = Color3.fromRGB(90, 180, 255),
	portal = Color3.fromRGB(190, 120, 255),
	boss = Color3.fromRGB(235, 70, 60),
	overtime = Color3.fromRGB(255, 90, 90),
	health = Color3.fromRGB(110, 220, 110),
	lowHealth = Color3.fromRGB(240, 80, 70),
	weapon = Color3.fromRGB(235, 145, 60),
	passive = Color3.fromRGB(80, 160, 255),
	evolution = Color3.fromRGB(255, 210, 60),
	heal = Color3.fromRGB(90, 200, 110),
	shard = Color3.fromRGB(120, 220, 255),
	good = Color3.fromRGB(80, 190, 100),
	bad = Color3.fromRGB(200, 70, 70),
})

Theme.FONTS = table.freeze({
	heading = Enum.Font.GothamBlack,
	body = Enum.Font.GothamBold,
	light = Enum.Font.GothamMedium,
})

Theme.CORNER = 10
Theme.PANEL_TRANSPARENCY = 0.15

-- A rounded, dark panel with a thin outline. `props` are passed to Create (Size, Position, ...).
function Theme.panel(props: { [string]: any }): Frame
	local frame = Create("Frame", {
		BackgroundColor3 = Theme.COLORS.panel,
		BackgroundTransparency = Theme.PANEL_TRANSPARENCY,
		BorderSizePixel = 0,
	})
	for key, value in props do
		if key ~= "Parent" then
			(frame :: any)[key] = value
		end
	end
	Create("UICorner", { CornerRadius = UDim.new(0, Theme.CORNER), Parent = frame })
	Create("UIStroke", {
		Color = Theme.COLORS.stroke,
		Thickness = 1.5,
		Transparency = 0.3,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = frame,
	})
	frame.Parent = props.Parent
	return frame
end

-- A transparent text label with an outline so it reads over the arena.
function Theme.label(props: { [string]: any }): TextLabel
	local label = Create("TextLabel", {
		BackgroundTransparency = 1,
		Font = Theme.FONTS.body,
		TextColor3 = Theme.COLORS.text,
		TextStrokeTransparency = 0.5,
		TextSize = 16,
		Text = "",
	})
	for key, value in props do
		if key ~= "Parent" then
			(label :: any)[key] = value
		end
	end
	label.Parent = props.Parent
	return label
end

export type Bar = {
	back: Frame,
	fill: Frame,
}

-- A rounded progress bar; set `fill.Size` to UDim2.fromScale(fraction, 1) to fill it.
function Theme.bar(parent: Instance, size: UDim2, position: UDim2, color: Color3): Bar
	local back = Create("Frame", {
		Size = size,
		Position = position,
		BackgroundColor3 = Color3.fromRGB(15, 14, 22),
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		Parent = parent,
	})
	Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = back })
	local fill = Create("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Parent = back,
	})
	Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = fill })
	-- A soft highlight along the top of the fill.
	Create("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 190)),
		Parent = fill,
	})
	return { back = back, fill = fill }
end

-- A rounded button in `color`. `props` are passed to Create (Size, Position, Text, ...).
function Theme.button(color: Color3, props: { [string]: any }): TextButton
	local button = Create("TextButton", {
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		AutoButtonColor = true,
		Font = Theme.FONTS.body,
		TextSize = 16,
		TextColor3 = Theme.COLORS.text,
	})
	for key, value in props do
		if key ~= "Parent" then
			(button :: any)[key] = value
		end
	end
	Create("UICorner", { CornerRadius = UDim.new(0, 8), Parent = button })
	Create("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 200)),
		Parent = button,
	})
	button.Parent = props.Parent
	return button
end

-- The icon for a weapon, passive, or the heal option (Config.Upgrades `icon` fields).
function Theme.upgradeIcon(config: any, id: string): string
	local weapon = config.WEAPONS[id]
	if weapon then
		return weapon.icon
	end
	local passive = config.PASSIVES[id]
	if passive then
		return passive.icon
	end
	return config.HEAL_ICON
end

return Theme
