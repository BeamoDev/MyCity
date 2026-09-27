local fs, luau, r = require("@lune/fs"), require("@lune/luau"), require("@lune/roblox")
local services = { RunService={RenderStepped={Connect=function() return {Disconnect=function() end} end}},
	ReplicatedStorage=r.Instance.new("Folder") }
local renderer = luau.load(fs.readFile("src/client/controllers/ui/BuildingViewport.luau"), {environment={
	CFrame=r.CFrame, Color3=r.Color3, Instance=r.Instance, UDim2=r.UDim2, Vector3=r.Vector3,
	game={GetService=function(_, name) return services[name] end},
}})()
local small, large = renderer.cameraDistance(r.Vector3.new(10,10,10),35), renderer.cameraDistance(r.Vector3.new(20,20,20),35)
assert(math.abs(large/small-2)<.001, "Camera fitting does not scale")
local ambient, light, direction = renderer.lightingState()
local function near(a,b) return math.abs(a.R-b.R)<.001 and math.abs(a.G-b.G)<.001 and math.abs(a.B-b.B)<.001 end
assert(near(ambient,r.Color3.fromRGB(145,145,155)) and near(light,r.Color3.fromRGB(255,244,225)))
assert((direction-r.Vector3.new(-1,-1,-.65)).Magnitude<.001)
local display, shared = fs.readFile("src/client/controllers/shop/ShopController/StockDisplay.luau"), fs.readFile("src/client/controllers/ui/BuildingViewport.luau")
assert(display:find('padding%.Name = "ShopBottomPadding1"'), "Shop is missing its single bottom padding row")
assert(not display:find('ShopBottomPadding2'), "Shop still creates a second bottom padding row")
assert(display:find('padding%.Size = UDim2%.fromScale%(1, 0%.9%)'), "Shop bottom padding size changed")
assert(display:find('padding%.BackgroundTransparency = 1'), "Shop bottom padding is visible")
assert(display:find('aspect%.AspectRatio = 3'), "Shop bottom padding aspect ratio changed")
assert(not display:find("ImageID") and display:find("createBuildingViewport"))
assert(shared:find('Instance%.new%("ViewportFrame"%)') and shared:find("255, 244, 225"))
assert(shared:find("GetBoundingBox") and shared:find("RELEASE_DELAY") and shared:find("RenderStepped"))
for _, path in { "src/client/controllers/shop/SellController/Display.luau", "src/client/controllers/ui/UIController/remotes/BuildingInfo.luau",
	"src/client/controllers/ui/UIController/RebirthRewards.luau", "src/client/controllers/ui/UIController/remotes/Quests.luau" } do
	assert(fs.readFile(path):find("BuildingViewport"), path.." does not use 3D previews")
end
local satchel = fs.readFile("src/client/Satchel/Satchel/init.luau")
assert(satchel:find("tool%.TextureId") and satchel:find("ToolIcon%.Image = icon"), "Inventory icons changed")
print("PASS: shared building viewports cover shop/info/sell/rebirth/quests while inventory keeps TextureId")
