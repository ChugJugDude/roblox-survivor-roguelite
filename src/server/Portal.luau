--!strict
-- The overtime portal: it opens near a living player, and fills while any living player stands
-- inside it. Its charge (0 to 1) is published as the Arena's PortalCharge attribute.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Arena = require(script.Parent.Arena)
local Characters = require(script.Parent.Characters)
local Config = require(ReplicatedStorage.Shared.Config.Run)

local PORTAL_COLOR = Color3.fromRGB(170, 90, 255)
-- Only republish the charge when it moves by at least this much, to limit replication.
local CHARGE_PUBLISH_STEP = 0.02

local random = Random.new()
local arena: Arena.Arena? = nil
local model: Model? = nil
local center = Vector3.zero
local charge = 0
local publishedCharge = 0

local Portal = {}

local function publishCharge(force: boolean?)
	local currentArena = arena
	if currentArena and (force or math.abs(charge - publishedCharge) >= CHARGE_PUBLISH_STEP or charge >= 1) then
		publishedCharge = charge
		currentArena.model:SetAttribute("PortalCharge", charge)
	end
end

local function makePart(parent: Instance, name: string, size: Vector3, cframe: CFrame, transparency: number)
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = Enum.PartType.Cylinder
	part.Size = size
	part.CFrame = cframe
	part.Color = PORTAL_COLOR
	part.Material = Enum.Material.Neon
	part.Transparency = transparency
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = parent
end

-- A point on the ring around a random living player, inside the walls.
local function pickPosition(currentArena: Arena.Arena, targets: { Characters.Target }): (number, number)
	local margin = Config.PORTAL_RADIUS + 4
	if #targets == 0 then
		return currentArena.origin.X, currentArena.origin.Z
	end
	local target = targets[random:NextInteger(1, #targets)]
	local x, z = target.x, target.z
	for _ = 1, 12 do
		local angle = random:NextNumber(0, 2 * math.pi)
		local distance = random:NextNumber(Config.PORTAL_DISTANCE_MIN, Config.PORTAL_DISTANCE_MAX)
		x = target.x + math.cos(angle) * distance
		z = target.z + math.sin(angle) * distance
		local clampedX, clampedZ = Arena.clamp(currentArena, x, z, margin)
		if clampedX == x and clampedZ == z then
			return x, z
		end
	end
	return Arena.clamp(currentArena, x, z, margin)
end

function Portal.init(newArena: Arena.Arena)
	arena = newArena
	newArena.model:SetAttribute("PortalCharge", 0)
end

function Portal.open(targets: { Characters.Target })
	local currentArena = assert(arena, "Portal.init() must be called first")
	Portal.close()

	local x, z = pickPosition(currentArena, targets)
	center = Vector3.new(x, currentArena.origin.Y, z)

	local newModel = Instance.new("Model")
	newModel.Name = "Portal"
	local diameter = Config.PORTAL_RADIUS * 2
	-- A cylinder's axis is its X size, so rotate it to stand up (Z 90 degrees).
	local upright = CFrame.Angles(0, 0, math.rad(90))
	makePart(newModel, "Pad", Vector3.new(0.4, diameter, diameter), CFrame.new(center) * upright, 0.2)
	makePart(newModel, "Beam", Vector3.new(60, 3, 3), CFrame.new(center + Vector3.new(0, 30, 0)) * upright, 0.5)
	newModel.Parent = currentArena.model
	model = newModel

	charge = 0
	publishCharge(true)
end

function Portal.close()
	if model then
		model:Destroy()
		model = nil
	end
	charge = 0
	publishCharge(true)
end

-- Adds charge while any living player is inside. Returns true once fully charged.
function Portal.step(dt: number, targets: { Characters.Target }): boolean
	if not model then
		return false
	end
	local radiusSq = Config.PORTAL_RADIUS * Config.PORTAL_RADIUS
	for _, target in targets do
		local dx, dz = target.x - center.X, target.z - center.Z
		if dx * dx + dz * dz <= radiusSq then
			charge = math.min(1, charge + dt / Config.PORTAL_CHARGE_TIME)
			publishCharge()
			break
		end
	end
	return charge >= 1
end

-- Studio dev command: fill the charge instantly.
function Portal.fill()
	if model then
		charge = 1
		publishCharge(true)
	end
end

return Portal
