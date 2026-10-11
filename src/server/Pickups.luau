--!strict
--[[
	Items on the floor; walk over one to use it.
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

local random = Random.new()
local arena: Arena.Arena? = nil
local items: { Item } = {} -- oldest first
local nearby: { EnemyService.Enemy } = {} -- reused by bombs
local started = false

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

-- Placeholder art built from parts. `base` is the floor point under the item.
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
		local wood, gold = Color3.fromRGB(140, 90, 45), Color3.fromRGB(255, 200, 60)
		makePart(model, Vector3.new(3, 1.6, 2.2), CFrame.new(base + Vector3.new(0, 0.8, 0)), wood, Enum.Material.Wood)
		makePart(
			model,
			Vector3.new(3.1, 0.7, 2.3),
			CFrame.new(base + Vector3.new(0, 1.95, 0)),
			wood,
			Enum.Material.Wood
		)
		makePart(model, Vector3.new(3.2, 0.3, 2.4), CFrame.new(base + Vector3.new(0, 1.6, 0)), gold, Enum.Material.Neon)
		-- A tall faint beam so chests are easy to spot from across the arena.
		makePart(model, Vector3.new(0.6, 30, 0.6), CFrame.new(base + Vector3.new(0, 15, 0)), gold, Enum.Material.Neon)
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

local function detonate(x: number, z: number)
	table.clear(nearby)
	EnemyService.queryRadius(x, z, Config.BOMB_RADIUS, nearby)
	for _, enemy in nearby do
		if EnemyService.isProp(enemy) then
			continue
		elseif enemy.def.isBoss then
			EnemyService.damage(enemy, enemy.maxHealth * Config.BOMB_BOSS_DAMAGE_FRACTION)
		else
			EnemyService.damage(enemy, math.huge)
		end
	end
	NetBatch.push(Remotes.Explosions, { x = x, z = z, radius = Config.BOMB_RADIUS, kind = "Bomb" })
end

local function use(item: Item, target: Characters.Target)
	if item.kind == "Chest" then
		Upgrades.grantBonusPick(target.player)
	elseif item.kind == "Meat" then
		local humanoid = target.humanoid
		humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + humanoid.MaxHealth * Config.MEAT_HEAL_FRACTION)
	elseif item.kind == "Bomb" then
		detonate(target.x, target.z)
	elseif item.kind == "Magnet" then
		Progression.vacuum({ target })
	end
end

-- Puts an item on the floor at (x, z), removing the oldest if the floor is full.
function Pickups.drop(kind: Kind, x: number, z: number)
	local currentArena = assert(arena, "Pickups.start() must be called first")
	if #items >= Config.MAX_ITEMS then
		table.remove(items, 1).model:Destroy()
	end
	local model = buildModel(kind, Vector3.new(x, currentArena.origin.Y, z))
	model.Parent = currentArena.model
	table.insert(items, { kind = kind, model = model, x = x, z = z })
end

-- Uses items that a living player is standing on.
function Pickups.step(targets: { Characters.Target })
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
		use(pickup.item, pickup.target)
	end
end

function Pickups.clear()
	for _, item in items do
		item.model:Destroy()
	end
	table.clear(items)
end

function Pickups.start(newArena: Arena.Arena)
	assert(not started, "Pickups.start() was called twice")
	started = true
	arena = newArena
	EnemyService.onKilled(function(enemy)
		if enemy.def.dropsChest then
			Pickups.drop("Chest", enemy.x, enemy.z)
		elseif EnemyService.isProp(enemy) or random:NextNumber() < Config.ENEMY_DROP_CHANCE then
			Pickups.drop(randomItemKind(), enemy.x, enemy.z)
		end
	end)
end

return Pickups
