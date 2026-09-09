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
rewards.render(scroll, data, templates, format.formatNumber)
assert(scroll.RebirthSummary.Text:find("$15,000", 1, true) and not scroll.RebirthSummary.Text:find("$$", 1, true))
assert(scroll.RebirthSummary.TextColor3.R < 0.5, "Summary unreadable on white confirmation")
assert(scroll.incomeBoost.Text:find("1.15", 1, true) and scroll.populationBoost and scroll.xpBoost)
assert(scroll.Building_1.Text == "Ice Cream Store" and scroll.Building_2.Text == "Donut Store")
local count = #scroll:GetChildren()
rewards.render(scroll, data, templates, format.formatNumber)
assert(
	#scroll:GetChildren() == count and decoration.Parent == scroll and layout.Parent == scroll,
	"Refresh duplicated generated rewards or removed authored UI"
)
data.unlockedBuildings = {}
rewards.render(scroll, data, templates, format.formatNumber)
assert(scroll:FindFirstChild("NoBuildingUnlock") and not scroll:FindFirstChild("Building_1"))
local card = item("Frame", "IncomeBoostTemp", templates)
item("TextLabel", "Now", card)
item("TextLabel", "Next", card)
rewards.render(scroll, data, templates, format.formatNumber)
assert(scroll.IncomeBoost.Now.Text == "x 1.00" and scroll.IncomeBoost.Next.Text == "x 1.15")
assert(card.Parent == templates and not card:GetAttribute("MyCityRebirthReward"))

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
	"PASS: readable rebirth fallback/boosts/unlocks/empty levels, authored card retention and R6/R15 civilian palettes without template mutation"
)
