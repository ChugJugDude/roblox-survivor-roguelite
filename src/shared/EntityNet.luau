--!strict
-- Payload shapes for projectile and explosion events (server/ProjectileService ->
-- client/ProjectileRenderer). Enemy and gem payloads are documented in Remotes and EnemySnapshot.

export type ProjectileKind = "Arrow" | "Fireball" | "EnemyArrow"

export type ProjectileInfo = {
	id: number,
	kind: ProjectileKind,
	x: number, -- where it started
	z: number,
	dirX: number, -- unit direction on the ground plane
	dirZ: number,
	speed: number, -- studs per second
	maxDistance: number,
	startedAt: number, -- server time it was fired
}

export type ExplosionInfo = {
	x: number,
	z: number,
	radius: number,
}

return nil
