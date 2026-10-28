--!strict
-- Runs every weapon for every living player in one match, once per frame. Weapons whose effects
-- outlast a cast (Holy Ground's zones) keep per-match state here.

local Players = game:GetService("Players")

local Characters = require(script.Parent.Parent.Characters)
local EnemyService = require(script.Parent.Parent.EnemyService)
local ProjectileService = require(script.Parent.Parent.ProjectileService)
local ChainLightning = require(script.Parent.ChainLightning)
local Fireball = require(script.Parent.Fireball)
local FrostNova = require(script.Parent.FrostNova)
local HolyGround = require(script.Parent.HolyGround)
local SpinningBlade = require(script.Parent.SpinningBlade)
local VolleyArrows = require(script.Parent.VolleyArrows)
local Warding = require(script.Parent.Warding)

export type State = {
	enemies: EnemyService.State,
	projectiles: ProjectileService.State,
	holyGround: HolyGround.State,
}

local started = false

local WeaponService = {}

function WeaponService.new(enemies: EnemyService.State, projectiles: ProjectileService.State): State
	return {
		enemies = enemies,
		projectiles = projectiles,
		holyGround = HolyGround.new(enemies),
	}
end

function WeaponService.step(state: State, now: number, dt: number, targets: { Characters.Target })
	local enemies, projectiles = state.enemies, state.projectiles
	SpinningBlade.step(enemies, now, targets)
	VolleyArrows.step(enemies, projectiles, now, targets)
	Fireball.step(enemies, projectiles, now, targets)
	ChainLightning.step(enemies, now, targets)
	FrostNova.step(enemies, now, targets)
	HolyGround.step(state.holyGround, now, dt, targets)
	Warding.step(enemies, projectiles, now, targets)
end

-- Removes lingering weapon effects (the run ended or restarted).
function WeaponService.clear(state: State)
	HolyGround.clear(state.holyGround)
end

function WeaponService.start()
	assert(not started, "WeaponService.start() was called twice")
	started = true
	Players.PlayerRemoving:Connect(function(player)
		VolleyArrows.forget(player)
		Fireball.forget(player)
		ChainLightning.forget(player)
		FrostNova.forget(player)
		HolyGround.forget(player)
		Warding.forget(player)
	end)
end

return WeaponService
