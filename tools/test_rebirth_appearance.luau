local fs = require("@lune/fs")
local luau = require("@lune/luau")
local r = require("@lune/roblox")
local env =
	{ Instance = r.Instance, Color3 = r.Color3, UDim = r.UDim, UDim2 = r.UDim2, Vector2 = r.Vector2, Enum = r.Enum }
local function load(path, environment)
	return luau.load(fs.readFile(path), { environment = environment or env })()
end
local function item(class, name, parent)
	local object = r.Instance.new(class)
	object.Name = name
	object.Parent = parent
	return object
end
local rewards = load("src/client/controllers/ui/UIController/RebirthRewards.luau")
local scroll = item("ScrollingFrame", "ScrollingFrame")
local decoration = item("Frame", "AuthoredDecoration", scroll)
local layout = item("UIListLayout", "UIListLayout", scroll)
local templates = item("Folder", "UIController")
local format = {}
load("src/client/controllers/ui/UIController/Displays.luau")(format)
local data = {
	startingCash = 15000,
	multipliers = { income = 1, population = 1, xp = 1 },
	nextMultipliers = { income = 1.15, population = 1.15, xp = 1.15 },
	unlockedBuildings = { { name = "Ice Cream Store" }, { name = "Donut Store" } },
}
-- Missing cards must never create fallback labels or a layout.
local summary = item("TextLabel", "RebirthSummary", scroll)
rewards.render(scroll, data, templates)
assert(#scroll:GetChildren() == 3 and summary.Parent == scroll)
local bare = item("ScrollingFrame", "Bare")
rewards.render(bare, data, templates)
assert(#bare:GetChildren() == 0, "Missing templates generated substitute UI")
for _, name in { "IncomeBoostTemp", "PopulationBoostTemp", "XPBoostTemp" } do
	local card = item("Frame", name, templates)
	item("TextLabel", "Now", card)
	item("TextLabel", "Next", card)
end
local buildingCard = item("Frame", "BuildingTemp", templates)
item("TextLabel", "BuildingName", buildingCard)
item("ImageLabel", "BuildingIcon", buildingCard)
data.unlockedBuildings[1].imageId = 123
rewards.render(scroll, data, templates)
assert(scroll.IncomeBoost.Now.Text == "x 1.00" and scroll.IncomeBoost.Next.Text == "x 1.15")
assert(scroll.PopulationBoost.Next.Text == "x 1.15" and scroll["Building XPBoost"].Next.Text == "x 1.15")
assert(
	scroll.Building_1.BuildingName.Text == "Ice Cream Store"
		and scroll.Building_1.BuildingIcon.Image == "rbxassetid://123"
)
assert(scroll.Building_2.BuildingName.Text == "Donut Store")
local count = #scroll:GetChildren()
rewards.render(scroll, data, templates)
assert(
	#scroll:GetChildren() == count
		and decoration.Parent == scroll
		and layout.Parent == scroll
		and summary.Parent == scroll
)
data.unlockedBuildings = {}
rewards.render(scroll, data, templates)
assert(not scroll:FindFirstChild("NoBuildingUnlock") and not scroll:FindFirstChild("Building_1"))
assert(not scroll:FindFirstChild("ShopUnlocks"))
for _, card in templates:GetChildren() do
	assert(not card:GetAttribute("MyCityRebirthReward"), "Source template modified")
end

local rng = {
	NextInteger = function(_, low)
		return low
	end,
}
local appearance = load(
	"src/server/systems/world/CivilianSystem/Appearance.luau",
	{ Instance = r.Instance, Color3 = r.Color3, Random = {
		new = function()
			return rng
		end,
	} }
)
local template = item("Model", "Civilian")
for _, name in
	{
		"Head",
		"Torso",
		"Left Arm",
		"Right Arm",
		"Left Leg",
		"Right Leg",
		"HumanoidRootPart",
		"UpperTorso",
		"LeftUpperArm",
		"LeftLowerArm",
		"LeftHand",
		"LeftFoot",
	}
do
	item("Part", name, template)
end
item("Shirt", "Shirt", template)
local light, dark = template:Clone(), template:Clone()
appearance.apply(light, rng)
appearance.apply(dark, {
	NextInteger = function(_, _, high)
		return high
	end,
})
assert(dark.Head.Color.R < light.Head.Color.R and dark.Head.Color == dark["Left Arm"].Color)
assert(light.Torso.Color ~= dark.Torso.Color and light["Left Leg"].Color ~= dark["Left Leg"].Color)
assert(dark.LeftHand.Color == dark.Head.Color and dark.LeftUpperArm.Color == dark.UpperTorso.Color)
assert(dark.LeftFoot.Color ~= dark.Head.Color)
assert(
	not dark:FindFirstChild("Shirt") and template:FindFirstChild("Shirt"),
	"Appearance changed source template instead of clone"
)
assert(template.Head.Color ~= dark.Head.Color and dark.HumanoidRootPart.Color == template.HumanoidRootPart.Color)
print(
	"PASS: template-only rebirth boosts/unlocks/empty levels, authored card retention and R6/R15 civilian palettes without template mutation"
)

-- XP tier particles use moved Assets templates, replacing only their previous clone.
local xpAssets = item("Folder", "Assets")
for _, name in { "SparklesGold", "SparklesBlue", "SparklesPink" } do
	local emitter = item("ParticleEmitter", name, xpAssets)
	emitter.Enabled = false
	emitter:SetAttribute("SourceTier", name)
end
local xp = {
	ReplicatedStorage = {
		WaitForChild = function(_, name)
			assert(name == "Assets")
			return xpAssets
		end,
	},
}
load("src/server/systems/building/BuildingSystem/BuildingXP/Effects.luau")(xp)
local building = item("Model", "Bank")
local base = item("Part", "Base", building)
for _, case in { { 20, "SparklesGold" }, { 40, "SparklesBlue" }, { 100, "SparklesPink" } } do
	xp.applySparkleEffect(building, case[1])
	local emitter = base:FindFirstChild("LevelSparkles")
	assert(emitter and emitter.Enabled and emitter:GetAttribute("SourceTier") == case[2])
	assert(#base:GetChildren() == 1 and not xpAssets:FindFirstChild(case[2]).Enabled)
end
xp.applySparkleEffect(building, 1)
assert(not base:FindFirstChild("LevelSparkles"))
print("PASS: Assets XP tier particle lookup, clone replacement and source preservation")
