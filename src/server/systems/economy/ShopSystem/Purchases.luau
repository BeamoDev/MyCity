-- Purchases: focused implementation for ShopSystem.
return function(Context)
	local State = Context.State
	local ShopSystem = Context.ShopSystem
	local ReplicatedStorage = Context.ReplicatedStorage
	local PRICE_TIERS = Context.PRICE_TIERS
	local playerShopStocks = Context.playerShopStocks
	local purchaseDebounce = Context.purchaseDebounce
	local ShopEvent = Context.ShopEvent

	function Context.getPriceTier(inGamePrice)
		if inGamePrice >= 0 and inGamePrice < 10000 then
			return 7
		elseif inGamePrice >= 10000 and inGamePrice < 30000 then
			return 15
		elseif inGamePrice >= 30000 and inGamePrice < 60000 then
			return 25
		elseif inGamePrice >= 60000 and inGamePrice < 100000 then
			return 40
		elseif inGamePrice >= 100000 and inGamePrice < 200000 then
			return 75
		elseif inGamePrice >= 200000 and inGamePrice < 500000 then
			return 150
		elseif inGamePrice >= 500000 and inGamePrice <= 10000000 then
			return 300
		else
			return nil
		end
	end

	function Context.handlePurchase(player, buildingName, currency)
		if type(buildingName) ~= "string" or (currency ~= "Cash" and currency ~= "Robux") then
			return false
		end
		-- Debounce check
		local debounceKey = player.UserId .. "_" .. buildingName
		if purchaseDebounce[debounceKey] then
			return
		end
		purchaseDebounce[debounceKey] = true

		-- Clear debounce after delay
		task.spawn(function()
			task.wait(0.2)
			purchaseDebounce[debounceKey] = nil
		end)

		-- Get player's specific stock
		local playerStock = playerShopStocks[player.UserId]
		if not playerStock then
			playerShopStocks[player.UserId] = Context.generatePlayerStock(player)
			playerStock = playerShopStocks[player.UserId]
		end
		if not playerStock then
			return false
		end

		local tutorial = player.Data.PlayerInfo:FindFirstChild("Tutorial")
		local tutorialPurchase = buildingName == "Shack"
			and currency == "Cash"
			and tutorial
			and tutorial.IsInTutorial.Value
			and tutorial.ServerStage.Value == 4
		local item = playerStock[buildingName]
		if not item then
			return
		end

		local playerRebirths, playerPopulation = Context.getPlayerStats(player)

		-- Check if locked
		local isLocked = false
		if item.PopulationRequired > 0 and playerPopulation < item.PopulationRequired then
			isLocked = true
		elseif item.RebirthRequired > 0 and playerRebirths < item.RebirthRequired then
			isLocked = true
		end

		if currency == "Cash" then
			if isLocked then
				ShopEvent:FireClient(player, "LockedItem", buildingName)
				return
			end

			if item.Stock <= 0 and not tutorialPurchase then
				ShopEvent:FireClient(player, "OutOfStock", buildingName)
				return
			end

			local leaderstats = player:FindFirstChild("leaderstats")
			local Cash = leaderstats and leaderstats:FindFirstChild("Cash")

			if not Cash or Cash.Value < item.Cost then
				ReplicatedStorage.Events.Notifications.BrokeAhh:FireClient(player)
				return
			end

			-- Process purchase

			-- Create tool
			local BuildingSystem =
				require(script.Parent.Parent.Parent:WaitForChild("building"):WaitForChild("BuildingSystem"))
			local tool = BuildingSystem.createToolWithBuilding(buildingName, false, 1, 0)
			if not tool or not player:FindFirstChild("Backpack") then
				if tool then
					tool:Destroy()
				end
				return false
			end
			Cash.Value -= item.Cost
			item.Stock = math.max(0, item.Stock - 1)
			tool.Parent = player.Backpack
			local questSignals = require(script.Parent.Parent.Parent.Parent.services.QuestSignals)
			questSignals.emit(player, "purchase", 1)
			questSignals.emit(player, "spend", item.Cost)
			if buildingName == "Shack" then
				require(script.Parent.Parent.Parent.progression.TutorialSystem).handleShackPurchase(player)
			end

			-- Only notify the purchasing player of their stock change
			ShopEvent:FireClient(player, "UpdateStock", buildingName, item.Stock)

			ReplicatedStorage.Events.Notifications.ItemBought:FireClient(player, buildingName)
			return true
		elseif currency == "Robux" then
			local priceTier = Context.getPriceTier(item.Cost)
			local devProductId = PRICE_TIERS[priceTier]
			if devProductId then
				local ok, message = require(
					script.Parent.Parent.Parent.Parent.services.MarketPlaceHandler.PurchaseIntents
				).prompt(player, devProductId, { Kind = "Building", Name = buildingName })
				if not ok then
					ReplicatedStorage.Events.Notifications.ErrorEvent:FireClient(
						player,
						message or "Purchase unavailable. Please try again."
					)
				end
				return ok
			end
		end
	end

	ShopSystem.purchase = Context.handlePurchase
	ShopSystem.syncPlayer = Context.sendShopUpdate
end
