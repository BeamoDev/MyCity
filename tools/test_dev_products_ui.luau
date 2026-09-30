local fs = require("@lune/fs")
local source = fs.readFile("src/client/controllers/ui/UIController/DevProducts.luau")
local lifecycle = fs.readFile("src/client/controllers/ui/UIController/Lifecycle.luau")
local purchasePanel = fs.readFile("src/client/controllers/shop/ShopController/PurchasePanel.luau")
local shopInit = fs.readFile("src/client/controllers/shop/ShopController/init.luau")

for name, id in {
	Cash1 = 3375056192,
	Cash2 = 3375055985,
	Cash3 = 3375056438,
	Cash4 = 3375055773,
	Cash5 = 3375056296,
	Cash6 = 3375056081,
	MidDeal1 = 3375057388,
	LuxuryDeal = 3375058229,
	Gamepass1 = 1406723890,
	Gamepass2 = 1407360513,
	Gamepass3 = 1406735933,
} do
	assert(source:find(name .. " = " .. id, 1, true), name .. " ID changed")
end
assert(source:find('card:FindFirstChild%("Buy"%)'), "Buy is not read directly from each card")
assert(not source:find('FindFirstChild%("Pattern"%)'), "obsolete Pattern path remains")
assert(source:find("GetProductInfoAsync", 1, true), "prices are not queried on the client")
assert(source:find("PromptProductPurchase", 1, true), "developer-product prompts are missing")
assert(source:find("PromptGamePassPurchase", 1, true), "game-pass prompts are missing")
assert(source:find("DevProductsClientScript", 1, true) and source:find("legacy:Destroy%(%s*%)"), "legacy GUI script is not removed")
assert(lifecycle:find("Context.setupDevProducts%(%)"), "dev-product controller is not initialized")
assert(purchasePanel:find('robuxBuyButton:FindFirstChild%("TextLabel"%)'), "PurchaseFrame RobuxBuy.TextLabel is not targeted")
assert(purchasePanel:find("Context.PRICE_TIERS%[tier%]"), "purchase modal does not resolve its developer product")
assert(purchasePanel:find("GetProductInfoAsync", 1, true), "building shop does not fetch the local price")
assert(purchasePanel:find("localizedRobuxPriceWaiters", 1, true), "same-tier local price lookups are not coalesced")
assert(purchasePanel:find("Context.updateLocalizedRobuxLabel%(robuxPriceLabel"), "purchase modal does not show the local Robux price")
local stockDisplay = fs.readFile("src/client/controllers/shop/ShopController/StockDisplay.luau")
assert(stockDisplay:find('buyRobux:FindFirstChild%("Cost"%)'), "ItemTemplate.Locked.Buy.Cost is not targeted")
assert(stockDisplay:find("Context.updateLocalizedRobuxLabel%(costText"), "locked card does not show the local Robux price")
assert(shopInit:find('GetService%("MarketplaceService"%)'), "ShopController does not provide MarketplaceService")
print("PASS: centralized Shop developer products/game passes, direct Buy paths and localized prices")
