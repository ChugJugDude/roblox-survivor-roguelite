--!strict
-- AI-made models (Roblox Studio's mesh generator), kept as data so they live in git. Made and
-- tuned in Studio's ReplicatedStorage.ModelLibrary, then exported with tools/export-models.luau:
-- don't edit by hand. client/ModelLibrary builds them at startup.

export type Part = {
	name: string,
	group: string?, -- for client/EnemyAnimation
	mesh: string?, -- nil for a plain Part
	texture: string?,
	material: string,
	size: Vector3,
	cframe: CFrame, -- from the model's pivot (on the ground, facing -Z)
	color: Color3, -- shown when the texture is off (hit flash, chill)
}

-- stylua: ignore
local MODELS: { [string]: { Part } } = {
	Goblin = {
		{ name = "Body", group = "Body", mesh = "rbxassetid://81281826814169", texture = "rbxassetid://137954534324681", material = "Plastic", size = Vector3.new(1.8154, 1.7596, 1.9472), cframe = CFrame.new(0.0047, 1.5104, 0.2405, 1, 0, 0, 0, 1, 0, 0, 0, 1), color = Color3.fromRGB(130, 80, 50) },
		{ name = "Head", group = "Head", mesh = "rbxassetid://114450439955990", texture = "rbxassetid://77973414886013", material = "Plastic", size = Vector3.new(4.0192, 1.8447, 2.1344), cframe = CFrame.new(0, 3.0778, 0.014, 1, 0, 0, 0, 1, 0, 0, 0, 1), color = Color3.fromRGB(110, 190, 70) },
		{ name = "ArmL", group = "ArmL", mesh = "rbxassetid://106654021183414", texture = "rbxassetid://89600992501552", material = "Plastic", size = Vector3.new(0.9209, 1.5074, 0.7787), cframe = CFrame.new(-0.977, 1.3464, 0.3045, 1, 0, 0, 0, 1, 0, 0, 0, 1), color = Color3.fromRGB(110, 190, 70) },
		{ name = "ArmR", group = "ArmR", mesh = "rbxassetid://83606404181123", texture = "rbxassetid://102245558327091", material = "Plastic", size = Vector3.new(0.922, 1.5062, 3.2485), cframe = CFrame.new(0.9864, 1.3351, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1), color = Color3.fromRGB(110, 190, 70) },
		{ name = "Legs", group = "Legs", mesh = "rbxassetid://85542481909677", texture = "rbxassetid://109694797582614", material = "Plastic", size = Vector3.new(1.8154, 0.8458, 0.9251), cframe = CFrame.new(0.0069, 0.4229, 0.1165, 1, 0, 0, 0, 1, 0, 0, 0, 1), color = Color3.fromRGB(90, 150, 60) },
		{ name = "Eye", group = "Head", material = "Neon", size = Vector3.new(0.36, 0.3, 0.12), cframe = CFrame.new(0.4, 3.1, -1, 1, 0, 0, 0, 1, 0, 0, 0, 1), color = Color3.fromRGB(255, 220, 60) },
		{ name = "Eye", group = "Head", material = "Neon", size = Vector3.new(0.36, 0.3, 0.12), cframe = CFrame.new(-0.4, 3.1, -1, 1, 0, 0, 0, 1, 0, 0, 0, 1), color = Color3.fromRGB(255, 220, 60) },
	},
}

return table.freeze(MODELS)
