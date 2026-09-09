-- Stock: focused implementation for ShopSystem.
return function(Context)
	local State = Context.State
	local ShopSystem = Context.ShopSystem
	local STOCK_RANGES = Context.STOCK_RANGES
	local LIMITED_BUILDINGS = Context.LIMITED_BUILDINGS

	function Context.getBuildingConfig()
		if not State.BuildingConfig then
			State.BuildingConfig =
				require(script.Parent.Parent.Parent.Parent:WaitForChild("config"):WaitForChild("BuildingConfig"))
		end
		return State.BuildingConfig
	end

	function Context.isLimitedBuilding(buildingName)
		for _, name in ipairs(LIMITED_BUILDINGS) do
			if name == buildingName then
				return true
			end
		end
		return false
	end

	function Context.getStockForBuilding(buildingName, info)
		-- Limited buildings get special stock
		if Context.isLimitedBuilding(buildingName) then
			if math.random() < 0.6 then
				return 0
			end
			return math.random(0, 2)
		end

		-- Regular stock based on rarity
		local rarity = info.Rarity or "Common"
		local range = STOCK_RANGES[rarity]

		if not range then
			return math.random(5, 10)
		end

		if math.random() < range.outOfStockChance then
			return 0
		end

		return math.random(range.min, range.max)
	end

	function Context.generatePlayerStock()
		local config = Context.getBuildingConfig()
		local newStock = {}

		for buildingName, info in pairs(config) do
			local stock = Context.getStockForBuilding(buildingName, info)

			newStock[buildingName] = {
				Name = buildingName,
				DisplayName = info.DisplayName or buildingName,
				Cost = info.Cost,
				Stock = stock,
				ImageID = info.ImageId,
				Rarity = info.Rarity or "Common",
				Description = info.Description or "",
				PopulationRequired = info.PopulationRequired or 0,
				RebirthRequired = info.RebirthRequired or 0,
				IsDecoration = info.IsDecoration or false,
			}
		end

		return newStock
	end

	function ShopSystem.getServerStock()
		-- For compatibility with MarketplaceHandler, return a dummy stock
		-- Or you could return the first player's stock if needed
		local config = Context.getBuildingConfig()
		local dummyStock = {}
		for buildingName, info in pairs(config) do
			dummyStock[buildingName] = {
				Name = buildingName,
				Stock = 1, -- Default stock for robux purchases
			}
		end
		return dummyStock
	end
end
