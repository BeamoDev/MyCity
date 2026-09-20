local State = {}
local ShopSystem = {}
local Guard = require(script.Parent.Parent.security.RequestGuard)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Stock configuration
local STOCK_RANGES = {
	Common = { min = 10, max = 25, outOfStockChance = 0.05 },
	Uncommon = { min = 5, max = 15, outOfStockChance = 0.15 },
	Rare = { min = 3, max = 10, outOfStockChance = 0.25 },
	Epic = { min = 2, max = 6, outOfStockChance = 0.35 },
	Legendary = { min = 1, max = 4, outOfStockChance = 0.45 },
	Mythic = { min = 0, max = 2, outOfStockChance = 0.6 },
}

local LIMITED_BUILDINGS = {
	"EmpireState",
	"LuxuryCondo",
	"Airport",
	"Stadium",
	"SoccerStadium",
	"NuclearPowerPlant",
	"PowerStation",
	"Mall",
	"SkyTower",
	"LuxuryHouse",
	"PetronasTowers",
	"Mansion",
	"TaipeiTower",
	"ChinaBankTower",
	"PrismTower",
	"AuroraTower",
}

local RESET_INTERVAL = 300 -- 5 minutes
local EPIC_MAX_MISSES = 3 -- The next stock generation guarantees availability.
local PRICE_TIERS = {
	[7] = 3375058573,
	[15] = 3375058621,
	[25] = 3375058684,
	[40] = 3375058756,
	[75] = 3375058850,
	[150] = 3375058936,
	[300] = 3375061785,
}

-- Player-specific shop data
local playerShopStocks = {} -- Each player gets their own stock
State.lastResetTime = tick()
local purchaseDebounce = {}

local ShopEvent = ReplicatedStorage.Events.Shop.ShopEvent
local PurchaseEvent = ReplicatedStorage.Events.Shop.PurchaseEvent

-- Cache building config
State.BuildingConfig = nil

local Context = {
	State = State,
	ShopSystem = ShopSystem,
	Guard = Guard,
	ReplicatedStorage = ReplicatedStorage,
	MarketplaceService = MarketplaceService,
	Players = Players,
	RunService = RunService,
	STOCK_RANGES = STOCK_RANGES,
	LIMITED_BUILDINGS = LIMITED_BUILDINGS,
	RESET_INTERVAL = RESET_INTERVAL,
	EPIC_MAX_MISSES = EPIC_MAX_MISSES,
	PRICE_TIERS = PRICE_TIERS,
	playerShopStocks = playerShopStocks,
	purchaseDebounce = purchaseDebounce,
	ShopEvent = ShopEvent,
	PurchaseEvent = PurchaseEvent,
}
require(script:WaitForChild("Stock"))(Context)
require(script:WaitForChild("PlayerView"))(Context)
require(script:WaitForChild("Refresh"))(Context)
require(script:WaitForChild("Purchases"))(Context)
require(script:WaitForChild("Lifecycle"))(Context)

return ShopSystem
