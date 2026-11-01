--!strict
-- Procedural walk cycles for enemy visuals (client/EnemyModels): no Animator or Humanoid, just a
-- pose applied to each part's offset inside EnemyRenderer's one BulkMoveTo, so it stays cheap at
-- 200 enemies.
--
-- An enemy's walk cycle advances with the distance it actually moves, so its steps match its speed
-- and stop when it stops. Every step the whole body bobs and rolls side to side; parts tagged with a
-- group swing about their joint: arms and legs (ArmL/ArmR, LegA/LegB, opposite pairs) and wings
-- (WingL/WingR, which flap all the time). Untagged parts move with the body.
--
-- When an enemy's contact attack lands (Remotes.EnemyAttacked), it strikes: its arms whip forward
-- and its body lunges and leans in, then recovers over strikeTime. A boss winding up an attack
-- (a telegraph) holds a pose until it lands: see EnemyAnimation.windUp.

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
	strike: number, -- radians the arms whip forward when it attacks
	lunge: number, -- studs the body lunges forward when it attacks
	lean: number, -- radians the body leans in when it attacks
	strikeTime: number, -- seconds an attack takes, out and back
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
		strike = math.rad(80),
		lunge = 0.5,
		lean = math.rad(12),
		strikeTime = 0.35,
	}
	for key, value in overrides do
		(result :: any)[key] = value
	end
	return result
end

local DEFAULT = profile({})
local ARCHER = profile({ stride = 0.9, bob = 0.15, waddle = math.rad(6), swing = math.rad(30), strike = math.rad(50) })
local BRUTE = profile({
	stride = 0.6,
	bob = 0.3,
	waddle = math.rad(6),
	swing = math.rad(25),
	breathe = 0.06,
	strike = math.rad(70),
	lunge = 0.8,
	strikeTime = 0.5,
})
local BOSS = profile({
	stride = 0.5,
	bob = 0.4,
	waddle = math.rad(5),
	swing = math.rad(25),
	breathe = 0.1,
	strike = math.rad(70),
	lunge = 1.2,
	strikeTime = 0.6,
})

local PROFILES: { [string]: Profile } = {
	-- Bats dive and hounds pounce: no arms, all lunge.
	Bat = profile({
		stride = 0,
		breathe = 0,
		flap = math.rad(40),
		flapRate = 18,
		hover = 0.3,
		lunge = 0.9,
		lean = math.rad(25),
	}),
	MagmaHound = profile({
		stride = 0.9,
		bob = 0.12,
		waddle = math.rad(3),
		swing = math.rad(45),
		lunge = 0.9,
		lean = math.rad(15),
	}),
	SkeletonArcher = ARCHER,
	EmberArcher = ARCHER,
	GoblinGiant = BRUTE,
	MagmaGolem = BRUTE,
	Ogre = BOSS,
	Infernal = BOSS,
	Crate = profile({ stride = 0, bob = 0, waddle = 0, swing = 0, breathe = 0, strike = 0, lunge = 0, lean = 0 }),
}

function EnemyAnimation.profile(kind: string): Profile
	return PROFILES[kind] or DEFAULT
end

-- How long a wind-up pose takes to settle in (seconds).
local WINDUP_IN = 0.25

type Pose = {
	raise: number, -- arms, radians (forward is positive)
	spread: number, -- arms out to the sides, radians
	tilt: number, -- body, radians (back is positive)
	pull: number?, -- the right arm only, radians (a bowstring drawn back is negative)
	twist: number?, -- the body about its vertical axis, radians (negative turns the left side forward)
}

type WindUp = {
	hold: Pose, -- held until the attack lands
	release: Pose, -- snapped to when it lands, then eased out over `out` seconds
	out: number,
}

local NO_SPREAD = 0
-- A charge rears back with the arms drawn back. An eruption raises both arms overhead, then slams.
-- A ring gathers its arms in front with a hunch, then flings them out wide as the shots fly.
local WINDUPS: { [string]: WindUp } = {
	Lane = {
		hold = { raise = math.rad(-45), spread = NO_SPREAD, tilt = math.rad(10) },
		release = { raise = math.rad(-45), spread = NO_SPREAD, tilt = math.rad(10) },
		out = 0.2,
	},
	Circle = {
		hold = { raise = math.rad(150), spread = NO_SPREAD, tilt = math.rad(8) },
		release = { raise = math.rad(150), spread = NO_SPREAD, tilt = math.rad(8) },
		out = 0.2,
	},
	Ring = {
		hold = { raise = math.rad(70), spread = math.rad(-10), tilt = math.rad(-10) },
		release = { raise = math.rad(40), spread = math.rad(80), tilt = math.rad(8) },
		out = 0.45,
	},
	-- An archer turns its bow shoulder (the left) a little toward the target and holds its bow arm
	-- out at it; the string arm comes up short of it, drawing. EnemyRenderer moves the bow itself
	-- (EnemyModels' bow rig) up in front and bends the string back to the nocked bolt.
	Draw = {
		hold = {
			raise = math.rad(75),
			spread = NO_SPREAD,
			tilt = math.rad(4),
			pull = math.rad(-45),
			twist = math.rad(-15),
		},
		release = { raise = math.rad(75), spread = NO_SPREAD, tilt = 0, pull = 0, twist = math.rad(-15) },
		out = 0.3,
	},
}

-- How far into its wind-up pose a telegraph of `shape` shown from `from` to `to` is `now`: easing
-- in to 1, holding, then easing back out to 0 once the attack lands.
function EnemyAnimation.windUpAmount(shape: string, from: number, to: number, now: number): number
	local windUp = WINDUPS[shape]
	if not windUp or now < from or now > to + windUp.out then
		return 0
	end
	return if now <= to then math.clamp((now - from) / WINDUP_IN, 0, 1) else 1 - (now - to) / windUp.out
end

-- A wind-up pose `now` for a telegraph of `shape` shown from `from` to `to` (os.clock times): the
-- extra arm angle, how far the arms spread to the sides, the body tilt, the right arm's pull, and
-- the body's twist.
function EnemyAnimation.windUp(
	shape: string,
	from: number,
	to: number,
	now: number
): (number, number, number, number, number)
	local windUp = WINDUPS[shape]
	if not windUp or now < from or now > to + windUp.out then
		return 0, 0, 0, 0, 0
	end
	local pose = if now <= to then windUp.hold else windUp.release
	local amount = EnemyAnimation.windUpAmount(shape, from, to, now)
	return pose.raise * amount,
		pose.spread * amount,
		pose.tilt * amount,
		(pose.pull or 0) * amount,
		(pose.twist or 0) * amount
end

-- The pose for this frame: the body's offset from the root, the limb swing, the wing flap, and the
-- strike angle. `walk` is the walk-cycle angle, `motion` how much it's walking (0 to 1), `time` a
-- clock with a per-enemy phase so crowds don't move in lockstep, and `sinceAttack` seconds since
-- its last attack landed.
function EnemyAnimation.pose(
	look: Profile,
	walk: number,
	motion: number,
	time: number,
	sinceAttack: number,
	tilt: number,
	twist: number
): (CFrame, number, number, number)
	local step = math.sin(walk)
	local rise = math.abs(step) * look.bob * motion + math.sin(time * 2) * look.breathe
	if look.hover > 0 then
		rise += math.sin(time * 3) * look.hover
	end
	-- Out and back: fast to full reach, then a slower recovery.
	local progress = sinceAttack / look.strikeTime
	local attack = if progress >= 0 and progress < 1 then math.sin(math.pi * math.sqrt(progress)) else 0
	local body = CFrame.new(0, rise, -look.lunge * attack)
		* CFrame.Angles(tilt - look.lean * attack, twist, step * look.waddle * motion * (1 - attack))
	local flap = if look.flap > 0 then math.sin(time * look.flapRate) * look.flap else 0
	return body, step * look.swing * motion * (1 - attack), flap, look.strike * attack
end

-- Where part `index` goes relative to the enemy's root this frame.
function EnemyAnimation.place(
	groups: { [number]: string },
	joints: { [number]: Vector3 },
	offset: CFrame,
	index: number,
	body: CFrame,
	swing: number,
	flap: number,
	strike: number,
	raise: number,
	spread: number,
	pull: number
): CFrame
	local group = groups[index]
	if not group then
		return body * offset
	end
	-- A positive angle about X swings a hanging limb forward. The right arm (the weapon hand) leads
	-- the strike.
	local rotation
	if group == "ArmL" then
		rotation = CFrame.Angles(swing + strike * 0.6 + raise, 0, -spread)
	elseif group == "ArmR" then
		rotation = CFrame.Angles(-swing + strike + raise + pull, 0, spread)
	elseif group == "LegB" then
		rotation = CFrame.Angles(swing, 0, 0)
	elseif group == "LegA" then
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
