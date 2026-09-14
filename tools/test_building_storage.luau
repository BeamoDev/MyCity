local fs, luau, r = require("@lune/fs"), require("@lune/luau"), require("@lune/roblox")
local function node(t)
	t = t or {}
	function t:FindFirstChild(k)
		return self[k]
	end
	t.WaitForChild = t.FindFirstChild
	return t
end
local function item(class, name, parent)
	local v = r.Instance.new(class)
	v.Name, v.Parent = name, parent
	return v
end
local player = item("Folder", "Owner")
local data = item("Folder", "Data", player)
local records = item("Folder", "CurrentBuildings", data)
local plot = item("Folder", "Plot1")
local buildings = item("Folder", "Buildings", plot)
local placed = item("Folder", "Placed", buildings)
local building = item("Model", "Bank_1", placed)
building:SetAttribute("BuildingType", "Bank")
building:SetAttribute("BuildingID", "1")
building:SetAttribute("RobuxBuilding", true)
local cfg = item("Folder", "Config", building)
item("IntValue", "BuildingLevel", cfg).Value = 12
item("IntValue", "BuildingXP", cfg).Value = 456
item("StringValue", "Mutation", building).Value = "Gold"
item("StringValue", "Bank_1", records).Value = "original"
local ready, stopped, creates = false, 0, 0
local tool
local api = node({
	BuildingValidation = {
		ownsBuilding = function()
			return true
		end,
	},
	BuildingXP = {
		stopBuildingXPLoop = function()
			stopped += 1
		end,
	},
	BuildingStats = { updatePlotStats = function() end },
	updatePopulation = function() end,
	BuildingStealing = {
		createToolWithBuilding = function(name, valid, level, xp)
			creates += 1
			assert(name == "Bank" and valid and level == 12 and xp == 456)
			if not ready then
				return nil
			end
			tool = item("Tool", "Bank")
			return tool
		end,
	},
})
api.Parent =
	{ Parent = node({ economy = node({ IncomeSystem = { calculateAndStackBuildingIncome = function() end } }) }) }
local event = { FireClient = function() end }
local rep = { Events = { Notifications = node({ BuildingCollected = event }), UI = { CloseBuildingInfo = event } } }
local config = luau.load(fs.readFile("src/server/systems/building/BuildingSystem/BuildingConfig.luau"), {
	environment = {
		script = { Parent = api },
		require = function(m)
			assert(m)
			return m
		end,
		game = {
			GetService = function()
				return rep
			end,
		},
		Instance = r.Instance,
	},
})()
assert(
	not config.deleteBuilding(player, building)
		and building.Parent == placed
		and records:FindFirstChild("Bank_1")
		and stopped == 0
)
ready = true
assert(
	not config.deleteBuilding(player, building) and building.Parent == placed and stopped == 0,
	"No-backpack failure destroyed original"
)
local backpack = item("Folder", "Backpack", player)
assert(config.deleteBuilding(player, building))
assert(tool.Parent == backpack and tool:GetAttribute("RobuxBuilding") == true and tool.Mutation.Value == "Gold")
assert(building.Parent == nil and not records:FindFirstChild("Bank_1") and stopped == 1)
print(
	"PASS: delete returns prepared inventory tool; failed creation/missing backpack preserves original and XP; paid/mutation/level/XP retained"
)
