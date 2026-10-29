--!strict
-- The arena built by server/Arena.luau: a square floor with walls around it.

return table.freeze({
	-- Center of the floor's top surface. Enemy and blade visuals sit on this height.
	ORIGIN = Vector3.new(0, 0, 0),
	-- Playable area inside the walls, in studs (SIZE x SIZE).
	SIZE = 160,
	FLOOR_THICKNESS = 4,
	-- Taller than a character can jump.
	WALL_HEIGHT = 10,
	WALL_THICKNESS = 4,
	-- Floor and wall colors come from the world (Config.Worlds).
})
