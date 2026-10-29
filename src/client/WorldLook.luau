--!strict
-- Applies the current world's lighting (Config.Worlds `lighting`) while the player is in its arena,
-- and puts the lobby's back when they return. Worlds without lighting keep the lobby's.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local CurrentArena = require(script.Parent.CurrentArena)
local Worlds = require(ReplicatedStorage.Shared.Config.Worlds)

local FADE_TIME = 0.8

local started = false

local WorldLook = {}

function WorldLook.start()
	assert(not started, "WorldLook.start() was called twice")
	started = true

	-- The lobby's look, as the place has it.
	local lobby: Worlds.Lighting = {
		ambient = Lighting.Ambient,
		outdoorAmbient = Lighting.OutdoorAmbient,
		tint = Color3.new(1, 1, 1),
		brightness = Lighting.Brightness,
	}
	local tint = Instance.new("ColorCorrectionEffect")
	tint.Name = "WorldTint"
	tint.Parent = Lighting

	local function apply(look: Worlds.Lighting)
		local info = TweenInfo.new(FADE_TIME)
		TweenService:Create(Lighting, info, {
			Ambient = look.ambient,
			OutdoorAmbient = look.outdoorAmbient,
			Brightness = look.brightness,
		}):Play()
		TweenService:Create(tint, info, { TintColor = look.tint }):Play()
	end

	local shownWorld: string? = nil
	RunService.Heartbeat:Connect(function()
		local arena = CurrentArena.get()
		local worldId = if arena then arena:GetAttribute("World") :: string? else nil
		if worldId == shownWorld then
			return
		end
		shownWorld = worldId
		local world = if worldId then Worlds.get(worldId) else nil
		apply(if world and world.lighting then world.lighting else lobby)
	end)
end

return WorldLook
