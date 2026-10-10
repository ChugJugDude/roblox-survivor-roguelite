--!strict
-- Builds client-side enemy visuals from primitive parts. Placeholder art for M0: swap these for
-- real low-poly models later without touching the renderer.
--
-- Every part is anchored and moved directly by EnemyRenderer. `offsets` holds each part's CFrame
-- relative to the enemy's root (on the ground, facing -Z).

export type Visual = {
	model: Model,
	parts: { BasePart },
	offsets: { CFrame },
}

local EnemyModels = {}

local function newVisual(name: string): Visual
	local model = Instance.new("Model")
	model.Name = name
	return { model = model, parts = {}, offsets = {} }
end

local function addPart(visual: Visual, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?)
	local part = Instance.new("Part")
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
end

local builders: { [string]: () -> Visual } = {
	Goblin = function()
		local visual = newVisual("Goblin")
		local skin = Color3.fromRGB(120, 186, 80)
		local eye = Color3.fromRGB(255, 220, 60)
		addPart(visual, Vector3.new(2.4, 2, 2), CFrame.new(0, 1.2, 0), Color3.fromRGB(96, 150, 64))
		addPart(visual, Vector3.new(2, 1.6, 1.8), CFrame.new(0, 2.9, 0), skin)
		addPart(visual, Vector3.new(1.2, 0.5, 0.4), CFrame.new(-1.4, 3.2, 0) * CFrame.Angles(0, 0, math.rad(25)), skin)
		addPart(visual, Vector3.new(1.2, 0.5, 0.4), CFrame.new(1.4, 3.2, 0) * CFrame.Angles(0, 0, math.rad(-25)), skin)
		addPart(visual, Vector3.new(0.4, 0.4, 0.2), CFrame.new(-0.45, 3, -0.95), eye, Enum.Material.Neon)
		addPart(visual, Vector3.new(0.4, 0.4, 0.2), CFrame.new(0.45, 3, -0.95), eye, Enum.Material.Neon)
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
