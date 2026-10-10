--!strict
-- During overtime, points toward the portal when it's off screen. Assumes the fixed overhead
-- camera from CameraController, where world +X is screen right and world +Z is screen down.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Create = require(script.Parent.Create)

local COLOR = Color3.fromRGB(190, 120, 255)
-- Keep the pointer this many pixels inside the screen edge.
local EDGE_MARGIN = 70

local PortalPointer = {}

function PortalPointer.start(arena: Instance)
	local player = Players.LocalPlayer
	local gui = Create("ScreenGui", {
		Name = "PortalPointer",
		ResetOnSpawn = false,
		-- Positions are computed in viewport pixels, so the GUI has to start at the very top too.
		IgnoreGuiInset = true,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local pointer = Create("Frame", {
		Name = "Pointer",
		Size = UDim2.fromOffset(90, 70),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})
	local arrow = Create("TextLabel", {
		Name = "Arrow",
		Size = UDim2.fromOffset(44, 44),
		Position = UDim2.fromScale(0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		TextSize = 40,
		TextColor3 = COLOR,
		TextStrokeTransparency = 0.3,
		Text = ">",
		Parent = pointer,
	})
	Create("TextLabel", {
		Name = "Label",
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.new(0, 0, 1, -20),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextColor3 = COLOR,
		TextStrokeTransparency = 0.3,
		Text = "PORTAL",
		Parent = pointer,
	})

	RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		local portal = arena:FindFirstChild("Portal")
		local pad = portal and portal:FindFirstChild("Pad")
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if
			arena:GetAttribute("Phase") ~= "Overtime"
			or not camera
			or not pad
			or not pad:IsA("BasePart")
			or not root
			or not root:IsA("BasePart")
		then
			pointer.Visible = false
			return
		end

		local viewport = camera.ViewportSize
		local screenPoint, inFront = camera:WorldToViewportPoint(pad.Position)
		local onScreen = inFront
			and screenPoint.X > EDGE_MARGIN
			and screenPoint.X < viewport.X - EDGE_MARGIN
			and screenPoint.Y > EDGE_MARGIN
			and screenPoint.Y < viewport.Y - EDGE_MARGIN
		if onScreen then
			pointer.Visible = false
			return
		end

		local dx = pad.Position.X - root.Position.X
		local dz = pad.Position.Z - root.Position.Z
		local length = math.sqrt(dx * dx + dz * dz)
		if length < 1e-3 then
			pointer.Visible = false
			return
		end
		local radius = math.min(viewport.X, viewport.Y) / 2 - EDGE_MARGIN
		pointer.Position =
			UDim2.fromOffset(viewport.X / 2 + dx / length * radius, viewport.Y / 2 + dz / length * radius)
		arrow.Rotation = math.deg(math.atan2(dz, dx))
		pointer.Visible = true
	end)
end

return PortalPointer
