--!strict
-- Weapon stats.

export type SpinningBladeDef = {
	bladeCount: number,
	-- Each blade covers this band of distance from the player's center. The inner edge is close
	-- enough to hit enemies pressed up against the player.
	innerRadius: number,
	outerRadius: number,
	width: number,
	spinSpeed: number, -- radians per second
	damage: number,
	hitCooldown: number, -- seconds before one player's blades can hit the same enemy again
}

return table.freeze({
	SpinningBlade = table.freeze({
		bladeCount = 3,
		innerRadius = 2.5,
		outerRadius = 9,
		width = 1.2,
		spinSpeed = 4,
		damage = 12,
		hitCooldown = 0.4,
	}) :: SpinningBladeDef,
})
