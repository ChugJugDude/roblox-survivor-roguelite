--!strict
-- Draws boss attack warnings (EntityNet.TelegraphInfo): a red lane on the ground that fills in over
-- the wind-up, so players see where a charge will go and get out of the way.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local CurrentArena = require(script.Parent.CurrentArena)
local ArenaConfig = require(ReplicatedStorage.Shared.Config.Arena)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

-- Solid (not neon) red: neon at this transparency blends toward orange over the green floor.
local LANE_COLOR = Color3.fromRGB(235, 25, 35)
local START_TRANSPARENCY = 0.7
local END_TRANSPARENCY = 0.3

local lanes: { [BasePart]: boolean } = {}
local started = false

local TelegraphRenderer = {}

local function draw(info: any)
	if
		typeof(info) ~= "table"
		or typeof(info.x) ~= "number"
		or typeof(info.z) ~= "number"
		or typeof(info.dirX) ~= "number"
		or typeof(info.dirZ) ~= "number"
		or typeof(info.length) ~= "number"
		or typeof(info.width) ~= "number"
		or typeof(info.duration) ~= "number"
	then
		return
	end
	local start = Vector3.new(info.x, ArenaConfig.ORIGIN.Y + 0.15, info.z)
	local direction = Vector3.new(info.dirX, 0, info.dirZ)
	local center = start + direction * (info.length / 2)
	local lane = Instance.new("Part")
	lane.Name = "Telegraph"
	lane.Anchored = true
	lane.CanCollide = false
	lane.CanQuery = false
	lane.CanTouch = false
	lane.CastShadow = false
	lane.Material = Enum.Material.SmoothPlastic
	lane.Color = LANE_COLOR
	lane.Transparency = START_TRANSPARENCY
	lane.Size = Vector3.new(info.width, 0.2, info.length)
	lane.CFrame = CFrame.lookAt(center, center + direction)
	lane.Parent = workspace
	lanes[lane] = true

	TweenService:Create(lane, TweenInfo.new(info.duration, Enum.EasingStyle.Linear), {
		Transparency = END_TRANSPARENCY,
	}):Play()
	-- Linger through the dash itself, then go.
	task.delay(info.duration + 0.6, function()
		lanes[lane] = nil
		lane:Destroy()
	end)
end

function TelegraphRenderer.start()
	assert(not started, "TelegraphRenderer.start() was called twice")
	started = true
	Remotes.EnemyTelegraph.OnClientEvent:Connect(function(list: any)
		if typeof(list) ~= "table" then
			return
		end
		for _, info in list do
			draw(info)
		end
	end)
	CurrentArena.onReset(function()
		for lane in lanes do
			lane:Destroy()
		end
		table.clear(lanes)
	end)
end

return TelegraphRenderer
