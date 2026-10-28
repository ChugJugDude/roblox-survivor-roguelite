--!strict
-- A fixed overhead camera that follows the local character. Roblox's movement input is relative
-- to the camera, so with this camera W / thumbstick-up always moves toward the top of the screen.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config.Camera)

local random = Random.new()
-- A shake's strength (studs) and when it ends; it fades out over its duration.
local shakeIntensity = 0
local shakeDuration = 0
local shakeEndsAt = 0

local CameraController = {}

-- Jolts the camera by up to `intensity` studs, fading out over `duration` seconds. A weaker shake
-- doesn't cut a stronger one short.
function CameraController.shake(intensity: number, duration: number)
	local now = os.clock()
	local remaining = if now < shakeEndsAt then shakeIntensity * (shakeEndsAt - now) / shakeDuration else 0
	if intensity >= remaining then
		shakeIntensity, shakeDuration, shakeEndsAt = intensity, duration, now + duration
	end
end

function CameraController.start()
	local player = Players.LocalPlayer

	RunService:BindToRenderStep("OverheadCamera", Enum.RenderPriority.Camera.Value + 1, function()
		local camera = workspace.CurrentCamera
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		-- While dead, hold the last view instead of following the falling body.
		if not camera or not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
			return
		end

		-- Roblox's camera scripts reset this on respawn, so reapply it.
		if camera.CameraType ~= Enum.CameraType.Scriptable then
			camera.CameraType = Enum.CameraType.Scriptable
		end
		camera.FieldOfView = Config.FIELD_OF_VIEW

		local focus = root.Position
		local now = os.clock()
		if now < shakeEndsAt then
			local strength = shakeIntensity * (shakeEndsAt - now) / shakeDuration
			focus += Vector3.new(random:NextNumber(-1, 1), 0, random:NextNumber(-1, 1)) * strength
		end
		camera.CFrame = CFrame.lookAt(focus + Config.OFFSET, focus)
	end)
end

return CameraController
