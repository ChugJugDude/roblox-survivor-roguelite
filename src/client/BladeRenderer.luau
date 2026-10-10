--!strict
-- Draws Spinning Blades around every living character. Angles come from the shared server clock
-- (shared/BladeOrbit), so the blades line up with where the server checks for hits.
-- M0 gives every player the blade. Once weapons are upgrades, the server will say who has what.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BladeOrbit = require(ReplicatedStorage.Shared.BladeOrbit)
local Config = require(ReplicatedStorage.Shared.Config.Weapons).SpinningBlade

-- How far below the character's root part the blades spin (roughly waist height).
local HEIGHT_OFFSET = -1
local BLADE_COLOR = Color3.fromRGB(225, 235, 255)

local bladesByCharacter: { [Model]: { BasePart } } = {}
local folder: Folder? = nil
local started = false

-- Reused every frame.
local seen: { [Model]: boolean } = {}
local moveParts: { BasePart } = {}
local moveCFrames: { CFrame } = {}

local BladeRenderer = {}

local function createBlades(): { BasePart }
	local length = Config.outerRadius - Config.innerRadius
	local blades = {}
	for _ = 1, Config.bladeCount do
		local part = Instance.new("Part")
		part.Name = "SpinningBlade"
		part.Size = Vector3.new(Config.width, 0.3, length)
		part.Color = BLADE_COLOR
		part.Material = Enum.Material.Neon
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Parent = folder
		table.insert(blades, part)
	end
	return blades
end

local function destroyBlades(blades: { BasePart })
	for _, part in blades do
		part:Destroy()
	end
end

local function render()
	local now = workspace:GetServerTimeNow()
	local midRadius = (Config.innerRadius + Config.outerRadius) / 2
	table.clear(seen)
	table.clear(moveParts)
	table.clear(moveCFrames)

	for _, player in Players:GetPlayers() do
		local character = player.Character
		if not character then
			continue
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local root = character:FindFirstChild("HumanoidRootPart")
		if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
			continue
		end

		local blades = bladesByCharacter[character]
		if not blades then
			blades = createBlades()
			bladesByCharacter[character] = blades
		end
		seen[character] = true

		local center = root.Position + Vector3.new(0, HEIGHT_OFFSET, 0)
		for index, part in blades do
			local angle = BladeOrbit.angle(index, now)
			local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
			local middle = center + direction * midRadius
			table.insert(moveParts, part)
			table.insert(moveCFrames, CFrame.lookAt(middle, middle + direction))
		end
	end

	-- Remove blades for characters that died, respawned, or left.
	for character, blades in bladesByCharacter do
		if not seen[character] then
			destroyBlades(blades)
			bladesByCharacter[character] = nil
		end
	end

	if #moveParts > 0 then
		workspace:BulkMoveTo(moveParts, moveCFrames, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

function BladeRenderer.start()
	assert(not started, "BladeRenderer.start() was called twice")
	started = true

	local newFolder = Instance.new("Folder")
	newFolder.Name = "BladeVisuals"
	newFolder.Parent = workspace
	folder = newFolder

	RunService.RenderStepped:Connect(render)
end

return BladeRenderer
