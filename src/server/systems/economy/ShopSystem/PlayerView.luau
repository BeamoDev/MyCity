-- PlayerView: focused implementation for ShopSystem.
return function(Context)
	local State = Context.State
	local RESET_INTERVAL = Context.RESET_INTERVAL
	local playerShopStocks = Context.playerShopStocks
	local ShopEvent = Context.ShopEvent

	function Context.getPlayerStats(player)
		local leaderstats = player:FindFirstChild("leaderstats")
		if not leaderstats then
			return 0, 0
		end

		local rebirths = leaderstats:FindFirstChild("Rebirths")
		local population = player:FindFirstChild("Data") and player.Data.PlayerInfo:FindFirstChild("Population")

		return rebirths and rebirths.Value or 0, population and population.Value or 0
	end

	function Context.getPlayerShopView(player)
		-- Get or create player's stock
		if not playerShopStocks[player.UserId] then
			playerShopStocks[player.UserId] = Context.generatePlayerStock()
		end

		local playerStock = playerShopStocks[player.UserId]
		local playerRebirths, playerPopulation = Context.getPlayerStats(player)
		local shopView = {}

		for buildingName, item in pairs(playerStock) do
			local viewItem = {
				Name = item.Name,
				DisplayName = item.DisplayName,
				Cost = item.Cost,
				Stock = item.Stock,
				ImageID = item.ImageID,
				Rarity = item.Rarity,
				Description = item.Description,
				PopulationRequired = item.PopulationRequired,
				RebirthRequired = item.RebirthRequired,
				IsDecoration = item.IsDecoration,
				IsLocked = false,
			}

			-- Check if locked for this player
			if item.PopulationRequired > 0 and playerPopulation < item.PopulationRequired then
				viewItem.IsLocked = true
			elseif item.RebirthRequired > 0 and playerRebirths < item.RebirthRequired then
				viewItem.IsLocked = true
			end

			table.insert(shopView, viewItem)
		end

		return shopView
	end

	function Context.sendShopUpdate(player)
		local shopView = Context.getPlayerShopView(player)
		local timeRemaining = math.max(0, RESET_INTERVAL - (tick() - State.lastResetTime))
		ShopEvent:FireClient(player, "UpdateShop", shopView, timeRemaining, true)
	end
end
