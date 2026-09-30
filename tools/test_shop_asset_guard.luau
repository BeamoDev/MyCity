local fs, luau = require("@lune/fs"), require("@lune/luau")

local function node(children, className)
	children = children or {}
	function children:FindFirstChild(name) return self[name] end
	function children:IsA(name) return name == className end
	return children
end

local installer = luau.load(fs.readFile("src/server/systems/economy/ShopSystem/Purchases.luau"), {
	environment = { task = { spawn = function() end } },
})()

local function attempt(currency, model, site)
	local notices = {}
	local player = node({ UserId = 42, Data = node({ PlayerInfo = node() }) })
	local item = { Cost = 100, Stock = 1, PopulationRequired = 0, RebirthRequired = 0 }
	local storage = node({ Buildings = node({ Bank = model }) })
	local replicated = node({
		Assets = node({ Constructions = node({ ["2x2"] = site }) }),
		Events = { Notifications = { ErrorEvent = { FireClient = function(_, _, message)
			table.insert(notices, message)
		end } } },
	})
	local context = {
		State = {}, ShopSystem = {}, ReplicatedStorage = replicated, ServerStorage = storage,
		PRICE_TIERS = {}, playerShopStocks = { [42] = { Bank = item } }, purchaseDebounce = {},
		ShopEvent = {},
		getBuildingConfig = function() return { Bank = { Size = "2x2", BuildTime = 10 } } end,
	}
	installer(context)
	assert(context.ShopSystem.purchase(player, "Bank", currency) == false)
	assert(#notices == 1 and item.Stock == 1, "Unavailable model or site reached a purchase path")
end

attempt("Cash", nil, node({}, "Model"))
attempt("Robux", node({ PrimaryPart = {} }, "Model"), nil)
print("PASS: missing building model or construction site blocks Cash and Robux purchase requests")
