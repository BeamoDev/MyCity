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
local step = { Kind = "Steal", OwnerId = 8, Snapshot = snapshot, Created = os.time() }
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
-- A steal blocked by the owner's lease/server past the grace period delivers the snapshot once.
local blocked = { Kind = "Steal", OwnerId = 8, Snapshot = snapshot, Created = os.time() - 601 }
outcome = "unavailable"
assert(actions.apply(player, blocked, "overdue") and grants == 2, "Overdue blocked steal stayed pending")
print(
	"PASS: unavailable target stays pending within grace, confirmed missing and overdue blocked targets compensate once, preserved metadata, compact completion"
)

local products = { Rewards = {}, Shop = { [2] = true }, Skip = {}, Steal = 1 }
handler.ProductConfig = products
root.systems.economy.ShopSystem.compensationBuilding = function(productId)
	return if productId == 2 then "Mansion" else nil
end
local plans = load("src/server/services/MarketPlaceHandler/GrantPlan.luau", env)
record = {
	PurchaseIntents = { ["2"] = { Details = { Kind = "Building", Name = "Bank" } } },
	IntentArchive = { ["2"] = { { Details = { Kind = "Building", Name = "Hotel" }, Created = os.time() } } },
}
-- 1. The open prompt's choice, bound to this receipt when the ledger records it.
local chosen, consume = plans.create(player, 2, record, "r1")
assert(chosen[1].Name == "Bank")
consume()
assert(record.PurchaseIntents["2"].PurchaseId == "r1")
assert(plans.create(player, 2, record, "r1")[1].Name == "Bank", "Retry of the bound receipt lost its target")
-- 2. Another receipt cannot reuse it; it takes the archived (replaced) choice instead.
chosen, consume = plans.create(player, 2, record, "r2")
assert(chosen[1].Name == "Hotel")
consume()
assert(#record.IntentArchive["2"] == 0, "Archived choice not consumed")
-- 3. Nothing recorded: equal-value compensation instead of a permanently pending receipt.
chosen = plans.create(player, 2, record, "r3")
assert(chosen[1].Name == "Mansion" and chosen[1].Compensation)
assert(plans.create(player, 99, record, "r4") == nil, "Unknown products must not invent rewards")
-- Former ambiguous receipts recorded in PendingReceipts now resolve on retry.
record.PendingReceipts = { ["2"] = "legacy" }
local legacy = { PurchaseId = "legacy", ProductId = 2 }
local granted = {}
assert(ledger.process(player, legacy, plans.create, function(_, step)
	table.insert(granted, step.Name)
	return true
end))
assert(granted[1] == "Mansion" and record.PendingReceipts["2"] == nil)
print("PASS: open choice binding, archived choice for a second receipt, compensation for unknown choices, legacy pending receipts resolve")
