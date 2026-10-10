--!strict
-- Where Spinning Blade blades are at a given server time. The server's hit checks and the
-- client's visuals both use this, so they agree without sending blade positions over the network.

local Config = require(script.Parent.Config.Weapons).SpinningBlade

local TAU = 2 * math.pi

local BladeOrbit = {}

-- Angle in radians of blade `index` (1-based) on the ground plane, where the blade points along
-- (cos(angle), 0, sin(angle)) from the player.
function BladeOrbit.angle(index: number, serverTime: number): number
	return (serverTime * Config.spinSpeed) % TAU + (index - 1) * TAU / Config.bladeCount
end

return BladeOrbit
