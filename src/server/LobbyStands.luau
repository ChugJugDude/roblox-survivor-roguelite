--!strict
--[[
	The lobby's Hero stand, Altar, and Codex: code-built props, each with a ProximityPrompt that
	opens its menu on the client (client/UI/LobbyMenus.luau). The prompts carry a Menu attribute
	("Heroes", "Altar", or "Codex") so the client knows which menu to open. Nothing is decided here: purchases go through
	server/Meta's remotes, which check everything again.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.Lobby)

local HERO_COLORS = {
	Color3.fromRGB(170, 175, 190), -- Knight
	Color3.fromRGB(90, 160, 80), -- Ranger
	Color3.fromRGB(235, 120, 50), -- Pyromancer
}
local ALTAR_STONE = Color3.fromRGB(95, 95, 110)
local ALTAR_CRYSTAL = Color3.fromRGB(120, 220, 255)
local WOOD = Color3.fromRGB(120, 85, 55)
local BOOK_COVER = Color3.fromRGB(120, 40, 50)
local BOOK_PAGES = Color3.fromRGB(240, 230, 205)
local CODEX_GLOW = Color3.fromRGB(255, 215, 120)

local LobbyStands = {}

local function makePart(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Anchored = true
	part.Parent = parent
	return part
end

local function addSign(adornee: BasePart, text: string, color: Color3, height: number)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(160, 40)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
	billboard.Adornee = adornee
	billboard.Parent = adornee
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextSize = 24
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.3
	label.Text = text
	label.Parent = billboard
end

local function addPrompt(parent: BasePart, menu: string, objectText: string)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "MenuPrompt"
	prompt.ActionText = "Open"
	prompt.ObjectText = objectText
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = Config.STAND_PROMPT_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("Menu", menu)
	prompt.Parent = parent
end

local function buildHeroStand(parent: Instance, center: Vector3)
	local stand = Instance.new("Model")
	stand.Name = "HeroStand"
	local base = makePart(stand, "Base", Vector3.new(10, 1, 5), CFrame.new(center + Vector3.new(0, 0.5, 0)), WOOD)
	-- One figure per hero: a body block with a head on top.
	for i, color in HERO_COLORS do
		local x = (i - 2) * 3
		local body =
			makePart(stand, `Figure{i}`, Vector3.new(1.6, 3, 1.2), CFrame.new(center + Vector3.new(x, 2.5, 0)), color)
		body.CanCollide = false
		local head =
			makePart(stand, `Head{i}`, Vector3.new(1.1, 1.1, 1.1), CFrame.new(center + Vector3.new(x, 4.6, 0)), color)
		head.CanCollide = false
	end
	addSign(base, "HEROES", Color3.new(1, 1, 1), 7)
	addPrompt(base, "Heroes", "Heroes")
	stand.Parent = parent
end

local function buildAltar(parent: Instance, center: Vector3)
	local altar = Instance.new("Model")
	altar.Name = "Altar"
	makePart(altar, "Step", Vector3.new(7, 1, 7), CFrame.new(center + Vector3.new(0, 0.5, 0)), ALTAR_STONE)
	local pillar =
		makePart(altar, "Pillar", Vector3.new(3, 3, 3), CFrame.new(center + Vector3.new(0, 2.5, 0)), ALTAR_STONE)
	local crystal = makePart(
		altar,
		"Crystal",
		Vector3.new(1.4, 2.6, 1.4),
		CFrame.new(center + Vector3.new(0, 5.6, 0)) * CFrame.Angles(0, math.rad(45), math.rad(15)),
		ALTAR_CRYSTAL
	)
	crystal.Material = Enum.Material.Neon
	crystal.CanCollide = false
	local light = Instance.new("PointLight")
	light.Color = ALTAR_CRYSTAL
	light.Range = 12
	light.Brightness = 1.5
	light.Parent = crystal
	addSign(pillar, "ALTAR", ALTAR_CRYSTAL, 6)
	addPrompt(pillar, "Altar", "Altar")
	altar.Parent = parent
end

-- A lectern with a big open book on it: the collection log.
local function buildCodex(parent: Instance, center: Vector3)
	local codex = Instance.new("Model")
	codex.Name = "Codex"
	makePart(codex, "Step", Vector3.new(5, 1, 5), CFrame.new(center + Vector3.new(0, 0.5, 0)), WOOD)
	local post = makePart(codex, "Post", Vector3.new(1.2, 3, 1.2), CFrame.new(center + Vector3.new(0, 2.5, 0)), WOOD)
	local tilt = CFrame.new(center + Vector3.new(0, 4.3, 0)) * CFrame.Angles(math.rad(-25), 0, 0)
	makePart(codex, "Desk", Vector3.new(3.4, 0.3, 2.4), tilt, WOOD)
	makePart(codex, "Cover", Vector3.new(3.2, 0.25, 2.2), tilt * CFrame.new(0, 0.25, 0), BOOK_COVER)
	local pages = makePart(codex, "Pages", Vector3.new(3, 0.2, 2), tilt * CFrame.new(0, 0.45, 0), BOOK_PAGES)
	pages.CanCollide = false
	local light = Instance.new("PointLight")
	light.Color = CODEX_GLOW
	light.Range = 10
	light.Brightness = 1.2
	light.Parent = pages
	addSign(post, "CODEX", CODEX_GLOW, 6)
	addPrompt(post, "Codex", "Codex")
	codex.Parent = parent
end

-- Builds every stand into the lobby model.
function LobbyStands.build(lobby: Model)
	buildHeroStand(lobby, Config.ORIGIN + Config.HERO_STAND_OFFSET)
	buildAltar(lobby, Config.ORIGIN + Config.ALTAR_OFFSET)
	buildCodex(lobby, Config.ORIGIN + Config.CODEX_OFFSET)
end

return LobbyStands
