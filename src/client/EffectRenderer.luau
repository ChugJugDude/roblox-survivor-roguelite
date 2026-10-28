--!strict
-- Draws visual-only weapon effects sent through Remotes.WeaponEffects: Chain Lightning bolts for now.
-- Damage is already dealt on the server by the time these arrive.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local CurrentArena = require(script.Parent.CurrentArena)
local ArenaConfig = require(ReplicatedStorage.Shared.Config.Arena)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local LIGHTNING_COLOR = Color3.fromRGB(200, 230, 255)
local THUNDERSTORM_COLOR = Color3.fromRGB(205, 160, 255)
local LIGHTNING_WIDTH = 0.35
local THUNDERSTORM_WIDTH = 0.6
local LIGHTNING_HEIGHT = 3 -- above the floor
-- Each hop bends once, sideways by up to this fraction of its length, so it reads as lightning.
local JAG = 0.25
local LIGHTNING_TIME = 0.2 -- seconds to fade out

local random = Random.new()
local folder: Folder? = nil
local started = false

local EffectRenderer = {}

local function segment(from: Vector3, to: Vector3, color: Color3, width: number)
	local length = (to - from).Magnitude
	if length < 1e-3 then
		return
	end
	local part = Instance.new("Part")
	part.Name = "Lightning"
	part.Size = Vector3.new(width, width, length)
	part.CFrame = CFrame.lookAt((from + to) / 2, to)
	part.Color = color
	part.Material = Enum.Material.Neon
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = folder
	local tween = TweenService:Create(part, TweenInfo.new(LIGHTNING_TIME), { Transparency = 1 })
	tween.Completed:Once(function()
		part:Destroy()
	end)
	tween:Play()
end

local function drawLightning(points: { any }, evolved: boolean)
	local color = if evolved then THUNDERSTORM_COLOR else LIGHTNING_COLOR
	local width = if evolved then THUNDERSTORM_WIDTH else LIGHTNING_WIDTH
	local height = ArenaConfig.ORIGIN.Y + LIGHTNING_HEIGHT
	local previous: Vector3? = nil
	for index = 1, #points - 1, 2 do
		local x, z = points[index], points[index + 1]
		if typeof(x) ~= "number" or typeof(z) ~= "number" then
			return
		end
		local point = Vector3.new(x, height, z)
		if previous then
			-- Kink the hop at its middle, sideways on the ground plane.
			local hop = point - previous
			local side = Vector3.new(-hop.Z, 0, hop.X) * random:NextNumber(-JAG, JAG)
			local middle = (previous + point) / 2 + side
			segment(previous, middle, color, width)
			segment(middle, point, color, width)
		end
		previous = point
	end
end

local function onEffects(list: any)
	if typeof(list) ~= "table" then
		return
	end
	for _, info in list do
		if typeof(info) ~= "table" then
			continue
		end
		if info.kind == "Lightning" and typeof(info.points) == "table" then
			drawLightning(info.points, info.evolved == true)
		end
	end
end

function EffectRenderer.start()
	assert(not started, "EffectRenderer.start() was called twice")
	started = true

	local newFolder = Instance.new("Folder")
	newFolder.Name = "EffectVisuals"
	newFolder.Parent = workspace
	folder = newFolder

	-- The player moved to another world: drop every effect.
	CurrentArena.onReset(function()
		newFolder:ClearAllChildren()
	end)

	Remotes.WeaponEffects.OnClientEvent:Connect(onEffects)
end

return EffectRenderer
