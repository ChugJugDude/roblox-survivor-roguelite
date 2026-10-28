--!strict
-- Payload shapes for projectile and explosion events (server/ProjectileService ->
-- client/ProjectileRenderer) and weapon effects (server/Weapons -> client/EffectRenderer). Enemy and gem payloads are documented in Remotes and EnemySnapshot.

export type ProjectileKind = "Arrow" | "Fireball" | "Meteor" | "EnemyArrow" | "BossOrb"

export type ProjectileInfo = {
	id: number,
	kind: ProjectileKind,
	x: number, -- where it started
	z: number,
	dirX: number, -- unit direction on the ground plane
	dirZ: number,
	speed: number, -- studs per second
	maxDistance: number,
	startedAt: number, -- game time (shared/GameClock) it was fired
}

export type ExplosionInfo = {
	x: number,
	z: number,
	radius: number,
	-- A bomb pickup or Frost Nova (Blizzard evolved) draws a flat shockwave instead of a fireball
	-- blast.
	kind: ("Bomb" | "Frost" | "Blizzard")?,
}

-- A visual-only weapon effect (server/Weapons -> client/EffectRenderer).
export type LightningEffect = {
	kind: "Lightning",
	evolved: boolean, -- Thunderstorm
	points: { number }, -- x, z pairs: where the bolt started, then each enemy it hit in order
}

-- Enemies a Frost Nova just slowed, tinted icy for `duration` seconds.
export type ChillEffect = {
	kind: "Chill",
	ids: { number },
	duration: number,
}

-- A Holy Ground zone on the floor until startedAt + duration (game time, shared/GameClock).
export type HolyGroundEffect = {
	kind: "HolyGround",
	evolved: boolean, -- Sanctuary
	x: number,
	z: number,
	radius: number,
	startedAt: number,
	duration: number,
}

export type EffectInfo = LightningEffect | ChillEffect | HolyGroundEffect

-- A warning drawn on the ground before a boss attack (server/BossBrain -> client/TelegraphRenderer).
export type TelegraphInfo = {
	x: number, -- where the lane starts
	z: number,
	dirX: number, -- unit direction
	dirZ: number,
	length: number,
	width: number,
	duration: number, -- seconds until the attack lands
}

return nil
