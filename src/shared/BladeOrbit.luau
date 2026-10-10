--!strict
-- Where Spinning Blade blades are at a given server time. The server's hit checks and the
-- client's visuals both use this, so they agree without sending blade positions over the network.

local TAU = 2 * math.pi

local BladeOrbit = {}

-- Angle in radians of blade `index` (1-based) out of `count`, on the ground plane: the blade points
-- along (cos(angle), 0, sin(angle)) from the player.
function BladeOrbit.angle(index: number, count: number, spinSpeed: number, serverTime: number): number
	return (serverTime * spinSpeed) % TAU + (index - 1) * TAU / count
end

return BladeOrbit
