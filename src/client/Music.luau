--!strict
-- Background music: the lobby track in the lobby, the run track during a run, the boss track in
-- the Boss phase, and silence on the results screen (SoundHooks plays the victory/defeat sting).
-- Tracks crossfade when the wanted one changes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local CurrentArena = require(script.Parent.CurrentArena)
local SoundPlayer = require(script.Parent.SoundPlayer)
local Config = require(ReplicatedStorage.Shared.Config.Audio)

-- How often to check which track should play.
local CHECK_INTERVAL = 0.25

local tracks: { [string]: Sound } = {}
local current: string? = nil
local started = false

local Music = {}

-- The track that fits where the player is, or nil for silence.
local function wanted(): string?
	local arena = CurrentArena.get()
	if not arena then
		return "Lobby"
	end
	local phase = arena:GetAttribute("Phase")
	if phase == "Victory" or phase == "Defeat" then
		return nil
	end
	return if phase == "Boss" then "Boss" else "Run"
end

local function fade(sound: Sound, volume: number)
	TweenService:Create(sound, TweenInfo.new(Config.MUSIC_FADE_TIME), { Volume = volume }):Play()
end

local function switchTo(name: string?)
	local old = if current then tracks[current] else nil
	current = name
	if old then
		fade(old, 0)
		task.delay(Config.MUSIC_FADE_TIME, function()
			-- Only stop it if it didn't become the current track again meanwhile.
			if not current or tracks[current] ~= old then
				old:Stop()
			end
		end)
	end
	local new = if name then tracks[name] else nil
	if new then
		if not new.IsPlaying then
			new.Volume = 0
			new.TimePosition = 0
			new:Play()
		end
		fade(new, Config.MUSIC[name :: string].volume)
	end
end

function Music.start()
	assert(not started, "Music.start() was called twice")
	started = true

	for name, def in Config.MUSIC do
		local sound = Instance.new("Sound")
		sound.Name = `Music{name}`
		sound.SoundId = `rbxassetid://{def.id}`
		sound.Looped = true
		sound.Volume = 0
		sound.SoundGroup = SoundPlayer.group("Music")
		sound.Parent = SoundService
		tracks[name] = sound
	end

	local sinceCheck = math.huge
	RunService.Heartbeat:Connect(function(dt)
		sinceCheck += dt
		if sinceCheck < CHECK_INTERVAL then
			return
		end
		sinceCheck = 0
		local name = wanted()
		if name ~= current then
			switchTo(name)
		end
	end)
end

return Music
