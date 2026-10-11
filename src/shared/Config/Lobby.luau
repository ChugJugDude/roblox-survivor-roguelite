--!strict
-- The lobby built by server/Lobby.luau: a square plaza at the world origin with the portal pad.

return table.freeze({
	-- Center of the plaza floor's top surface.
	ORIGIN = Vector3.new(0, 0, 0),
	SIZE = 100,
	FLOOR_COLOR = Color3.fromRGB(150, 140, 125),
	BORDER_COLOR = Color3.fromRGB(110, 95, 80),
	BORDER_HEIGHT = 4,
	-- Where players appear, relative to ORIGIN.
	SPAWN_OFFSET = Vector3.new(0, 4, 25),
	-- The portal pad, relative to ORIGIN. Stand within PAD_RADIUS of its center to join the party.
	PAD_OFFSET = Vector3.new(0, 0, -20),
	PAD_RADIUS = 7,
	PAD_COLOR = Color3.fromRGB(170, 90, 255),
})
