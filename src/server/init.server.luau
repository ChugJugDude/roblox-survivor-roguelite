--!strict
-- Server entry point. Start services here, in dependency order.

local Characters = require(script.Characters)
local DevCommands = require(script.DevCommands)
local Lobby = require(script.Lobby)
local PlayerData = require(script.PlayerData)
local Simulation = require(script.Simulation)
local Upgrades = require(script.Upgrades)
local WeaponService = require(script.Weapons.WeaponService)

PlayerData.start()
Characters.start()
Upgrades.start()
WeaponService.start()
Lobby.start()
DevCommands.start()
Simulation.start()
