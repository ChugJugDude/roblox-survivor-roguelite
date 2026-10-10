--!strict
-- XP and gems (server/Progression.luau, client/GemRenderer.luau).

export type GemTier = {
	minValue: number,
	color: Color3,
	size: number,
}

return table.freeze({
	-- XP to go from level L to L + 1: XP_BASE + XP_GROWTH * (L - 1) ^ XP_EXPONENT, rounded.
	-- Level 2 takes 5 XP, level 10 about 50, level 25 about 125.
	XP_BASE = 5,
	XP_GROWTH = 4,
	XP_EXPONENT = 1.2,

	-- Base gem pickup radius in studs, before Magnet.
	PICKUP_RADIUS = 6,
	-- Most gems on the floor at once. Past this, a kill's XP goes straight into the bar.
	MAX_GEMS = 300,
	-- Grid cell size for gem lookups.
	GEM_CELL_SIZE = 8,

	-- How gems look by value. The highest tier whose minValue fits is used.
	GEM_TIERS = {
		{ minValue = 0, color = Color3.fromRGB(90, 180, 255), size = 0.8 },
		{ minValue = 5, color = Color3.fromRGB(90, 230, 120), size = 1 },
		{ minValue = 20, color = Color3.fromRGB(200, 110, 255), size = 1.3 },
		{ minValue = 100, color = Color3.fromRGB(255, 200, 60), size = 1.7 },
	} :: { GemTier },
})
