--!strict
--[[
	One match's items on the floor; walk over one to use it.
		Chest   from mini-bosses: a bonus upgrade pick
		Meat    heals
		Bomb    kills every regular enemy around you and hurts bosses
		Magnet  pulls every gem on the floor to you

	Crates always drop an item, and any regular enemy has a small chance to (Config.Pickups). Items
	are rare and never move, so each is an ordinary anchored model in the Arena; no custom
	replication needed.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Arena = require(script.Parent.Arena)
local Characters = require(script.Parent.Characters)
local EnemyService = require(script.Parent.EnemyService)
local NetBatch = require(script.Parent.NetBatch)
local Progression = require(script.Parent.Progression)
local Upgrades = require(script.Parent.Upgrades)
local Config = require(ReplicatedStorage.Shared.Config.Pickups)
local EntityNet = require(ReplicatedStorage.Shared.EntityNet)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

export type Kind = "Chest" | "Meat" | "Bomb" | "Magnet"

type Item = {
	kind: Kind,
	model: Model,
	x: number,
	z: number,
}

-- Floor ring color per kind, so items read at a glance.
local RING_COLORS: { [Kind]: Color3 } = {
	Chest = Color3.fromRGB(255, 200, 60),
	Meat = Color3.fromRGB(255, 110, 110),
	Bomb = Color3.fromRGB(255, 150, 40),
	Magnet = Color3.fromRGB(90, 170, 255),
}

export type State = {
	arena: Arena.Arena,
	enemies: EnemyService.State,
	progression: Progression.State,
	party: Upgrades.Party,
	net: NetBatch.Batch,
	items: { Item }, -- oldest first
}

local random = Random.new()
local nearby: { EnemyService.Enemy } = {} -- reused by bombs

local Pickups = {}

local function makePart(
	parent: Instance,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material,
	shape: Enum.PartType?
): Part
	local part = Instance.new("Part")
	part.Shape = shape or Enum.PartType.Block
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Parent = parent
	return part
end

local CHEST_WOOD = Color3.fromRGB(105, 64, 34)
local CHEST_GOLD = Color3.fromRGB(240, 190, 70)

-- A treasure chest: a wood body on a gold base band, a rounded lid (a cylinder whose lower half
-- sits inside the body) with gold bands over it, and a lock plate. Instead of a tall beam (which
-- pulled the eye in busy fights) it has a short faint glow column, gold sparkles rising from the
-- lid, and a soft light, so it's still easy to find.
local function buildChest(model: Model, base: Vector3)
	local width, depth, height = 3, 2.1, 1.5
	local body = makePart(
		model,
		Vector3.new(width, height, depth),
		CFrame.new(base + Vector3.new(0, height / 2, 0)),
		CHEST_WOOD,
		Enum.Material.Wood
	)
	makePart(
		model,
		Vector3.new(width + 0.15, 0.2, depth + 0.15),
		CFrame.new(base + Vector3.new(0, 0.1, 0)),
		CHEST_GOLD,
		Enum.Material.Metal
	)
	-- A cylinder's axis is its X size, which already runs along the chest's width.
	local lidCenter = base + Vector3.new(0, height, 0)
	makePart(
		model,
		Vector3.new(width + 0.05, depth + 0.1, depth + 0.1),
		CFrame.new(lidCenter),
		CHEST_WOOD,
		Enum.Material.Wood,
		Enum.PartType.Cylinder
	)
	for _, x in { -width * 0.32, width * 0.32 } do
		-- A gold band over the lid and down both sides of the body.
		makePart(
			model,
			Vector3.new(0.25, depth + 0.2, depth + 0.2),
			CFrame.new(lidCenter + Vector3.new(x, 0, 0)),
			CHEST_GOLD,
			Enum.Material.Metal,
			Enum.PartType.Cylinder
		)
		makePart(
			model,
			Vector3.new(0.25, height, depth + 0.1),
			CFrame.new(base + Vector3.new(x, height / 2, 0)),
			CHEST_GOLD,
			Enum.Material.Metal
		)
	end
	-- The lock plate on the front.
	makePart(
		model,
		Vector3.new(0.55, 0.65, 0.15),
		CFrame.new(base + Vector3.new(0, height - 0.15, -depth / 2 - 0.08)),
		CHEST_GOLD,
		Enum.Material.Neon
	)

	local glow = makePart(
		model,
		Vector3.new(7, 1.4, 1.4),
		CFrame.new(base + Vector3.new(0, 3.5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		CHEST_GOLD,
		Enum.Material.Neon,
		Enum.PartType.Cylinder
	)
	glow.Transparency = 0.8
	glow.CastShadow = false

	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkles.Color = ColorSequence.new(CHEST_GOLD)
	sparkles.LightEmission = 1
	sparkles.Rate = 8
	sparkles.Lifetime = NumberRange.new(0.8, 1.4)
	sparkles.Speed = NumberRange.new(2, 4)
	sparkles.SpreadAngle = Vector2.new(25, 25)
	sparkles.Size = NumberSequence.new(0.6, 0)
	sparkles.EmissionDirection = Enum.NormalId.Top
	sparkles.Parent = body
	local light = Instance.new("PointLight")
	light.Color = CHEST_GOLD
	light.Range = 10
	light.Brightness = 1.5
	light.Parent = body
end

-- Placeholder art built from parts (the chest is the polished one). `base` is the floor point under
-- the item.
local function buildModel(kind: Kind, base: Vector3): Model
	local model = Instance.new("Model")
	model.Name = kind
	local upright = CFrame.Angles(0, 0, math.rad(90)) -- turns a cylinder's axis to vertical
	local ring = makePart(
		model,
		Vector3.new(0.15, 3.6, 3.6),
		CFrame.new(base + Vector3.new(0, 0.08, 0)) * upright,
		RING_COLORS[kind],
		Enum.Material.Neon,
		Enum.PartType.Cylinder
	)
	ring.Transparency = 0.4

	if kind == "Chest" then
		buildChest(model, base)
	elseif kind == "Meat" then
		local center = base + Vector3.new(0, 1.2, 0)
		makePart(
			model,
			Vector3.one * 1.7,
			CFrame.new(center),
			Color3.fromRGB(190, 85, 60),
			Enum.Material.SmoothPlastic,
			Enum.PartType.Ball
		)
		makePart(
			model,
			Vector3.new(1.6, 0.45, 0.45),
			CFrame.new(center + Vector3.new(1, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(25)),
			Color3.fromRGB(245, 240, 225),
			Enum.Material.SmoothPlastic
		)
	elseif kind == "Bomb" then
		local center = base + Vector3.new(0, 1.2, 0)
		makePart(
			model,
			Vector3.one * 1.9,
			CFrame.new(center),
			Color3.fromRGB(30, 30, 35),
			Enum.Material.SmoothPlastic,
			Enum.PartType.Ball
		)
		makePart(
			model,
			Vector3.new(0.3, 0.6, 0.3),
			CFrame.new(center + Vector3.new(0, 1.1, 0)),
			Color3.fromRGB(255, 150, 40),
			Enum.Material.Neon
		)
	else -- Magnet: a red U with silver tips
		local red, silver = Color3.fromRGB(220, 40, 40), Color3.fromRGB(220, 220, 230)
		makePart(
			model,
			Vector3.new(2, 0.6, 0.6),
			CFrame.new(base + Vector3.new(0, 0.6, 0)),
			red,
			Enum.Material.SmoothPlastic
		)
		makePart(
			model,
			Vector3.new(0.6, 1.4, 0.6),
			CFrame.new(base + Vector3.new(-0.7, 1.5, 0)),
			red,
			Enum.Material.SmoothPlastic
		)
		makePart(
			model,
			Vector3.new(0.6, 1.4, 0.6),
			CFrame.new(base + Vector3.new(0.7, 1.5, 0)),
			red,
			Enum.Material.SmoothPlastic
		)
		makePart(
			model,
			Vector3.new(0.6, 0.4, 0.6),
			CFrame.new(base + Vector3.new(-0.7, 2.4, 0)),
			silver,
			Enum.Material.Metal
		)
		makePart(
			model,
			Vector3.new(0.6, 0.4, 0.6),
			CFrame.new(base + Vector3.new(0.7, 2.4, 0)),
			silver,
			Enum.Material.Metal
		)
	end
	return model
end

local function randomItemKind(): Kind
	local total = 0
	for _, weight in Config.ITEM_WEIGHTS do
		total += weight
	end
	local roll = random:NextNumber(0, total)
	for kind, weight in Config.ITEM_WEIGHTS do
		roll -= weight
		if roll <= 0 then
			return kind :: Kind
		end
	end
	return "Meat"
end

local function detonate(state: State, x: number, z: number)
	local enemies = state.enemies
	table.clear(nearby)
	EnemyService.queryRadius(enemies, x, z, Config.BOMB_RADIUS, nearby)
	for _, enemy in nearby do
		if EnemyService.isProp(enemy) then
			continue
		elseif enemy.def.isBoss then
			EnemyService.damage(enemies, enemy, enemy.maxHealth * Config.BOMB_BOSS_DAMAGE_FRACTION)
		else
			EnemyService.damage(enemies, enemy, math.huge)
		end
	end
	NetBatch.push(state.net, Remotes.Explosions, { x = x, z = z, radius = Config.BOMB_RADIUS, kind = "Bomb" })
end

local function use(state: State, item: Item, target: Characters.Target)
	if item.kind == "Chest" then
		-- The burst goes out first; the pick then pauses the game with the TREASURE! cards.
		local opened: EntityNet.ChestOpenEffect = { kind = "ChestOpen", x = item.x, z = item.z }
		NetBatch.push(state.net, Remotes.WeaponEffects, opened)
		Upgrades.grantBonusPick(state.party, target.player)
	elseif item.kind == "Meat" then
		local humanoid = target.humanoid
		humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + humanoid.MaxHealth * Config.MEAT_HEAL_FRACTION)
	elseif item.kind == "Bomb" then
		detonate(state, target.x, target.z)
	elseif item.kind == "Magnet" then
		Progression.vacuum(state.progression, { target })
	end
end

-- Puts an item on the floor at (x, z), removing the oldest if the floor is full.
function Pickups.drop(state: State, kind: Kind, x: number, z: number)
	local items = state.items
	if #items >= Config.MAX_ITEMS then
		table.remove(items, 1).model:Destroy()
	end
	local model = buildModel(kind, Vector3.new(x, state.arena.origin.Y, z))
	model.Parent = state.arena.model
	table.insert(items, { kind = kind, model = model, x = x, z = z })
end

-- Uses items that a living player is standing on.
function Pickups.step(state: State, targets: { Characters.Target })
	local items = state.items
	-- Collect first, then use: a bomb's kills can drop new items, which would shift this list.
	local collected: { { item: Item, target: Characters.Target } } = {}
	local radiusSq = Config.PICKUP_RADIUS * Config.PICKUP_RADIUS
	for index = #items, 1, -1 do
		local item = items[index]
		for _, target in targets do
			local dx, dz = target.x - item.x, target.z - item.z
			if dx * dx + dz * dz <= radiusSq then
				table.remove(items, index)
				item.model:Destroy()
				table.insert(collected, { item = item, target = target })
				break
			end
		end
	end
	for _, pickup in collected do
		use(state, pickup.item, pickup.target)
	end
end

function Pickups.clear(state: State)
	for _, item in state.items do
		item.model:Destroy()
	end
	table.clear(state.items)
end

function Pickups.new(
	arena: Arena.Arena,
	enemies: EnemyService.State,
	progression: Progression.State,
	party: Upgrades.Party,
	net: NetBatch.Batch
): State
	local state: State = {
		arena = arena,
		enemies = enemies,
		progression = progression,
		party = party,
		net = net,
		items = {},
	}
	EnemyService.onKilled(enemies, function(enemy)
		if enemy.def.dropsChest or enemy.elite then
			Pickups.drop(state, "Chest", enemy.x, enemy.z)
		elseif EnemyService.isProp(enemy) or random:NextNumber() < Config.ENEMY_DROP_CHANCE then
			Pickups.drop(state, randomItemKind(), enemy.x, enemy.z)
		end
	end)
	return state
end

return Pickups
