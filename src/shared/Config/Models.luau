--!strict
-- AI-made models (Roblox Studio's mesh generator), kept as data so they live in git. Made and
-- tuned in Studio's ReplicatedStorage.ModelLibrary, then exported with tools/export-models.luau:
-- don't edit by hand. client/ModelLibrary builds them at startup.

export type Part = {
	name: string,
	group: string?, -- for client/EnemyAnimation
	joint: Vector3?, -- where it swings from, if not the top of the part (an arm holding a raised club)
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
	GoblinGiant = {
		{ name = "Body", group = "Body", mesh = "rbxassetid://85841909565281", texture = "rbxassetid://98143984552197", material = "Plastic", size = Vector3.new(3.7952, 4.7735, 3.5102), cframe = CFrame.new(-0.1492, 3.7578, 0.9574, 1, 0, 0, 0, 1, 0, 0, 0, 1), color = Color3.fromRGB(110, 80, 55) },
		{ name = "Head", group = "Head", mesh = "rbxassetid://83094527667471", texture = "rbxassetid://92267310550384", material = "Plastic", size = Vector3.new(4.3511, 2.495, 3.0145), cframe = CFrame.new(-0.1258, 6.8109, 0.7359, 1, 0, 0, 0, 1, 0, 0, 0, 1), color = Color3.fromRGB(80, 130, 55) },
		{ name = "ArmL", group = "ArmL", mesh = "rbxassetid://106708242813238", texture = "rbxassetid://132859676377497", material = "Plastic", size = Vector3.new(2.425, 4.945, 3.1809), cframe = CFrame.new(-2.4662, 4.1291, 1.0038, 1, 0, 0, 0, 1, 0, 0, 0, 1), color = Color3.fromRGB(80, 130, 55) },
		{ name = "ArmR", group = "ArmR", joint = Vector3.new(1.6832, 5.5445, 0.9574), mesh = "rbxassetid://119274905893469", texture = "rbxassetid://72543276571385", material = "Plastic", size = Vector3.new(2.6606, 8.5001, 5.2985), cframe = CFrame.new(2.3484, 4.2499, -0.0632, 1, 0, 0, 0, 1, 0, 0, 0, 1), color = Color3.fromRGB(110, 85, 55) },
		{ name = "Legs", group = "Legs", mesh = "rbxassetid://121714766789866", texture = "rbxassetid://104609195389981", material = "Plastic", size = Vector3.new(4.5538, 2.7757, 2.3608), cframe = CFrame.new(-0.1165, 1.4218, 0.6541, 1, 0, 0, 0, 1, 0, 0, 0, 1), color = Color3.fromRGB(70, 105, 45) },
	},
	Infernal = {
		{ name = "Body", group = "Body", mesh = "rbxassetid://109755809860690", texture = "rbxassetid://92259827779292", material = "Plastic", size = Vector3.new(4.7644, 7.2196, 3.9735), cframe = CFrame.new(-0.0001, 6.4761, 0.0897, 1, 0, 0, 0, 1, 0, 0, 0, 1), color = Color3.fromRGB(90, 30, 28) },
		{ name = "Head", group = "Head", mesh = "rbxassetid://115302479935518", texture = "rbxassetid://81647462145557", material = "Plastic", size = Vector3.new(4.4863, 3.5329, 2.1428), cframe = CFrame.new(-0.0035, 10.7335, -0.899, 1, 0, 0, 0, 1, 0, 0, 0, 1), color = Color3.fromRGB(110, 35, 30) },
		{ name = "ArmL", group = "ArmL", mesh = "rbxassetid://119756163215914", texture = "rbxassetid://109288686088398", material = "Plastic", size = Vector3.new(2.9849, 7.8913, 3.0525), cframe = CFrame.new(-3.085, 6.4057, 0.153, 1, 0, 0, 0, 1, 0, 0, 0, 1), color = Color3.fromRGB(110, 35, 30) },
		{ name = "ArmR", group = "ArmR", mesh = "rbxassetid://108025039034804", texture = "rbxassetid://86934606524714", material = "Plastic", size = Vector3.new(2.9603, 7.8692, 3.043), cframe = CFrame.new(3.0972, 6.4073, 0.1531, 1, 0, 0, 0, 1, 0, 0, 0, 1), color = Color3.fromRGB(110, 35, 30) },
		{ name = "LegA", group = "LegA", mesh = "rbxassetid://132010267642216", texture = "rbxassetid://75311738000990", material = "Plastic", size = Vector3.new(2.9855, 5.2889, 3.2114), cframe = CFrame.new(-1.6838, 2.6456, -0.4709, 1, 0, 0, 0, 1, 0, 0, 0, 1), color = Color3.fromRGB(60, 25, 25) },
		{ name = "LegB", group = "LegB", mesh = "rbxassetid://77394647188580", texture = "rbxassetid://94800413678525", material = "Plastic", size = Vector3.new(2.9821, 5.2848, 3.1743), cframe = CFrame.new(1.6885, 2.6424, -0.4466, 1, 0, 0, 0, 1, 0, 0, 0, 1), color = Color3.fromRGB(60, 25, 25) },
	},
	MagmaGolem = {
		{ name = "Body", group = "Body", mesh = "rbxassetid://110584648699721", texture = "rbxassetid://120454643176989", material = "Plastic", size = Vector3.new(4.6735, 5.5856, 3.8415), cframe = CFrame.new(-0.0218, 5.207, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1), color = Color3.fromRGB(65, 50, 46) },
		{ name = "Head", group = "Head", mesh = "rbxassetid://78779103547776", texture = "rbxassetid://125957995269347", material = "Plastic", size = Vector3.new(2.2329, 1.9441, 2.4606), cframe = CFrame.new(-0.0118, 8.028, -0.4431, 1, 0, 0, 0, 1, 0, 0, 0, 1), color = Color3.fromRGB(70, 55, 50) },
		{ name = "ArmL", group = "ArmL", mesh = "rbxassetid://98200128507508", texture = "rbxassetid://79311131110459", material = "Plastic", size = Vector3.new(2.8821, 6.6779, 2.9597), cframe = CFrame.new(-3.1698, 4.4708, 0.1732, 1, 0, 0, 0, 1, 0, 0, 0, 1), color = Color3.fromRGB(70, 55, 50) },
		{ name = "ArmR", group = "ArmR", mesh = "rbxassetid://136077815040020", texture = "rbxassetid://81211637927602", material = "Plastic", size = Vector3.new(2.8912, 6.6782, 2.9465), cframe = CFrame.new(3.1654, 4.4654, 0.1807, 1, 0, 0, 0, 1, 0, 0, 0, 1), color = Color3.fromRGB(70, 55, 50) },
		{ name = "LegA", group = "LegA", mesh = "rbxassetid://133574313809979", texture = "rbxassetid://112125079066193", material = "Plastic", size = Vector3.new(1.9244, 3.6797, 2.6936), cframe = CFrame.new(-1.2947, 1.8398, -0.1859, 1, 0, 0, 0, 1, 0, 0, 0, 1), color = Color3.fromRGB(60, 46, 42) },
		{ name = "LegB", group = "LegB", mesh = "rbxassetid://115599933751906", texture = "rbxassetid://128898815994239", material = "Plastic", size = Vector3.new(1.906, 3.6776, 2.6941), cframe = CFrame.new(1.2695, 1.84, -0.1829, 1, 0, 0, 0, 1, 0, 0, 0, 1), color = Color3.fromRGB(60, 46, 42) },
	},
	Ogre = {
		{ name = "Body", group = "Body", mesh = "rbxassetid://112455717926494", texture = "rbxassetid://71599753085096", material = "Plastic", size = Vector3.new(5.9591, 6.4375, 5.3906), cframe = CFrame.new(-0.5901, 5.1515, 0.3383, 1, 0, 0, 0, 1, 0, 0, 0, 1), color = Color3.fromRGB(110, 120, 85) },
		{ name = "Head", group = "Head", mesh = "rbxassetid://79912843052901", texture = "rbxassetid://131173278989439", material = "Plastic", size = Vector3.new(3.0593, 2.9152, 3.6908), cframe = CFrame.new(-0.7118, 9.1661, -1.1882, 1, 0, 0, 0, 1, 0, 0, 0, 1), color = Color3.fromRGB(125, 135, 95) },
		{ name = "ArmL", group = "ArmL", mesh = "rbxassetid://125875551467091", texture = "rbxassetid://89811889451923", material = "Plastic", size = Vector3.new(3.8241, 6.5846, 3.3198), cframe = CFrame.new(-3.8458, 5.2642, 0.1249, 1, 0, 0, 0, 1, 0, 0, 0, 1), color = Color3.fromRGB(125, 135, 95) },
		{ name = "ArmR", group = "ArmR", joint = Vector3.new(2.0608, 7.7703, 0.3383), mesh = "rbxassetid://95031501562612", texture = "rbxassetid://84868101982946", material = "Plastic", size = Vector3.new(4.9296, 11.7908, 4.4388), cframe = CFrame.new(3.2932, 6.1046, -0.4364, 1, 0, 0, 0, 1, 0, 0, 0, 1), color = Color3.fromRGB(110, 90, 60) },
		{ name = "LegA", group = "LegA", mesh = "rbxassetid://107687154654161", texture = "rbxassetid://99713355804914", material = "Plastic", size = Vector3.new(2.4761, 2.869, 3.0668), cframe = CFrame.new(-2.3821, 1.4406, -0.0894, 1, 0, 0, 0, 1, 0, 0, 0, 1), color = Color3.fromRGB(95, 100, 70) },
		{ name = "LegB", group = "LegB", mesh = "rbxassetid://114499028325954", texture = "rbxassetid://139544236663344", material = "Plastic", size = Vector3.new(2.5148, 2.9151, 3.0601), cframe = CFrame.new(1.223, 1.4576, -0.0899, 1, 0, 0, 0, 1, 0, 0, 0, 1), color = Color3.fromRGB(95, 100, 70) },
	},
}

return table.freeze(MODELS)
