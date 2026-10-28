--!strict
-- Decides when sound effects play. Everything here listens to events the client already gets
-- (remotes, Arena attributes, the local player's attributes and character), so the renderers and
-- UI don't need to know about sound. Throttling lives in SoundPlayer.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CurrentArena = require(script.Parent.CurrentArena)
local SoundPlayer = require(script.Parent.SoundPlayer)
local Config = require(ReplicatedStorage.Shared.Config.Audio)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local UpgradesConfig = require(ReplicatedStorage.Shared.Config.Upgrades)

-- Sounds for entering each run phase.
local PHASE_SOUNDS: { [string]: string } = {
	Stage = "StageStart",
	Overtime = "PortalOpen",
	Transition = "StageClear",
	Boss = "BossWarning",
	Victory = "Victory",
	Defeat = "Defeat",
}
local PROJECTILE_SOUNDS: { [string]: string } = {
	Arrow = "Arrow",
	Fireball = "Fireball",
	Meteor = "Fireball",
	EnemyArrow = "EnemyShot",
	BossOrb = "EnemyShot",
}
local EXPLOSION_SOUNDS: { [string]: string } = {
	Bomb = "Bomb",
	Frost = "Frost",
	Blizzard = "Frost",
}
local EFFECT_SOUNDS: { [string]: string } = {
	Lightning = "Lightning",
	HolyGround = "Holy",
}

local started = false

local SoundHooks = {}

local function isList(value: any): boolean
	return typeof(value) == "table" and #value > 0
end

-- Plays the sound for each kind in a batch once (SoundPlayer throttles repeats anyway).
local function playKinds(list: any, sounds: { [string]: string }, default: string?)
	if typeof(list) ~= "table" then
		return
	end
	for _, info in list do
		local name = if typeof(info) == "table" then sounds[info.kind] or default else nil
		if name then
			SoundPlayer.play(name)
		end
	end
end

local function hookRemotes()
	local localPlayer = Players.LocalPlayer
	Remotes.EnemiesHit.OnClientEvent:Connect(function(list)
		if isList(list) then
			SoundPlayer.play("Hit")
		end
	end)
	Remotes.EnemyDespawned.OnClientEvent:Connect(function(list)
		if isList(list) then
			SoundPlayer.play("Kill")
		end
	end)
	Remotes.ProjectilesSpawned.OnClientEvent:Connect(function(list)
		playKinds(list, PROJECTILE_SOUNDS)
	end)
	Remotes.Explosions.OnClientEvent:Connect(function(list)
		playKinds(list, EXPLOSION_SOUNDS, "Explosion")
	end)
	Remotes.WeaponEffects.OnClientEvent:Connect(function(list)
		playKinds(list, EFFECT_SOUNDS)
	end)
	Remotes.EnemyTelegraph.OnClientEvent:Connect(function(list)
		if isList(list) then
			SoundPlayer.play("BossWarning")
		end
	end)

	-- Gems the local player picks up climb in pitch while they keep coming.
	local streak = 0
	local lastGemAt = -math.huge
	Remotes.GemsCollected.OnClientEvent:Connect(function(list)
		if typeof(list) ~= "table" then
			return
		end
		for _, info in list do
			if typeof(info) == "table" and info.userId == localPlayer.UserId then
				local now = os.clock()
				streak = if now - lastGemAt > Config.GEM_STREAK_RESET then 0 else streak + 1
				lastGemAt = now
				SoundPlayer.play("Gem", 1 + math.min(streak, Config.GEM_PITCH_STEPS) * Config.GEM_PITCH_STEP)
				return
			end
		end
	end)
end

-- Phase changes and party level-ups, read from the current Arena's attributes.
local function hookArena()
	local arena: Instance? = nil
	local phase: any = nil
	local level: any = nil
	RunService.Heartbeat:Connect(function()
		local current = CurrentArena.get()
		if current ~= arena then
			-- A new world: take its state as the baseline without playing anything.
			arena = current
			phase = current and current:GetAttribute("Phase")
			level = current and current:GetAttribute("PartyLevel")
			return
		end
		if not current then
			return
		end
		local newPhase = current:GetAttribute("Phase")
		if newPhase ~= phase then
			phase = newPhase
			local name = PHASE_SOUNDS[newPhase]
			if name then
				SoundPlayer.play(name)
			end
		end
		local newLevel = current:GetAttribute("PartyLevel")
		if typeof(newLevel) == "number" and typeof(level) == "number" and newLevel > level then
			SoundPlayer.play("LevelUp")
		end
		level = newLevel
	end)
end

local function hookLocalPlayer()
	local player = Players.LocalPlayer
	local lastShards = player:GetAttribute("Shards")
	player.AttributeChanged:Connect(function(attribute)
		local value = player:GetAttribute(attribute)
		if attribute == "Downed" then
			-- A fresh character also clears Downed (e.g. back in the lobby after a defeat); only a
			-- revive mid-run gets the sound.
			local arena = CurrentArena.get()
			local phase = arena and arena:GetAttribute("Phase")
			if value then
				SoundPlayer.play("Downed")
			elseif phase ~= nil and phase ~= "Victory" and phase ~= "Defeat" then
				SoundPlayer.play("Revived")
			end
		elseif attribute == "Shards" then
			if typeof(value) == "number" and typeof(lastShards) == "number" and value < lastShards then
				SoundPlayer.play("Purchase")
			end
			lastShards = value
		elseif
			string.sub(attribute, 1, 2) == "W_"
			and typeof(value) == "number"
			and value > UpgradesConfig.MAX_LEVEL
		then
			SoundPlayer.play("Evolve")
		end
	end)

	-- Taking damage in a run.
	local function onCharacter(character: Model)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if not humanoid or not humanoid:IsA("Humanoid") then
			return
		end
		local last = humanoid.Health
		humanoid.HealthChanged:Connect(function(health)
			if health < last and CurrentArena.get() and not player:GetAttribute("Downed") then
				SoundPlayer.play("Hurt")
			end
			last = health
		end)
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
end

-- Every button in the game clicks.
local function hookButtons()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local function hook(instance: Instance)
		if instance:IsA("GuiButton") then
			instance.Activated:Connect(function()
				SoundPlayer.play("Click")
			end)
		end
	end
	for _, descendant in playerGui:GetDescendants() do
		hook(descendant)
	end
	playerGui.DescendantAdded:Connect(hook)
end

function SoundHooks.start()
	assert(not started, "SoundHooks.start() was called twice")
	started = true
	hookRemotes()
	hookArena()
	hookLocalPlayer()
	task.spawn(hookButtons)
end

return SoundHooks
