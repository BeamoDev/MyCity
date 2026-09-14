local fs, luau, serde = require("@lune/fs"), require("@lune/luau"), require("@lune/serde")
local function load(path, env)
	return luau.load(fs.readFile(path), { environment = env })()
end
local function node(t)
	function t:FindFirstChild(key)
		return self[key]
	end
	return t
end
local record, durable, grants, outcome = {}, {}, 0, "missing"
local snapshot = { Name = "Bank", BuildingLevel = 12, BuildingXP = 99, IsValid = true, RobuxBuilding = true }
local player = node({ UserId = 7, Backpack = {}, leaderstats = node({ Cash = { Value = 0 } }) })
local guard = {
	ready = function()
		return true
	end,
	run = function(_, _, fn)
		return fn()
	end,
}
local data = {
	isLoaded = function()
		return true
	end,
	getRecord = function()
		return record
	end,
	savePlayerData = function()
		durable = serde.decode("json", serde.encode("json", record))
		return true
	end,
}
local root = {
	persistence = { PlayerDataModule = data },
	systems = {
		security = { RequestGuard = guard },
		construction = { ConstructionSystem = {} },
		economy = { ShopSystem = {} },
	},
}
local services = {
	Parent = root,
	ToolFactory = {},
	ToolSerialization = {
		decode = function(descriptor)
			assert(
				descriptor.Name == "Bank"
					and descriptor.BuildingLevel == 12
					and descriptor.BuildingXP == 99
					and descriptor.RobuxBuilding
			)
			grants += 1
			return {}
		end,
	},
}
local handler = { Parent = services, TransferService = {
	take = function()
		return nil, outcome
	end,
} }
local env = {
	script = { Parent = handler },
	require = function(m)
		assert(m)
		return m
	end,
}
local actions = load("src/server/services/MarketPlaceHandler/GrantActions.luau", env)
local ledger = load("src/server/services/MarketPlaceHandler/ReceiptLedger.luau", env)
local step = { Kind = "Steal", OwnerId = 8, Snapshot = snapshot }
local receipt = { PurchaseId = "missing-paid-steal", ProductId = 1 }
local function plan()
	return { step }
end
outcome = "unavailable"
assert(
	not ledger.process(player, receipt, plan, actions.apply) and grants == 0,
	"Lease/service failure granted compensation"
)
outcome = "missing"
assert(ledger.process(player, receipt, plan, actions.apply) and grants == 1)
assert(ledger.process(player, receipt, plan, actions.apply) and grants == 1, "Compensation duplicated")
assert(durable.Receipts[receipt.PurchaseId].Complete and durable.Receipts[receipt.PurchaseId].Plan == nil)
assert(
	not actions.apply(player, { Kind = "Steal", OwnerId = 8 }, "legacy") and grants == 1,
	"Legacy missing snapshot invented a reward"
)
local unknown = { PurchaseId = "unknown-target", ProductId = 2 }
assert(not ledger.process(player, unknown, function()
	return nil
end, actions.apply))
assert(durable.PendingReceipts["2"] == "unknown-target", "Ambiguity was not persisted")
local products = { Rewards = {}, Shop = { [2] = true }, Skip = {}, Steal = 1 }
handler.ProductConfig = products
local plans = load("src/server/services/MarketPlaceHandler/GrantPlan.luau", env)
record.PurchaseIntents = { ["2"] = { Details = { Kind = "Building", Name = "Bank" } } }
assert(plans.create(player, 2, record) == nil, "Ambiguous historical receipt consumed a newer target")
print(
	"PASS: unavailable target stays pending, confirmed missing target compensation, preserved metadata, replay-once, compact completion and durable ambiguous-target block"
)
