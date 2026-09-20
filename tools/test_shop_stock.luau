local fs, luau, roblox = require("@lune/fs"), require("@lune/luau"), require("@lune/roblox")
local function load(path, env)
	return luau.load(fs.readFile(path), { environment = env or {} })()
end
local function node(fields)
	function fields:FindFirstChild(name)
		return self[name]
	end
	fields.WaitForChild = fields.FindFirstChild
	return fields
end
local function signal()
	local callbacks = {}
	return {
		Connect = function(_, fn)
			table.insert(callbacks, fn)
		end,
		Fire = function(_, ...)
			for _, fn in callbacks do
				fn(...)
			end
		end,
	}
end
local env = { Instance = roblox.Instance }
local codec = load("src/server/persistence/PlayerDataModule/ProfileCodec.luau", env)
local schema = load("src/server/persistence/PlayerDataModule/DataSchema.luau", env)
local catalogue = {}
for _, category in { "Decorations", "Starter", "Population", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" } do
	for name, info in load("src/server/config/BuildingConfig/" .. category .. ".luau") do
		catalogue[name] = info
	end
end
local function player(id, snapshot)
	local data, stats = codec.restore(snapshot or { NewProfile = true })
	schema.Reconcile(data, stats, "Tester", 1000)
	local p = node({ UserId = id, Name = "Tester", Parent = true, Data = data, leaderstats = stats,
		attributes = { MyCityLoaded = true }, Chatted = signal() })
	function p:GetAttribute(name)
		return self.attributes[name]
	end
	return p
end
local p1, p2, loading = player(1), player(2), player(3)
loading.attributes.MyCityLoaded = false
local roster = { p1, p2, loading }
local players = { PlayerAdded = signal(), PlayerRemoving = signal(), GetPlayers = function() return roster end }
local messages, queued = {}, {}
local shopEvent = { OnServerEvent = signal(), FireClient = function(_, p, action, view, remaining)
	table.insert(messages, { player = p, action = action, view = view, remaining = remaining })
end }
local services = {
	Players = players, RunService = {}, MarketplaceService = {},
	ReplicatedStorage = { Events = { Shop = { ShopEvent = shopEvent, PurchaseEvent = { OnServerEvent = signal() } } } },
}
local chance, upperQuantity, randomCalls = 0, false, 0
local randomMath = table.clone(math)
randomMath.random = function(minimum, maximum)
	randomCalls += 1
	if minimum then return if upperQuantity then maximum else minimum end
	return chance
end
local context
env = {
	Instance = roblox.Instance, math = randomMath, tick = function() return 1000 end,
	task = { spawn = function(fn) table.insert(queued, fn) end, wait = function() end },
	game = { Players = players, CreatorId = -1, GetService = function(_, name) return services[name] end },
	require = function(module) return module end,
}
local module = node({ Parent = { Parent = { security = { RequestGuard = {} } } } })
for _, name in { "Stock", "PlayerView", "Refresh", "Purchases", "Lifecycle" } do
	local installer = load("src/server/systems/economy/ShopSystem/" .. name .. ".luau", env)
	module[name] = function(c)
		context = c
		installer(c)
	end
end
env.script = module
local shop = load("src/server/systems/economy/ShopSystem/init.luau", env)
context.State.BuildingConfig = catalogue
shop.init()
assert(context.RESET_INTERVAL == 300 and context.EPIC_MAX_MISSES == 3)

-- Early join, snapshot and timer callbacks cannot roll before the saved profile is ready.
local before = randomCalls
local loadingStats = loading.leaderstats
loading.leaderstats = nil
players.PlayerAdded:Fire(loading)
loading.leaderstats = loadingStats
shop.resetPlayerShop(loading)
assert(randomCalls == before and context.playerShopStocks[3] == nil)
assert(#loading.Data.ShopEpicMisses:GetChildren() == 0)

-- Forced bad luck must produce exactly three misses, then positive stock for every Epic.
for generation = 1, 4 do
	shop.resetPlayerShop(p1)
	for name, info in catalogue do
		if info.Rarity == "Epic" then
			assert(context.playerShopStocks[1][name].Stock == (if generation == 4 then 2 else 0), name)
			assert(p1.Data.ShopEpicMisses[name].Value == (if generation == 4 then 0 else generation), name)
		end
	end
end
assert(#p2.Data.ShopEpicMisses:GetChildren() == 0, "Players must not share streaks")

-- Reopening, ClientReady/stat updates, rebirth sync and buying out stock are not missed rolls.
local current = context.playerShopStocks[1]
current.Mall.Stock = 0
before = randomCalls
for _ = 1, 10 do shop.syncPlayer(p1) end
shop.onPlayerRebirth(p1)
assert(randomCalls == before and context.playerShopStocks[1] == current)
assert(p1.Data.ShopEpicMisses.Mall.Value == 0)
local mallView
for _, item in messages[#messages].view do if item.Name == "Mall" then mallView = item end end
assert(mallView.IsLocked and mallView.PopulationRequired == 35000 and mallView.Cost == 500000)
p1.Data.PlayerInfo.Population.Value = 35000
shop.syncPlayer(p1)
for _, item in messages[#messages].view do
	if item.Name == "Mall" then assert(not item.IsLocked and item.Stock == 0) end
end
assert(randomCalls == before)

-- Both ends of the normal Epic availability boundary apply to every named Epic.
for _, roll in { 0.349, 0.35, 0.99 } do
	chance = roll
	upperQuantity = true
	for name, info in catalogue do
		if info.Rarity == "Epic" then
			assert(context.getStockForBuilding(name, info, 0) == (if roll < 0.35 then 0 else 6), name)
		end
	end
end
chance, upperQuantity = 0, false
shop.resetPlayerShop(p1)
assert(p1.Data.ShopEpicMisses.Mall.Value == 1)
chance = 0.5
shop.resetPlayerShop(p1)
assert(p1.Data.ShopEpicMisses.Mall.Value == 0 and context.playerShopStocks[1].Mall.Stock == 2)

-- Keep non-Epic limited stock and normal rarity behavior unchanged.
assert(context.getStockForBuilding("Airport", catalogue.Airport, 0) == 0)
assert(context.getStockForBuilding("Shack", catalogue.Shack, 0) == context.STOCK_RANGES[catalogue.Shack.Rarity].min)
chance = 0.9
assert(context.getStockForBuilding("Airport", catalogue.Airport, 0) == 0) -- existing 0..2 quantity roll
upperQuantity = true
assert(context.getStockForBuilding("Airport", catalogue.Airport, 0) == 2)
chance, upperQuantity = 0, false

-- Actual profile encode/normalize/restore retains streaks through a normal leave/rejoin.
for _ = 1, 3 do shop.resetPlayerShop(p1) end
local snapshot = { PlayerData = codec.encodeFolder(p1.Data), LeaderBoardData = codec.encodeFolder(p1.leaderstats), FolderEncoding = 2 }
snapshot = schema.Normalize(snapshot, p1.Name, 1000)
players.PlayerRemoving:Fire(p1)
assert(context.playerShopStocks[1] == nil)
local returning = player(1, snapshot)
assert(returning.Data.ShopEpicMisses.Mall.Value == 3)
shop.syncPlayer(returning)
assert(context.playerShopStocks[1].Mall.Stock == 2 and returning.Data.ShopEpicMisses.Mall.Value == 0)

-- Global resets skip loading/departing players and keep counters independent.
roster = { returning, p2, loading }
returning.attributes.MyCityLeaving = true
context.resetAllPlayerShops()
assert(returning.Data.ShopEpicMisses.Mall.Value == 0)
assert(p2.Data.ShopEpicMisses.Mall.Value == 1)
assert(#loading.Data.ShopEpicMisses:GetChildren() == 0)
p2.Data.ShopEpicMisses.Mall.Value = 3
shop.resetPlayerShop(p2)
assert(context.playerShopStocks[2].Mall.Stock == 2 and p2.Data.ShopEpicMisses.Mall.Value == 0)
assert(context.playerShopStocks[2].NeedleTower.Stock == 0 and p2.Data.ShopEpicMisses.NeedleTower.Value == 2)
loading.attributes.MyCityLoaded = true
shop.syncPlayer(loading)
assert(loading.Data.ShopEpicMisses.Mall.Value == 1 and context.playerShopStocks[3])
print("PASS: all Epic odds/quantities, fourth-roll guarantee, per-player/per-building streaks, snapshot stability, eligibility, load/departure gates and saved rejoin recovery")
