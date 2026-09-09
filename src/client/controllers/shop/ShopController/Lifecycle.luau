-- Lifecycle: focused implementation for ShopController.
return function(Context)
	local State = Context.State
	local ShopController = Context.ShopController
	local RunService = Context.RunService
	local RESET_INTERVAL = Context.RESET_INTERVAL
	local ShopEvent = Context.ShopEvent
	local ReplicatedStorage = Context.ReplicatedStorage

	function Context.startResetCountdown(time)
		if State.timerConnection then
			State.timerConnection:Disconnect()
		end

		State.remainingTime = time or RESET_INTERVAL

		State.timerConnection = Context.connections:connect(RunService.Heartbeat, function(deltaTime)
			State.remainingTime = State.remainingTime - deltaTime
			if State.remainingTime <= 0 then
				State.remainingTime = 0
				if State.timerConnection then
					State.timerConnection:Disconnect()
					State.timerConnection = nil
				end
			end
			if State.ResetTimerLabel then
				State.ResetTimerLabel.Text = "Stock Refresh: " .. Context.formatTime(math.ceil(State.remainingTime))
			end
		end)
	end

	function ShopController.init(gui)
		State.playerGui = gui

		local shopAssets = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Shop")
		State.ShopFrame = State.playerGui.Frames.ItemShop.Frame
		State.PurchaseFrameTemplate = shopAssets:WaitForChild("PurchaseFrame")
		State.ItemTemplate = shopAssets:WaitForChild("ItemTemplate")
		State.ItemList = State.ShopFrame.ScrollingFrame
		State.ResetTimerLabel = State.ShopFrame.RestockTimerFrame.Pattern:WaitForChild("TextLabel")

		-- Connect shop events
		Context.connections:connect(ShopEvent.OnClientEvent, function(action, ...)
			if action == "UpdateShop" then
				-- Regular update (from stat changes) - preserve purchase frame
				local stock, timer, isInitialLoad = ...
				Context.updateShopDisplay(stock, timer, isInitialLoad)
			elseif action == "ResetShop" then
				-- Full shop reset - close purchase frame
				local stock, timer, isInitialLoad = ...

				-- Close purchase frame on full reset
				if State.currentPurchaseFrame then
					State.currentPurchaseFrame:Destroy()
					State.currentPurchaseFrame = nil
					State.currentPurchaseItem = nil
				end

				Context.updateShopDisplay(stock, timer, isInitialLoad)
			elseif action == "UpdateStock" then
				local buildingName, newStock = ...

				-- Update in current stock list
				for _, item in ipairs(State.currentStockList) do
					if item.Name == buildingName then
						item.Stock = newStock
						break
					end
				end

				-- Update UI
				local itemFrame = State.ItemList:FindFirstChild(buildingName)
				if itemFrame then
					local costLabel = itemFrame:FindFirstChild("Cost")
					local limitText = itemFrame:FindFirstChild("Limit")

					if costLabel then
						if newStock == 0 then
							costLabel.Text = "NO STOCK"
							costLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
							local costStroke = costLabel:FindFirstChild("UIStroke")
							if costStroke then
								costStroke.Color = Color3.fromRGB(100, 30, 30)
							end
						else
							for _, item in ipairs(State.currentStockList) do
								if item.Name == buildingName then
									costLabel.Text = Context.formatCash(item.Cost)
									costLabel.TextColor3 = Color3.fromRGB(68, 255, 11)
									local costStroke = costLabel:FindFirstChild("UIStroke")
									if costStroke then
										costStroke.Color = Color3.fromRGB(31, 106, 5)
									end
									break
								end
							end
						end
					end

					if limitText then
						limitText.Text = tostring(newStock) .. "x STOCK"
					end

					-- Update purchase frame if open
					if State.currentPurchaseFrame and State.currentPurchaseItem == buildingName then
						for _, item in ipairs(State.currentStockList) do
							if item.Name == buildingName then
								Context.updatePurchaseFrame(State.currentPurchaseFrame, item)
								break
							end
						end
					end
				end
			end
		end)

		task.wait(0.1)
		ShopEvent:FireServer("RequestShopData")
	end
end
