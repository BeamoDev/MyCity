local fs = require("@lune/fs")
local luau = require("@lune/luau")
local r = require("@lune/roblox")
local function load(path, env)
	return luau.load(fs.readFile(path), { environment = env or {} })()
end
local function node(t)
	t = t or {}
	function t:FindFirstChild(name)
		return self[name]
	end
	function t:WaitForChild(name)
		return assert(self[name], name)
	end
	function t:GetChildren()
		local result = {}
		for _, value in self do
			if type(value) == "table" then
				table.insert(result, value)
			end
		end
		return result
	end
	return t
end
local function signal()
	local callbacks = {}
	return {
		Connect = function(_, fn)
			table.insert(callbacks, fn)
			return { Disconnect = function() end }
		end,
		Fire = function(_, ...)
			for _, fn in callbacks do
				fn(...)
			end
		end,
	}
end
local function remote()
	return {
		OnServerEvent = signal(),
		OnClientEvent = signal(),
		calls = {},
		FireClient = function(self, ...)
			table.insert(self.calls, { ... })
			self.OnClientEvent:Fire(select(2, ...))
		end,
	}
end
local config = {}
for _, name in { "Decorations", "Starter", "Population", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" } do
	local entries = load("src/server/config/BuildingConfig/" .. name .. ".luau")
	for key, value in entries do
		config[key] = value
	end
end
local tools, failTool = {}, false
local factory = {
	create = function(name)
		assert(config[name], "Missing reward building " .. name)
		if failTool then
			return nil
		end
		local tool = {
			Name = name,
			SetAttribute = function(self, key, value)
				self[key] = value
			end,
			Destroy = function(self)
				self.destroyed = true
			end,
		}
		table.insert(tools, tool)
		return tool
	end,
}
local stats = node({ Cash = { Value = 0 }, Rebirths = { Value = 0 } })
local questValues = node({
	QuestProgression = { Value = 0 },
	PostTutorialQuestProgress = { Value = 0 },
	PostTutorialQuestComplete = { Value = false },
})
local tutorial = node({ IsInTutorial = { Value = false }, ServerStage = { Value = 0 } })
local daily = node({ CurrentCycle = { Value = 1 }, LastClaimTime = { Value = 0 }, CurrentStreak = { Value = 77 } })
for i = 1, 7 do
	daily["Day" .. i] = { Value = false }
end
local player = node({
	UserId = 7,
	Parent = true,
	Backpack = {},
	leaderstats = stats,
	Data = node({
		PlotInfo = node({ Plot = { Value = 1 } }),
		PlayerInfo = node({
			Quests = questValues,
			Tutorial = tutorial,
			Population = { Value = 100 },
			DailyRewards = daily,
		}),
	}),
	GetAttribute = function()
		return false
	end,
})
local placed = node({})
local plot = node({ Buildings = node({ Placed = placed }) })
local questEvents = node({ UpdateQuest = remote(), QuestComplete = remote(), AllQuestsDone = remote() })
local events = node({ PostTutorialQuest = questEvents })
local root = { services = { ToolFactory = factory } }
local questScript = node({ Parent = { Parent = { Parent = root } } })
local context
local modules = {}
for _, name in { "State", "Progression", "Objectives" } do
	local install = load("src/server/systems/progression/PostTutorialQuest/" .. name .. ".luau", {
		script = { Parent = questScript },
		require = function(module)
			return module
		end,
		task = {
			defer = function(fn)
				fn()
			end,
		},
	})
	modules[name] = function(c)
		context = c
		install(c)
	end
end
modules.Lifecycle = function() end
for k, v in modules do
	questScript[k] = v
end
local quest = load("src/server/systems/progression/PostTutorialQuest/init.luau", {
	script = questScript,
	require = function(module)
		return module
	end,
	game = {
		GetService = function(_, name)
			if name == "ReplicatedStorage" then
				return node({ Events = events })
			end
			if name == "Workspace" then
				return { Plots = node({ Plot1 = plot }) }
			end
			return {}
		end,
	},
})
local function building(name, id)
	return {
		GetAttribute = function(_, key)
			return if key == "BuildingType" then name else id
		end,
	}
end
context.loadState(player)
quest.onIncomeCollected(player)
assert(stats.Cash.Value == 500 and questValues.QuestProgression.Value == 1)
quest.onConstructionStarted(player, "Bank")
assert(questValues.PostTutorialQuestProgress.Value == 0, "Unfinished construction counted")
local bank = building("Bank", "one")
quest.onBuildingPlaced(player, bank)
quest.onBuildingPlaced(player, bank)
assert(questValues.PostTutorialQuestProgress.Value == 1, "Duplicate building counted")
quest.onBuildingPlaced(player, building("Shack", "two"))
quest.onBuildingPlaced(player, building("Bank", "three"))
assert(stats.Cash.Value == 1500 and questValues.QuestProgression.Value == 2)
for i = 1, 8 do
	placed["house" .. i] = building("Shack", "h" .. i)
end
for i = 1, 5 do
	placed["road" .. i] = building("StraightRoad", "r" .. i)
end
quest.onBuildingPlaced(player, placed.house8)
assert(questValues.PostTutorialQuestComplete.Value and questValues.QuestProgression.Value == 5)
assert(stats.Cash.Value == 3500 and #tools == 2 and tools[1].Name == "SheriffOffice" and tools[2].Name == "Apartments")
context.loadState(player)
context.updateUI(player)
assert(
	questEvents.AllQuestsDone.calls[#questEvents.AllQuestsDone.calls][2] == true,
	"Completed rejoin must hide quest UI"
)
questValues.PostTutorialQuestComplete.Value = false
context.loadState(player)
assert(questValues.PostTutorialQuestComplete.Value, "Legacy completion flag not repaired")
-- Reward failure at an already-complete objective is retryable without new progress.
questValues.QuestProgression.Value, questValues.PostTutorialQuestProgress.Value, questValues.PostTutorialQuestComplete.Value =
	2, 8, false
context.loadState(player)
failTool = true
assert(context.recalculateProgress(player))
context.completeQuest(player)
assert(questValues.QuestProgression.Value == 2)
failTool = false
assert(context.recalculateProgress(player))
context.completeQuest(player)
assert(questValues.PostTutorialQuestComplete.Value)
print(
	"PASS: all five quests, exact rewards, duplicate milestones, deferred reward recovery and completed/legacy rejoin"
)

local now = 1000000
local dailyEvents = { ClaimReward = remote(), UpdateUI = remote(), RequestUpdate = remote() }
local dailyRoot = {
	security = { RequestGuard = {
		ready = function()
			return true
		end,
	} },
	building = node({ BuildingSystem = { createToolWithBuilding = factory.create } }),
}
local dailySystem = load("src/server/systems/progression/DailyRewards.luau", {
	script = { Parent = { Parent = node(dailyRoot) } },
	require = function(module)
		return module
	end,
	os = {
		time = function()
			return now
		end,
	},
	game = {
		GetService = function(_, name)
			return if name == "ReplicatedStorage" then node({ Events = { DailyRewards = dailyEvents } }) else {}
		end,
	},
})
local cashBefore, toolsBefore = stats.Cash.Value, #tools
for day = 1, 7 do
	assert(daily.CurrentCycle.Value == day)
	if day == 3 then
		local backpack = player.Backpack
		player.Backpack = nil
		local stamp = daily.LastClaimTime.Value
		assert(not dailySystem.claimReward(player) and daily.LastClaimTime.Value == stamp)
		player.Backpack = backpack
	end
	assert(dailySystem.claimReward(player))
	assert(daily.CurrentStreak.Value == day)
	assert(not dailySystem.claimReward(player), "Daily duplicate claim granted")
	dailySystem.updatePlayerUI(player)
	now += 86399
	assert(not dailySystem.claimReward(player), "Claim before 24h granted")
	now += 1
end
assert(stats.Cash.Value - cashBefore == 140000 and #tools - toolsBefore == 3)
assert(daily.CurrentCycle.Value == 1 and not daily.Day7.Value)
now += 172801
assert(dailySystem.claimReward(player) and daily.CurrentStreak.Value == 1, "Missed-day streak did not reset")
print(
	"PASS: all seven daily rewards, exact cash/tools, 24h boundaries, missing backpack, cycle rollover and missed-day streak"
)

-- Every catalog entry has a cash and mapped Robux purchase path.
local productConfig = load("src/server/services/MarketPlaceHandler/ProductConfig.luau")
local shopEvent = remote()
local priceMap = {
	[7] = 3375058573,
	[15] = 3375058621,
	[25] = 3375058684,
	[40] = 3375058756,
	[75] = 3375058850,
	[150] = 3375058936,
	[300] = 3375061785,
}
local prompted = {}
local intents = {
	prompt = function(_, id, details)
		assert(productConfig.Shop[id])
		table.insert(prompted, details.Name)
		return true
	end,
}
local questMetrics = {}
local shopRoot = {
	services = {
		QuestSignals = {
			emit = function(_, metric, amount)
				questMetrics[metric] = (questMetrics[metric] or 0) + amount
			end,
		},
		MarketPlaceHandler = { PurchaseIntents = intents },
	},
}
local shopSystems = node({
	Parent = shopRoot,
	building = node({ BuildingSystem = { createToolWithBuilding = factory.create } }),
	progression = { TutorialSystem = { handleShackPurchase = function() end } },
})
local shop = {
	State = {},
	ShopSystem = {},
	PRICE_TIERS = priceMap,
	playerShopStocks = { [7] = {} },
	purchaseDebounce = {},
	ShopEvent = shopEvent,
	ReplicatedStorage = {
		Events = { Notifications = { BrokeAhh = remote(), ItemBought = remote(), ErrorEvent = remote() } },
	},
	getPlayerStats = function()
		return 1000, 1e12
	end,
}
load("src/server/systems/economy/ShopSystem/Purchases.luau", {
	script = { Parent = { Parent = { Parent = shopSystems } } },
	require = function(module)
		return module
	end,
	task = { spawn = function() end },
})(shop)
local catalogCount = 0
for name, definition in config do
	catalogCount += 1
	local item = { Cost = definition.Cost, Stock = 1, PopulationRequired = 0, RebirthRequired = 0 }
	shop.playerShopStocks[7][name] = item
	stats.Cash.Value = definition.Cost + 100
	local previousPurchases = questMetrics.purchase or 0
	local previousSpend = questMetrics.spend or 0
	shop.purchaseDebounce = shop.purchaseDebounce -- installer retains this table
	table.clear(shop.purchaseDebounce)
	assert(shop.ShopSystem.purchase(player, name, "Cash") == true and stats.Cash.Value == 100 and item.Stock == 0)
	assert(
		questMetrics.purchase == previousPurchases + 1 and questMetrics.spend == previousSpend + definition.Cost,
		"Cash purchase did not report exact quest progress"
	)
	table.clear(shop.purchaseDebounce)
	assert(shop.ShopSystem.purchase(player, name, "Robux") == true)
end
local countBefore = #tools
table.clear(shop.purchaseDebounce)
local item = shop.playerShopStocks[7].Shack
item.Stock = 0
shop.ShopSystem.purchase(player, "Shack", "Cash")
assert(#tools == countBefore)
item.Stock, item.RebirthRequired = 1, 2000
table.clear(shop.purchaseDebounce)
shop.ShopSystem.purchase(player, "Shack", "Cash")
assert(#tools == countBefore, "Locked cash purchase granted")
item.RebirthRequired = 0
stats.Cash.Value = 0
table.clear(shop.purchaseDebounce)
shop.ShopSystem.purchase(player, "Shack", "Cash")
assert(#tools == countBefore, "Unaffordable purchase granted")
assert(not shop.ShopSystem.purchase(player, {}, "Cash"))
for _, product in productConfig.Rewards do
	for _, name in product.rewards.buildings or {} do
		assert(config[name], name)
	end
end
print(
	"PASS: "
		.. catalogCount
		.. " catalog entries cash deduction/stock/tool and mapped Robux prompt; locks, empty stock, insufficient cash, malformed input, bundle reward names"
)

local planModule = load("src/server/services/MarketPlaceHandler/GrantPlan.luau", {
	script = { Parent = { ProductConfig = productConfig } },
	require = function(module)
		return module
	end,
})
local skipped, refreshed = 0, 0
local grantRoot = {
	systems = {
		construction = {
			ConstructionSystem = {
				skipConstruction = function()
					skipped += 1
					return true
				end,
			},
		},
		economy = { ShopSystem = {
			resetPlayerShop = function()
				refreshed += 1
			end,
		} },
		security = { RequestGuard = {
			ready = function()
				return true
			end,
		} },
	},
}
local grantParent =
	{ Parent = { Parent = grantRoot, ToolFactory = factory, ToolSerialization = {} }, TransferService = {} }
local actions = load("src/server/services/MarketPlaceHandler/GrantActions.luau", {
	script = { Parent = grantParent },
	require = function(module)
		return module
	end,
})
for name, definition in config do
	local id = priceMap[shop.getPriceTier(definition.Cost)]
	local plan = planModule.create(
		player,
		id,
		{ PurchaseIntents = { [tostring(id)] = { Details = { Kind = "Building", Name = name } } } }
	)
	assert(plan and #plan == 1 and plan[1].Name == name)
	assert(actions.apply(player, plan[1], "receipt"))
	assert(tools[#tools].RobuxBuilding == true and tools[#tools].Parent == player.Backpack)
end
for id, product in productConfig.Rewards do
	local beforeCash, beforeTools = stats.Cash.Value, #tools
	local plan = assert(planModule.create(player, id, {}))
	for _, step in plan do
		assert(actions.apply(player, step, "bundle"))
	end
	assert(stats.Cash.Value - beforeCash == (product.rewards.cash or 0))
	assert(#tools - beforeTools == #(product.rewards.buildings or {}))
end
player.Data.CurrentConstructions = node({})
assert(actions.apply(player, { Kind = "Skip", Identifier = "finished" }, "skip"))
player.Data.CurrentConstructions.active = {}
assert(actions.apply(player, { Kind = "Skip", Identifier = "active" }, "skip"))
assert(skipped == 1)
assert(actions.apply(player, { Kind = "Refresh" }, "refresh") and refreshed == 1)
assert(not planModule.create(player, 999, {}))
assert(not planModule.create(player, 3375058573, {}), "Ambiguous paid target must not guess a building")
print(
	"PASS: all 82 Robux building grant plans/actions, every configured cash/building bundle, finished/active skips, refresh dispatch and unknown/missing-intent rejection"
)

-- The latest quest snapshot wins over all earlier delayed completion effects.
local delayed = {}
local label = {}
local ui = node({ Visible = false, Parent = true, QuestTitle = label, ProgressBar = node({ FillBar = {} }) })
local questPositionGoal
local notificationCenter = {}
local notificationPositionGoal
local questVisibleChanged = signal()
function ui:GetPropertyChangedSignal()
	return questVisibleChanged
end
local tutorialChanged = signal()
function tutorial.IsInTutorial:GetPropertyChangedSignal()
	return tutorialChanged
end
local clientContext = {
	Transitions = {
		cancel = function() end,
		immediate = function(object, visible)
			object.Visible = visible
		end,
		show = function(object, visible)
			object.Visible = visible
		end,
	},
	State = { questUI = ui, playerGui = node({ NotificationCenter = notificationCenter }) },
	questEvents = questEvents,
	player = player,
	UIController = { flashScreen = function() end },
	TweenService = {
		Create = function(_, target, _, goal)
			if target == notificationCenter then
				notificationPositionGoal = goal.Position
			elseif goal.Position then
				questPositionGoal = goal.Position
			end
			return { Play = function() end, Cancel = function() end }
		end,
	},
	connections = {
		connect = function(_, event, fn)
			return event:Connect(fn)
		end,
		delay = function(_, _, fn)
			table.insert(delayed, fn)
		end,
	},
}
load("src/client/controllers/ui/UIController/remotes/Quests.luau", {
	Enum = r.Enum,
	game = {
		GetService = function()
			return node({})
		end,
	},
	Color3 = r.Color3,
	UDim2 = r.UDim2,
	TweenInfo = {
		new = function()
			return {}
		end,
	},
})(clientContext)
clientContext.connectQuests()
assert(notificationCenter.Position == r.UDim2.fromScale(0.5, 0.15))
tutorial.IsInTutorial.Value = true
questEvents.UpdateQuest.OnClientEvent:Fire("Buffered quest", 0, 1, 1, 5, { type = "cash", amount = 500 })
assert(not ui.Visible)
tutorial.IsInTutorial.Value = false
tutorialChanged:Fire()
questVisibleChanged:Fire()
assert(notificationPositionGoal == r.UDim2.fromScale(0.5, 0.28), "Notifications must move below visible quests")
assert(questPositionGoal == r.UDim2.fromScale(0.5, 0.21), "Quest panel did not tween to requested position")
assert(ui.Visible and label.Text:find("Buffered quest", 1, true), "Tutorial replication race discarded quest snapshot")
questEvents.QuestComplete.OnClientEvent:Fire()
questEvents.UpdateQuest.OnClientEvent:Fire("New quest", 1, 3, 2, 5, { type = "cash", amount = 1000 })
assert(label.Text:find("New quest", 1, true))
questEvents.AllQuestsDone.OnClientEvent:Fire(false)
questEvents.UpdateQuest.OnClientEvent:Fire("Latest quest", 1, 3, 2, 5, { type = "cash", amount = 1000 })
for _, fn in delayed do
	fn()
end
assert(ui.Visible and label.Text:find("Latest quest", 1, true))
questEvents.AllQuestsDone.OnClientEvent:Fire(true)
questVisibleChanged:Fire()
assert(notificationPositionGoal == r.UDim2.fromScale(0.5, 0.15), "Notifications must return after quests hide")
assert(not ui.Visible)
print("PASS: quest HUD without optional reward section, latest snapshot wins, completed rejoin hides UI")

-- Accrue elapsed whole seconds without discarding fractional scheduling delay.
local clock, elapsedTotal, updates = 0, 0, 0
local incomePlayer = {
	FindFirstChild = function()
		return {}
	end,
	GetAttribute = function(_, name)
		return name == "MyCityLoaded"
	end,
}
local income = {
	State = {},
	IncomeSystem = {
		calculateAndStackBuildingIncome = function(_, seconds)
			elapsedTotal += seconds
			updates += 1
		end,
		calculatePopulation = function() end,
	},
	Players = {
		GetPlayers = function()
			return { incomePlayer }
		end,
	},
}
load(
	"src/server/systems/economy/IncomeSystem/Lifecycle.luau",
	{ os = {
		clock = function()
			return clock
		end,
	}, task = { wait = coroutine.yield } }
)(income)
local loop = coroutine.create(income.updateIncomeAndPopulationForAllPlayers)
assert(coroutine.resume(loop))
for _, timestamp in { 1.2, 2.4, 5.9, 6.1 } do
	clock = timestamp
	assert(coroutine.resume(loop))
end
assert(elapsedTotal == 6 and updates == 5, "Scheduler lag lost income")
coroutine.close(loop)
print("PASS: delayed income loop pays elapsed time and preserves sub-second remainder")
