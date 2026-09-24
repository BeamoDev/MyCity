local fs = require("@lune/fs")
local luau = require("@lune/luau")
local r = require("@lune/roblox")
local guard = luau.load(fs.readFile("src/server/systems/security/RequestGuard.luau"))()
local attributes = { MyCityLoaded = true }
local storage = r.Instance.new("Folder")
local function child(parent, kind, name)
	local result = r.Instance.new(kind)
	result.Name, result.Parent = name, parent
	return result
end
local backpack = child(storage, "Folder", "Backpack")
local character = child(storage, "Model", "Character")
local root = child(character, "Part", "HumanoidRootPart")
root.Position = r.Vector3.new(0, 4, 0)
local data = child(storage, "Folder", "Data")
local plotNumber = child(child(data, "Folder", "PlotInfo"), "IntValue", "Plot")
plotNumber.Value = 1
local player = { Parent = true, Character = character }
function player:GetAttribute(name)
	return attributes[name]
end
function player:FindFirstChild(name)
	return storage:FindFirstChild(name)
end
local tool = child(backpack, "Tool", "Shack")
child(tool, "StringValue", "ToolName")
child(tool, "BoolValue", "IsValid")
local plots = child(storage, "Folder", "Plots")
local plot = child(plots, "Folder", "Plot1")
local buildings = child(plot, "Folder", "Buildings")
local placed = child(buildings, "Folder", "Placed")
child(buildings, "Folder", "Construction")
local land = child(plot, "Folder", "Land")
local owned = child(land, "Folder", "Owned")
child(land, "Folder", "Locked")
local tile = child(owned, "Part", "Tile1")
tile.Position = r.Vector3.new(0, 1.15, 0)
tile.Size, tile.CFrame = r.Vector3.new(5, 0.2, 5), r.CFrame.new(0, 1.15, 0)
local assets = child(storage, "Folder", "Assets")
local template = child(child(assets, "Folder", "Buildings"), "Model", "Shack")
local base = child(template, "Part", "Base")
base.Size = r.Vector3.new(2, 0.2, 2)
template.PrimaryPart = base
local overlap = {}
local range = luau.load(fs.readFile("src/shared/util/PlacementRange.luau"), { environment = { Vector3 = r.Vector3 } })()
local rules = luau.load(fs.readFile("src/shared/util/PlacementRules.luau"), { environment = { Vector3 = r.Vector3 } })()
local services = {
	Workspace = {
		Plots = plots,
		GetPartBoundsInBox = function()
			return overlap
		end,
	},
	ReplicatedStorage = { Assets = {}, shared = { util = { PlacementRange = range, PlacementRules = rules } } },
	ServerStorage = assets,
}
local validation = luau.load(fs.readFile("src/server/systems/building/BuildingSystem/BuildingValidation.luau"), {
	environment = {
		script = { Parent = { Parent = { Parent = { security = { RequestGuard = guard } } } } },
		require = function(module)
			return module
		end,
		game = {
			GetService = function(_, name)
				return assert(services[name])
			end,
		},
		Vector3 = r.Vector3,
		Enum = r.Enum,
		OverlapParams = {
			new = function()
				return {}
			end,
		},
	},
})()
local position = r.CFrame.new(0, 1.25, 0)
assert(validation.placement(player, position, tool), "Valid owned placement rejected")
root.Position = r.Vector3.new(100, 4, 0)
assert(not validation.placement(player, position, tool), "Remote accepted placement from outside plot range")
root.Position = r.Vector3.new(0, 4, 0)
-- Base and PrimaryPart may be different authored parts; height follows Base.
local primary = child(template, "Part", "AuthoredPivot")
primary.CFrame = r.CFrame.new(0, 2, 0)
template.PrimaryPart = primary
assert(validation.placement(player, r.CFrame.new(0, 3.25, 0), tool), "Valid offset PrimaryPart placement rejected")
assert(not validation.placement(player, r.CFrame.new(0, 5.25, 0), tool), "Offset model floated above land")
template.PrimaryPart = base
assert(not validation.placement(player, "bad", tool))
assert(not validation.placement(player, r.CFrame.new(2.2, 1.25, 0), tool), "Footprint outside owned land accepted")
assert(not validation.placement(player, r.CFrame.new(0, 8, 0), tool), "Floating placement accepted")
assert(not validation.placement(player, position * r.CFrame.Angles(0.2, 0, 0), tool), "Tilted building accepted")
tool.Parent = assets
assert(not validation.placement(player, position, tool), "Unowned/template tool accepted")
tool.Parent = backpack
local building = child(placed, "Model", "Owned")
building:SetAttribute("BuildingID", "id")
assert(validation.ownsBuilding(player, building))
building.Parent = storage
assert(not validation.ownsBuilding(player, building), "Foreign building accepted")
local occupant = child(placed, "Model", "Occupant")
local occupantBase = child(occupant, "Part", "Base")
occupantBase.Size, occupantBase.CFrame = r.Vector3.new(2, 0.2, 2), r.CFrame.new(0.5, 1.25, 0.5)
local ok, reason = validation.placement(player, position, tool)
assert(not ok and reason == "Overlap", "Occupied placement accepted")
occupant.Parent = storage
local ran = 0
assert(guard.run(player, "test", function()
	ran += 1
	assert(not guard.run(player, "nested", function()
		error("Concurrent mutation")
	end))
	return true
end))
assert(not guard.run(player, "test", function()
	ran += 1
end))
attributes.MyCityLeaving = true
assert(not guard.run(player, "different", function()
	ran += 1
end))
assert(ran == 1)
print(
	"PASS: valid placement, forged tools, malformed/tilted/floating/out-of-bounds/occupied placement, foreign building, mutation serialization, rate limit, leaving player"
)

-- Regression (player report): flush against a corner next to buyable land used to be refused because
-- the expansion sign / locked scenery inside Land.Locked overhangs onto owned land.
attributes.MyCityLeaving = nil
local locked = land.Locked
local lockedTile = child(locked, "Part", "Tile2")
lockedTile.Size, lockedTile.CFrame = r.Vector3.new(5, 0.2, 5), r.CFrame.new(5, 1.15, 0)
local sign = child(lockedTile, "Part", "ExpansionPrompt")
sign.Size, sign.CFrame = r.Vector3.new(7, 4, 7), r.CFrame.new(5, 3.15, 0)
local scenery = child(lockedTile, "Part", "LockedScenery")
scenery.Size, scenery.CFrame = r.Vector3.new(3, 3, 3), r.CFrame.new(2.5, 2, 2.5)
local corner = r.CFrame.new(1.5, 1.25, 1.5) -- 2x2 footprint flush with the tile's +X/+Z corner
assert(validation.placement(player, corner, tool), "Corner placement beside locked land was refused")
assert(validation.placement(player, corner * r.CFrame.Angles(0, math.rad(90), 0), tool), "Rotated corner refused")
ok, reason = validation.placement(player, r.CFrame.new(1.6, 1.25, 1.5), tool)
assert(not ok and reason == "OutsideLand", "Footprint over locked land accepted")
-- Buildings may sit flush against each other, or with float noise, but not overlap.
occupant.Parent = placed
occupantBase.CFrame = r.CFrame.new(-0.5, 1.25, 1.5)
assert(validation.placement(player, corner, tool), "Flush neighbour refused")
occupantBase.CFrame = r.CFrame.new(-0.47, 1.25, 1.5)
assert(validation.placement(player, corner, tool), "Float-noise touch refused")
occupantBase.CFrame = r.CFrame.new(-0.2, 1.25, 1.5)
ok, reason = validation.placement(player, corner, tool)
assert(not ok and reason == "Overlap", "Overlapping neighbour accepted")
-- Hitboxes, decorations and construction sites: only Base footprints block.
occupantBase.CFrame = r.CFrame.new(-3, 1.25, 1.5)
local wideHitbox = child(occupant, "Part", "Hitbox")
wideHitbox.Size, wideHitbox.CFrame = r.Vector3.new(6, 8, 6), r.CFrame.new(-2, 5, 1.5)
assert(validation.placement(player, corner, tool), "Neighbour's Hitbox overhang blocked placement")
local site = child(buildings.Construction, "Model", "Site")
local siteBase = child(site, "Part", "Base")
siteBase.Size, siteBase.CFrame = r.Vector3.new(2, 0.2, 2), r.CFrame.new(1, 1.25, 1)
ok, reason = validation.placement(player, corner, tool)
assert(not ok and reason == "Overlap", "Construction site ignored")
print("PASS: corner/edge beside locked land with overhanging signs/scenery, flush and float-noise neighbours, Hitbox overhang ignored, construction overlap, reasons")

-- Range is measured from tile edges, including vertical distance and expanded land.
assert(range.isNear(r.Vector3.new(26, 1.15, 0), plot))
assert(not range.isNear(r.Vector3.new(27, 1.15, 0), plot))
assert(not range.isNear(r.Vector3.new(0, 100, 0), plot))
assert(not range.isNear(r.Vector3.zero, nil))
local extra = child(owned, "Part", "ExpandedLand")
extra.Size = r.Vector3.new(20, 0.2, 20)
extra.CFrame = r.CFrame.new(100, 1.15, 0)
assert(range.isNear(r.Vector3.new(115, 3, 0), plot), "Range used the plot center instead of owned land")
local notices = 0
local notification = {
	showNotification = function(_, message)
		assert(message:find("Too far", 1, true))
		notices += 1
	end,
}
local access = luau.load(
	fs.readFile("src/client/controllers/placement/PlacementAccess.luau"),
	{
		environment = {
			game = {
				GetService = function()
					return services.ReplicatedStorage
				end,
			},
			script = { Parent = { Parent = { ui = { NotificationController = notification } } } },
			require = function(module)
				return module
			end,
		},
	}
)()
function player:FindFirstChild(name)
	if name == "Backpack" then
		return backpack
	end
	return storage:FindFirstChild(name)
end
root.Position = r.Vector3.new(0, 4, 200)
tool.Parent = character
assert(
	not access.check(player, plot, tool) and tool.Parent == backpack and notices == 1,
	"Far equip was not rejected and notified"
)
assert(not access.check(player, plot, tool) and notices == 1, "Repeated equip spammed distance notices")
root.Position = r.Vector3.new(0, 4, 0)
tool.Parent = character
assert(access.check(player, plot, tool) and tool.Parent == character)
print(
	"PASS: plot-edge/vertical/expansion range, distant equip returns tool to Backpack, throttled notice and nearby equip"
)
