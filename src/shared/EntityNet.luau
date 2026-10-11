--!strict
-- Payload shapes for projectile and explosion events (server/ProjectileService ->
-- client/ProjectileRenderer). Enemy and gem payloads are documented in Remotes and EnemySnapshot.

export type ProjectileKind = "Arrow" | "Fireball" | "Meteor" | "EnemyArrow"

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

return nil
