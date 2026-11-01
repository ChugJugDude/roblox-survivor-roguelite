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
	Bat = {
		{ name = "Body", group = "Body", mesh = "rbxassetid://133652560408579", texture = "rbxassetid://91088871428832", material = "Plastic", size = Vector3.new(1.7393, 2.64, 2.4275), cframe = CFrame.new(-0.0092, 3.5, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1), color = Color3.fromRGB(70, 45, 90) },
		{ name = "WingL", group = "WingL", mesh = "rbxassetid://94264491604638", texture = "rbxassetid://93037874734046", material = "Plastic", size = Vector3.new(1.6632, 1.573, 0.6853), cframe = CFrame.new(-1.1684, 3.8737, -0.5634, 1, 0, 0, 0, 1, 0, 0, 0, 1), color = Color3.fromRGB(110, 70, 140) },
		{ name = "WingR", group = "WingR", mesh = "rbxassetid://112490017134720", texture = "rbxassetid://71535241561098", material = "Plastic", size = Vector3.new(1.6689, 1.5777, 0.6968), cframe = CFrame.new(1.1656, 3.8758, -0.567, 1, 0, 0, 0, 1, 0, 0, 0, 1), color = Color3.fromRGB(110, 70, 140) },
	},
	EmberArcher = {
		{ name = "Body", group = "Body", mesh = "rbxassetid://118070272051897", texture = "rbxassetid://130240651234075", material = "Plastic", size = Vector3.new(1.8869, 2.2919, 1.614), cframe = CFrame.new(-0.0231, 1.4798, 0.1765, 1, 0, 0, 0, 1, 0, 0, 0, 1), color = Color3.fromRGB(120, 32, 26) },
		{ name = "Head", group = "Head", mesh = "rbxassetid://133726992789808", texture = "rbxassetid://90525944268091", material = "Plastic", size = Vector3.new(1.8745, 1.857, 1.7027), cframe = CFrame.new(-0.0189, 3.0715, 0.0151, 1, 0, 0, 0, 1, 0, 0, 0, 1), color = Color3.fromRGB(60, 22, 20) },
		{ name = "ArmL", group = "ArmL", joint = Vector3.new(-0.7198, 2.3257, 0.1765), mesh = "rbxassetid://103974176891482", texture = "rbxassetid://119166378504125", material = "Plastic", size = Vector3.new(1.1011, 3.6589, 1.4613), cframe = CFrame.new(-0.94, 1.8514, -0.2528, 1, 0, 0, 0, 1, 0, 0, 0, 1), color = Color3.fromRGB(120, 32, 26) },
		{ name = "ArmR", group = "ArmR", mesh = "rbxassetid://129349691390748", texture = "rbxassetid://114384946832246", material = "Plastic", size = Vector3.new(1.1496, 1.3259, 1.187), cframe = CFrame.new(0.9158, 1.6826, -0.1073, 1, 0, 0, 0, 1, 0, 0, 0, 1), color = Color3.fromRGB(120, 32, 26) },
		{ name = "Legs", group = "Legs", mesh = "rbxassetid://96594063653195", texture = "rbxassetid://126195156801787", material = "Plastic", size = Vector3.new(1.5951, 0.6331, 0.7647), cframe = CFrame.new(-0.0157, 0.3165, -0.0143, 1, 0, 0, 0, 1, 0, 0, 0, 1), color = Color3.fromRGB(120, 32, 26) },
	},
	FireImp = {
		{ name = "Body", group = "Body", mesh = "rbxassetid://82552410433046", texture = "rbxassetid://95543230056657", material = "Plastic", size = Vector3.new(1.4338, 1.7944, 1.9393), cframe = CFrame.new(-0.2109, 1.054, 0.0803, 1, 0, 0, 0, 1, 0, 0, 0, 1), color = Color3.fromRGB(150, 40, 30) },
		{ name = "Head", group = "Head", mesh = "rbxassetid://127149373984602", texture = "rbxassetid://89828811094519", material = "Plastic", size = Vector3.new(2.1181, 1.9335, 1.219), cframe = CFrame.new(0, 2.8332, -0.4404, 1, 0, 0, 0, 1, 0, 0, 0, 1), color = Color3.fromRGB(210, 75, 45) },
		{ name = "ArmL", group = "ArmL", mesh = "rbxassetid://77744028913321", texture = "rbxassetid://98765055322710", material = "Plastic", size = Vector3.new(0.7429, 1.1338, 0.5813), cframe = CFrame.new(-0.5329, 1.1816, -0.5743, 1, 0, 0, 0, 1, 0, 0, 0, 1), color = Color3.fromRGB(210, 75, 45) },
		{ name = "ArmR", group = "ArmR", mesh = "rbxassetid://72875895786344", texture = "rbxassetid://91598361111140", material = "Plastic", size = Vector3.new(0.7193, 1.1379, 0.5916), cframe = CFrame.new(0.5415, 1.1713, -0.5727, 1, 0, 0, 0, 1, 0, 0, 0, 1), color = Color3.fromRGB(210, 75, 45) },
		{ name = "Legs", group = "Legs", mesh = "rbxassetid://119290130967037", texture = "rbxassetid://120625580237352", material = "Plastic", size = Vector3.new(1.4372, 1.024, 0.611), cframe = CFrame.new(0, 0.512, -0.5132, 1, 0, 0, 0, 1, 0, 0, 0, 1), color = Color3.fromRGB(150, 40, 30) },
	},
	MagmaHound = {
		{ name = "Body", group = "Body", mesh = "rbxassetid://97857851215312", texture = "rbxassetid://75618133543073", material = "Plastic", size = Vector3.new(1.7602, 1.6728, 2.6034), cframe = CFrame.new(-0.0008, 1.5425, 0.5142, 1, 0, 0, 0, 1, 0, 0, 0, 1), color = Color3.fromRGB(120, 78, 60) },
		{ name = "Head", group = "Head", mesh = "rbxassetid://72015368814360", texture = "rbxassetid://84058464747584", material = "Plastic", size = Vector3.new(1.6551, 1.6666, 1.5618), cframe = CFrame.new(0.0022, 1.7667, -1.035, 1, 0, 0, 0, 1, 0, 0, 0, 1), color = Color3.fromRGB(120, 78, 60) },
		{ name = "LegFL", group = "LegA", mesh = "rbxassetid://99669676129905", texture = "rbxassetid://109593993032257", material = "Plastic", size = Vector3.new(0.62, 2.0579, 1.0396), cframe = CFrame.new(-0.6043, 1.0289, -0.3995, 1, 0, 0, 0, 1, 0, 0, 0, 1), color = Color3.fromRGB(120, 78, 60) },
		{ name = "LegFR", group = "LegB", mesh = "rbxassetid://81027147518797", texture = "rbxassetid://103554721478303", material = "Plastic", size = Vector3.new(0.6312, 2.0436, 1.036), cframe = CFrame.new(0.5987, 1.0228, -0.4002, 1, 0, 0, 0, 1, 0, 0, 0, 1), color = Color3.fromRGB(120, 78, 60) },
		{ name = "LegBL", group = "LegB", mesh = "rbxassetid://119630537357229", texture = "rbxassetid://136297238722155", material = "Plastic", size = Vector3.new(0.6106, 0.9906, 0.8675), cframe = CFrame.new(-0.5806, 0.4963, 1.0236, 1, 0, 0, 0, 1, 0, 0, 0, 1), color = Color3.fromRGB(120, 78, 60) },
		{ name = "LegBR", group = "LegA", mesh = "rbxassetid://138613724865959", texture = "rbxassetid://119372332938928", material = "Plastic", size = Vector3.new(0.6085, 0.9915, 0.8631), cframe = CFrame.new(0.5781, 0.497, 1.0225, 1, 0, 0, 0, 1, 0, 0, 0, 1), color = Color3.fromRGB(120, 78, 60) },
	},
	SkeletonArcher = {
		{ name = "Body", group = "Body", mesh = "rbxassetid://74823285133990", texture = "rbxassetid://86638403382131", material = "Plastic", size = Vector3.new(1.825, 2.2831, 1.4671), cframe = CFrame.new(0.113, 1.7311, 0.393, 1, 0, 0, 0, 1, 0, 0, 0, 1), color = Color3.fromRGB(150, 90, 190) },
		{ name = "Head", group = "Head", mesh = "rbxassetid://136507953482620", texture = "rbxassetid://108637041392387", material = "Plastic", size = Vector3.new(1.1499, 1.2778, 1.34), cframe = CFrame.new(0.1478, 3.1315, 0.0409, 1, 0, 0, 0, 1, 0, 0, 0, 1), color = Color3.fromRGB(225, 220, 200) },
		{ name = "ArmL", group = "ArmL", joint = Vector3.new(-0.5545, 2.5726, 0.393), mesh = "rbxassetid://111258928764580", texture = "rbxassetid://81577560850747", material = "Plastic", size = Vector3.new(1.0892, 4, 1.5343), cframe = CFrame.new(-0.7723, 2, -0.3595, 1, 0, 0, 0, 1, 0, 0, 0, 1), color = Color3.fromRGB(225, 220, 200) },
		{ name = "ArmR", group = "ArmR", mesh = "rbxassetid://88079612070467", texture = "rbxassetid://99543337897264", material = "Plastic", size = Vector3.new(0.7875, 1.2588, 0.7614), cframe = CFrame.new(0.9231, 1.8154, -0.246, 1, 0, 0, 0, 1, 0, 0, 0, 1), color = Color3.fromRGB(225, 220, 200) },
		{ name = "Legs", group = "Legs", mesh = "rbxassetid://99124439389102", texture = "rbxassetid://86147408680403", material = "Plastic", size = Vector3.new(1.4968, 1.4322, 0.6603), cframe = CFrame.new(0.1902, 0.723, 0.0228, 1, 0, 0, 0, 1, 0, 0, 0, 1), color = Color3.fromRGB(225, 220, 200) },
	},
	-- Weapons and projectiles: centered pivots, pointing -Z.
	Arrow = {
		{ name = "Arrow", mesh = "rbxassetid://132266105831569", texture = "rbxassetid://99736383135903", material = "Plastic", size = Vector3.new(0.2948, 0.3238, 2.8), cframe = CFrame.new(0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1), color = Color3.fromRGB(200, 170, 120) },
	},
	Meteor = {
		{ name = "Rock", mesh = "rbxassetid://92779308310585", texture = "rbxassetid://134233252102059", material = "Plastic", size = Vector3.new(3.3539, 3.4001, 3.3527), cframe = CFrame.new(0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1), color = Color3.fromRGB(255, 110, 40) },
	},
}

return table.freeze(MODELS)
