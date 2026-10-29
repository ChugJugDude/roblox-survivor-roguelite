--!strict
-- Builds client-side enemy visuals from primitive parts. Placeholder art: swap these for real
-- low-poly models later without touching the renderer.
--
-- Every part is anchored and moved directly by EnemyRenderer. `offsets` holds each part's CFrame
-- relative to the enemy's root (on the ground, facing -Z), and `colors` its normal color so a hit
-- flash can restore it.

export type Visual = {
	model: Model,
	parts: { BasePart },
	offsets: { CFrame },
	colors: { Color3 },
}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EnemyConfig = require(ReplicatedStorage.Shared.Config.Enemies)

local ELITE_GLOW = Color3.fromRGB(255, 200, 60)

local EnemyModels = {}

local function newVisual(name: string): Visual
	local model = Instance.new("Model")
	model.Name = name
	return { model = model, parts = {}, offsets = {}, colors = {} }
end

local function addPart(
	visual: Visual,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material?,
	shape: Enum.PartType?
)
	local part = Instance.new("Part")
	part.Shape = shape or Enum.PartType.Block
	part.Size = size
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = visual.model
	table.insert(visual.parts, part)
	table.insert(visual.offsets, offset)
	table.insert(visual.colors, color)
end

-- A goblin at any scale. The Goblin Giant is a big, darker one with a club.
local function buildGoblin(name: string, scale: number, body: Color3, skin: Color3): Visual
	local visual = newVisual(name)
	local eye = Color3.fromRGB(255, 220, 60)
	local function at(x: number, y: number, z: number): CFrame
		return CFrame.new(x * scale, y * scale, z * scale)
	end
	addPart(visual, Vector3.new(2.4, 2, 2) * scale, at(0, 1.2, 0), body)
	addPart(visual, Vector3.new(2, 1.6, 1.8) * scale, at(0, 2.9, 0), skin)
	addPart(visual, Vector3.new(1.2, 0.5, 0.4) * scale, at(-1.4, 3.2, 0) * CFrame.Angles(0, 0, math.rad(25)), skin)
	addPart(visual, Vector3.new(1.2, 0.5, 0.4) * scale, at(1.4, 3.2, 0) * CFrame.Angles(0, 0, math.rad(-25)), skin)
	addPart(visual, Vector3.new(0.4, 0.4, 0.2) * scale, at(-0.45, 3, -0.95), eye, Enum.Material.Neon)
	addPart(visual, Vector3.new(0.4, 0.4, 0.2) * scale, at(0.45, 3, -0.95), eye, Enum.Material.Neon)
	return visual
end

local builders: { [string]: () -> Visual } = {
	Goblin = function()
		return buildGoblin("Goblin", 1, Color3.fromRGB(96, 150, 64), Color3.fromRGB(120, 186, 80))
	end,

	GoblinGiant = function()
		local scale = 2.3
		local visual = buildGoblin("GoblinGiant", scale, Color3.fromRGB(70, 105, 45), Color3.fromRGB(95, 145, 60))
		-- A wooden club held out to the side.
		addPart(
			visual,
			Vector3.new(0.8, 4, 0.8) * scale / 2,
			CFrame.new(1.9 * scale, 1.6 * scale, -0.4 * scale) * CFrame.Angles(math.rad(-30), 0, 0),
			Color3.fromRGB(120, 80, 40),
			Enum.Material.Wood
		)
		return visual
	end,

	-- Hovers at head height with wings out, so it reads as flying from above.
	Bat = function()
		local visual = newVisual("Bat")
		local fur = Color3.fromRGB(70, 45, 90)
		local wing = Color3.fromRGB(110, 70, 140)
		addPart(visual, Vector3.new(1.2, 1, 1.2), CFrame.new(0, 3.5, 0), fur, nil, Enum.PartType.Ball)
		addPart(visual, Vector3.new(1.6, 0.15, 1), CFrame.new(-1.3, 3.7, 0) * CFrame.Angles(0, 0, math.rad(15)), wing)
		addPart(visual, Vector3.new(1.6, 0.15, 1), CFrame.new(1.3, 3.7, 0) * CFrame.Angles(0, 0, math.rad(-15)), wing)
		addPart(
			visual,
			Vector3.new(0.25, 0.25, 0.1),
			CFrame.new(-0.25, 3.6, -0.6),
			Color3.fromRGB(255, 70, 70),
			Enum.Material.Neon
		)
		addPart(
			visual,
			Vector3.new(0.25, 0.25, 0.1),
			CFrame.new(0.25, 3.6, -0.6),
			Color3.fromRGB(255, 70, 70),
			Enum.Material.Neon
		)
		return visual
	end,

	-- Bone-white with a purple bow, matching its purple arrows.
	SkeletonArcher = function()
		local visual = newVisual("SkeletonArcher")
		local bone = Color3.fromRGB(225, 220, 200)
		addPart(visual, Vector3.new(1.6, 2.2, 1), CFrame.new(0, 1.4, 0), bone)
		addPart(visual, Vector3.new(1.5, 1.4, 1.4), CFrame.new(0, 3.2, 0), bone)
		addPart(
			visual,
			Vector3.new(0.35, 0.35, 0.1),
			CFrame.new(-0.35, 3.3, -0.72),
			Color3.fromRGB(190, 90, 255),
			Enum.Material.Neon
		)
		addPart(
			visual,
			Vector3.new(0.35, 0.35, 0.1),
			CFrame.new(0.35, 3.3, -0.72),
			Color3.fromRGB(190, 90, 255),
			Enum.Material.Neon
		)
		addPart(
			visual,
			Vector3.new(0.25, 3, 0.25),
			CFrame.new(1.1, 2, -0.5),
			Color3.fromRGB(150, 80, 200),
			Enum.Material.Wood
		)
		return visual
	end,
}

-- An archer at any colors: a body, a head with glowing eyes, and a bow.
local function buildArcher(name: string, body: Color3, head: Color3, eye: Color3, bow: Color3): Visual
	local visual = newVisual(name)
	addPart(visual, Vector3.new(1.6, 2.2, 1), CFrame.new(0, 1.4, 0), body)
	addPart(visual, Vector3.new(1.5, 1.4, 1.4), CFrame.new(0, 3.2, 0), head)
	addPart(visual, Vector3.new(0.35, 0.35, 0.1), CFrame.new(-0.35, 3.3, -0.72), eye, Enum.Material.Neon)
	addPart(visual, Vector3.new(0.35, 0.35, 0.1), CFrame.new(0.35, 3.3, -0.72), eye, Enum.Material.Neon)
	addPart(visual, Vector3.new(0.25, 3, 0.25), CFrame.new(1.1, 2, -0.5), bow, Enum.Material.Wood)
	return visual
end

local LAVA = Color3.fromRGB(255, 110, 30)
local BASALT = Color3.fromRGB(60, 46, 42)
-- Hounds are lighter rock, so they don't vanish against the Volcano's dark floor.
local HOUND_ROCK = Color3.fromRGB(120, 78, 60)

-- The Volcano's enemies: reskins of the Meadow's.
builders.FireImp = function()
	local visual = buildGoblin("FireImp", 0.95, Color3.fromRGB(150, 40, 30), Color3.fromRGB(210, 75, 45))
	local horn = Color3.fromRGB(45, 30, 28)
	addPart(visual, Vector3.new(0.3, 0.8, 0.3), CFrame.new(-0.5, 4, 0) * CFrame.Angles(0, 0, math.rad(15)), horn)
	addPart(visual, Vector3.new(0.3, 0.8, 0.3), CFrame.new(0.5, 4, 0) * CFrame.Angles(0, 0, math.rad(-15)), horn)
	return visual
end

-- A low, four-legged hound of dark rock with a glowing lava stripe down its back.
builders.MagmaHound = function()
	local visual = newVisual("MagmaHound")
	addPart(visual, Vector3.new(1.3, 1.1, 2.6), CFrame.new(0, 1.6, 0), HOUND_ROCK, Enum.Material.Slate)
	addPart(visual, Vector3.new(1.1, 1, 1.1), CFrame.new(0, 2.1, -1.6), HOUND_ROCK, Enum.Material.Slate)
	addPart(visual, Vector3.new(0.35, 0.2, 2.4), CFrame.new(0, 2.2, 0.1), LAVA, Enum.Material.Neon)
	addPart(visual, Vector3.new(0.25, 0.25, 0.1), CFrame.new(-0.3, 2.2, -2.18), LAVA, Enum.Material.Neon)
	addPart(visual, Vector3.new(0.25, 0.25, 0.1), CFrame.new(0.3, 2.2, -2.18), LAVA, Enum.Material.Neon)
	for _, x in { -0.45, 0.45 } do
		for _, z in { -0.9, 0.9 } do
			addPart(visual, Vector3.new(0.35, 1.1, 0.35), CFrame.new(x, 0.55, z), HOUND_ROCK, Enum.Material.Slate)
		end
	end
	return visual
end

builders.EmberArcher = function()
	return buildArcher(
		"EmberArcher",
		Color3.fromRGB(120, 32, 26),
		Color3.fromRGB(60, 22, 20),
		Color3.fromRGB(255, 150, 40),
		Color3.fromRGB(45, 30, 28)
	)
end

-- A hulking slab of dark rock with lava glowing through cracks in its chest.
builders.MagmaGolem = function()
	local visual = newVisual("MagmaGolem")
	local scale = 2.1
	local function at(x: number, y: number, z: number): CFrame
		return CFrame.new(x * scale, y * scale, z * scale)
	end
	addPart(visual, Vector3.new(0.9, 1.4, 0.9) * scale, at(-0.6, 0.7, 0), BASALT, Enum.Material.Slate)
	addPart(visual, Vector3.new(0.9, 1.4, 0.9) * scale, at(0.6, 0.7, 0), BASALT, Enum.Material.Slate)
	addPart(visual, Vector3.new(2.6, 2, 1.6) * scale, at(0, 2.3, 0), BASALT, Enum.Material.Slate)
	addPart(visual, Vector3.new(1.2, 1, 1.1) * scale, at(0, 3.7, -0.1), BASALT, Enum.Material.Slate)
	addPart(visual, Vector3.new(0.9, 2, 0.9) * scale, at(-1.75, 2.1, 0), BASALT, Enum.Material.Slate)
	addPart(visual, Vector3.new(0.9, 2, 0.9) * scale, at(1.75, 2.1, 0), BASALT, Enum.Material.Slate)
	-- Lava cracks across the chest, and glowing eyes.
	addPart(
		visual,
		Vector3.new(1.8, 0.15, 0.1) * scale,
		at(0, 2.6, -0.82) * CFrame.Angles(0, 0, math.rad(15)),
		LAVA,
		Enum.Material.Neon
	)
	addPart(
		visual,
		Vector3.new(1.2, 0.15, 0.1) * scale,
		at(0.2, 2, -0.82) * CFrame.Angles(0, 0, math.rad(-20)),
		LAVA,
		Enum.Material.Neon
	)
	addPart(visual, Vector3.new(0.25, 0.2, 0.1) * scale, at(-0.25, 3.8, -0.67), LAVA, Enum.Material.Neon)
	addPart(visual, Vector3.new(0.25, 0.2, 0.1) * scale, at(0.25, 3.8, -0.67), LAVA, Enum.Material.Neon)
	return visual
end

-- The final boss: a huge, hunched grey-olive brute with tusks and a spiked club.
builders.Ogre = function()
	local visual = newVisual("Ogre")
	local skin = Color3.fromRGB(125, 135, 95)
	local dark = Color3.fromRGB(95, 100, 70)
	local cloth = Color3.fromRGB(110, 75, 45)
	local tusk = Color3.fromRGB(240, 230, 200)
	local wood = Color3.fromRGB(90, 60, 35)
	local eye = Color3.fromRGB(255, 60, 40)
	-- Legs, loincloth, belly, shoulders.
	addPart(visual, Vector3.new(2, 3, 2), CFrame.new(-1.6, 1.5, 0), dark)
	addPart(visual, Vector3.new(2, 3, 2), CFrame.new(1.6, 1.5, 0), dark)
	addPart(visual, Vector3.new(5.4, 1.6, 3.6), CFrame.new(0, 3.4, 0), cloth)
	addPart(visual, Vector3.new(6, 4.2, 4.4), CFrame.new(0, 6, 0.2), skin)
	addPart(visual, Vector3.new(7.2, 2, 3.6), CFrame.new(0, 8.4, 0.6) * CFrame.Angles(math.rad(-10), 0, 0), skin)
	-- Head, hunched forward, with eyes and tusks.
	addPart(visual, Vector3.new(2.8, 2.4, 2.6), CFrame.new(0, 8.6, -1.6), skin)
	addPart(visual, Vector3.new(0.5, 0.4, 0.2), CFrame.new(-0.6, 9.1, -2.95), eye, Enum.Material.Neon)
	addPart(visual, Vector3.new(0.5, 0.4, 0.2), CFrame.new(0.6, 9.1, -2.95), eye, Enum.Material.Neon)
	addPart(visual, Vector3.new(0.4, 1, 0.4), CFrame.new(-0.8, 7.9, -2.9) * CFrame.Angles(math.rad(-20), 0, 0), tusk)
	addPart(visual, Vector3.new(0.4, 1, 0.4), CFrame.new(0.8, 7.9, -2.9) * CFrame.Angles(math.rad(-20), 0, 0), tusk)
	-- Arms: the left hangs, the right holds the club forward.
	addPart(visual, Vector3.new(1.8, 5, 1.8), CFrame.new(-4.2, 5.6, 0) * CFrame.Angles(0, 0, math.rad(-8)), skin)
	addPart(
		visual,
		Vector3.new(1.8, 5, 1.8),
		CFrame.new(4.2, 5.8, -1) * CFrame.Angles(math.rad(35), 0, math.rad(8)),
		skin
	)
	addPart(
		visual,
		Vector3.new(1, 6, 1),
		CFrame.new(4.6, 4.6, -3.6) * CFrame.Angles(math.rad(70), 0, 0),
		wood,
		Enum.Material.Wood
	)
	addPart(
		visual,
		Vector3.new(2.2, 3, 2.2),
		CFrame.new(4.6, 3.6, -6.2) * CFrame.Angles(math.rad(70), 0, 0),
		wood,
		Enum.Material.Wood
	)
	return visual
end

-- Wooden supply crate with metal bands; breaks into an item.
builders.Crate = function()
	local visual = newVisual("Crate")
	local wood, band = Color3.fromRGB(160, 110, 60), Color3.fromRGB(90, 90, 100)
	addPart(visual, Vector3.new(2.6, 2.4, 2.6), CFrame.new(0, 1.2, 0), wood, Enum.Material.Wood)
	addPart(visual, Vector3.new(2.7, 0.3, 2.7), CFrame.new(0, 0.5, 0), band, Enum.Material.Metal)
	addPart(visual, Vector3.new(2.7, 0.3, 2.7), CFrame.new(0, 1.9, 0), band, Enum.Material.Metal)
	return visual
end

-- A bright block, so an enemy kind without a model is obvious instead of invisible.
local function buildFallback(kind: string): Visual
	local visual = newVisual(kind)
	addPart(visual, Vector3.new(3, 3, 3), CFrame.new(0, 1.5, 0), Color3.fromRGB(255, 0, 255))
	return visual
end

-- Grows a visual about its root and gives it a gold glow, for elites.
local function makeElite(visual: Visual)
	local scale = EnemyConfig.ELITE.scale
	for i, part in visual.parts do
		part.Size *= scale
		local offset = visual.offsets[i]
		visual.offsets[i] = offset - offset.Position + offset.Position * scale
	end
	local glow = Instance.new("Highlight")
	glow.FillTransparency = 0.75
	glow.FillColor = ELITE_GLOW
	glow.OutlineColor = ELITE_GLOW
	glow.DepthMode = Enum.HighlightDepthMode.Occluded
	glow.Parent = visual.model
end

-- A new visual for `kind`; elites come out bigger and glowing.
function EnemyModels.create(kind: string, elite: boolean?): Visual
	local build = builders[kind]
	local visual
	if build then
		visual = build()
	else
		warn(`[EnemyModels] No model for enemy kind "{kind}"; using a placeholder block.`)
		visual = buildFallback(kind)
	end
	if elite then
		makeElite(visual)
	end
	return visual
end

return EnemyModels
