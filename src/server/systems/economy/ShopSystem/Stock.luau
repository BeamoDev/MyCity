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

	function Context.getStockForBuilding(buildingName, info, misses)
		-- Every Epic follows the same rule, including names in the limited list.
		if info.Rarity == "Epic" then
			local range = STOCK_RANGES.Epic
			if misses < Context.EPIC_MAX_MISSES and math.random() < range.outOfStockChance then
				return 0
			end
			return math.random(range.min, range.max)
		end

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

	function Context.generatePlayerStock(player)
		-- Join callbacks and timer resets can arrive before profile restoration.
		-- Never roll against temporary defaults or overwrite a restored streak.
		if not player.Parent or not player:GetAttribute("MyCityLoaded") or player:GetAttribute("MyCityLeaving") then
			return nil
		end
		local data = player:FindFirstChild("Data")
		local counters = data and data:FindFirstChild("ShopEpicMisses")
		if not counters then
			return nil
		end
		local config = Context.getBuildingConfig()
		local newStock = {}

		for buildingName, info in pairs(config) do
			local counter, misses = nil, 0
			if info.Rarity == "Epic" then
				counter = counters:FindFirstChild(buildingName)
				if not counter or not counter:IsA("IntValue") then
					if counter then
						counter:Destroy()
					end
					counter = Instance.new("IntValue")
					counter.Name, counter.Parent = buildingName, counters
				end
				misses = math.clamp(counter.Value, 0, Context.EPIC_MAX_MISSES)
			end
			local stock = Context.getStockForBuilding(buildingName, info, misses)
			if counter then
				counter.Value = if stock > 0 then 0 else misses + 1
			end

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
