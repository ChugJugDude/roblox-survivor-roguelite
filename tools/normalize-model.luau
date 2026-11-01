--[[
	Turns a freshly generated model (Studio's generate_mesh) into a ModelLibrary template, ready for
	tools/export-models.luau. Run in Studio's Edit mode with the settings filled in at the bottom
	(the MCP execute_luau tool, or paste into the command bar).

	It flattens the generated sub-models into named MeshParts (each tagged with its animation
	Group and given a flat color for the hit flash), squares the model up (generations arrive
	turned toward the editor camera, often by an odd angle), turns it to face -Z using a check you
	choose, scales it to its in-game height, and puts its pivot on the ground (or `lift` studs
	below it, for fliers).

	The facing check trusts the generator's part labels, which are sometimes wrong (the Ember
	Archer's left and right arms were swapped). Always confirm with a front-view screenshot in game
	(models face -Z: look from -Z toward +Z and every face should show) before exporting.
]]

type GroupSpec = { keyword: string, group: string, color: Color3 }
type Facing =
	{ kind: "side", part: string, sign: number } -- this part's X has this sign when facing -Z
	| { kind: "ahead", front: string, back: string } -- `front` is further toward -Z than `back`

type Settings = {
	tag: string, -- the generation's CollectionService tag
	name: string, -- the template's name (an enemy kind, or a weapon piece)
	height: number, -- in-game height, studs
	groups: { GroupSpec },
	facing: Facing?,
	lift: number?, -- studs between the ground pivot and the model's bottom (fliers)
}

local function normalize(settings: Settings): string
	local CollectionService = game:GetService("CollectionService")
	local library = game:GetService("ReplicatedStorage"):FindFirstChild("ModelLibrary")
	assert(library, "No ReplicatedStorage.ModelLibrary")
	local model = CollectionService:GetTagged(settings.tag)[1]
	assert(model and model:IsA("Model"), `No generated model tagged {settings.tag}`)
	model.Name = settings.name

	-- Flatten, name, color.
	local yaw: number? = nil
	for _, part in model:GetDescendants() do
		if part:IsA("MeshPart") then
			local label = string.lower(if part.Parent and part.Parent ~= model then part.Parent.Name else part.Name)
			for _, spec in settings.groups do
				if string.find(label, spec.keyword, 1, true) then
					part.Name = spec.group
					part.Color = spec.color
					part:SetAttribute("Group", spec.group)
					break
				end
			end
			if not yaw then
				local _, y = part.CFrame:ToOrientation()
				yaw = y
			end
			part.Parent = model
		end
	end
	for _, child in model:GetChildren() do
		if child:IsA("Model") then
			child:Destroy()
		end
	end

	-- Square up: spin about the center until the parts' own rotation is zero.
	model.WorldPivot = CFrame.new(model:GetBoundingBox().Position)
	model:PivotTo(CFrame.Angles(0, -(yaw or 0), 0))
	model.WorldPivot = CFrame.new(model:GetPivot().Position)
	model:PivotTo(CFrame.new())

	-- Face -Z.
	local facing = settings.facing
	local turned = false
	if facing then
		local wrong
		if facing.kind == "side" then
			local part = model:FindFirstChild(facing.part) :: BasePart
			wrong = math.sign(part.Position.X) ~= facing.sign
		else
			local front = model:FindFirstChild(facing.front) :: BasePart
			local back = model:FindFirstChild(facing.back) :: BasePart
			wrong = front.Position.Z > back.Position.Z
		end
		if wrong then
			model:PivotTo(CFrame.Angles(0, math.pi, 0))
			model.WorldPivot = CFrame.new(model:GetPivot().Position)
			model:PivotTo(CFrame.new())
			turned = true
		end
	end

	-- Scale, then pivot on the ground under the center.
	model:ScaleTo(model:GetScale() * settings.height / model:GetExtentsSize().Y)
	local box, size = model:GetBoundingBox()
	local lift = settings.lift or 0
	model.WorldPivot = CFrame.new(box.Position.X, box.Position.Y - size.Y / 2 - lift, box.Position.Z)
	model:PivotTo(CFrame.new())
	model.Parent = library

	local report = {}
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") then
			table.insert(report, string.format("%s(%.1f,%.1f,%.1f)", part.Name, part.Position.X, part.Position.Y, part.Position.Z))
		end
	end
	return string.format(
		"%s: squared %.1f deg%s, size %s: %s",
		settings.name,
		math.deg(yaw or 0),
		if turned then ", turned 180" else "",
		tostring(model:GetExtentsSize()),
		table.concat(report, " ")
	)
end

return normalize
