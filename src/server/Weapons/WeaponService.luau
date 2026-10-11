--!strict
-- Runs every weapon for every living player in one match, once per frame.

local Players = game:GetService("Players")

local Characters = require(script.Parent.Parent.Characters)
local EnemyService = require(script.Parent.Parent.EnemyService)
local ProjectileService = require(script.Parent.Parent.ProjectileService)
local Fireball = require(script.Parent.Fireball)
local SpinningBlade = require(script.Parent.SpinningBlade)
local VolleyArrows = require(script.Parent.VolleyArrows)

local started = false

local WeaponService = {}

function WeaponService.step(
	enemies: EnemyService.State,
	projectiles: ProjectileService.State,
	now: number,
	targets: { Characters.Target }
)
	SpinningBlade.step(enemies, now, targets)
	VolleyArrows.step(enemies, projectiles, now, targets)
	Fireball.step(enemies, projectiles, now, targets)
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
