local fs, luau = require("@lune/fs"), require("@lune/luau")
local source = fs.readFile("src/client/controllers/ui/UIController/Buttons.luau")
local lifecycle = fs.readFile("src/client/controllers/ui/UIController/Lifecycle.luau")
local products = fs.readFile("src/server/services/MarketPlaceHandler/ProductConfig.luau")
assert(products:find("[3388944230]", 1, true), "Authoritative Builder Pack product changed")
assert(source:find("BUILDER_PACK_PRODUCT_ID = 3388944230", 1, true))
assert(source:find("GetProductInfo(BUILDER_PACK_PRODUCT_ID, Enum.InfoType.Product)", 1, true))
assert(not source:find("Enum.InfoType.GamePass", 1, true))
assert(lifecycle:find("Context.setupBuilderPackPrice()", 1, true))

local function scenario(initialPrice)
	local calls, delays = {}, {}
	local label = { Parent = true, Text = "hardcoded" }
	function label:IsA(class) return class == "TextLabel" end
	local button = { TextLabel1 = label }
	function button:FindFirstChild(name) return self[name] end
	local state = { ButtonFolder = { Right = { BuilderPack = button } } }
	local market = { price = initialPrice }
	function market:GetProductInfo(id, infoType)
		table.insert(calls, { id = id, infoType = infoType })
		if not self.price then error("API unavailable") end
		return { PriceInRobux = self.price }
	end
	local scope = {}
	function scope:spawn(fn) fn() end
	function scope:delay(seconds, fn) table.insert(delays, { seconds = seconds, fn = fn }) end
	local context = { State = state, MarketPlace = market, connections = scope }
	luau.load(source, { environment = { Enum = { InfoType = { Product = "Product", GamePass = "GamePass" } } } })()(context)
	context.setupBuilderPackPrice()
	return label, market, calls, delays
end

local label, _, calls, delays = scenario(99)
assert(label.Text == "99 R$" and #calls == 1 and calls[1].id == 3388944230 and calls[1].infoType == "Product")
assert(delays[1].seconds == 600, "Successful pricing refreshes too frequently")
local failed, market, failedCalls, retry = scenario(nil)
assert(failed.Text == "— R$" and #failedCalls == 1 and retry[1].seconds == 90)
market.price = 79
retry[1].fn()
assert(failed.Text == "79 R$" and #failedCalls == 2)
assert(retry[2].seconds == 600)
print("PASS: Builder Pack local Product price, amount-R$ format, neutral failure, conservative retry and no game-pass lookup")
