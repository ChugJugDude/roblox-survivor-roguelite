--!strict
-- The M0 placeholder spawner (server/EnemySpawner.luau). M1's wave director replaces it.

return table.freeze({
	ENEMY_KIND = "Goblin",
	MAX_ALIVE = 40,
	-- Seconds between spawns.
	SPAWN_INTERVAL = 0.6,
	-- Enemies appear on a ring around a random living player, near the edge of the screen.
	SPAWN_DISTANCE_MIN = 35,
	SPAWN_DISTANCE_MAX = 50,
	-- Keep spawns at least this far inside the walls.
	ARENA_MARGIN = 4,
})
