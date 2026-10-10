--!strict
-- Runs every weapon for every living player, once per frame.

local Players = game:GetService("Players")

local Characters = require(script.Parent.Parent.Characters)
local Fireball = require(script.Parent.Fireball)
local SpinningBlade = require(script.Parent.SpinningBlade)
local VolleyArrows = require(script.Parent.VolleyArrows)

local started = false

local WeaponService = {}

function WeaponService.step(now: number, targets: { Characters.Target })
	SpinningBlade.step(now, targets)
	VolleyArrows.step(now, targets)
	Fireball.step(now, targets)
end

function WeaponService.start()
	assert(not started, "WeaponService.start() was called twice")
	started = true
	Players.PlayerRemoving:Connect(function(player)
		VolleyArrows.forget(player)
		Fireball.forget(player)
	end)
end

return WeaponService
