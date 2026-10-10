--!strict
-- Client entry point.

local BladeRenderer = require(script.BladeRenderer)
local CameraController = require(script.CameraController)
local EnemyRenderer = require(script.EnemyRenderer)
local Hud = require(script.UI.Hud)
local PortalPointer = require(script.UI.PortalPointer)
local Results = require(script.UI.Results)

CameraController.start()
EnemyRenderer.start()
BladeRenderer.start()

local arena = workspace:WaitForChild("Arena")
Hud.start(arena)
PortalPointer.start(arena)
Results.start(arena)
