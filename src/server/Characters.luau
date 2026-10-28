--!strict
-- Spawns characters where they're wanted (lobby or a match's arena), sets them up, and lists the
-- ones still standing for each match's simulation.
--
-- Downed, not dead: a hit that would kill instead downs the player (Downed attribute, held at 1
-- health and anchored in place). Downed players aren't targets, so enemies ignore them, their
-- weapons stop, and they can't pick things up. A standing teammate nearby revives them
-- (stepRevives); progress is published as their ReviveProgress attribute (0 to 1).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.Player)
local PartyConfig = require(ReplicatedStorage.Shared.Config.Party)

export type Target = {
	player: Player,
	humanoid: Humanoid,
	x: number,
	z: number,
}

local Characters = {}

local spawnAt: { [Player]: CFrame } = {} -- where each player's next character appears
local connections: { [Player]: RBXScriptConnection } = {}
local started = false

-- Max health and walk speed for a player's new character. Upgrades replaces this so passives
-- (Vitality, Swiftness) apply from the moment a character spawns.
local statsFor: (Player) -> (number, number) = function(_player: Player)
	return Config.MAX_HEALTH, Config.WALK_SPEED
end

-- Multiplier on damage a player takes. Upgrades replaces this so Armor applies.
local damageTakenFor: (Player) -> number = function(_player: Player)
	return 1
end

-- Health per second a player regenerates. Upgrades replaces this so Regen applies.
local regenFor: (Player) -> number = function(_player: Player)
	return 0
end

local function onCharacterAdded(character: Model)
	character:WaitForChild("HumanoidRootPart")
	local player = Players:GetPlayerFromCharacter(character)
	local cframe = player and spawnAt[player]
	if cframe and character.Parent then
		character:PivotTo(cframe)
	end

	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local maxHealth, walkSpeed = Config.MAX_HEALTH, Config.WALK_SPEED
	if player then
		maxHealth, walkSpeed = statsFor(player)
		-- A fresh character is never downed.
		player:SetAttribute("Downed", nil)
		player:SetAttribute("ReviveProgress", nil)
	end
	humanoid.MaxHealth = maxHealth
	humanoid.Health = maxHealth
	humanoid.WalkSpeed = walkSpeed

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
	spawnAt[player] = nil
end

function Characters.start()
	assert(not started, "Characters.start() was called twice")
	started = true

	-- The lobby and matches decide when and where characters spawn; never automatically after death.
	Players.CharacterAutoLoads = false

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

function Characters.setStatsProvider(provider: (Player) -> (number, number))
	statsFor = provider
end

function Characters.setDamageTakenProvider(provider: (Player) -> number)
	damageTakenFor = provider
end

function Characters.setRegenProvider(provider: (Player) -> number)
	regenFor = provider
end

-- Spawns (or respawns) the player's character at `cframe`. Doesn't yield.
function Characters.spawn(player: Player, cframe: CFrame)
	spawnAt[player] = cframe
	task.spawn(function()
		local ok, err = pcall(player.LoadCharacter, player)
		if not ok and player.Parent then
			warn(`[Characters] Couldn't spawn {player.Name}: {err}`)
		end
	end)
end

function Characters.isDowned(player: Player): boolean
	return player:GetAttribute("Downed") == true
end

-- Downs the player: held at 1 health and anchored in place until a teammate revives them.
function Characters.down(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or Characters.isDowned(player) then
		return
	end
	humanoid.Health = 1
	if root and root:IsA("BasePart") then
		root.Anchored = true
	end
	player:SetAttribute("ReviveProgress", 0)
	player:SetAttribute("Downed", true)
end

local function revive(player: Player, now: number)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	player:SetAttribute("Downed", nil)
	player:SetAttribute("ReviveProgress", nil)
	if not character or not humanoid then
		return
	end
	humanoid.Health = humanoid.MaxHealth * PartyConfig.REVIVE_HEALTH_FRACTION
	if root and root:IsA("BasePart") then
		root.Anchored = false
	end
	-- A moment to get clear of whatever downed them. The ForceField is the visible cue.
	player:SetAttribute("InvulnerableUntil", now + PartyConfig.REVIVE_GRACE)
	local shield = Instance.new("ForceField")
	shield.Parent = character
	task.delay(PartyConfig.REVIVE_GRACE, function()
		shield:Destroy()
	end)
end

-- Fills each downed member's revive while a standing teammate (in `targets`) is close enough,
-- and revives them when it's full. Progress holds when the teammate steps away.
function Characters.stepRevives(members: { Player }, targets: { Target }, dt: number, now: number)
	local radiusSq = PartyConfig.REVIVE_RADIUS * PartyConfig.REVIVE_RADIUS
	for _, player in members do
		if not Characters.isDowned(player) then
			continue
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") then
			continue
		end
		-- The fastest helper in range sets the pace (the Altar's Rescue upgrade, B_reviveSpeed).
		local helped = false
		local speedBonus = 0
		for _, target in targets do
			local dx, dz = target.x - root.Position.X, target.z - root.Position.Z
			if dx * dx + dz * dz <= radiusSq then
				helped = true
				local bonus = target.player:GetAttribute("B_reviveSpeed")
				if typeof(bonus) == "number" then
					speedBonus = math.max(speedBonus, bonus)
				end
			end
		end
		if helped then
			local reviveTime = PartyConfig.REVIVE_TIME * (1 - math.clamp(speedBonus, 0, 0.9))
			local progress = (player:GetAttribute("ReviveProgress") or 0) + dt / reviveTime
			if progress >= 1 then
				revive(player, now)
			else
				player:SetAttribute("ReviveProgress", progress)
			end
		end
	end
end

-- The one way to hurt a player (Armor reduces it). Skips the hit while they're invulnerable: until the game time in
-- their InvulnerableUntil attribute, or always with the Studio-only Dev_God attribute. A hit
-- that would kill downs them instead.
function Characters.damage(target: Target, amount: number, now: number)
	local player = target.player
	local invulnerableUntil = player:GetAttribute("InvulnerableUntil")
	if player:GetAttribute("Dev_God") or (typeof(invulnerableUntil) == "number" and now < invulnerableUntil) then
		return
	end
	amount *= damageTakenFor(player)
	if target.humanoid.Health - amount <= 0 then
		Characters.down(player)
	else
		target.humanoid:TakeDamage(amount)
	end
end

-- Heals a standing player, up to their max health.
function Characters.heal(target: Target, amount: number)
	local humanoid = target.humanoid
	humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + amount)
end

-- Regen for everyone standing. Downed players aren't targets, so they don't regenerate.
function Characters.stepRegen(targets: { Target }, dt: number)
	for _, target in targets do
		local perSecond = regenFor(target.player)
		if perSecond > 0 and target.humanoid.Health < target.humanoid.MaxHealth then
			Characters.heal(target, perSecond * dt)
		end
	end
end

-- Each of `players` who is standing (alive and not downed), with their position on the ground
-- plane.
function Characters.getTargets(players: { Player }): { Target }
	local targets: { Target } = {}
	for _, player in players do
		local character = player.Character
		if not character then
			continue
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local root = character:FindFirstChild("HumanoidRootPart")
		if humanoid and humanoid.Health > 0 and not Characters.isDowned(player) and root and root:IsA("BasePart") then
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
