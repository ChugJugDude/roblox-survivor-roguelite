--!strict
-- Draws what orbits each living character: Spinning Blades (as swords) and Warding rings, sized from
-- each player's build (read from their W_ / P_ attributes). Angles come from the shared server
-- clock (shared/BladeOrbit), so they line up with where the server checks for hits. Each orbiter is
-- a few parts (pieces) placed at offsets from one moving CFrame.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CurrentArena = require(script.Parent.CurrentArena)
local Graphics = require(script.Parent.Graphics)
local Particles = require(script.Parent.Particles)
local ProjectileRenderer = require(script.Parent.ProjectileRenderer)
local BladeOrbit = require(ReplicatedStorage.Shared.BladeOrbit)
local BuildStats = require(ReplicatedStorage.Shared.BuildStats)
local GameClock = require(ReplicatedStorage.Shared.GameClock)

-- How far below the character's root part the blades spin (roughly waist height).
local HEIGHT_OFFSET = -1
local STEEL_COLOR = Color3.fromRGB(215, 225, 240)
local GRIP_COLOR = Color3.fromRGB(110, 70, 40)
local BLADESTORM_COLOR = Color3.fromRGB(255, 210, 70)
local BLADESTORM_GUARD_COLOR = Color3.fromRGB(150, 100, 30)
-- Bladestorm covers a lot of screen, so it's see-through enough for enemy shots under it to show.
local BLADESTORM_TRANSPARENCY = 0.35
-- Warding rings: pale-blue discs with a glowing rim. Not cyan (XP gems) and never red (enemy shots).
local WARD_COLOR = Color3.fromRGB(170, 215, 255)
local WARD_RIM_COLOR = Color3.fromRGB(225, 240, 255)
local WARD_THICKNESS = 0.3
local WARD_POP_REACH = 1.5 -- a removed enemy shot this close to a ring's edge was destroyed by it

type Piece = {
	name: string,
	size: Vector3,
	offset: CFrame, -- from the orbiter's CFrame (which faces outward along -Z)
	color: Color3,
	transparency: number,
	shape: Enum.PartType,
	material: Enum.Material,
}

type TrailLook = {
	piece: number, -- which piece carries it
	from: Vector3, -- the two attachment points, in that piece's space
	to: Vector3,
	color: Color3,
	lifetime: number,
	transparency: number, -- where the ribbon starts; it fades to clear
}

type Look = {
	pieces: { Piece },
	trail: TrailLook?,
}

-- One set of orbiters around a character: parts[orbiter][piece].
type Orbiters = {
	parts: { { BasePart } },
	shape: string, -- what the parts were built for
}

local bladesByCharacter: { [Model]: Orbiters } = {}
local wardsByCharacter: { [Model]: Orbiters } = {}
local wardRadius: { [Model]: number } = {} -- each character's ring radius, for the pop check
local folder: Folder? = nil
local started = false

-- Reused every frame.
local seenBlades: { [Model]: boolean } = {}
local seenWards: { [Model]: boolean } = {}
local moveParts: { BasePart } = {}
local moveCFrames: { CFrame } = {}

local BladeRenderer = {}

local function piece(
	name: string,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	transparency: number?,
	material: Enum.Material?,
	shape: Enum.PartType?
): Piece
	return {
		name = name,
		size = size,
		offset = offset,
		color = color,
		transparency = transparency or 0,
		shape = shape or Enum.PartType.Block,
		material = material or Enum.Material.SmoothPlastic,
	}
end

-- A sword from `length` studs of blade band: the grip at the inner end (near the player), then the
-- guard, the blade, and a narrower tip at the outer end.
-- Smooth, not Metal: metal reflects the sky and turns the steel blue and the gold brown.
local FULLER_COLOR = Color3.fromRGB(150, 158, 170)
local GREATSWORD_GOLD = Color3.fromRGB(235, 185, 70)

-- Spinning Blade's greatsword over `length` studs of blade band (the orbiter's CFrame faces outward
-- along -Z): the pommel and grip at the inner end, a wide crossguard, then a long broad blade with
-- a fuller down its middle and a pointed tip at the outer end. Bladestorm is the same greatsword in
-- glowing, see-through gold, so the evolution reads as an upgrade of the same weapon.
local function swordLook(length: number, width: number, evolved: boolean): Look
	local steel = if evolved then BLADESTORM_COLOR else STEEL_COLOR
	local fuller = if evolved then BLADESTORM_GUARD_COLOR else FULLER_COLOR
	local gold = if evolved then BLADESTORM_GUARD_COLOR else GREATSWORD_GOLD
	local bladeMaterial = if evolved then Enum.Material.Neon else Enum.Material.SmoothPlastic
	local bladeTransparency = if evolved then BLADESTORM_TRANSPARENCY else 0
	local inner = length / 2 -- the inner end, toward the player
	local guardZ = inner - 0.19 * length
	local bladeStart = inner - 0.2 * length
	local bladeLength = 0.7 * length
	local bladeZ = bladeStart - bladeLength / 2
	local tipSize = width * 0.72
	-- A diamond whose outer point lands on the outer end.
	local tipZ = -inner + tipSize * 0.707
	return {
		pieces = {
			piece(
				"Blade",
				Vector3.new(width, 0.22, bladeLength),
				CFrame.new(0, 0, bladeZ),
				steel,
				bladeTransparency,
				bladeMaterial
			),
			piece(
				"Tip",
				Vector3.new(tipSize, 0.22, tipSize),
				CFrame.new(0, 0, tipZ) * CFrame.Angles(0, math.rad(45), 0),
				steel,
				bladeTransparency,
				bladeMaterial
			),
			piece(
				"Fuller",
				Vector3.new(width * 0.22, 0.26, bladeLength * 0.8),
				CFrame.new(0, 0, bladeZ + bladeLength * 0.05),
				fuller,
				bladeTransparency
			),
			piece("Guard", Vector3.new(width * 2.6, 0.32, 0.36), CFrame.new(0, 0, guardZ), gold),
			piece("Grip", Vector3.new(0.34, 0.34, 0.15 * length), CFrame.new(0, 0, inner - 0.11 * length), GRIP_COLOR),
			piece(
				"Pommel",
				Vector3.new(0.55, 0.55, 0.55),
				CFrame.new(0, 0, inner - 0.02 * length),
				gold,
				0,
				nil,
				Enum.PartType.Ball
			),
		},
		-- The Low graphics quality skips swing trails.
		trail = if not Graphics.profile().swordTrails
			then nil
			else {
				piece = 1,
				from = Vector3.new(0, 0, -bladeLength / 2),
				to = Vector3.zero,
				color = steel,
				lifetime = if evolved then 0.18 else 0.12,
				-- Eight overlapping Bladestorm ribbons make a solid ring, so each is fainter.
				transparency = if evolved then 0.7 else 0.45,
			},
	}
end

local function wardLook(radius: number): Look
	local diameter = radius * 2
	-- A cylinder's axis is its X size; turn it upright so it lies flat as a disc.
	local flat = CFrame.Angles(0, 0, math.rad(90))
	return {
		pieces = {
			piece(
				"Ward",
				Vector3.new(WARD_THICKNESS, diameter, diameter),
				flat,
				WARD_COLOR,
				0.15,
				nil,
				Enum.PartType.Cylinder
			),
			-- A bigger glowing disc just underneath, which shows as a bright rim around the edge.
			piece(
				"WardRim",
				Vector3.new(WARD_THICKNESS * 0.5, diameter * 1.25, diameter * 1.25),
				CFrame.new(0, -0.15, 0) * flat,
				WARD_RIM_COLOR,
				0.2,
				Enum.Material.Neon,
				Enum.PartType.Cylinder
			),
		},
	}
end

local function shapeKey(count: number, look: Look): string
	local first = look.pieces[1]
	return `{count}:{first.size}:{first.color}:{#look.pieces}:{if look.trail then look.trail.transparency else 0}`
end

local function destroyOrbiters(orbiters: Orbiters)
	for _, parts in orbiters.parts do
		for _, part in parts do
			part:Destroy()
		end
	end
end

local function createOrbiters(count: number, look: Look, shape: string): Orbiters
	local all = {}
	for _ = 1, count do
		local parts = {}
		for _, spec in look.pieces do
			local part = Instance.new("Part")
			part.Shape = spec.shape
			part.Name = spec.name
			part.Size = spec.size
			part.Color = spec.color
			part.Transparency = spec.transparency
			part.Material = spec.material
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = false
			part.Parent = folder
			table.insert(parts, part)
		end
		local trail = look.trail
		if trail then
			local carrier = parts[trail.piece]
			local from = Instance.new("Attachment")
			from.Position = trail.from
			from.Parent = carrier
			local to = Instance.new("Attachment")
			to.Position = trail.to
			to.Parent = carrier
			local ribbon = Instance.new("Trail")
			ribbon.Attachment0 = from
			ribbon.Attachment1 = to
			ribbon.Color = ColorSequence.new(trail.color)
			ribbon.Transparency = NumberSequence.new(trail.transparency, 1)
			ribbon.Lifetime = trail.lifetime
			ribbon.LightEmission = 0.6
			ribbon.MinLength = 0
			ribbon.Parent = carrier
		end
		table.insert(all, parts)
	end
	return { parts = all, shape = shape }
end

-- The character's orbiters in `byCharacter`, rebuilt when the count or look changes.
local function orbitersFor(byCharacter: { [Model]: Orbiters }, character: Model, count: number, look: Look): Orbiters
	local shape = shapeKey(count, look)
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

-- Queues every piece of orbiter `index` to move to `base`.
local function place(orbiters: Orbiters, index: number, look: Look, base: CFrame)
	for pieceIndex, part in orbiters.parts[index] do
		table.insert(moveParts, part)
		table.insert(moveCFrames, base * look.pieces[pieceIndex].offset)
	end
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

-- An enemy shot stopped at `position`: if it was at a Warding ring, it was destroyed there.
local function onEnemyShotStopped(position: Vector3)
	for character, orbiters in wardsByCharacter do
		local reach = (wardRadius[character] or 0) + WARD_POP_REACH
		for _, parts in orbiters.parts do
			local ring = parts[1].Position
			local dx, dz = position.X - ring.X, position.Z - ring.Z
			if dx * dx + dz * dz <= reach * reach then
				Particles.emit("WardPop", position, 10)
				return
			end
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
			local look = swordLook(
				blade.outerRadius - blade.innerRadius,
				blade.width,
				BuildStats.isEvolved(build, "SpinningBlade")
			)
			local blades = orbitersFor(bladesByCharacter, character, blade.bladeCount, look)
			seenBlades[character] = true

			local center = root.Position + Vector3.new(0, HEIGHT_OFFSET, 0)
			local midRadius = (blade.innerRadius + blade.outerRadius) / 2
			for index = 1, blade.bladeCount do
				local angle = BladeOrbit.angle(index, blade.bladeCount, blade.spinSpeed, now)
				local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
				local middle = center + direction * midRadius
				place(blades, index, look, CFrame.lookAt(middle, middle + direction))
			end
		end

		local ward = BuildStats.warding(build)
		if ward then
			local look = wardLook(ward.ringRadius)
			local wards = orbitersFor(wardsByCharacter, character, ward.count, look)
			seenWards[character] = true
			wardRadius[character] = ward.ringRadius

			local center = root.Position
			for index = 1, ward.count do
				local angle = BladeOrbit.angle(index, ward.count, ward.spinSpeed, now)
				local position = center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * ward.orbitRadius
				place(wards, index, look, CFrame.new(position))
			end
		end
	end

	removeUnseen(bladesByCharacter, seenBlades)
	removeUnseen(wardsByCharacter, seenWards)
	for character in wardRadius do
		if not wardsByCharacter[character] then
			wardRadius[character] = nil
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

	ProjectileRenderer.onEnemyShotStopped(onEnemyShotStopped)
	RunService.RenderStepped:Connect(render)
end

return BladeRenderer
