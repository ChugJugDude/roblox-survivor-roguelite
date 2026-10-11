--!strict
-- Parties and matches (server/Lobby.luau, server/Match.luau).

return table.freeze({
	MAX_PARTY_SIZE = 4,
	-- Seconds the portal pad counts down once someone steps on (anyone stepping on joins).
	PARTY_COUNTDOWN = 10,
	-- Most matches running at once in one server. Each has its own arena far from the lobby.
	MAX_MATCHES = 4,
	-- After a run ends, players go back to the lobby on their own after this many seconds.
	RETURN_TO_LOBBY_AFTER = 20,
})
