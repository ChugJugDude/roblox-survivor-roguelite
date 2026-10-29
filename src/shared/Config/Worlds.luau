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
