--!strict
-- Draws Spinning Blades around every living character that has them, sized from each player's build
-- (read from their W_ / P_ attributes). Angles come from the shared server clock
-- (shared/BladeOrbit), so the blades line up with where the server checks for hits.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BladeOrbit = require(ReplicatedStorage.Shared.BladeOrbit)
local GameClock = require(ReplicatedStorage.Shared.GameClock)
local BuildStats = require(ReplicatedStorage.Shared.BuildStats)

-- How far below the character's root part the blades spin (roughly waist height).
local HEIGHT_OFFSET = -1
local BLADE_COLOR = Color3.fromRGB(225, 235, 255)
local BLADESTORM_COLOR = Color3.fromRGB(255, 210, 70)
-- Bladestorm covers a lot of screen, so it's see-through enough for enemy shots under it to show.
local BLADESTORM_TRANSPARENCY = 0.35

type Blades = {
	parts: { BasePart },
	shape: string, -- count and size the parts were built for
}

local bladesByCharacter: { [Model]: Blades } = {}
local folder: Folder? = nil
local arena: Instance? = nil
local started = false

-- Reused every frame.
local seen: { [Model]: boolean } = {}
local moveParts: { BasePart } = {}
local moveCFrames: { CFrame } = {}

local BladeRenderer = {}

local function destroyBlades(blades: Blades)
	for _, part in blades.parts do
		part:Destroy()
	end
end

local function createBlades(count: number, size: Vector3, color: Color3, shape: string): Blades
	local parts = {}
	for _ = 1, count do
		local part = Instance.new("Part")
		part.Name = "SpinningBlade"
		part.Size = size
		part.Color = color
		part.Transparency = if color == BLADESTORM_COLOR then BLADESTORM_TRANSPARENCY else 0
		part.Material = Enum.Material.Neon
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

local function render()
	local currentArena = arena
	if not currentArena then
		return
	end
	local now = GameClock.read(currentArena)
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
		local build = BuildStats.fromAttributes(player)
		local stats = BuildStats.spinningBlade(build)
		if not stats then
			continue
		end

		-- Rebuild the parts when an upgrade changes the blade count, size, or color.
		local size = Vector3.new(stats.width, 0.3, stats.outerRadius - stats.innerRadius)
		local color = if BuildStats.isEvolved(build, "SpinningBlade") then BLADESTORM_COLOR else BLADE_COLOR
		local shape = `{stats.bladeCount}:{size}:{color}`
		local blades = bladesByCharacter[character]
		if blades and blades.shape ~= shape then
			destroyBlades(blades)
			blades = nil
		end
		if not blades then
			blades = createBlades(stats.bladeCount, size, color, shape)
			bladesByCharacter[character] = blades
		end
		seen[character] = true

		local center = root.Position + Vector3.new(0, HEIGHT_OFFSET, 0)
		local midRadius = (stats.innerRadius + stats.outerRadius) / 2
		for index, part in (blades :: Blades).parts do
			local angle = BladeOrbit.angle(index, stats.bladeCount, stats.spinSpeed, now)
			local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
			local middle = center + direction * midRadius
			table.insert(moveParts, part)
			table.insert(moveCFrames, CFrame.lookAt(middle, middle + direction))
		end
	end

	-- Remove blades for characters that died, respawned, left, or lost the weapon.
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

function BladeRenderer.start(newArena: Instance)
	assert(not started, "BladeRenderer.start() was called twice")
	started = true
	arena = newArena

	local newFolder = Instance.new("Folder")
	newFolder.Name = "BladeVisuals"
	newFolder.Parent = workspace
	folder = newFolder

	RunService.RenderStepped:Connect(render)
end

return BladeRenderer
