--!strict
--[[
	The lobby: where players spawn, the Hero stand and Altar (server/LobbyStands), and the portal pad
	that turns whoever stands on it into a party.

	The first living lobby player to step on the pad starts a PARTY_COUNTDOWN; anyone else who steps
	on joins (up to MAX_PARTY_SIZE), and stepping off leaves. When the countdown ends, or someone on
	the pad presses Start now, the party gets its own match in a free arena slot. If every slot is
	busy, the pad waits until one frees up.

	After a run ends, members go back to the lobby when they press Back to lobby, or on their own
	after RETURN_TO_LOBBY_AFTER seconds. A match with no members left is destroyed.

	The pad publishes PartySize and PartyCountdownEndsAt (server time, 0 when idle) on the Lobby
	model, and sets an OnPad attribute on each player standing on it (for the Start now button).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Characters = require(script.Parent.Characters)
local LobbyStands = require(script.Parent.LobbyStands)
local Match = require(script.Parent.Match)
local Config = require(ReplicatedStorage.Shared.Config.Lobby)
local PartyConfig = require(ReplicatedStorage.Shared.Config.Party)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Worlds = require(ReplicatedStorage.Shared.Config.Worlds)

-- Minimum seconds between Start now / Back to lobby requests from one player.
local REQUEST_COOLDOWN = 1

local model: Model? = nil
local padLabel: TextLabel? = nil
local padPlayers: { Player } = {} -- in the order they stepped on
local countdownEndsAt = 0 -- server time; 0 when nobody is on the pad
local startRequested = false
local lastRequest: { [Player]: number } = {}
local endedAt: { [Match.Match]: number } = {} -- os.clock() when each finished match was first seen
local started = false

local Lobby = {}

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

local function build()
	local origin = Config.ORIGIN
	local size = Config.SIZE
	local lobby = Instance.new("Model")
	lobby.Name = "Lobby"

	makePart(lobby, "Floor", Vector3.new(size, 4, size), CFrame.new(origin - Vector3.new(0, 2, 0)), Config.FLOOR_COLOR)
	local half = size / 2
	local height = Config.BORDER_HEIGHT
	local y = origin.Y + height / 2
	makePart(
		lobby,
		"BorderN",
		Vector3.new(size + 4, height, 2),
		CFrame.new(origin.X, y, origin.Z - half - 1),
		Config.BORDER_COLOR
	)
	makePart(
		lobby,
		"BorderS",
		Vector3.new(size + 4, height, 2),
		CFrame.new(origin.X, y, origin.Z + half + 1),
		Config.BORDER_COLOR
	)
	makePart(
		lobby,
		"BorderW",
		Vector3.new(2, height, size),
		CFrame.new(origin.X - half - 1, y, origin.Z),
		Config.BORDER_COLOR
	)
	makePart(
		lobby,
		"BorderE",
		Vector3.new(2, height, size),
		CFrame.new(origin.X + half + 1, y, origin.Z),
		Config.BORDER_COLOR
	)

	-- The pad: a glowing disc (a cylinder turned upright) with a beam, like the overtime portal.
	local padCenter = origin + Config.PAD_OFFSET
	local upright = CFrame.Angles(0, 0, math.rad(90))
	local diameter = Config.PAD_RADIUS * 2
	local pad = makePart(
		lobby,
		"PortalPad",
		Vector3.new(0.4, diameter, diameter),
		CFrame.new(padCenter) * upright,
		Config.PAD_COLOR
	)
	pad.Shape = Enum.PartType.Cylinder
	pad.Material = Enum.Material.Neon
	pad.Transparency = 0.25
	pad.CanCollide = false
	local beam = makePart(
		lobby,
		"PortalBeam",
		Vector3.new(30, 2.5, 2.5),
		CFrame.new(padCenter + Vector3.new(0, 15, 0)) * upright,
		Config.PAD_COLOR
	)
	beam.Shape = Enum.PartType.Cylinder
	beam.Material = Enum.Material.Neon
	beam.Transparency = 0.5
	beam.CanCollide = false

	-- A sign above the pad with the party size and countdown.
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(260, 90)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 9, 0)
	billboard.AlwaysOnTop = true
	billboard.Adornee = pad
	billboard.Parent = pad
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 22
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Parent = billboard
	padLabel = label

	LobbyStands.build(lobby)
	lobby.Parent = workspace
	model = lobby
end

local function spawnCFrame(): CFrame
	return CFrame.new(Config.ORIGIN + Config.SPAWN_OFFSET)
end

local function setPadText(text: string)
	local label = padLabel
	if label and label.Text ~= text then
		label.Text = text
	end
end

-- Living players who aren't in a match and are standing on the pad, oldest first (up to the cap).
local function updatePadPlayers()
	local center = Config.ORIGIN + Config.PAD_OFFSET
	local onPad: { [Player]: boolean } = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if Match.forPlayer(player) or not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
			continue
		end
		local offset = root.Position - center
		if
			offset.X * offset.X + offset.Z * offset.Z <= Config.PAD_RADIUS * Config.PAD_RADIUS
			and math.abs(offset.Y) < 10
		then
			onPad[player] = true
		end
	end

	-- Keep the ones still on, in order, then add newcomers until the party is full.
	local kept: { Player } = {}
	for _, player in padPlayers do
		if onPad[player] then
			table.insert(kept, player)
			onPad[player] = nil
		end
	end
	for player in onPad do
		if #kept < PartyConfig.MAX_PARTY_SIZE then
			table.insert(kept, player)
		end
	end

	for _, player in Players:GetPlayers() do
		local on = table.find(kept, player) ~= nil
		if player:GetAttribute("OnPad") ~= on then
			player:SetAttribute("OnPad", on)
		end
	end
	padPlayers = kept
end

local function freeSlot(): number?
	local used: { [number]: boolean } = {}
	for _, match in Match.all() do
		used[match.slot] = true
	end
	for slot = 1, PartyConfig.MAX_MATCHES do
		if not used[slot] then
			return slot
		end
	end
	return nil
end

local function launch(players: { Player }): boolean
	local slot = freeSlot()
	if not slot then
		return false
	end
	-- The party plays the leader's world (the first player on the pad). In Studio, the `world` dev
	-- command overrides it.
	local worldId = Worlds.DEFAULT
	local override = workspace:GetAttribute("Dev_World")
	if RunService:IsStudio() and typeof(override) == "string" and Worlds.exists(override) then
		worldId = override
	end
	local match = Match.create(slot, worldId)
	for _, player in players do
		player:SetAttribute("OnPad", false)
		Match.addMember(match, player)
	end
	Match.startRun(match)
	return true
end

-- Sends a player back to the lobby from their match (destroying the match if it's now empty).
function Lobby.returnPlayer(player: Player)
	local match = Match.forPlayer(player)
	if match then
		Match.removeMember(match, player)
		if #match.members == 0 then
			endedAt[match] = nil
			Match.destroy(match)
		end
	end
	player:SetAttribute("ArenaName", nil)
	Remotes.WorldReset:FireClient(player, nil)
	Characters.spawn(player, spawnCFrame())
end

local function stepPad()
	updatePadPlayers()
	local lobby = model
	if not lobby then
		return
	end

	if #padPlayers == 0 then
		countdownEndsAt = 0
		startRequested = false
	elseif countdownEndsAt == 0 then
		countdownEndsAt = workspace:GetServerTimeNow() + PartyConfig.PARTY_COUNTDOWN
	end

	local now = workspace:GetServerTimeNow()
	if #padPlayers > 0 and (startRequested or now >= countdownEndsAt) then
		if launch(padPlayers) then
			padPlayers = {}
			countdownEndsAt = 0
			startRequested = false
		else
			setPadText("Arenas full - waiting...")
			lobby:SetAttribute("PartySize", #padPlayers)
			lobby:SetAttribute("PartyCountdownEndsAt", now)
			return
		end
	end

	lobby:SetAttribute("PartySize", #padPlayers)
	lobby:SetAttribute("PartyCountdownEndsAt", countdownEndsAt)
	if #padPlayers == 0 then
		setPadText("PORTAL\nStep in to start a run")
	else
		local seconds = math.max(0, math.ceil(countdownEndsAt - now))
		setPadText(`PORTAL  {#padPlayers}/{PartyConfig.MAX_PARTY_SIZE}\nStarting in {seconds}`)
	end
end

-- Finished matches send everyone back after RETURN_TO_LOBBY_AFTER seconds.
local function stepFinishedMatches()
	local clock = os.clock()
	for _, match in table.clone(Match.all()) do
		if not Match.hasEnded(match) then
			endedAt[match] = nil
			continue
		end
		local since = endedAt[match]
		if not since then
			endedAt[match] = clock
		elseif clock - since >= PartyConfig.RETURN_TO_LOBBY_AFTER then
			for _, player in table.clone(match.members) do
				Lobby.returnPlayer(player)
			end
		end
	end
end

-- Rate limit per player; true if the request may go ahead.
local function accept(player: Player): boolean
	local clock = os.clock()
	local last = lastRequest[player]
	if last and clock - last < REQUEST_COOLDOWN then
		return false
	end
	lastRequest[player] = clock
	return true
end

-- Studio dev command: start the pad's party now.
function Lobby.devStartParty()
	startRequested = #padPlayers > 0
end

function Lobby.start()
	assert(not started, "Lobby.start() was called twice")
	started = true
	build()

	local function onPlayerAdded(player: Player)
		Remotes.WorldReset:FireClient(player, nil)
		Characters.spawn(player, spawnCFrame())
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
		local match = Match.forPlayer(player)
		if match then
			Match.removeMember(match, player)
			if #match.members == 0 then
				endedAt[match] = nil
				Match.destroy(match)
			end
		end
	end)

	Remotes.RequestStartParty.OnServerEvent:Connect(function(player)
		if accept(player) and table.find(padPlayers, player) then
			startRequested = true
		end
	end)

	Remotes.ReturnToLobby.OnServerEvent:Connect(function(player)
		local match = Match.forPlayer(player)
		if accept(player) and match and Match.hasEnded(match) then
			Lobby.returnPlayer(player)
		end
	end)

	RunService.Heartbeat:Connect(function()
		stepPad()
		stepFinishedMatches()
	end)
end

return Lobby
