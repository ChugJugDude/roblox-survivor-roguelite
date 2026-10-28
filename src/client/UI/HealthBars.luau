--!strict
-- A small health bar under every player in the local player's arena (teammates show their name
-- too), turning red when low. Hidden while a player is downed; DownedIndicator shows their sign and
-- revive bar instead. Roblox's own health bar is turned off in the client entry point.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local CurrentArena = require(script.Parent.Parent.CurrentArena)
local Create = require(script.Parent.Create)
local Theme = require(script.Parent.Theme)

local LOW_HEALTH = 0.3 -- below this fraction the bar turns red
local BAR_OFFSET = Vector3.new(0, -3.6, 0) -- under the character's feet, so it never covers them

type Bar = {
	billboard: BillboardGui,
	fill: Frame,
	name: TextLabel,
}

local bars: { [Player]: Bar } = {}

local HealthBars = {}

local function createBar(player: Player, root: BasePart): Bar
	local isLocal = player == Players.LocalPlayer
	local billboard = Create("BillboardGui", {
		Name = `HealthBar_{player.Name}`,
		Size = UDim2.fromOffset(70, if isLocal then 10 else 26),
		StudsOffsetWorldSpace = BAR_OFFSET,
		AlwaysOnTop = true,
		LightInfluence = 0,
		Adornee = root,
		-- PlayerGui drops everything but ScreenGuis on respawn; the bar is rebuilt when that happens.
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
	local bar = Theme.bar(billboard, UDim2.new(1, 0, 0, 10), UDim2.fromOffset(0, 0), Theme.COLORS.health)
	local name = Theme.label({
		Size = UDim2.new(1, 40, 0, 14),
		Position = UDim2.new(0.5, 0, 0, 11),
		AnchorPoint = Vector2.new(0.5, 0),
		TextSize = 12,
		Text = player.DisplayName,
		Visible = not isLocal,
		Parent = billboard,
	})
	return { billboard = billboard, fill = bar.fill, name = name }
end

function HealthBars.start()
	RunService.RenderStepped:Connect(function()
		local arena = CurrentArena.get()
		local seen: { [Player]: boolean } = {}
		if arena then
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if
					not humanoid
					or not root
					or not root:IsA("BasePart")
					or player:GetAttribute("ArenaName") ~= arena.Name
					or player:GetAttribute("Downed") == true
					or humanoid.Health <= 0
				then
					continue
				end
				seen[player] = true
				local bar = bars[player]
				if not bar or bar.billboard.Adornee ~= root or bar.billboard.Parent == nil then
					if bar then
						bar.billboard:Destroy()
					end
					bar = createBar(player, root)
					bars[player] = bar
				end
				local fraction = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
				local fill = (bar :: Bar).fill
				fill.Size = UDim2.fromScale(fraction, 1)
				fill.BackgroundColor3 = if fraction < LOW_HEALTH then Theme.COLORS.lowHealth else Theme.COLORS.health
			end
		end
		for player, bar in bars do
			if not seen[player] then
				bar.billboard:Destroy()
				bars[player] = nil
			end
		end
	end)
end

return HealthBars
