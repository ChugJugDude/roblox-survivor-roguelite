--!strict
--[[
	Every RemoteEvent and RemoteFunction in the game is declared here. The server creates them
	under ReplicatedStorage.Remotes the first time this module is required; clients wait for them
	to replicate.

	Each remote notes its direction and payload. Server handlers must validate argument types and
	ranges and rate-limit the caller: assume every client is an exploiter. Don't invoke
	RemoteFunctions from the server to a client.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "Remotes"
local IS_SERVER = RunService:IsServer()

local folder: Instance
if IS_SERVER then
	local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if existing then
		folder = existing
	else
		local created = Instance.new("Folder")
		created.Name = FOLDER_NAME
		created.Parent = ReplicatedStorage
		folder = created
	end
else
	folder = ReplicatedStorage:WaitForChild(FOLDER_NAME)
end

local function remote(className: string, name: string): Instance
	if not IS_SERVER then
		return folder:WaitForChild(name)
	end
	local existing = folder:FindFirstChild(name)
	if existing then
		return existing
	end
	local created = Instance.new(className)
	created.Name = name
	created.Parent = folder
	return created
end

return table.freeze({
	-- Server -> client. Payload: the player's full data snapshot (Config.PlayerData.Data).
	-- Fired once the data loads and again after each change.
	DataChanged = remote("RemoteEvent", "DataChanged") :: RemoteEvent,

	-- Client -> server. No arguments. Returns the caller's data snapshot, or nil if it isn't
	-- available. Yields until the data has loaded.
	GetData = remote("RemoteFunction", "GetData") :: RemoteFunction,

	-- Server -> client. Payload: { EnemySnapshot.SpawnInfo }, batched per frame. A client can get
	-- the same id twice (when it joins mid-fight); ignore the repeat.
	EnemySpawned = remote("RemoteEvent", "EnemySpawned") :: RemoteEvent,

	-- Server -> client. Payload: { number } of enemy ids that died or were removed, batched per frame.
	EnemyDespawned = remote("RemoteEvent", "EnemyDespawned") :: RemoteEvent,

	-- Server -> client, unreliable. Payload: a position buffer from EnemySnapshot. Packets can be
	-- dropped or arrive out of order.
	EnemySnapshot = remote("UnreliableRemoteEvent", "EnemySnapshot") :: UnreliableRemoteEvent,

	-- Server -> client. Payload: { { id: number, x: number, z: number, value: number } }, batched per
	-- frame. A client can get the same id twice (when it joins mid-run); ignore the repeat.
	GemsSpawned = remote("RemoteEvent", "GemsSpawned") :: RemoteEvent,

	-- Server -> client. Payload: { { id: number, userId: number } }, batched per frame. userId is the
	-- player who picked the gem up (so it can fly to them), or 0 if it was just removed.
	GemsCollected = remote("RemoteEvent", "GemsCollected") :: RemoteEvent,

	-- Server -> client. Payload: { number } of enemy ids that took damage this frame. Visual only
	-- (hit flash).
	EnemiesHit = remote("RemoteEvent", "EnemiesHit") :: RemoteEvent,

	-- Server -> client. Payload: { EntityNet.ProjectileInfo }, batched per frame. Projectiles fly in
	-- straight lines, so clients work out positions themselves from this.
	ProjectilesSpawned = remote("RemoteEvent", "ProjectilesSpawned") :: RemoteEvent,

	-- Server -> client. Payload: { number } of projectile ids that stopped early (hit something).
	-- Projectiles that reach their max distance just expire on the client.
	ProjectilesRemoved = remote("RemoteEvent", "ProjectilesRemoved") :: RemoteEvent,

	-- Server -> client. Payload: { EntityNet.ExplosionInfo }, batched per frame. Visual only.
	Explosions = remote("RemoteEvent", "Explosions") :: RemoteEvent,

	-- Server -> client. Payload: { EntityNet.TelegraphInfo }, batched per frame. Visual only: the
	-- ground warning before a boss charge.
	EnemyTelegraph = remote("RemoteEvent", "EnemyTelegraph") :: RemoteEvent,

	-- Server -> client. Payload: the player's open level-up choice, or nil to close it:
	-- { options: { Upgrades.Option }, pending: number (picks queued, including this one),
	--   rerolls: number }. Re-sent with the same options when more picks queue up.
	UpgradeOffered = remote("RemoteEvent", "UpgradeOffered") :: RemoteEvent,

	-- Client -> server. Payload: (index: number), 1-based into the open offer's options. Ignored
	-- unless it's a whole number in range for an open offer; rate-limited.
	ChooseUpgrade = remote("RemoteEvent", "ChooseUpgrade") :: RemoteEvent,

	-- Client -> server. No arguments. Swaps the open offer's options if the player has a reroll
	-- left; rate-limited.
	RerollUpgrade = remote("RemoteEvent", "RerollUpgrade") :: RemoteEvent,

	-- Server -> client. Payload: (arenaName: string?). The player moved to another world: the named
	-- model under workspace.Arenas, or nil for the lobby. The client drops every enemy, gem, and
	-- projectile it's drawing; the server then sends what's in the new world.
	WorldReset = remote("RemoteEvent", "WorldReset") :: RemoteEvent,

	-- Client -> server. No arguments. "Start now" for the party forming on the lobby's portal pad.
	-- Ignored unless the sender is on the pad; rate-limited per player.
	RequestStartParty = remote("RemoteEvent", "RequestStartParty") :: RemoteEvent,

	-- Client -> server. No arguments. Leave a finished run for the lobby. Ignored unless the
	-- sender's match has ended; rate-limited per player.
	ReturnToLobby = remote("RemoteEvent", "ReturnToLobby") :: RemoteEvent,

	-- Client -> server. Payload: (heroId: string). Select an unlocked hero for the next run.
	-- Ignored unless it's a known, unlocked hero and the sender is in the lobby; rate-limited.
	SelectHero = remote("RemoteEvent", "SelectHero") :: RemoteEvent,

	-- Client -> server. Payload: (heroId: string). Buy a locked hero with Shards (and select it).
	-- Ignored unless it's a known, locked hero the sender can afford and they're in the lobby;
	-- rate-limited. The result arrives through DataChanged.
	UnlockHero = remote("RemoteEvent", "UnlockHero") :: RemoteEvent,

	-- Client -> server. Payload: (upgradeId: string). Buy the next level of an Altar upgrade.
	-- Ignored unless it's a known upgrade below max level, the sender can afford it, and they're
	-- in the lobby; rate-limited. The result arrives through DataChanged.
	BuyAltarUpgrade = remote("RemoteEvent", "BuyAltarUpgrade") :: RemoteEvent,
})
