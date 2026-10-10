--!strict
-- Sets up each player's character when it spawns, and lists the living ones for the simulation.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.Player)

export type Target = {
	player: Player,
	humanoid: Humanoid,
	x: number,
	z: number,
}

local Characters = {}

local spawnCFrame = CFrame.new()
local connections: { [Player]: RBXScriptConnection } = {}
local started = false

local function onCharacterAdded(character: Model)
	character:WaitForChild("HumanoidRootPart")
	if character.Parent then
		character:PivotTo(spawnCFrame)
	end

	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.MaxHealth = Config.MAX_HEALTH
	humanoid.Health = Config.MAX_HEALTH
	humanoid.WalkSpeed = Config.WALK_SPEED

	-- Roblox adds a "Health" script that regenerates 1% HP per second. Healing should only come
	-- from upgrades (the Regen passive), so remove it.
	local regen = character:WaitForChild("Health", 5)
	if regen and regen:IsA("Script") then
		regen:Destroy()
	end
end

local function onPlayerAdded(player: Player)
	if connections[player] then
		return
	end
	connections[player] = player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then
		task.spawn(onCharacterAdded, player.Character)
	end
end

local function onPlayerRemoving(player: Player)
	local connection = connections[player]
	if connection then
		connection:Disconnect()
		connections[player] = nil
	end
end

function Characters.start(spawnPosition: Vector3)
	assert(not started, "Characters.start() was called twice")
	started = true
	spawnCFrame = CFrame.new(spawnPosition)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

-- Every player whose character is alive, with their position on the ground plane.
function Characters.getTargets(): { Target }
	local targets: { Target } = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if not character then
			continue
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local root = character:FindFirstChild("HumanoidRootPart")
		if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
			local position = root.Position
			table.insert(targets, {
				player = player,
				humanoid = humanoid,
				x = position.X,
				z = position.Z,
			})
		end
	end
	return targets
end

return Characters
