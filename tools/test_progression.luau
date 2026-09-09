-- Execute the actual tutorial state machine and code redemption against service mocks.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local function node(values)
	values = values or {}
	function values:FindFirstChild(name)
		return self[name]
	end
	function values:GetChildren()
		local result = {}
		for _, item in self do
			if type(item) == "table" and item.Name then
				table.insert(result, item)
			end
		end
		return result
	end
	return values
end
local function value(initial)
	return { Value = initial }
end
local function remote()
	return { FireClient = function() end }
end
local tutorialState = node({
	IsInTutorial = value(true),
	ServerStage = value(0),
	TutorialBankPlaced = value(false),
	NewPlayer = value(true),
	StarterBuilding = value(false),
})
local player = node({
	Name = "Test",
	UserId = 12,
	Backpack = node({}),
	Data = node({
		PlayerInfo = node({ Tutorial = tutorialState }),
		CurrentBuildings = node({}),
		CurrentConstructions = node({}),
	}),
})
local attributes = {}
function player:GetAttribute(name)
	return attributes[name]
end
function player:SetAttribute(name, v)
	attributes[name] = v
end
local events = {}
for _, name in
	{
		"ToolEquipped",
		"BankPlaced",
		"ConstructionComplete",
		"ShackConstructionStarted",
		"ShackPlaced",
		"IncomeCollect",
		"ShackPurchased",
	}
do
	events[name] = remote()
end
local guard = {
	ready = function()
		return true
	end,
}
local analytics = { Tutorial = setmetatable({}, {
	__index = function()
		return function() end
	end,
}) }
local rewards = 0
local root = {
	config = { TutorialConfig = { OwnerUserId = 1790165114, ReplayEveryJoin = true } },
	services = { ToolFactory = {} },
	persistence = { FunnelAnalytics = analytics },
	systems = { security = { RequestGuard = guard } },
}
local parent = { Parent = root.systems, PlayerRewards = {
	giveGroupReward = function()
		rewards += 1
	end,
} }
root.systems.Parent = root
local tutorial = luau.load(fs.readFile("src/server/systems/progression/TutorialSystem.luau"), {
	environment = {
		script = { Parent = parent },
		require = function(module)
			return assert(module)
		end,
		game = {
			GetService = function()
				return { Events = { Tutorial = events } }
			end,
		},
		task = {
			spawn = function(callback, ...)
				callback(...)
			end,
		},
	},
})()
assert(not tutorial.finishTutorial(player), "Client skipped authoritative stages")
tutorial.handleShackPurchase(player)
assert(tutorialState.ServerStage.Value == 0)
tutorial.handleBuildingPlacement(player, "Bank")
assert(tutorialState.ServerStage.Value == 2)
tutorial.handleConstructionComplete(player, "Bank")
assert(tutorialState.ServerStage.Value == 3)
tutorial.handleIncomeCollection(player)
assert(tutorialState.ServerStage.Value == 4)
tutorial.handleIncomeCollection(player)
assert(tutorialState.ServerStage.Value == 4)
tutorial.handleShackPurchase(player)
tutorial.handleBuildingPlacement(player, "Shack")
assert(tutorialState.ServerStage.Value == 6)
tutorial.handleConstructionComplete(player, "Shack")
assert(tutorialState.ServerStage.Value == 7, "Shack completion stranded the tutorial")
assert(tutorial.finishTutorial(player) and not tutorial.finishTutorial(player) and rewards == 1)
tutorialState.IsInTutorial.Value, tutorialState.ServerStage.Value = true, 0
player.Data.CurrentBuildings.bank = { Name = "Bank_saved-id" }
tutorial.resume(player)
assert(tutorialState.ServerStage.Value == 3, "Legacy Bank profile did not resume")
tutorialState.ServerStage.Value = 0
player.Data.CurrentConstructions.shack = { Name = "Shack_saved-id" }
tutorial.resume(player)
assert(tutorialState.ServerStage.Value == 6)

-- Owner replay resets tutorial and quest fields once per join, preserving the city.
player.Data.PlayerInfo.Quests = node({
	QuestProgression = value(5),
	PostTutorialQuestProgress = value(100),
	PostTutorialQuestComplete = value(true),
})
local ownerQuests = player.Data.PlayerInfo.Quests
-- Legacy city evidence
-- and completions from old constructions must not skip the replay.
tutorialState.IsInTutorial.Value, tutorialState.ServerStage.Value = false, 7
tutorial.prepareForJoin(player)
assert(not tutorialState.IsInTutorial.Value and tutorialState.ServerStage.Value == 7)
assert(ownerQuests.QuestProgression.Value == 5 and ownerQuests.PostTutorialQuestComplete.Value)
player.UserId = 1790165114
attributes.MyCityTutorialPrepared = nil
local originalBuildings, originalConstructions = player.Data.CurrentBuildings, player.Data.CurrentConstructions
tutorial.prepareForJoin(player)
assert(tutorialState.IsInTutorial.Value and tutorialState.ServerStage.Value == 0)
assert(
	ownerQuests.QuestProgression.Value == 0
		and ownerQuests.PostTutorialQuestProgress.Value == 0
		and not ownerQuests.PostTutorialQuestComplete.Value
)
assert(player.Data.CurrentBuildings == originalBuildings and player.Data.CurrentConstructions == originalConstructions)
tutorial.resume(player)
assert(tutorialState.ServerStage.Value == 0, "Old city evidence skipped owner replay")
tutorial.handleConstructionComplete(player, "Bank", "old")
assert(tutorialState.ServerStage.Value == 0)
tutorial.handleBuildingPlacement(player, "Bank", "new")
tutorial.handleConstructionComplete(player, "Bank", "old")
assert(tutorialState.ServerStage.Value == 2)
tutorial.handleConstructionComplete(player, "Bank", "new")
assert(tutorialState.ServerStage.Value == 3)
tutorial.prepareForJoin(player)
assert(tutorialState.ServerStage.Value == 3, "Duplicate startup reset in-session progress")
local equippedBindings = 0
player.Backpack.Bank = { Name = "Bank", Equipped = {
	Connect = function()
		equippedBindings += 1
	end,
} }
attributes.MyCityTutorialPrepared = nil
tutorial.prepareForJoin(player)
assert(tutorial.giveBankTool(player) and tutorial.giveBankTool(player))
assert(tutorialState.ServerStage.Value == 1 and equippedBindings == 1, "Replay must reuse/bind existing Bank once")
player.UserId = 12

-- Execute the real shop purchase against zero random stock: only the required
-- tutorial Shack bypasses stock, and still costs cash exactly once.
function player:WaitForChild(name)
	return self[name]
end
local tutorialCash = value(500)
player.leaderstats = node({ Cash = tutorialCash })
tutorialState.ServerStage.Value = 4
local boughtTools = 0
local buildingModule = {
	createToolWithBuilding = function()
		boughtTools += 1
		return {}
	end,
}
local services =
	node({ building = node({ BuildingSystem = buildingModule }), progression = { TutorialSystem = tutorial } })
services.Parent = { services = { QuestSignals = { emit = function() end } } }
function services:WaitForChild(name)
	return assert(self[name])
end
function services.building:WaitForChild(name)
	return assert(self[name])
end
local stock = { Shack = { Stock = 0, Cost = 100, PopulationRequired = 0, RebirthRequired = 0 } }
local shopContext = {
	State = {},
	ShopSystem = {},
	PRICE_TIERS = {},
	purchaseDebounce = {},
	playerShopStocks = { [12] = stock },
	getPlayerStats = function()
		return 0, 0
	end,
	ShopEvent = remote(),
	ReplicatedStorage = { Events = { Notifications = { BrokeAhh = remote(), ItemBought = remote() } } },
}
luau.load(fs.readFile("src/server/systems/economy/ShopSystem/Purchases.luau"), {
	environment = {
		script = { Parent = { Parent = { Parent = services } } },
		require = function(m)
			return m
		end,
		task = { spawn = function() end },
	},
})()(shopContext)
shopContext.handlePurchase(player, "Shack", "Cash")
assert(
	tutorialCash.Value == 400 and boughtTools == 1 and stock.Shack.Stock == 0 and tutorialState.ServerStage.Value == 5
)
shopContext.purchaseDebounce["12_Shack"] = nil
shopContext.handlePurchase(player, "Shack", "Cash")
assert(tutorialCash.Value == 400 and boughtTools == 1, "Stock bypass escaped tutorial purchase stage")
tutorialState.ServerStage.Value = 4
tutorialCash.Value = 0
shopContext.purchaseDebounce["12_Shack"] = nil
shopContext.handlePurchase(player, "Shack", "Cash")
assert(boughtTools == 1 and tutorialState.ServerStage.Value == 4, "Tutorial purchase bypassed cash requirement")

local record, legacy, reads, saves = {}, nil, 0, 0
local readFails, saveFails = false, false
local cash = value(0)
player.leaderstats = node({ Cash = cash })
local data = {
	getRecord = function()
		return record
	end,
	savePlayerData = function()
		saves += 1
		assert(record.CodeRedemptions and cash.Value > 0, "Reward and marker were not in the same snapshot")
		return not saveFails
	end,
}
local store = {
	GetAsync = function(_, key)
		reads += 1
		assert(key == "12_RELEASE")
		if readFails then
			error("service unavailable")
		end
		return legacy
	end,
}
local code = luau.load(fs.readFile("src/server/services/CodeSystem.luau"), {
	environment = {
		script = {
			Parent = {
				Parent = {
					persistence = { PlayerDataModule = data },
					systems = { security = { RequestGuard = guard } },
				},
			},
		},
		require = function(module)
			return module
		end,
		game = {
			GetService = function(_, name)
				if name == "DataStoreService" then
					return {
						GetDataStore = function(_, namespace)
							assert(namespace == "Codes")
							return store
						end,
					}
				end
				if name == "ReplicatedStorage" then
					return { Events = { UI = {
						WaitForChild = function()
							return {}
						end,
					} } }
				end
				return {}
			end,
		},
	},
})()
assert(not code.redeemCode(player, {}) and reads == 0)
readFails = true
assert(not code.redeemCode(player, "release") and cash.Value == 0)
readFails, legacy = false, true
assert(not code.redeemCode(player, "release") and cash.Value == 0)
legacy = nil
assert(code.redeemCode(player, "  release  ") and cash.Value == 10000 and saves == 1)
assert(not code.redeemCode(player, "RELEASE") and cash.Value == 10000)
record, saveFails = {}, true
assert(not code.redeemCode(player, "release") and cash.Value == 20000)
assert(not code.redeemCode(player, "release") and cash.Value == 20000, "Failed save duplicated a reward on retry")
print(
	"PASS: authoritative tutorial order, Shack completion, legacy progress resume, malformed/legacy code rejection, code lookup failure, atomic reward marker and retry"
)

record, saveFails, legacy = {}, false, true
player:SetAttribute("MyCityFreshStart", true)
local beforeReads = reads
assert(code.redeemCode(player, "release"))
assert(reads == beforeReads, "Fresh-start owner was blocked by old code redemption store")
assert(not code.redeemCode(player, "release"), "Fresh-start code was repeatable within one join")
print("PASS: fresh-start owner can test codes again, with one redemption per join")
