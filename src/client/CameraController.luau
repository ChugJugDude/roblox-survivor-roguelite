--!strict
-- A fixed overhead camera that follows the local character. Roblox's movement input is relative
-- to the camera, so with this camera W / thumbstick-up always moves toward the top of the screen.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config.Camera)

local CameraController = {}

function CameraController.start()
	local player = Players.LocalPlayer

	RunService:BindToRenderStep("OverheadCamera", Enum.RenderPriority.Camera.Value + 1, function()
		local camera = workspace.CurrentCamera
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not camera or not root or not root:IsA("BasePart") then
			return
		end

		-- Roblox's camera scripts reset this on respawn, so reapply it.
		if camera.CameraType ~= Enum.CameraType.Scriptable then
			camera.CameraType = Enum.CameraType.Scriptable
		end
		camera.FieldOfView = Config.FIELD_OF_VIEW

		local focus = root.Position
		camera.CFrame = CFrame.lookAt(focus + Config.OFFSET, focus)
	end)
end

return CameraController
