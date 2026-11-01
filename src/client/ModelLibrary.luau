--!strict
-- Builds the AI-made models in Config.Models once, in the background at startup (each mesh is
-- fetched with AssetService:CreateMeshPartAsync), and hands out the finished ones as templates to
-- clone. Until a model is ready (or if a mesh fails to load), `get` returns nil and callers use
-- their code-built fallback; the lobby gives plenty of time for everything to load.

local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Models = require(ReplicatedStorage.Shared.Config.Models)

local ready: { [string]: Model } = {}
local started = false

local ModelLibrary = {}

local function buildPart(data: Models.Part): BasePart?
	local part: BasePart
	if data.mesh then
		local ok, result = pcall(function()
			return AssetService:CreateMeshPartAsync(
				Content.fromUri(data.mesh :: string),
				{ CollisionFidelity = Enum.CollisionFidelity.Box }
			)
		end)
		if not ok then
			warn(`[ModelLibrary] Couldn't load mesh {data.mesh}: {result}`)
			return nil
		end
		local mesh = result :: MeshPart
		mesh.TextureID = data.texture or ""
		part = mesh
	else
		part = Instance.new("Part")
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
	end
	part.Name = data.name
	part.Size = data.size
	part.CFrame = data.cframe
	part.Color = data.color
	part.Material = (Enum.Material :: any)[data.material] or Enum.Material.Plastic
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	if data.group then
		part:SetAttribute("Group", data.group)
	end
	return part
end

local function build(name: string, parts: { Models.Part })
	local model = Instance.new("Model")
	model.Name = name
	for _, data in parts do
		local part = buildPart(data)
		if not part then
			model:Destroy()
			return
		end
		part.Parent = model
	end
	model.WorldPivot = CFrame.identity
	ready[name] = model
end

-- The finished model called `name` (its pivot on the ground, facing -Z), or nil if it isn't
-- loaded. Clone it; don't change it.
function ModelLibrary.get(name: string): Model?
	return ready[name]
end

function ModelLibrary.start()
	assert(not started, "ModelLibrary.start() was called twice")
	started = true
	for name, parts in Models do
		task.spawn(build, name, parts)
	end
end

return ModelLibrary
