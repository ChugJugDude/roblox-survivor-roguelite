--!strict
-- Draws what orbits each living character: Spinning Blades and Warding rings, sized from each
-- player's build (read from their W_ / P_ attributes). Angles come from the shared server clock
-- (shared/BladeOrbit), so they line up with where the server checks for hits.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CurrentArena = require(script.Parent.CurrentArena)
local BladeOrbit = require(ReplicatedStorage.Shared.BladeOrbit)
local GameClock = require(ReplicatedStorage.Shared.GameClock)
local BuildStats = require(ReplicatedStorage.Shared.BuildStats)

-- How far below the character's root part the blades spin (roughly waist height).
local HEIGHT_OFFSET = -1
local BLADE_COLOR = Color3.fromRGB(225, 235, 255)
local BLADESTORM_COLOR = Color3.fromRGB(255, 210, 70)
-- Bladestorm covers a lot of screen, so it's see-through enough for enemy shots under it to show.
local BLADESTORM_TRANSPARENCY = 0.35
-- Warding rings: flat pale-blue discs. Not neon (it would bloom to white like the blades), not
-- cyan (XP gems), and never red (enemy shots).
local WARD_COLOR = Color3.fromRGB(170, 215, 255)
local WARD_TRANSPARENCY = 0.15
local WARD_THICKNESS = 0.3
local WARD_HEIGHT_OFFSET = 0

-- One set of parts orbiting a character.
type Orbiters = {
	parts: { BasePart },
	shape: string, -- count and size the parts were built for
}

type Look = {
	name: string,
	size: Vector3,
	color: Color3,
	transparency: number,
	shape: Enum.PartType,
	material: Enum.Material,
}

local bladesByCharacter: { [Model]: Orbiters } = {}
local wardsByCharacter: { [Model]: Orbiters } = {}
local folder: Folder? = nil
local started = false

-- Reused every frame.
local seenBlades: { [Model]: boolean } = {}
local seenWards: { [Model]: boolean } = {}
local moveParts: { BasePart } = {}
local moveCFrames: { CFrame } = {}

local BladeRenderer = {}

local function destroyOrbiters(orbiters: Orbiters)
	for _, part in orbiters.parts do
		part:Destroy()
	end
end

local function createOrbiters(count: number, look: Look, shape: string): Orbiters
	local parts = {}
	for _ = 1, count do
		local part = Instance.new("Part")
		part.Name = look.name
		part.Shape = look.shape
		part.Size = look.size
		part.Color = look.color
		part.Transparency = look.transparency
		part.Material = look.material
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Parent = folder
		table.insert(parts, part)
	end
	return { parts = parts, shape = shape }
end

-- The character's orbiters in `byCharacter`, rebuilt when the count or look changes.
local function orbitersFor(byCharacter: { [Model]: Orbiters }, character: Model, count: number, look: Look): Orbiters
	local shape = `{count}:{look.size}:{look.color}`
	local orbiters = byCharacter[character]
	if orbiters and orbiters.shape ~= shape then
		destroyOrbiters(orbiters)
		orbiters = nil
	end
	if not orbiters then
		orbiters = createOrbiters(count, look, shape)
		byCharacter[character] = orbiters
	end
	return orbiters :: Orbiters
end

-- Removes orbiters for characters that died, respawned, left, or lost the upgrade.
local function removeUnseen(byCharacter: { [Model]: Orbiters }, seen: { [Model]: boolean })
	for character, orbiters in byCharacter do
		if not seen[character] then
			destroyOrbiters(orbiters)
			byCharacter[character] = nil
		end
	end
end

local function render()
	local currentArena = CurrentArena.get()
	if not currentArena then
		return
	end
	local now = GameClock.read(currentArena)
	table.clear(seenBlades)
	table.clear(seenWards)
	table.clear(moveParts)
	table.clear(moveCFrames)

	for _, player in Players:GetPlayers() do
		-- Only players in this arena (others are in their own matches, or the lobby).
		local character = player.Character
		if not character or player:GetAttribute("ArenaName") ~= currentArena.Name then
			continue
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local root = character:FindFirstChild("HumanoidRootPart")
		if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
			continue
		end
		local build = BuildStats.fromAttributes(player)

		local blade = BuildStats.spinningBlade(build)
		if blade then
			local evolved = BuildStats.isEvolved(build, "SpinningBlade")
			local blades = orbitersFor(bladesByCharacter, character, blade.bladeCount, {
				name = "SpinningBlade",
				size = Vector3.new(blade.width, 0.3, blade.outerRadius - blade.innerRadius),
				color = if evolved then BLADESTORM_COLOR else BLADE_COLOR,
				transparency = if evolved then BLADESTORM_TRANSPARENCY else 0,
				shape = Enum.PartType.Block,
				material = Enum.Material.Neon,
			})
			seenBlades[character] = true

			local center = root.Position + Vector3.new(0, HEIGHT_OFFSET, 0)
			local midRadius = (blade.innerRadius + blade.outerRadius) / 2
			for index, part in blades.parts do
				local angle = BladeOrbit.angle(index, blade.bladeCount, blade.spinSpeed, now)
				local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
				local middle = center + direction * midRadius
				table.insert(moveParts, part)
				table.insert(moveCFrames, CFrame.lookAt(middle, middle + direction))
			end
		end

		local ward = BuildStats.warding(build)
		if ward then
			local diameter = ward.ringRadius * 2
			local wards = orbitersFor(wardsByCharacter, character, ward.count, {
				name = "WardingRing",
				size = Vector3.new(WARD_THICKNESS, diameter, diameter),
				color = WARD_COLOR,
				transparency = WARD_TRANSPARENCY,
				shape = Enum.PartType.Cylinder,
				material = Enum.Material.SmoothPlastic,
			})
			seenWards[character] = true

			local center = root.Position + Vector3.new(0, WARD_HEIGHT_OFFSET, 0)
			for index, part in wards.parts do
				local angle = BladeOrbit.angle(index, ward.count, ward.spinSpeed, now)
				local position = center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * ward.orbitRadius
				table.insert(moveParts, part)
				-- A cylinder's axis is its X size; turn it upright so it lies flat as a disc.
				table.insert(moveCFrames, CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)))
			end
		end
	end

	removeUnseen(bladesByCharacter, seenBlades)
	removeUnseen(wardsByCharacter, seenWards)

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
