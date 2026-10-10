--!strict
-- Client entry point.

local StarterGui = game:GetService("StarterGui")

local BladeRenderer = require(script.BladeRenderer)
local CameraController = require(script.CameraController)
local EnemyRenderer = require(script.EnemyRenderer)
local GemRenderer = require(script.GemRenderer)
local Hud = require(script.UI.Hud)
local PortalPointer = require(script.UI.PortalPointer)
local ProjectileRenderer = require(script.ProjectileRenderer)
local Results = require(script.UI.Results)
local UpgradePicker = require(script.UI.UpgradePicker)

-- There are no tools in this game, and the Backpack hotbar claims the 1-9 keys the level-up
-- picker uses.
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)

local arena = workspace:WaitForChild("Arena")

CameraController.start()
EnemyRenderer.start(arena)
GemRenderer.start()
ProjectileRenderer.start(arena)
BladeRenderer.start(arena)
Hud.start(arena)
PortalPointer.start(arena)
Results.start(arena)
UpgradePicker.start()
