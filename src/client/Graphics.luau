--!strict
-- The graphics quality: "High" (every effect) or "Low" (fewer particles, damage numbers, and lights,
-- for phones). Low by default on touch-only devices; players can switch in the settings panel.
-- Renderers read Graphics.profile() when they draw, so a switch applies right away (pooled pieces
-- pick it up the next time they're used).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config.Effects)

export type Quality = "High" | "Low"

local quality: Quality = if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	then "Low"
	else "High"
local listeners: { (Quality) -> () } = {}

local Graphics = {}

function Graphics.quality(): Quality
	return quality
end

-- The effect caps and switches for the current quality (Config.Effects.HIGH / LOW).
function Graphics.profile(): Config.Profile
	return if quality == "Low" then Config.LOW else Config.HIGH
end

function Graphics.setQuality(newQuality: Quality)
	if newQuality == quality then
		return
	end
	quality = newQuality
	for _, listener in listeners do
		listener(quality)
	end
end

function Graphics.onChanged(listener: (Quality) -> ())
	table.insert(listeners, listener)
end

return Graphics
