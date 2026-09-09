local Scope = require(game:GetService("ReplicatedStorage").shared.util.ConnectionScope)
local State = {}
local ShopController = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
require(game:GetService("ReplicatedStorage"):WaitForChild("shared"):WaitForChild("Network")).wait()
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

State.playerGui = nil
State.ShopFrame = nil
State.PurchaseFrameTemplate = nil
State.ItemTemplate = nil
State.ItemList = nil
State.ResetTimerLabel = nil

local RESET_INTERVAL = 300
State.remainingTime = RESET_INTERVAL
State.purchaseDebounce = false
State.currentPurchaseFrame = nil
State.currentPurchaseItem = nil
State.currentStockList = {}
local buttonConnections = {}

State.timerConnection = nil

local ShopEvent = ReplicatedStorage.Events.Shop:WaitForChild("ShopEvent")
local PurchaseEvent = ReplicatedStorage.Events.Shop:WaitForChild("PurchaseEvent")

local PRICE_TIERS = {
	[7] = 3375058573,
	[15] = 3375058621,
	[25] = 3375058684,
	[40] = 3375058756,
	[75] = 3375058850,
	[150] = 3375058936,
	[300] = 3375061785,
}

local RARITY_COLORS = {
	Common = Color3.fromRGB(150, 150, 150),
	Uncommon = Color3.fromRGB(100, 200, 100),
	Rare = Color3.fromRGB(85, 170, 255),
	Epic = Color3.fromRGB(170, 85, 255),
	Legendary = Color3.fromRGB(255, 170, 0),
	Mythic = Color3.fromRGB(255, 85, 85),
}

local Context = {
	State = State,
	connections = Scope.new(),
	ShopController = ShopController,
	ReplicatedStorage = ReplicatedStorage,
	RunService = RunService,
	Players = Players,
	RESET_INTERVAL = RESET_INTERVAL,
	buttonConnections = buttonConnections,
	ShopEvent = ShopEvent,
	PurchaseEvent = PurchaseEvent,
	PRICE_TIERS = PRICE_TIERS,
	RARITY_COLORS = RARITY_COLORS,
}
require(script:WaitForChild("Formatting"))(Context)
require(script:WaitForChild("PurchasePanel"))(Context)
require(script:WaitForChild("StockDisplay"))(Context)
require(script:WaitForChild("Lifecycle"))(Context)

ShopController.clearConnections = function()
	Context.connections:clear()
end
return ShopController
