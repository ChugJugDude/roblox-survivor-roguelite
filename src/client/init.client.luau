--!strict
-- Client entry point.

local StarterGui = game:GetService("StarterGui")

local BladeRenderer = require(script.BladeRenderer)
local CameraController = require(script.CameraController)
local CurrentArena = require(script.CurrentArena)
local DownedIndicator = require(script.UI.DownedIndicator)
local EnemyRenderer = require(script.EnemyRenderer)
local GemRenderer = require(script.GemRenderer)
local Hud = require(script.UI.Hud)
local LobbyHud = require(script.UI.LobbyHud)
local LobbyMenus = require(script.UI.LobbyMenus)
local PlayerDataClient = require(script.PlayerDataClient)
local PortalPointer = require(script.UI.PortalPointer)
local ProjectileRenderer = require(script.ProjectileRenderer)
local Results = require(script.UI.Results)
local TelegraphRenderer = require(script.TelegraphRenderer)
local UpgradePicker = require(script.UI.UpgradePicker)

-- There are no tools in this game, and the Backpack hotbar claims the 1-9 keys the level-up
-- picker uses.
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)

-- First, so it's listening before the server's first WorldReset arrives.
CurrentArena.start()
PlayerDataClient.start()

CameraController.start()
EnemyRenderer.start()
GemRenderer.start()
ProjectileRenderer.start()
TelegraphRenderer.start()
BladeRenderer.start()
Hud.start()
LobbyHud.start()
LobbyMenus.start()
DownedIndicator.start()
PortalPointer.start()
Results.start()
UpgradePicker.start()
