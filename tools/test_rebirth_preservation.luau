local fs = require("@lune/fs")
local luau = require("@lune/luau")
local function node(fields)
	function fields:FindFirstChild(name)
		return self[name]
	end
	function fields:WaitForChild(name)
		return assert(self[name], name)
	end
	return fields
end
local Config = luau.load(fs.readFile("src/server/systems/progression/RebirthConfig.luau"))()
local cash, rebirths, population = { Value = 98765 }, { Value = 0 }, { Value = 100 }
local protected = setmetatable({}, {
	__index = function(_, method)
		error("Rebirth touched city data: " .. method)
	end,
})
local player = node({
	leaderstats = node({ Cash = cash, Rebirths = rebirths }),
	Data = node({
		PlayerInfo = node({ Population = population }),
		CurrentBuildings = protected,
		CurrentConstructions = protected,
		Inventory = protected,
		OwnedTiles = protected,
	}),
	Backpack = protected,
	Character = protected,
})
local success, failure, refreshed, previews = 0, 0, 0, 0
local ctx = {
	State = {},
	RebirthSystem = { updateRebirthUI = function() end },
	RebirthConfig = Config,
	BuildingSystem = {
		updatePopulation = function()
			population.Value = math.floor(100 * Config.getMultipliers(rebirths.Value).population)
		end,
	},
	IncomeSystem = { calculateAndStackBuildingIncome = function() end },
	rebirthSuccess = {
		FireClient = function()
			success += 1
		end,
	},
	rebirthFailed = {
		FireClient = function()
			failure += 1
		end,
	},
	ReplicatedStorage = {
		Events = { Movement = { CleanupPreview = {
			FireClient = function()
				previews += 1
			end,
		} } },
	},
}
luau.load(fs.readFile("src/server/systems/progression/RebirthSystem/Reset.luau"))()(ctx)
luau.load(fs.readFile("src/server/systems/progression/RebirthSystem/Rebirth.luau"), {
	environment = {
		script = {
			Parent = {
				Parent = {
					Parent = node({
						economy = node({
							ShopSystem = {
								onPlayerRebirth = function()
									refreshed += 1
								end,
							},
						}),
					}),
				},
			},
		},
		require = function(module)
			return module
		end,
	},
})()(ctx)
assert(Config.canRebirth(player, 0))
ctx.RebirthSystem.performRebirth(player)
assert(cash.Value == 15000 and rebirths.Value == 1 and success == 1 and refreshed == 1 and previews == 1)
assert(
	player.Data.CurrentBuildings == protected
		and player.Data.CurrentConstructions == protected
		and player.Data.Inventory == protected
)
ctx.RebirthSystem.performRebirth(player)
assert(cash.Value == 15000 and rebirths.Value == 1 and failure == 1, "Requirements must reject an ineligible repeat")
assert(Config.getRequiredPopulation(1) == 100)
assert(Config.getRequiredPopulation(2) == 300 and Config.getRequiredPopulation(10) == 16000)
for level = 1, 400 do
	assert(Config.getRequiredPopulation(level + 1) > Config.getRequiredPopulation(level), "Requirements plateaued")
end
assert(not player.leaderstats:FindFirstChild("Population"))
print(
	"PASS: city/inventory untouched, existing cash reset, hidden population eligibility, rejected repeat and uncapped late requirements"
)
