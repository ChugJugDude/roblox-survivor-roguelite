--[[
	Exports the AI models from Studio's workshop folder (ReplicatedStorage.ModelLibrary) as the
	source of src/shared/Config/Models.luau. Run it in Studio's Edit mode (the command bar, or
	the MCP execute_luau tool) and save what it returns over that file.

	Each template is a Model named after what it's for (an enemy kind like "Goblin", or a weapon
	piece), normalized first: its pivot on the ground under its center, facing -Z, at its in-game
	size. Parts may carry a "Group" attribute for animation (ArmL, ArmR, LegA, LegB, WingL, WingR).
]]

local library = game:GetService("ReplicatedStorage"):FindFirstChild("ModelLibrary")
assert(library, "No ReplicatedStorage.ModelLibrary to export")

local function num(n: number): string
	local s = string.format("%.4f", n)
	s = string.gsub(s, "0+$", "")
	s = string.gsub(s, "%.$", "")
	return if s == "-0" then "0" else s
end

local function list(values: { number }): string
	local out = {}
	for _, v in values do
		table.insert(out, num(v))
	end
	return table.concat(out, ", ")
end

local lines = {
	"--!strict",
	"-- AI-made models (Roblox Studio's mesh generator), kept as data so they live in git. Made and",
	"-- tuned in Studio's ReplicatedStorage.ModelLibrary, then exported with tools/export-models.luau:",
	"-- don't edit by hand. client/ModelLibrary builds them at startup.",
	"",
	"export type Part = {",
	"\tname: string,",
	"\tgroup: string?, -- for client/EnemyAnimation",
	"\tmesh: string?, -- nil for a plain Part",
	"\ttexture: string?,",
	"\tmaterial: string,",
	"\tsize: Vector3,",
	"\tcframe: CFrame, -- from the model's pivot (on the ground, facing -Z)",
	"\tcolor: Color3, -- shown when the texture is off (hit flash, chill)",
	"}",
	"",
	"-- stylua: ignore",
	"local MODELS: { [string]: { Part } } = {",
}
local templates = library:GetChildren()
table.sort(templates, function(a, b)
	return a.Name < b.Name
end)
for _, template in templates do
	if not template:IsA("Model") then
		continue
	end
	table.insert(lines, `\t{template.Name} = \{`)
	local pivot = template:GetPivot()
	for _, part in template:GetDescendants() do
		if not part:IsA("BasePart") then
			continue
		end
		local fields = { `name = "{part.Name}"` }
		local group = part:GetAttribute("Group")
		if typeof(group) == "string" then
			table.insert(fields, `group = "{group}"`)
		end
		if part:IsA("MeshPart") then
			table.insert(fields, `mesh = "{part.MeshId}"`)
			if part.TextureID ~= "" then
				table.insert(fields, `texture = "{part.TextureID}"`)
			end
		end
		table.insert(fields, `material = "{part.Material.Name}"`)
		table.insert(fields, `size = Vector3.new({list({ part.Size.X, part.Size.Y, part.Size.Z })})`)
		table.insert(fields, `cframe = CFrame.new({list({ pivot:ToObjectSpace(part.CFrame):GetComponents() })})`)
		local c = part.Color
		table.insert(
			fields,
			`color = Color3.fromRGB({math.round(c.R * 255)}, {math.round(c.G * 255)}, {math.round(c.B * 255)})`
		)
		table.insert(lines, `\t\t\{ {table.concat(fields, ", ")} \},`)
	end
	table.insert(lines, "\t},")
end
table.insert(lines, "}")
table.insert(lines, "")
table.insert(lines, "return table.freeze(MODELS)")
return table.concat(lines, "\n") .. "\n"
