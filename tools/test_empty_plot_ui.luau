local fs, luau = require("@lune/fs"), require("@lune/luau")
local function node(class, children)
	local item = children or {}
	function item:FindFirstChild(name) return self[name] end
	function item:IsA(name) return class == name end
	function item:GetDescendants() return self.descendants or {} end
	return item
end

local signName = node("TextLabel", { Text = "Unassigned" })
local sign = node("Model", { Body = node("Part", { SurfaceGui = node("SurfaceGui", {
	Frame = node("Frame", { CityName = signName }),
}) }) })
local buttonInfo = node("SurfaceGui", { Enabled = true })
local button = node("BasePart", { Transparency = 0, ButtonInfo = buttonInfo })
local likeGui = node("LayerCollector", { Enabled = true })
local likePrompt = node("ProximityPrompt", { Enabled = true })
local likeSign = node("Model", { descendants = { likeGui, likePrompt } })
local plot = node("Folder", { UI = node("Model", {
	CitySign = sign,
	CollectIncome = node("Model", { Button = button }),
	RatioSign = likeSign,
}) })
local prepare = luau.load(fs.readFile("src/server/systems/world/EmptyPlotPresentation.luau"), {
	environment = { Color3 = { fromRGB = function() return {} end } },
})()
prepare(plot)
assert(signName.Text == "Nothing", "Empty world sign did not replace Unassigned")
assert(button.Transparency < 1 and not buttonInfo.Enabled, "Collection pad or owner info has wrong empty state")
assert(not likeGui.Enabled and not likePrompt.Enabled, "Empty plot still exposes like actions")

local income = fs.readFile("src/server/systems/economy/IncomeSystem/PlotDisplays.luau")
assert(income:find("surfaceGui.Enabled = occupied", 1, true), "Collection info does not restore on assignment")
assert(income:find('cityNameLabel.Text = "Nothing"', 1, true), "Empty name refresh is not stable")
local rating = fs.readFile("src/server/systems/social/CityRating.luau")
assert(rating:find('GetAttributeChangedSignal("Assigned")', 1, true))
assert(rating:find('GetAttributeChangedSignal("CityId")', 1, true))
assert(rating:find('"UnoccupiedPlot", "This plot is unoccupied."', 1, true))
local client = fs.readFile("src/client/controllers/social/LikeSystem.luau")
assert(client:find('title == "LikeConfirmed" or title == "UnoccupiedPlot"', 1, true))
print("PASS: empty plot keeps its pad, hides owner/like UI, and refreshes on assignment")
