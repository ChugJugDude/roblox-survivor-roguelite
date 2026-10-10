--!strict
-- Server entry point. Start services here, in dependency order.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Arena = require(script.Arena)
local Characters = require(script.Characters)
local DevCommands = require(script.DevCommands)
local EnemyReplicator = require(script.EnemyReplicator)
local EnemyService = require(script.EnemyService)
local PlayerData = require(script.PlayerData)
local Portal = require(script.Portal)
local Progression = require(script.Progression)
local Run = require(script.Run)
local Simulation = require(script.Simulation)
local WaveDirector = require(script.WaveDirector)
local ArenaConfig = require(ReplicatedStorage.Shared.Config.Arena)

PlayerData.start()

local arena = Arena.build(ArenaConfig.ORIGIN)
Characters.start(arena.origin + Vector3.new(0, 4, 0))
EnemyService.init(arena)
Portal.init(arena)
Progression.start(arena)
WaveDirector.init(arena)
EnemyReplicator.start()
Run.start(arena)
DevCommands.start(arena)
Simulation.start()
