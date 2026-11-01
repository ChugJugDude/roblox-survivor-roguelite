--!strict
-- Procedural walk cycles for enemy visuals (client/EnemyModels): no Animator or Humanoid, just a
-- pose applied to each part's offset inside EnemyRenderer's one BulkMoveTo, so it stays cheap at
-- 200 enemies.
--
-- An enemy's walk cycle advances with the distance it actually moves, so its steps match its speed
-- and stop when it stops. Every step the whole body bobs and rolls side to side; parts tagged with a
-- group swing about their joint: arms and legs (ArmL/ArmR, LegA/LegB, opposite pairs) and wings
-- (WingL/WingR, which flap all the time). Untagged parts move with the body.

local EnemyAnimation = {}

export type Profile = {
	stride: number, -- walk-cycle radians per stud moved (two steps per cycle)
	bob: number, -- studs the body rises on each step
	waddle: number, -- radians of side-to-side roll on each step
	swing: number, -- radians arms and legs swing on each step
	breathe: number, -- studs of slow rise and fall, moving or not
	flap: number, -- radians wings flap
	flapRate: number, -- radians per second
	hover: number, -- studs fliers drift up and down
}

local function profile(overrides: { [string]: number }): Profile
	local result: Profile = {
		stride = 1,
		bob = 0.2,
		waddle = math.rad(8),
		swing = math.rad(40),
		breathe = 0.03,
		flap = 0,
		flapRate = 0,
		hover = 0,
	}
	for key, value in overrides do
		(result :: any)[key] = value
	end
	return result
end

local DEFAULT = profile({})
local ARCHER = profile({ stride = 0.9, bob = 0.15, waddle = math.rad(6), swing = math.rad(30) })
local BRUTE = profile({ stride = 0.6, bob = 0.3, waddle = math.rad(6), swing = math.rad(25), breathe = 0.06 })
local BOSS = profile({ stride = 0.5, bob = 0.4, waddle = math.rad(5), swing = math.rad(25), breathe = 0.1 })

local PROFILES: { [string]: Profile } = {
	Bat = profile({ stride = 0, breathe = 0, flap = math.rad(40), flapRate = 18, hover = 0.3 }),
	MagmaHound = profile({ stride = 0.9, bob = 0.12, waddle = math.rad(3), swing = math.rad(45) }),
	SkeletonArcher = ARCHER,
	EmberArcher = ARCHER,
	GoblinGiant = BRUTE,
	MagmaGolem = BRUTE,
	Ogre = BOSS,
	Infernal = BOSS,
	Crate = profile({ stride = 0, bob = 0, waddle = 0, swing = 0, breathe = 0 }),
}

function EnemyAnimation.profile(kind: string): Profile
	return PROFILES[kind] or DEFAULT
end

-- The pose for this frame: the body's offset from the root, and the limb and wing angles.
-- `walk` is the walk-cycle angle, `motion` how much it's walking (0 to 1), `time` a clock with a
-- per-enemy phase so crowds don't move in lockstep.
function EnemyAnimation.pose(look: Profile, walk: number, motion: number, time: number): (CFrame, number, number)
	local step = math.sin(walk)
	local rise = math.abs(step) * look.bob * motion + math.sin(time * 2) * look.breathe
	if look.hover > 0 then
		rise += math.sin(time * 3) * look.hover
	end
	local body = CFrame.new(0, rise, 0) * CFrame.Angles(0, 0, step * look.waddle * motion)
	local flap = if look.flap > 0 then math.sin(time * look.flapRate) * look.flap else 0
	return body, step * look.swing * motion, flap
end

-- Where part `index` goes relative to the enemy's root this frame.
function EnemyAnimation.place(
	groups: { [number]: string },
	joints: { [number]: Vector3 },
	offset: CFrame,
	index: number,
	body: CFrame,
	swing: number,
	flap: number
): CFrame
	local group = groups[index]
	if not group then
		return body * offset
	end
	local rotation
	if group == "ArmL" or group == "LegB" then
		rotation = CFrame.Angles(swing, 0, 0)
	elseif group == "ArmR" or group == "LegA" then
		rotation = CFrame.Angles(-swing, 0, 0)
	elseif group == "WingL" then
		rotation = CFrame.Angles(0, 0, -flap)
	elseif group == "WingR" then
		rotation = CFrame.Angles(0, 0, flap)
	else
		return body * offset
	end
	local joint = joints[index]
	return body * CFrame.new(joint) * rotation * CFrame.new(-joint) * offset
end

return EnemyAnimation
