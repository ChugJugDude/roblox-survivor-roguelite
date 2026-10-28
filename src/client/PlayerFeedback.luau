--!strict
-- Feedback on the players themselves: a red screen-edge flash and a camera shake when the local
-- player is hurt, a ring and sparkles around every player when the party levels up, and a bigger
-- gold burst plus a screen flash when the local player evolves a weapon. Tuning in Config.Effects.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local CameraController = require(script.Parent.CameraController)
local CurrentArena = require(script.Parent.CurrentArena)
local Create = require(script.Parent.UI.Create)
local ArenaConfig = require(ReplicatedStorage.Shared.Config.Arena)
local Config = require(ReplicatedStorage.Shared.Config.Effects)
local UpgradesConfig = require(ReplicatedStorage.Shared.Config.Upgrades)

local HURT_COLOR = Color3.fromRGB(200, 20, 30)
local HURT_EDGE = 0.18 -- fraction of the screen each red edge covers
local HURT_MIN = 0.3 -- even a scratch shows this much of the flash
local LEVEL_COLOR = Color3.fromRGB(90, 180, 255)
local EVOLVE_COLOR = Color3.fromRGB(255, 210, 70)
local SPARKLE_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"

local anchor: Part = nil :: any
local sparkles: ParticleEmitter = nil :: any
local started = false

local PlayerFeedback = {}

-- A flat ring of light racing out across the floor from `position`.
local function ring(position: Vector3, radius: number, color: Color3)
	local disc = Instance.new("Part")
	disc.Name = "Ring"
	disc.Shape = Enum.PartType.Cylinder
	disc.Size = Vector3.new(0.2, 1, 1)
	-- A cylinder's axis is its X size; turn it upright so it lies flat.
	disc.CFrame = CFrame.new(position.X, ArenaConfig.ORIGIN.Y + 0.3, position.Z) * CFrame.Angles(0, 0, math.rad(90))
	disc.Color = color
	disc.Material = Enum.Material.Neon
	disc.Transparency = 0.3
	disc.Anchored = true
	disc.CanCollide = false
	disc.CanQuery = false
	disc.CanTouch = false
	disc.CastShadow = false
	disc.Parent = anchor.Parent
	local tween = TweenService:Create(disc, TweenInfo.new(Config.RING_TIME, Enum.EasingStyle.Quad), {
		Size = Vector3.new(0.2, radius * 2, radius * 2),
		Transparency = 1,
	})
	tween.Completed:Once(function()
		disc:Destroy()
	end)
	tween:Play()
end

local function burst(position: Vector3, color: Color3, count: number)
	sparkles.Color = ColorSequence.new(color)
	local attachment = sparkles.Parent :: Attachment
	attachment.WorldPosition = position
	sparkles:Emit(count)
end

-- The ground position of each player in the current arena.
local function playersInArena(arena: Instance): { Vector3 }
	local positions = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") and player:GetAttribute("ArenaName") == arena.Name then
			table.insert(positions, root.Position)
		end
	end
	return positions
end

-- The four red screen edges, each fading from solid at the screen edge to clear toward the middle.
-- Faded by their own BackgroundTransparency (a CanvasGroup's GroupTransparency didn't hide them).
local function buildHurtFlash(): { Frame }
	local gui = Create("ScreenGui", {
		Name = "HurtFlash",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 1,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
	local frames: { Frame } = {}
	local edges = {
		{ size = UDim2.fromScale(HURT_EDGE, 1), position = UDim2.fromScale(0, 0), rotation = 0 },
		{ size = UDim2.fromScale(HURT_EDGE, 1), position = UDim2.fromScale(1 - HURT_EDGE, 0), rotation = 180 },
		{ size = UDim2.fromScale(1, HURT_EDGE), position = UDim2.fromScale(0, 0), rotation = 90 },
		{ size = UDim2.fromScale(1, HURT_EDGE), position = UDim2.fromScale(0, 1 - HURT_EDGE), rotation = 270 },
	}
	for _, edge in edges do
		local frame = Create("Frame", {
			Size = edge.size,
			Position = edge.position,
			BackgroundColor3 = HURT_COLOR,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Parent = gui,
		})
		table.insert(frames, frame)
		Create("UIGradient", {
			Rotation = edge.rotation,
			Transparency = NumberSequence.new(0, 1),
			Parent = frame,
		})
	end
	return frames
end

local function buildScreenFlash(): Frame
	local gui = Create("ScreenGui", {
		Name = "EvolveFlash",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 1,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
	return Create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(255, 245, 210),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = gui,
	})
end

local function hookHurt(hurtFlash: { Frame })
	local player = Players.LocalPlayer
	local function onCharacter(character: Model)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if not humanoid or not humanoid:IsA("Humanoid") then
			return
		end
		local last = humanoid.Health
		humanoid.HealthChanged:Connect(function(health)
			local lost = last - health
			last = health
			if lost <= 0 or not CurrentArena.get() or humanoid.MaxHealth <= 0 then
				return
			end
			local strength = math.clamp(lost / humanoid.MaxHealth / Config.HURT_FULL_FRACTION, HURT_MIN, 1)
			for _, frame in hurtFlash do
				frame.BackgroundTransparency = 1 - strength
				TweenService:Create(frame, TweenInfo.new(Config.HURT_FLASH_TIME), { BackgroundTransparency = 1 }):Play()
			end
			CameraController.shake(Config.HURT_SHAKE * strength, Config.HURT_SHAKE_TIME)
		end)
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
end

local function hookLevelUps()
	local arena: Instance? = nil
	local level: any = nil
	RunService.Heartbeat:Connect(function()
		local current = CurrentArena.get()
		local newLevel = current and current:GetAttribute("PartyLevel")
		if current == arena and current and typeof(newLevel) == "number" and typeof(level) == "number" then
			if newLevel > level then
				for _, position in playersInArena(current) do
					ring(position, Config.LEVEL_RING_RADIUS, LEVEL_COLOR)
					burst(position, LEVEL_COLOR, 24)
				end
			end
		end
		arena, level = current, newLevel
	end)
end

local function hookEvolutions(screenFlash: Frame)
	local player = Players.LocalPlayer
	player.AttributeChanged:Connect(function(attribute)
		local value = player:GetAttribute(attribute)
		if string.sub(attribute, 1, 2) ~= "W_" or typeof(value) ~= "number" or value <= UpgradesConfig.MAX_LEVEL then
			return
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not CurrentArena.get() or not root or not root:IsA("BasePart") then
			return
		end
		ring(root.Position, Config.EVOLVE_RING_RADIUS, EVOLVE_COLOR)
		burst(root.Position, EVOLVE_COLOR, 60)
		screenFlash.BackgroundTransparency = 0.5
		TweenService:Create(screenFlash, TweenInfo.new(Config.EVOLVE_FLASH_TIME), { BackgroundTransparency = 1 }):Play()
	end)
end

function PlayerFeedback.start()
	assert(not started, "PlayerFeedback.start() was called twice")
	started = true

	local folder = Instance.new("Folder")
	folder.Name = "PlayerFeedback"
	folder.Parent = workspace
	anchor = Instance.new("Part")
	anchor.Name = "EffectAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.Parent = folder
	local attachment = Instance.new("Attachment")
	attachment.Parent = anchor
	sparkles = Instance.new("ParticleEmitter")
	sparkles.Texture = SPARKLE_TEXTURE
	sparkles.Enabled = false
	sparkles.LightEmission = 1
	sparkles.Lifetime = NumberRange.new(0.5, 0.9)
	sparkles.Speed = NumberRange.new(8, 16)
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.Size = NumberSequence.new(1, 0)
	sparkles.Drag = 3
	sparkles.Acceleration = Vector3.new(0, 6, 0)
	sparkles.Parent = attachment

	hookHurt(buildHurtFlash())
	hookLevelUps()
	hookEvolutions(buildScreenFlash())
end

return PlayerFeedback
