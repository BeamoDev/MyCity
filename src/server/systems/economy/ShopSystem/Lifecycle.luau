-- Lifecycle: focused implementation for ShopSystem.
return function(Context)
	local State = Context.State
	local ShopSystem = Context.ShopSystem
	local Guard = Context.Guard
	local Players = Context.Players
	local RESET_INTERVAL = Context.RESET_INTERVAL
	local playerShopStocks = Context.playerShopStocks
	local ShopEvent = Context.ShopEvent
	local PurchaseEvent = Context.PurchaseEvent

	function ShopSystem.init()
		-- Handle purchase requests
		PurchaseEvent.OnServerEvent:Connect(function(player, buildingName, currency)
			Guard.run(player, "Purchase", Context.handlePurchase, buildingName, currency)
		end)

		-- Handle shop data requests
		ShopEvent.OnServerEvent:Connect(function(player, action)
			if action == "RequestShopData" then
				Context.sendShopUpdate(player)
			end
		end)

		-- Send shop to existing players
		for _, player in pairs(Players:GetPlayers()) do
			task.spawn(function()
				task.wait(1)
				Context.sendShopUpdate(player)
			end)
		end

		-- Handle new players
		Players.PlayerAdded:Connect(function(player)
			-- Generate fresh stock for new player
			playerShopStocks[player.UserId] = Context.generatePlayerStock()

			task.wait(2)
			Context.sendShopUpdate(player)

			-- Listen for stat changes to update lock status
			local leaderstats = player:WaitForChild("leaderstats", 10)
			if leaderstats then
				local population = player:FindFirstChild("Data") and player.Data.PlayerInfo:FindFirstChild("Population")
				local rebirths = leaderstats:FindFirstChild("Rebirths")

				if population then
					population.Changed:Connect(function()
						task.wait(0.5)
						Context.sendShopUpdate(player)
					end)
				end

				if rebirths then
					rebirths.Changed:Connect(function()
						task.wait(0.5)
						Context.sendShopUpdate(player)
					end)
				end
			end
		end)

		-- Clean up when player leaves
		Players.PlayerRemoving:Connect(function(player)
			playerShopStocks[player.UserId] = nil
		end)

		-- Shop reset timer - resets all player shops simultaneously
		task.spawn(function()
			while true do
				task.wait(1)
				local elapsed = tick() - State.lastResetTime
				if elapsed >= RESET_INTERVAL then
					Context.resetAllPlayerShops()
				end
			end
		end)

		-- Admin commands
		game.Players.PlayerAdded:Connect(function(player)
			player.Chatted:Connect(function(msg)
				if player.UserId == game.CreatorId then
					if msg:lower() == "/resetshop" then
						Context.resetAllPlayerShops()
						print("[SHOP] Admin reset all shops")
					end
				end
			end)
		end)
	end
end
