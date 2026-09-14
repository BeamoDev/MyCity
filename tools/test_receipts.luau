local fs = require("@lune/fs")
local luau = require("@lune/luau")
local serde = require("@lune/serde")
local record, durable, saves, failAt, grants = {}, {}, 0, nil, 0
local loaded = true
local Data = {
	isLoaded = function()
		return loaded
	end,
	getRecord = function()
		return record
	end,
	savePlayerData = function()
		saves += 1
		if saves == failAt then
			return false
		end
		durable = serde.decode("json", serde.encode("json", record))
		return true
	end,
}
local Guard = {
	ready = function()
		return true
	end,
	run = function(_, _, callback)
		return callback()
	end,
}
local root = { persistence = { PlayerDataModule = Data }, systems = { security = { RequestGuard = Guard } } }
local ledger = luau.load(fs.readFile("src/server/services/MarketPlaceHandler/ReceiptLedger.luau"), {
	environment = {
		script = { Parent = { Parent = { Parent = root } } },
		require = function(module)
			return module
		end,
	},
})()
local function plan()
	return { { Kind = "Cash" }, { Kind = "Building" } }
end
local function apply()
	grants += 1
	return true
end
local receipt = { PurchaseId = "purchase-a", ProductId = 42 }
assert(ledger.process({}, receipt, plan, apply))
assert(grants == 2 and durable.Receipts[receipt.PurchaseId].Complete)
assert(ledger.process({}, receipt, plan, apply) and grants == 2, "Receipt replay granted twice")

record, durable, saves, grants, failAt = {}, {}, 0, 0, 2
assert(not ledger.process({}, receipt, plan, apply))
assert(grants == 1, "Failure did not stop the remaining grant steps")
failAt = nil
assert(ledger.process({}, receipt, plan, apply))
assert(grants == 2, "Save retry duplicated a step already granted in this server")

record, durable, saves, grants, failAt = {}, {}, 0, 0, 3
assert(not ledger.process({}, receipt, plan, apply))
assert(grants == 2)
-- Rejoin restores the last DURABLE profile: first item exists, second does not.
record = durable
grants = 1
failAt = nil
assert(ledger.process({}, receipt, plan, apply) and grants == 2, "Crash/rejoin replay duplicated a durable step")
loaded = false
assert(not ledger.process({}, { PurchaseId = "new", ProductId = 42 }, plan, apply))
print(
	"PASS: receipt replay, partial save failure, same-server retry, crash/rejoin continuation, unloaded profile rejection"
)

-- Two receipt IDs cannot consume the same bound purchase target.
loaded = true
record = { PurchaseIntents = { ["42"] = { PurchaseId = "old-receipt", Details = {} } } }
local beforeGrants = grants
assert(not ledger.process({}, receipt, plan, apply) and grants == beforeGrants)
-- Completing an older receipt preserves a newer intent at the same price.
record = {
	Receipts = { [receipt.PurchaseId] = { ProductId = 42, Plan = {}, Applied = {} } },
	PurchaseIntents = { ["42"] = { PurchaseId = "newer", Details = {} } },
}
assert(ledger.process({}, receipt, plan, apply))
assert(record.PurchaseIntents["42"].PurchaseId == "newer")
print("PASS: bound-intent receipt ownership and newer pending-target preservation")

-- City likes use a monotonic reward sequence persisted with owner cash.
record, durable, saves, failAt = {}, {}, 0, 1
local cash = { Value = 100 }
local stats = {
	FindFirstChild = function()
		return cash
	end,
}
local owner = {
	leaderstats = stats,
	FindFirstChild = function()
		return stats
	end,
}
local socialRoot = { persistence = { PlayerDataModule = Data } }
local systems = { Parent = socialRoot, security = { RequestGuard = Guard } }
local rewards = luau.load(
	fs.readFile("src/server/systems/social/CityLikeRewards.luau"),
	{
		environment = {
			script = { Parent = { Parent = systems } },
			require = function(m)
				assert(m)
				return m
			end,
		},
	}
)()
assert(not rewards.settle(owner, 3) and cash.Value == 250 and record.CityLikeRewardSequence == 3)
assert(not rewards.settle(owner, 3) and cash.Value == 250, "Failed save retried a cash grant twice")
failAt = nil
assert(rewards.settle(owner, 4) and cash.Value == 300 and durable.CityLikeRewardSequence == 4)
assert(not rewards.settle(owner, 2) and cash.Value == 300, "Stale cross-server count reduced watermark")
assert(not rewards.settle(owner, 0 / 0))
print("PASS: durable city-like reward watermark, save failure duplicate prevention, catch-up and stale count rejection")
