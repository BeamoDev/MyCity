local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function node(children)
	children = children or {}
	function children:FindFirstChild(name)
		return self[name]
	end
	children.WaitForChild = children.FindFirstChild
	return children
end

local resets = 0
local cash = { Value = 10 }
local plot = node()
local player = node({ UserId = 123, Data = node({ PlotInfo = node({ Plot = { Value = 1 } }) }) })
local context = {
	State = {},
	IncomeSystem = { calculateAndStackBuildingIncome = function() return 100 end },
	Workspace = { Plots = node({ Plot1 = plot }) },
	ReplicatedStorage = {},
	TweenService = {},
	collectIncomeEvent = {},
	errorEvent = { FireClient = function() error("Unexpected error notification") end },
	buttonDebounces = {},
	plotOwners = { [1] = player },
	hasDoubleCashGamepass = function() return false end,
}
luau.load(fs.readFile("src/server/systems/economy/IncomeSystem/Collection.luau"))()(context)
context.IncomeSystem.resetBuildingIncome = function() resets += 1 end
assert(context.IncomeSystem.collectPendingIncome(player) == false and resets == 0)
context.handleIncomeCollection(player, 1)
assert(resets == 0 and context.buttonDebounces["123_collection"] == false)
player.leaderstats = node({ Cash = cash })
context.IncomeSystem.collectPendingIncome(player)
assert(cash.Value == 110 and resets == 1, "Pending income was not credited exactly once")

local destroyed, errorText = false, nil
local tool = node({ Name = "Bank" })
function tool:Destroy() destroyed = true end
local character = { FindFirstChildWhichIsA = function() return tool end }
local seller = node({ Character = character })
local buildingConfig = { Bank = { Cost = 50 } }
local sale = luau.load(fs.readFile("src/server/systems/economy/SellSystem/Sale.luau"), {
	environment = {
		script = { Parent = { Parent = { Parent = { Parent = node({ config = node({ BuildingConfig = buildingConfig }) }) } } } },
		require = function(module) return module end,
	},
})()
local sellSystem = {
	canSellTool = function() return true end,
	calculateSellValue = function() return 75 end,
}
sale({
	State = {}, SellSystem = sellSystem,
	ReplicatedStorage = {},
	SellEvents = { ErrorEvent = { FireClient = function(_, _, message) errorText = message end } },
})
assert(sellSystem.sellBuilding(seller, "Bank") == false)
assert(not destroyed and errorText, "Sale consumed a building without a Cash destination")
print("PASS: unavailable Cash preserves income and equipped sale tool; valid pending income credits once")
