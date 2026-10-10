--!strict
-- Server entry point. Start services here, in dependency order.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Arena = require(script.Arena)
local Characters = require(script.Characters)
local EnemyReplicator = require(script.EnemyReplicator)
local EnemyService = require(script.EnemyService)
local EnemySpawner = require(script.EnemySpawner)
local PlayerData = require(script.PlayerData)
local Simulation = require(script.Simulation)
local ArenaConfig = require(ReplicatedStorage.Shared.Config.Arena)

PlayerData.start()

local arena = Arena.build(ArenaConfig.ORIGIN)
Characters.start(arena.origin + Vector3.new(0, 4, 0))
EnemyService.init(arena)
EnemySpawner.init(arena)
EnemyReplicator.start()
Simulation.start()
