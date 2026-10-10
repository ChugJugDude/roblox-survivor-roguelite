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

-- A bright block, so an enemy kind without a model is obvious instead of invisible.
local function buildFallback(kind: string): Visual
	local visual = newVisual(kind)
	addPart(visual, Vector3.new(3, 3, 3), CFrame.new(0, 1.5, 0), Color3.fromRGB(255, 0, 255))
	return visual
end

function EnemyModels.create(kind: string): Visual
	local build = builders[kind]
	if build then
		return build()
	end
	warn(`[EnemyModels] No model for enemy kind "{kind}"; using a placeholder block.`)
	return buildFallback(kind)
end

return EnemyModels
