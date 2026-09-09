local SKIP_TIME_PRODUCTS = {
	[3375059582] = 300,
	[3375059694] = 900,
	[3375059795] = 1800,
	[3375059899] = 3600,
	[3375059969] = 7200,
	[3375060077] = 21600,
	[3375060171] = 100000000,
}

local SHOP_PRICE_PRODUCT_IDS = {
	[3375058573] = true,
	[3375058621] = true,
	[3375058684] = true,
	[3375058756] = true,
	[3375058850] = true,
	[3375058936] = true,
	[3375061785] = true,
}

local BUILDALL_PRODUCTID = 3375057542
local LD_PRODUCTID = 3375058095
local REFRESH_STOCK_PRODUCTID = 3375059242
local STEAL_BUILDING_PRODUCT_ID = 3375062345

local DEV_PRODUCTS = {
	[3375056192] = { rewards = { cash = 2500 } },
	[3375055985] = { rewards = { cash = 10000 } },
	[3375056438] = { rewards = { cash = 50000 } },
	[3375055773] = { rewards = { cash = 100000 } },
	[3375056296] = { rewards = { cash = 250000 } },
	[3375056081] = { rewards = { cash = 1000000 } },
	[3375057388] = { rewards = { buildings = { "Apartments" } } },
	[3375058229] = { rewards = { buildings = { "LuxuryCondo", "OfficeBuilding" } } },
	-- NEW ADDITION
	[3388944230] = {
		rewards = { buildings = { "Clinic", "Clinic", "IceCreamStore", "PrismTower", "VortexTower", "BlockTower" } },
	},
}

return {
	Skip = SKIP_TIME_PRODUCTS,
	Shop = SHOP_PRICE_PRODUCT_IDS,
	BuildAll = BUILDALL_PRODUCTID,
	Refresh = REFRESH_STOCK_PRODUCTID,
	Steal = STEAL_BUILDING_PRODUCT_ID,
	Rewards = DEV_PRODUCTS,
}
