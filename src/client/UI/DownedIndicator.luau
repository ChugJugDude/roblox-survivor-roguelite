--!strict
-- A "DOWNED" sign with a revive bar over every downed player in the local player's arena, so
-- teammates can find them and see the revive filling. Reads each player's Downed and ReviveProgress
-- attributes (see server/Characters.luau). Placeholder look; polish comes in M4.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local CurrentArena = require(script.Parent.Parent.CurrentArena)
local Create = require(script.Parent.Create)

local DOWNED_COLOR = Color3.fromRGB(255, 90, 90)
local REVIVE_COLOR = Color3.fromRGB(120, 230, 120)

type Sign = {
	billboard: BillboardGui,
	fill: Frame,
}

local signs: { [Player]: Sign } = {}

local DownedIndicator = {}

local function createSign(root: BasePart): Sign
	local billboard = Create("BillboardGui", {
		Name = "DownedSign",
		Size = UDim2.fromOffset(120, 44),
		StudsOffsetWorldSpace = Vector3.new(0, 5, 0),
		AlwaysOnTop = true,
		Adornee = root,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
	Create("TextLabel", {
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		TextSize = 20,
		TextColor3 = DOWNED_COLOR,
		TextStrokeTransparency = 0.3,
		Text = "DOWNED",
		Parent = billboard,
	})
	local back = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 10),
		Position = UDim2.fromOffset(0, 28),
		BackgroundColor3 = Color3.fromRGB(30, 30, 30),
		BorderSizePixel = 0,
		Parent = billboard,
	})
	local fill = Create("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = REVIVE_COLOR,
		BorderSizePixel = 0,
		Parent = back,
	})
	return { billboard = billboard, fill = fill }
end

function DownedIndicator.start()
	local localPlayer = Players.LocalPlayer
	RunService.RenderStepped:Connect(function()
		local arena = CurrentArena.get()
		local arenaName = localPlayer:GetAttribute("ArenaName")
		local seen: { [Player]: boolean } = {}
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local show = arena ~= nil
				and player:GetAttribute("Downed") == true
				and player:GetAttribute("ArenaName") == arenaName
				and root ~= nil
				and root:IsA("BasePart")
			if not show then
				continue
			end
			seen[player] = true
			local sign = signs[player]
			if not sign or sign.billboard.Adornee ~= root then
				if sign then
					sign.billboard:Destroy()
				end
				sign = createSign(root :: BasePart)
				signs[player] = sign
			end
			local progress = math.clamp(player:GetAttribute("ReviveProgress") or 0, 0, 1)
			sign.fill.Size = UDim2.fromScale(progress, 1)
		end
		for player, sign in signs do
			if not seen[player] then
				sign.billboard:Destroy()
				signs[player] = nil
			end
		end
	end)
end

return DownedIndicator
