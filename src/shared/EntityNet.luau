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
	kind: "Bomb"?, -- a bomb pickup draws a wide flat shockwave instead of a fireball blast
}

-- A visual-only weapon effect (server/Weapons -> client/EffectRenderer).
export type LightningEffect = {
	kind: "Lightning",
	evolved: boolean, -- Thunderstorm
	points: { number }, -- x, z pairs: where the bolt started, then each enemy it hit in order
}

export type EffectInfo = LightningEffect

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
