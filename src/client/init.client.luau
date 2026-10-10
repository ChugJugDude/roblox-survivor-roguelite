--!strict
-- Client entry point.

local BladeRenderer = require(script.BladeRenderer)
local CameraController = require(script.CameraController)
local EnemyRenderer = require(script.EnemyRenderer)

CameraController.start()
EnemyRenderer.start()
BladeRenderer.start()
