-- Refresh: focused implementation for ShopSystem.
return function(Context)
	local State = Context.State
	local ShopSystem = Context.ShopSystem
	local Players = Context.Players
	local RESET_INTERVAL = Context.RESET_INTERVAL
	local playerShopStocks = Context.playerShopStocks
	local ShopEvent = Context.ShopEvent

	function ShopSystem.resetPlayerShop(player)
		-- Reset specific player's shop
		playerShopStocks[player.UserId] = Context.generatePlayerStock()

		local shopView = Context.getPlayerShopView(player)
		local timeRemaining = math.max(0, RESET_INTERVAL - (tick() - State.lastResetTime))
		ShopEvent:FireClient(player, "ResetShop", shopView, timeRemaining, false)
	end

	function Context.resetAllPlayerShops()
		State.lastResetTime = tick()

		-- Reset each player's shop individually
		for _, player in pairs(Players:GetPlayers()) do
			playerShopStocks[player.UserId] = Context.generatePlayerStock()
			local shopView = Context.getPlayerShopView(player)
			ShopEvent:FireClient(player, "ResetShop", shopView, RESET_INTERVAL, false)
		end
	end

	function ShopSystem.onPlayerRebirth(player)
		Context.sendShopUpdate(player)
	end
end
