--!strict
-- Parties and matches (server/Lobby.luau, server/Match.luau, server/Characters.luau).

return table.freeze({
	MAX_PARTY_SIZE = 4,
	-- Seconds the portal pad counts down once someone steps on (anyone stepping on joins).
	PARTY_COUNTDOWN = 10,
	-- Most matches running at once in one server. Each has its own arena far from the lobby.
	MAX_MATCHES = 4,
	-- After a run ends, players go back to the lobby on their own after this many seconds.
	RETURN_TO_LOBBY_AFTER = 20,

	-- Downed, not dead: a hit that would kill instead downs the player. A teammate standing within
	-- REVIVE_RADIUS for REVIVE_TIME seconds brings them back at REVIVE_HEALTH_FRACTION health with
	-- REVIVE_GRACE seconds of invulnerability. Everyone down (or gone) loses the run.
	REVIVE_RADIUS = 5,
	REVIVE_TIME = 3,
	REVIVE_HEALTH_FRACTION = 0.5,
	REVIVE_GRACE = 1.5,

	-- Scaling for a party of N (counted when the run starts). Each player past the first adds:
	HEALTH_PER_EXTRA_PLAYER = 0.5, -- to enemy health
	SPAWN_RATE_PER_EXTRA_PLAYER = 0.35, -- to how fast enemies spawn
	MAX_ALIVE_PER_EXTRA_PLAYER = 0.35, -- to how many can be alive (still capped by Config.Waves)
})
