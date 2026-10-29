--!strict
-- Turns a build (weapon and passive levels, plus permanent hero and Altar bonuses) into the numbers
-- weapons and characters use. Shared, so the server's hit checks and the client's visuals always
-- agree.

local Config = require(script.Parent.Config.Upgrades)
local MetaStats = require(script.Parent.MetaStats)

export type Build = {
	weapons: { [string]: number },
	passives: { [string]: number },
	bonus: MetaStats.Totals?, -- permanent bonuses from the hero and the Altar (shared/MetaStats)
}

-- Multipliers (1 = no change) and flat bonuses from passives and permanent bonuses.
export type Modifiers = {
	damage: number,
	cooldown: number,
	spin: number,
	area: number,
	moveSpeed: number,
	pickupRadius: number,
	maxHealthBonus: number,
	damageTaken: number,
	regen: number, -- health per second
}

local BuildStats = {}

-- A weapon's stats at `level`, where MAX_LEVEL + 1 means evolved.
local function weaponBase(id: string, level: number): any
	local def = Config.WEAPONS[id]
	return if level > Config.MAX_LEVEL then def.evolution.stats else def.levels[level]
end

-- Whether the weapon has evolved.
function BuildStats.isEvolved(build: Build, id: string): boolean
	return (build.weapons[id] or 0) > Config.MAX_LEVEL
end

-- The weapon a passive evolves, or nil if it isn't any weapon's evolution pair.
function BuildStats.weaponEvolvedBy(passiveId: string): string?
	for id, def in Config.WEAPONS do
		if def.evolution.passive == passiveId then
			return id
		end
	end
	return nil
end

-- The display name for a weapon at `level` (its evolution's name once evolved).
function BuildStats.weaponName(id: string, level: number): string
	local def = Config.WEAPONS[id]
	return if level > Config.MAX_LEVEL then def.evolution.name else def.name
end

-- What a passive gives at `level`, as shown on upgrade cards and in the pause menu, e.g.
-- "+40% weapon damage".
function BuildStats.passiveText(id: string, level: number): string
	local def = Config.PASSIVES[id]
	local value = def.values[level] or 0
	return string.format(def.description, math.floor((if def.percent then value * 100 else value) + 0.5))
end

local function passiveValue(build: Build, id: string): number
	local level = build.passives[id]
	local def = Config.PASSIVES[id]
	return if level and def then def.values[level] or 0 else 0
end

function BuildStats.modifiers(build: Build): Modifiers
	local haste = passiveValue(build, "Haste")
	local bonus = build.bonus or MetaStats.NONE
	return {
		damage = 1 + passiveValue(build, "Might") + bonus.damage,
		cooldown = 1 - haste,
		spin = 1 + haste,
		area = 1 + passiveValue(build, "Reach") + bonus.area,
		moveSpeed = 1 + passiveValue(build, "Swiftness") + bonus.moveSpeed,
		pickupRadius = 1 + passiveValue(build, "Magnet") + bonus.pickupRadius,
		maxHealthBonus = passiveValue(build, "Vitality") + bonus.maxHealth,
		damageTaken = 1 - passiveValue(build, "Armor"),
		regen = passiveValue(build, "Regen"),
	}
end

-- The player's Spinning Blade after passives, or nil if they don't have it.
function BuildStats.spinningBlade(build: Build): Config.SpinningBladeStats?
	local level = build.weapons.SpinningBlade
	if not level then
		return nil
	end
	local base: Config.SpinningBladeStats = weaponBase("SpinningBlade", level)
	local modifiers = BuildStats.modifiers(build)
	return {
		bladeCount = base.bladeCount,
		innerRadius = base.innerRadius,
		-- Reach lengthens the blade outward; the inner edge stays put.
		outerRadius = base.innerRadius + (base.outerRadius - base.innerRadius) * modifiers.area,
		width = base.width,
		spinSpeed = base.spinSpeed * modifiers.spin,
		damage = base.damage * modifiers.damage,
		hitCooldown = base.hitCooldown,
	}
end

-- The player's Volley Arrows after passives, or nil if they don't have it.
function BuildStats.volleyArrows(build: Build): Config.VolleyArrowsStats?
	local level = build.weapons.VolleyArrows
	if not level then
		return nil
	end
	local base: Config.VolleyArrowsStats = weaponBase("VolleyArrows", level)
	local modifiers = BuildStats.modifiers(build)
	return {
		cooldown = base.cooldown * modifiers.cooldown,
		arrowCount = base.arrowCount,
		spread = base.spread,
		speed = base.speed,
		damage = base.damage * modifiers.damage,
		pierce = base.pierce,
		range = base.range,
		radius = base.radius,
		targets = base.targets,
	}
end

-- The player's Fireball after passives, or nil if they don't have it.
function BuildStats.fireball(build: Build): Config.FireballStats?
	local level = build.weapons.Fireball
	if not level then
		return nil
	end
	local base: Config.FireballStats = weaponBase("Fireball", level)
	local modifiers = BuildStats.modifiers(build)
	return {
		cooldown = base.cooldown * modifiers.cooldown,
		count = base.count,
		speed = base.speed,
		damage = base.damage * modifiers.damage,
		blastRadius = base.blastRadius * modifiers.area,
		range = base.range,
		radius = base.radius,
	}
end

-- The player's Chain Lightning after passives, or nil if they don't have it.
function BuildStats.chainLightning(build: Build): Config.ChainLightningStats?
	local level = build.weapons.ChainLightning
	if not level then
		return nil
	end
	local base: Config.ChainLightningStats = weaponBase("ChainLightning", level)
	local modifiers = BuildStats.modifiers(build)
	return {
		cooldown = base.cooldown * modifiers.cooldown,
		bolts = base.bolts,
		chains = base.chains,
		-- Reach lets bolts jump farther between enemies.
		jumpRange = base.jumpRange * modifiers.area,
		damage = base.damage * modifiers.damage,
		range = base.range,
	}
end

-- The player's Frost Nova after passives, or nil if they don't have it.
function BuildStats.frostNova(build: Build): Config.FrostNovaStats?
	local level = build.weapons.FrostNova
	if not level then
		return nil
	end
	local base: Config.FrostNovaStats = weaponBase("FrostNova", level)
	local modifiers = BuildStats.modifiers(build)
	return {
		cooldown = base.cooldown * modifiers.cooldown,
		radius = base.radius * modifiers.area,
		damage = base.damage * modifiers.damage,
		slow = base.slow,
		slowDuration = base.slowDuration,
	}
end

-- The player's Holy Ground after passives, or nil if they don't have it.
function BuildStats.holyGround(build: Build): Config.HolyGroundStats?
	local level = build.weapons.HolyGround
	if not level then
		return nil
	end
	local base: Config.HolyGroundStats = weaponBase("HolyGround", level)
	local modifiers = BuildStats.modifiers(build)
	return {
		cooldown = base.cooldown * modifiers.cooldown,
		zones = base.zones,
		radius = base.radius * modifiers.area,
		damage = base.damage * modifiers.damage,
		tick = base.tick,
		duration = base.duration,
		heal = base.heal,
		range = base.range,
	}
end

-- The player's Warding rings after passives, or nil if they don't have the passive.
function BuildStats.warding(build: Build): Config.WardingStats?
	local count = passiveValue(build, "Warding")
	if count <= 0 then
		return nil
	end
	local base = Config.WARDING
	return {
		count = count,
		orbitRadius = base.orbitRadius,
		ringRadius = base.ringRadius,
		spinSpeed = base.spinSpeed,
		damage = base.damage * BuildStats.modifiers(build).damage,
		hitCooldown = base.hitCooldown,
	}
end

-- Reads a build from a Player's W_<weapon> / P_<passive> / B_<bonus> attributes (published by
-- server/Upgrades).
function BuildStats.fromAttributes(player: Player): Build
	local build: Build = { weapons = {}, passives = {} }
	for id in Config.WEAPONS do
		local level = player:GetAttribute("W_" .. id)
		if typeof(level) == "number" then
			build.weapons[id] = level
		end
	end
	for id in Config.PASSIVES do
		local level = player:GetAttribute("P_" .. id)
		if typeof(level) == "number" then
			build.passives[id] = level
		end
	end
	local bonus: { [string]: number } = {}
	for _, field in MetaStats.FIELDS do
		local value = player:GetAttribute("B_" .. field)
		if typeof(value) == "number" then
			bonus[field] = value
		end
	end
	build.bonus = MetaStats.fromMap(bonus)
	return build
end

return BuildStats
