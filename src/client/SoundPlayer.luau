--!strict
-- Plays the sound effects in Config.Audio. Every sound is 2D (parented to SoundService, not a part):
-- with the overhead camera, everything on screen is close by. Each sound keeps a small pool of
-- Sound instances so overlapping plays don't cut each other off, and honors its minInterval so a
-- crowd of hits in one frame makes one sound. Music (client/Music) shares the "Music" SoundGroup
-- so both can be muted separately.

local ContentProvider = game:GetService("ContentProvider")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(game:GetService("ReplicatedStorage").Shared.Config.Audio)

-- Copies of each sound that can play at once.
local POOL_SIZE = 3
-- Seconds to fade a sound out when it reaches its maxDuration.
local CUT_FADE_TIME = 0.15

type Pool = {
	def: Config.SoundDef,
	sounds: { Sound },
	plays: { number }, -- per copy, counts plays so a delayed cut-off skips a copy that restarted
	next: number, -- which copy to use next (round robin)
	lastPlayed: number, -- os.clock time
}

export type Group = "SFX" | "Music"

local pools: { [string]: Pool } = {}
local groups: { [Group]: SoundGroup } = {}
local groupVolumes: { [Group]: number } = { SFX = 1, Music = 1 }
local muted: { [Group]: boolean } = { SFX = false, Music = false }
local random = Random.new()
local started = false

local SoundPlayer = {}

local function makeGroup(name: Group): SoundGroup
	local group = Instance.new("SoundGroup")
	group.Name = name
	group.Volume = groupVolumes[name]
	group.Parent = SoundService
	return group
end

-- Plays the named sound (a key of Config.Audio.SOUNDS). `pitch` multiplies the sound's own pitch.
-- Ignored if the sound played less than its minInterval ago.
function SoundPlayer.play(name: string, pitch: number?)
	local pool = pools[name]
	if not pool then
		warn(`[SoundPlayer] Unknown sound "{name}"`)
		return
	end
	local now = os.clock()
	if now - pool.lastPlayed < pool.def.minInterval then
		return
	end
	pool.lastPlayed = now

	local index = pool.next
	local sound = pool.sounds[index]
	pool.next = index % #pool.sounds + 1
	local jitter = pool.def.pitchJitter or 0
	sound.PlaybackSpeed = (pool.def.pitch or 1) * (pitch or 1) * (1 + random:NextNumber(-jitter, jitter))
	sound.Volume = pool.def.volume
	sound.TimePosition = 0
	sound:Play()

	local maxDuration = pool.def.maxDuration
	if maxDuration then
		pool.plays[index] += 1
		local play = pool.plays[index]
		task.delay(maxDuration, function()
			if pool.plays[index] == play and sound.IsPlaying then
				TweenService:Create(sound, TweenInfo.new(CUT_FADE_TIME), { Volume = 0 }):Play()
			end
		end)
	end
end

-- The SoundGroup a sound should join (Music uses this for its tracks).
function SoundPlayer.group(name: Group): SoundGroup
	return groups[name]
end

function SoundPlayer.isMuted(name: Group): boolean
	return muted[name]
end

function SoundPlayer.setMuted(name: Group, isMuted: boolean)
	muted[name] = isMuted
	groups[name].Volume = if isMuted then 0 else groupVolumes[name]
end

function SoundPlayer.start()
	assert(not started, "SoundPlayer.start() was called twice")
	started = true
	groups.SFX = makeGroup("SFX")
	groups.Music = makeGroup("Music")

	local folder = Instance.new("Folder")
	folder.Name = "SoundEffects"
	folder.Parent = SoundService
	local toPreload: { Instance } = {}
	for name, def in Config.SOUNDS do
		local sounds = {}
		for index = 1, POOL_SIZE do
			local sound = Instance.new("Sound")
			sound.Name = if index == 1 then name else `{name}{index}`
			sound.SoundId = `rbxassetid://{def.id}`
			sound.Volume = def.volume
			sound.SoundGroup = groups.SFX
			sound.Parent = folder
			table.insert(sounds, sound)
		end
		table.insert(toPreload, sounds[1])
		pools[name] =
			{ def = def, sounds = sounds, plays = table.create(POOL_SIZE, 0), next = 1, lastPlayed = -math.huge }
	end

	task.spawn(function()
		ContentProvider:PreloadAsync(toPreload, function(contentId, status)
			if status ~= Enum.AssetFetchStatus.Success then
				warn(`[SoundPlayer] {contentId} failed to load: {status.Name}`)
			end
		end)
	end)
end

return SoundPlayer
