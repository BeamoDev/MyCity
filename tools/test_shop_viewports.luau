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
assert(display:find('tonumber%(item%.ImageID%)'), "Shop does not validate ImageId")
assert(display:find('imageId and imageId > 0'), "Valid ImageIds no longer use authored icons")
assert(display:find('Context%.createBuildingViewport%(frame, item%.Name%)'), "Missing ImageIds have no viewport fallback")
assert(display:find('Context%.clearViewportPreviews%(%)'), "Shop refresh does not release old previews")
assert(display:find('padding%.Name = "ShopBottomPadding1"'), "Final shop card can be clipped")
assert(shared:find('Instance%.new%("ViewportFrame"%)') and shared:find("255, 244, 225"))
assert(shared:find("GetBoundingBox") and shared:find("RELEASE_DELAY") and shared:find("RenderStepped"))
for _, path in { "src/client/controllers/shop/SellController/Display.luau", "src/client/controllers/ui/UIController/remotes/BuildingInfo.luau",
	"src/client/controllers/ui/UIController/RebirthRewards.luau", "src/client/controllers/ui/UIController/remotes/Quests.luau" } do
	assert(not fs.readFile(path):find("BuildingViewport"), path.." unexpectedly uses 3D previews")
end
local satchel = fs.readFile("src/client/Satchel/Satchel/init.luau")
assert(satchel:find("tool%.TextureId") and satchel:find("ToolIcon%.Image = icon"), "Inventory icons changed")
assert(satchel:find('tool:GetAttribute%("DisplayName"%) or tool%.Name'), "Missing-image toolbar has no player-facing name")
print("PASS: shop uses image-first viewport fallback while inventory keeps icons/text")
