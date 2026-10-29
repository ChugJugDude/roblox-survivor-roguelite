--!strict
-- Builds an arena (floor and walls) from Config.Arena at a given origin, as a model named `name`
-- under workspace.Arenas. Each match gets its own, far apart from the others and the lobby.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.Arena)
local Worlds = require(ReplicatedStorage.Shared.Config.Worlds)

export type Arena = {
	model: Model,
	origin: Vector3, -- center of the floor's top surface
	halfSize: number, -- distance from the center to the inside of each wall
}

local Arena = {}

local function makePart(name: string, size: Vector3, cframe: CFrame, color: Color3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function arenasFolder(): Folder
	local existing = workspace:FindFirstChild("Arenas")
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = "Arenas"
	folder.Parent = workspace
	return folder
end

-- Lava cracks: glowing seams across the floor, each a few short segments that wander. Decoration
-- only (enemies and players ignore them).
local CRACKS = 16
local CRACK_SEGMENTS = 3
-- Rock pillars set into the walls, for a rough silhouette. In the walls, so they never block play.
local PILLARS_PER_WALL = 3

local function decorate(model: Model, origin: Vector3, half: number, world: Worlds.World)
	local random = Random.new()
	local accent = world.accentColor :: Color3
	for _ = 1, CRACKS do
		local x = origin.X + random:NextNumber(-half + 8, half - 8)
		local z = origin.Z + random:NextNumber(-half + 8, half - 8)
		local angle = random:NextNumber(0, 2 * math.pi)
		for _ = 1, CRACK_SEGMENTS do
			local length = random:NextNumber(4, 10)
			local dx, dz = math.cos(angle) * length, math.sin(angle) * length
			local crack = makePart(
				"LavaCrack",
				Vector3.new(random:NextNumber(0.4, 0.9), 0.1, length),
				CFrame.lookAt(
					Vector3.new(x + dx / 2, origin.Y + 0.03, z + dz / 2),
					Vector3.new(x + dx, origin.Y + 0.03, z + dz)
				),
				accent,
				model
			)
			crack.Material = Enum.Material.Neon
			crack.CanCollide = false
			crack.CanQuery = false
			x += dx
			z += dz
			angle += random:NextNumber(-0.8, 0.8)
		end
	end
	local wallLine = half + Config.WALL_THICKNESS / 2
	for side = 1, 4 do
		for index = 1, PILLARS_PER_WALL do
			local along = (index / (PILLARS_PER_WALL + 1) * 2 - 1) * half + random:NextNumber(-8, 8)
			local x = if side <= 2 then along else (if side == 3 then -wallLine else wallLine)
			local z = if side <= 2 then (if side == 1 then -wallLine else wallLine) else along
			local width = random:NextNumber(5, 8)
			local height = random:NextNumber(12, 18)
			local pillar = makePart(
				"RockPillar",
				Vector3.new(width, height, width),
				CFrame.new(origin.X + x, origin.Y + height / 2, origin.Z + z)
					* CFrame.Angles(0, random:NextNumber(0, math.pi), 0),
				world.wallColor,
				model
			)
			pillar.Material = Enum.Material.Slate
		end
	end
end

-- Builds an arena in `world`'s colors at `origin`, named `name`, and tags it with the world's id (the
-- World attribute) for clients.
function Arena.build(origin: Vector3, name: string, world: Worlds.World): Arena
	local size = Config.SIZE
	local half = size / 2
	local wallThickness = Config.WALL_THICKNESS
	local outer = size + wallThickness * 2

	local model = Instance.new("Model")
	model.Name = name

	makePart(
		"Floor",
		Vector3.new(outer, Config.FLOOR_THICKNESS, outer),
		CFrame.new(origin - Vector3.new(0, Config.FLOOR_THICKNESS / 2, 0)),
		world.floorColor,
		model
	)

	local wallY = origin.Y + Config.WALL_HEIGHT / 2
	local wallOffset = half + wallThickness / 2
	local alongX = Vector3.new(outer, Config.WALL_HEIGHT, wallThickness)
	local alongZ = Vector3.new(wallThickness, Config.WALL_HEIGHT, size)
	makePart("WallNorth", alongX, CFrame.new(origin.X, wallY, origin.Z - wallOffset), world.wallColor, model)
	makePart("WallSouth", alongX, CFrame.new(origin.X, wallY, origin.Z + wallOffset), world.wallColor, model)
	makePart("WallWest", alongZ, CFrame.new(origin.X - wallOffset, wallY, origin.Z), world.wallColor, model)
	makePart("WallEast", alongZ, CFrame.new(origin.X + wallOffset, wallY, origin.Z), world.wallColor, model)

	if world.accentColor then
		decorate(model, origin, half, world)
	end

	-- Debug counters, kept up to date by EnemyService. Handy for playtests and the Studio MCP.
	model:SetAttribute("World", world.id)
	model:SetAttribute("EnemiesAlive", 0)
	model:SetAttribute("Kills", 0)

	model.Parent = arenasFolder()

	return {
		model = model,
		origin = origin,
		halfSize = half,
	}
end

function Arena.destroy(arena: Arena)
	arena.model:Destroy()
end

-- Where players appear: just above the middle of the floor.
function Arena.spawnCFrame(arena: Arena): CFrame
	return CFrame.new(arena.origin + Vector3.new(0, 4, 0))
end

-- Clamps a ground position so it stays `margin` studs inside the walls.
function Arena.clamp(arena: Arena, x: number, z: number, margin: number): (number, number)
	local limit = arena.halfSize - margin
	local origin = arena.origin
	return math.clamp(x, origin.X - limit, origin.X + limit), math.clamp(z, origin.Z - limit, origin.Z + limit)
end

return Arena
