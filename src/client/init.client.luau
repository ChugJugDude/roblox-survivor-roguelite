--!strict
-- Client entry point.

local StarterGui = game:GetService("StarterGui")

local AudioToggles = require(script.UI.AudioToggles)
local BladeRenderer = require(script.BladeRenderer)
local CameraController = require(script.CameraController)
local CurrentArena = require(script.CurrentArena)
local DownedIndicator = require(script.UI.DownedIndicator)
local EffectRenderer = require(script.EffectRenderer)
local EnemyRenderer = require(script.EnemyRenderer)
local GemRenderer = require(script.GemRenderer)
local HealthBars = require(script.UI.HealthBars)
local HitEffects = require(script.HitEffects)
local Hud = require(script.UI.Hud)
local LobbyHud = require(script.UI.LobbyHud)
local LobbyMenus = require(script.UI.LobbyMenus)
local Music = require(script.Music)
local PauseMenu = require(script.UI.PauseMenu)
local PlayerDataClient = require(script.PlayerDataClient)
local PlayerFeedback = require(script.PlayerFeedback)
local PortalPointer = require(script.UI.PortalPointer)
local ProjectileRenderer = require(script.ProjectileRenderer)
local Results = require(script.UI.Results)
local SoundHooks = require(script.SoundHooks)
local SoundPlayer = require(script.SoundPlayer)
local TelegraphRenderer = require(script.TelegraphRenderer)
local UpgradePicker = require(script.UI.UpgradePicker)

-- There are no tools in this game, and the Backpack hotbar claims the 1-9 keys the level-up
-- picker uses.
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
-- Our own health bars (UI/HealthBars) replace Roblox's.
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)

-- First, so it's listening before the server's first WorldReset arrives.
CurrentArena.start()
PlayerDataClient.start()
SoundPlayer.start()

CameraController.start()
EnemyRenderer.start()
GemRenderer.start()
ProjectileRenderer.start()
TelegraphRenderer.start()
EffectRenderer.start()
HitEffects.start()
PlayerFeedback.start()
BladeRenderer.start()
Hud.start()
LobbyHud.start()
LobbyMenus.start()
DownedIndicator.start()
HealthBars.start()
PortalPointer.start()
Results.start()
UpgradePicker.start()
AudioToggles.start()
PauseMenu.start()
Music.start()
-- Last, so it hooks every button the UI made.
SoundHooks.start()
