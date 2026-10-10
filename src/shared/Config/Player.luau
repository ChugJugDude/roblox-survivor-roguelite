--!strict
-- Base character stats, applied by server/Characters.luau on every spawn.

return table.freeze({
	MAX_HEALTH = 100,
	-- Roblox's default is 16. Enemies should be slower than this so the player can kite.
	WALK_SPEED = 20,
})
