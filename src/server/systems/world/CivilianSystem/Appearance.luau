-- Apply once to each cloned civilian; the ServerStorage template stays untouched.
local Appearance = {}
local random = Random.new()
local skins = {
	Color3.fromRGB(255, 219, 172),
	Color3.fromRGB(241, 194, 151),
	Color3.fromRGB(214, 157, 111),
	Color3.fromRGB(179, 119, 78),
	Color3.fromRGB(139, 88, 56),
	Color3.fromRGB(101, 65, 43),
	Color3.fromRGB(70, 45, 32),
}
local shirts = {
	Color3.fromRGB(58, 117, 184),
	Color3.fromRGB(194, 66, 59),
	Color3.fromRGB(71, 140, 93),
	Color3.fromRGB(235, 187, 66),
	Color3.fromRGB(142, 98, 169),
	Color3.fromRGB(228, 221, 204),
	Color3.fromRGB(53, 59, 70),
	Color3.fromRGB(220, 133, 155),
}
local trousers =
	{ Color3.fromRGB(43, 62, 91), Color3.fromRGB(51, 52, 58), Color3.fromRGB(117, 99, 73), Color3.fromRGB(72, 83, 72) }
local shoes = Color3.fromRGB(37, 35, 34)
function Appearance.apply(model, rng)
	rng = rng or random
	local skin = skins[rng:NextInteger(1, #skins)]
	local shirt = shirts[rng:NextInteger(1, #shirts)]
	local pants = trousers[rng:NextInteger(1, #trousers)]
	-- Classic clothes would cover the requested solid-colour outfits.
	for _, child in model:GetChildren() do
		if child:IsA("Shirt") or child:IsA("Pants") or child:IsA("ShirtGraphic") then
			child:Destroy()
		end
	end
	local colors = model:FindFirstChildOfClass("BodyColors")
	if not colors then
		colors = Instance.new("BodyColors")
		colors.Parent = model
	end
	colors.HeadColor3 = skin
	colors.LeftArmColor3, colors.RightArmColor3 = skin, skin
	colors.TorsoColor3 = shirt
	colors.LeftLegColor3, colors.RightLegColor3 = pants, pants
	local parts = {
		Head = skin,
		Torso = shirt,
		UpperTorso = shirt,
		LowerTorso = pants,
		["Left Arm"] = skin,
		["Right Arm"] = skin,
		["Left Leg"] = pants,
		["Right Leg"] = pants,
		LeftUpperArm = shirt,
		RightUpperArm = shirt,
		LeftLowerArm = skin,
		RightLowerArm = skin,
		LeftHand = skin,
		RightHand = skin,
		LeftUpperLeg = pants,
		RightUpperLeg = pants,
		LeftLowerLeg = pants,
		RightLowerLeg = pants,
		LeftFoot = shoes,
		RightFoot = shoes,
	}
	for name, color in parts do
		local part = model:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			part.Color = color
		end
	end
end
return Appearance
