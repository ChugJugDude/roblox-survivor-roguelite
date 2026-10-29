--!strict
-- The worlds a run can take place in (server/Match.luau, server/Arena.luau, server/WaveDirector.luau,
-- client/WorldLook.luau). Each world has its own look, enemy waves, final boss, and Shard reward, and
-- clearing one unlocks the next (`order`).

local Waves = require(script.Parent.Waves)

export type Lighting = {
	ambient: Color3,
	outdoorAmbient: Color3,
	tint: Color3, -- a ColorCorrection tint over the whole view
	brightness: number,
}

export type World = {
	id: string,
	name: string,
	order: number, -- unlock order: clearing world N unlocks world N + 1
	stages: { Waves.Stage }, -- Config.Run.STAGE_COUNT of them; the last one has a finalBoss
	eliteKinds: { string }, -- kinds that can spawn as elites
	shardMultiplier: number, -- on the run's Shard reward
	floorColor: Color3,
	wallColor: Color3,
	accentColor: Color3?, -- glowing floor details (the Volcano's lava cracks)
	lighting: Lighting?, -- nil keeps the lobby's lighting
}

local WORLDS: { World } = {
	{
		id = "Meadow",
		name = "Green Meadow",
		order = 1,
		stages = {
			{
				healthMultiplier = 1,
				damageMultiplier = 1,
				xpMultiplier = 1,
				segments = {
					{ at = 0, interval = 0.8, maxAlive = 25, mix = { Goblin = 1 } },
					{ at = 45, interval = 0.6, maxAlive = 35, mix = { Goblin = 1, Bat = 0.15 } },
					{
						at = 100,
						interval = 0.45,
						maxAlive = 50,
						mix = { Goblin = 1, Bat = 0.15, SkeletonArcher = 0.25 },
					},
				},
				miniBoss = "GoblinGiant",
				miniBossAt = 90,
			},
			{
				healthMultiplier = 1.8,
				damageMultiplier = 1.25,
				xpMultiplier = 2,
				segments = {
					{ at = 0, interval = 0.6, maxAlive = 40, mix = { Goblin = 1, Bat = 0.15, SkeletonArcher = 0.25 } },
					{ at = 60, interval = 0.45, maxAlive = 60, mix = { Goblin = 1, Bat = 0.2, SkeletonArcher = 0.35 } },
					{
						at = 120,
						interval = 0.35,
						maxAlive = 75,
						mix = { Goblin = 1, Bat = 0.25, SkeletonArcher = 0.4 },
					},
				},
				miniBoss = "GoblinGiant",
				miniBossAt = 90,
			},
			{
				healthMultiplier = 3,
				damageMultiplier = 1.5,
				xpMultiplier = 3,
				segments = {
					{ at = 0, interval = 0.45, maxAlive = 60, mix = { Goblin = 1, Bat = 0.25, SkeletonArcher = 0.4 } },
					{ at = 60, interval = 0.35, maxAlive = 80, mix = { Goblin = 1, Bat = 0.3, SkeletonArcher = 0.5 } },
					{
						at = 120,
						interval = 0.28,
						maxAlive = 100,
						mix = { Goblin = 1, Bat = 0.3, SkeletonArcher = 0.5 },
					},
				},
				miniBoss = "GoblinGiant",
				miniBossAt = 90,
				finalBoss = "Ogre",
			},
		},
		eliteKinds = { "Goblin", "SkeletonArcher" },
		shardMultiplier = 1,
		floorColor = Color3.fromRGB(122, 168, 88),
		wallColor = Color3.fromRGB(138, 112, 86),
	},
	{
		id = "Volcano",
		name = "Volcano",
		order = 2,
		-- One row per segment; StyLua would wrap the longer ones.
		-- stylua: ignore
		stages = {
			{
				healthMultiplier = 1.6,
				damageMultiplier = 1.3,
				xpMultiplier = 1.2,
				segments = {
					{ at = 0, interval = 0.8, maxAlive = 25, mix = { FireImp = 1 } },
					{ at = 45, interval = 0.6, maxAlive = 35, mix = { FireImp = 1, MagmaHound = 0.2 } },
					{ at = 100, interval = 0.45, maxAlive = 50, mix = { FireImp = 1, MagmaHound = 0.2, EmberArcher = 0.25 } },
				},
				miniBoss = "MagmaGolem",
				miniBossAt = 90,
			},
			{
				healthMultiplier = 2.8,
				damageMultiplier = 1.6,
				xpMultiplier = 2.4,
				segments = {
					{ at = 0, interval = 0.6, maxAlive = 40, mix = { FireImp = 1, MagmaHound = 0.2, EmberArcher = 0.25 } },
					{ at = 60, interval = 0.45, maxAlive = 60, mix = { FireImp = 1, MagmaHound = 0.25, EmberArcher = 0.35 } },
					{ at = 120, interval = 0.35, maxAlive = 75, mix = { FireImp = 1, MagmaHound = 0.3, EmberArcher = 0.4 } },
				},
				miniBoss = "MagmaGolem",
				miniBossAt = 90,
			},
			{
				healthMultiplier = 4.6,
				damageMultiplier = 1.9,
				xpMultiplier = 3.6,
				segments = {
					{ at = 0, interval = 0.45, maxAlive = 60, mix = { FireImp = 1, MagmaHound = 0.3, EmberArcher = 0.4 } },
					{ at = 60, interval = 0.35, maxAlive = 80, mix = { FireImp = 1, MagmaHound = 0.35, EmberArcher = 0.5 } },
					{ at = 120, interval = 0.28, maxAlive = 100, mix = { FireImp = 1, MagmaHound = 0.35, EmberArcher = 0.5 } },
				},
				miniBoss = "MagmaGolem",
				miniBossAt = 90,
				finalBoss = "Infernal",
			},
		},
		eliteKinds = { "FireImp", "EmberArcher" },
		shardMultiplier = 1.5,
		floorColor = Color3.fromRGB(68, 54, 50),
		wallColor = Color3.fromRGB(78, 60, 52),
		accentColor = Color3.fromRGB(255, 110, 30),
		lighting = {
			ambient = Color3.fromRGB(95, 50, 40),
			outdoorAmbient = Color3.fromRGB(120, 70, 50),
			tint = Color3.fromRGB(255, 228, 210),
			brightness = 1.6,
		},
	},
}

local byId: { [string]: World } = {}
for _, world in WORLDS do
	byId[world.id] = world
end

local Worlds = {}

Worlds.LIST = WORLDS -- in unlock order
Worlds.DEFAULT = "Meadow"

-- The world with `id`, or the default world for an unknown id.
function Worlds.get(id: string?): World
	return (if id then byId[id] else nil) or byId[Worlds.DEFAULT]
end

function Worlds.exists(id: string): boolean
	return byId[id] ~= nil
end

-- The world unlocked by clearing `id`, or nil for the last one.
function Worlds.next(id: string): World?
	local order = Worlds.get(id).order
	for _, world in WORLDS do
		if world.order == order + 1 then
			return world
		end
	end
	return nil
end

return table.freeze(Worlds)
