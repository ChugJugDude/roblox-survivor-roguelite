--!strict
-- Items on the floor (server/Pickups.luau): chests from mini-bosses, plus meat, bombs, and magnets
-- from crates and the occasional enemy. Walk over one to use it.

return table.freeze({
	-- Studs from a player's center to collect an item.
	PICKUP_RADIUS = 3.5,
	-- Most items on the floor at once; the oldest goes when a new one drops.
	MAX_ITEMS = 12,

	-- What a broken crate (or a lucky enemy) drops: kind -> relative weight.
	ITEM_WEIGHTS = table.freeze({
		Meat = 0.5,
		Bomb = 0.25,
		Magnet = 0.25,
	}),
	-- Chance for any regular enemy (not a crate or boss) to drop an item.
	ENEMY_DROP_CHANCE = 0.005,

	-- Meat heals this fraction of max health.
	MEAT_HEAL_FRACTION = 0.3,
	-- Bombs kill every regular enemy within this many studs of the player (about a screen), and take
	-- this fraction of a boss's max health.
	BOMB_RADIUS = 45,
	BOMB_BOSS_DAMAGE_FRACTION = 0.15,
})
