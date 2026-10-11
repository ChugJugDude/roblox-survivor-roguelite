--!strict
-- Turns a build (weapon and passive levels) into the numbers weapons and characters use. Shared, so
-- the server's hit checks and the client's visuals always agree.

local Config = require(script.Parent.Config.Upgrades)

export type Build = {
	weapons: { [string]: number },
	passives: { [string]: number },
}

-- Multipliers (1 = no change) and flat bonuses from passives.
export type Modifiers = {
	damage: number,
	cooldown: number,
	spin: number,
	area: number,
	moveSpeed: number,
	pickupRadius: number,
	maxHealthBonus: number,
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

-- The display name for a weapon at `level` (its evolution's name once evolved).
function BuildStats.weaponName(id: string, level: number): string
	local def = Config.WEAPONS[id]
	return if level > Config.MAX_LEVEL then def.evolution.name else def.name
end

local function passiveValue(build: Build, id: string): number
	local level = build.passives[id]
	local def = Config.PASSIVES[id]
	return if level and def then def.values[level] or 0 else 0
end

function BuildStats.modifiers(build: Build): Modifiers
	local haste = passiveValue(build, "Haste")
	return {
		damage = 1 + passiveValue(build, "Might"),
		cooldown = 1 - haste,
		spin = 1 + haste,
		area = 1 + passiveValue(build, "Reach"),
		moveSpeed = 1 + passiveValue(build, "Swiftness"),
		pickupRadius = 1 + passiveValue(build, "Magnet"),
		maxHealthBonus = passiveValue(build, "Vitality"),
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

-- Reads a build from a Player's W_<weapon> / P_<passive> attributes (published by server/Upgrades).
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
	return build
end

return BuildStats
