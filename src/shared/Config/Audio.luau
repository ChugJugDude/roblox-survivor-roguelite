--!strict
-- Sound effects and music (client/SoundPlayer, client/Music, client/SoundHooks). Every id is a free
-- Creator Store asset; most come from Roblox's licensed libraries (Pro Sound Effects, APM Music).
-- Swap a sound by changing its id here.

-- Sounds are grouped so players can turn each kind up or down (the settings panel's sliders).
export type Category = "Hits" | "Arrows" | "Fireball" | "Lightning" | "Frost" | "Holy" | "Enemies" | "Game"

export type SoundDef = {
	category: Category,
	id: number,
	volume: number,
	-- Plays at most once per this many seconds, so a crowd of hits in one frame makes one sound.
	minInterval: number,
	pitch: number?, -- default 1
	pitchJitter: number?, -- random +/- this much pitch per play, so repeats don't sound identical
	-- Fades the sound out after this many seconds, cutting off a long tail (e.g. explosion reverb
	-- that would pile up when many play close together).
	maxDuration: number?,
}

export type MusicDef = {
	id: number,
	volume: number,
}

local function sound(
	category: Category,
	id: number,
	volume: number,
	minInterval: number,
	pitch: number?,
	pitchJitter: number?,
	maxDuration: number?
): SoundDef
	return table.freeze({
		category = category,
		id = id,
		volume = volume,
		minInterval = minInterval,
		pitch = pitch,
		pitchJitter = pitchJitter,
		maxDuration = maxDuration,
	})
end

return table.freeze({
	-- The settings panel's per-kind sliders, in order.
	CATEGORIES = table.freeze({
		table.freeze({ id = "Hits", name = "Hits and kills" }),
		table.freeze({ id = "Arrows", name = "Volley Arrows" }),
		table.freeze({ id = "Fireball", name = "Fireball and Meteor" }),
		table.freeze({ id = "Lightning", name = "Chain Lightning" }),
		table.freeze({ id = "Frost", name = "Frost Nova" }),
		table.freeze({ id = "Holy", name = "Holy Ground" }),
		table.freeze({ id = "Enemies", name = "Enemy attacks" }),
		table.freeze({ id = "Game", name = "Pickups and alerts" }),
	}) :: { { id: Category, name: string } },

	SOUNDS = table.freeze({
		-- Combat
		Hit = sound("Hits", 138293953015099, 0.3, 0.07, 1, 0.12),
		Kill = sound("Hits", 109359226723492, 0.3, 0.05, 1, 0.15),
		Arrow = sound("Arrows", 123796710194563, 0.25, 0.1, 1.4, 0.1),
		Fireball = sound("Fireball", 126941244422484, 0.2, 0.15, 1, 0.08),
		-- Meteor drops several at once, so it's quieter, spaced out, and cut short.
		Explosion = sound("Fireball", 126462172690929, 0.14, 0.25, 1, 0.1, 0.7),
		Bomb = sound("Game", 138533090376585, 0.5, 0.3, 1, 0, 1.5),
		Frost = sound("Frost", 9125611419, 0.45, 0.2, 1.2, 0.05),
		Lightning = sound("Lightning", 9114277757, 0.3, 0.15, 1, 0.1),
		Holy = sound("Holy", 9126073001, 0.2, 0.3, 0.8, 0.05),
		EnemyShot = sound("Enemies", 138890894929151, 0.15, 0.2, 1.3, 0.1),
		BossWarning = sound("Enemies", 6875748361, 0.6, 1),
		-- The player
		Hurt = sound("Game", 84636875169658, 0.45, 0.25, 0.8, 0.08),
		Downed = sound("Game", 84636875169658, 0.7, 1, 0.5),
		Revived = sound("Game", 87617283678788, 0.5, 0.5),
		Gem = sound("Game", 4612374807, 0.2, 0.04),
		LevelUp = sound("Game", 112485797063762, 0.5, 0.3),
		Evolve = sound("Game", 9126073011, 0.6, 0.5),
		-- The run
		StageStart = sound("Game", 9126073318, 0.4, 1),
		PortalOpen = sound("Game", 93989620006639, 0.5, 1),
		StageClear = sound("Game", 1836473398, 0.5, 1),
		Victory = sound("Game", 1836473422, 0.6, 1),
		Defeat = sound("Game", 9042970759, 0.5, 1),
		-- UI and lobby
		Click = sound("Game", 88442833509532, 0.4, 0.05),
		Purchase = sound("Game", 4612374495, 0.5, 0.2),
	}) :: { [string]: SoundDef },

	-- Gem pickups in quick succession climb in pitch, up to this many steps, then reset after a pause.
	GEM_PITCH_STEP = 0.04,
	GEM_PITCH_STEPS = 12,
	GEM_STREAK_RESET = 0.6, -- seconds without a pickup

	MUSIC = table.freeze({
		Lobby = table.freeze({ id = 1841593944, volume = 0.3 }),
		Run = table.freeze({ id = 1846800656, volume = 0.25 }),
		Boss = table.freeze({ id = 9043602056, volume = 0.3 }),
	}) :: { [string]: MusicDef },
	MUSIC_FADE_TIME = 1.2, -- seconds to crossfade between tracks
})
