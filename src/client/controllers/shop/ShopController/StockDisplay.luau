-- StockDisplay: focused implementation for ShopController.
return function(Context)
	local State = Context.State
	local Players = Context.Players
	local buttonConnections = Context.buttonConnections
	local PurchaseEvent = Context.PurchaseEvent
	local RARITY_COLORS = Context.RARITY_COLORS

	function Context.createItemFrame(item)
		Context.clearButtonConnections(item.Name)

		local frame = State.ItemTemplate:Clone()
		frame.Name = item.Name
		frame.Visible = true

		-- Set basic info
		frame.ItemName.Text = item.DisplayName or item.Name
		frame.Description.Text = item.Description or ""
		frame.BuildingIcon.ImageLabel.Image = "rbxassetid://" .. tostring(item.ImageID)

		-- Set rarity colors for backgrounds
		local rarityColor = RARITY_COLORS[item.Rarity] or RARITY_COLORS.Common

		-- Apply darker version to frame.BG
		local frameBG = frame:FindFirstChild("BG")
		if frameBG then
			-- Darken the color by multiplying by 0.4
			frameBG.ImageColor3 = Color3.new(rarityColor.R * 0.4, rarityColor.G * 0.4, rarityColor.B * 0.4)
		end

		-- Apply lighter version to BuildingIcon.BG
		local buildingIconBG = frame.BuildingIcon:FindFirstChild("BG")
		if buildingIconBG then
			-- Lighten the color by blending with white (0.6 original + 0.4 white)
			buildingIconBG.ImageColor3 =
				Color3.new(rarityColor.R * 0.6 + 0.4, rarityColor.G * 0.6 + 0.4, rarityColor.B * 0.6 + 0.4)
		end

		-- Set rarity bar
		local rarityBar = frame:FindFirstChild("Rarity")
		if rarityBar then
			rarityBar.BackgroundColor3 = rarityColor
			local rarityLabel = rarityBar:FindFirstChildOfClass("TextLabel")
			if rarityLabel then
				rarityLabel.Text = item.Rarity or "Common"
			end
		end

		-- Find UI elements
		local lockedFrame = frame:FindFirstChild("Locked")
		local buyButton = frame:FindFirstChild("BuyButton")
		local limitText = frame:FindFirstChild("Limit")
		local costLabel = frame:FindFirstChild("Cost")

		buttonConnections[item.Name] = {}

		-- Handle locked state
		if item.IsLocked then
			if lockedFrame then
				lockedFrame.Visible = true

				-- Set robux price
				local robuxPrice = Context.getPriceTier(item.Cost)
				local buyRobux = lockedFrame:FindFirstChild("Buy")
				if buyRobux then
					local costText = buyRobux:FindFirstChild("Cost")
					if costText then
						costText.Text = tostring(robuxPrice) .. " R$"
					end

					-- Connect robux purchase
					local connection = Context.connections:connect(buyRobux.Activated, function()
						if not State.purchaseDebounce then
							State.purchaseDebounce = true
							PurchaseEvent:FireServer(item.Name, "Robux")
							task.wait(0.25)
							State.purchaseDebounce = false
						end
					end)
					table.insert(buttonConnections[item.Name], connection)
				end

				-- Update progress bar
				local player = Players.LocalPlayer
				local current = 0
				local required = 0
				local requirementText = ""

				if item.PopulationRequired > 0 then
					required = item.PopulationRequired
					local leaderstats = player:FindFirstChild("leaderstats")
					if leaderstats then
						local population = player:FindFirstChild("Data")
							and player.Data.PlayerInfo:FindFirstChild("Population")
						if population then
							current = population.Value
						end
					end
					requirementText = "Reach " .. tostring(required) .. " Population to unlock"
				elseif item.RebirthRequired > 0 then
					required = item.RebirthRequired
					local leaderstats = player:FindFirstChild("leaderstats")
					if leaderstats then
						local rebirths = leaderstats:FindFirstChild("Rebirths")
						if rebirths then
							current = rebirths.Value
						end
					end
					local rebirthText = required == 1 and " Rebirth" or " Rebirths"
					requirementText = "Reach " .. tostring(required) .. rebirthText .. " to unlock"
				end

				-- Set progress bar
				local progressBar = lockedFrame:FindFirstChild("ProgressBar")
				if progressBar then
					local requiredLabel = progressBar:FindFirstChild("Required")
					if requiredLabel then
						requiredLabel.Text = tostring(current) .. " / " .. tostring(required)
					end

					local fill = progressBar:FindFirstChild("Fill")
					if fill then
						local progress = required > 0 and math.clamp(current / required, 0, 1) or 0
						fill.Size = UDim2.new(progress, 0, 1, 0)
					end
				end

				local infoLabel = lockedFrame:FindFirstChild("Info")
				if infoLabel then
					infoLabel.Text = requirementText
				end
			end

			if buyButton then
				buyButton.Visible = false
			end
			if limitText then
				limitText.Visible = false
			end
			if costLabel then
				costLabel.Visible = false
			end
		else
			-- Unlocked state
			if lockedFrame then
				lockedFrame.Visible = false
			end
			if buyButton then
				buyButton.Visible = true
			end
			if limitText then
				limitText.Visible = true
			end

			-- Set cost
			if costLabel then
				if item.Stock == 0 then
					costLabel.Text = "NO STOCK"
					costLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
					local costStroke = costLabel:FindFirstChild("UIStroke")
					if costStroke then
						costStroke.Color = Color3.fromRGB(100, 30, 30)
					end
				else
					costLabel.Text = Context.formatCash(item.Cost)
					costLabel.TextColor3 = Color3.fromRGB(68, 255, 11)
					local costStroke = costLabel:FindFirstChild("UIStroke")
					if costStroke then
						costStroke.Color = Color3.fromRGB(31, 106, 5)
					end
				end
				costLabel.Visible = true
			end

			-- Set stock
			if limitText then
				limitText.Text = tostring(item.Stock) .. "x STOCK"
				limitText.TextColor3 = Color3.fromRGB(226, 226, 226)
			end

			-- Connect buy button
			if buyButton then
				local connection = Context.connections:connect(buyButton.Activated, function()
					if item.Stock == 0 then
						return
					end

					-- Handle purchase frame
					if State.currentPurchaseFrame and State.currentPurchaseItem ~= item.Name then
						State.currentPurchaseFrame:Destroy()
						State.currentPurchaseFrame = nil
					end

					if State.currentPurchaseFrame and State.currentPurchaseItem == item.Name then
						State.currentPurchaseFrame:Destroy()
						State.currentPurchaseFrame = nil
						State.currentPurchaseItem = nil
						return
					end

					local purchaseFrame = State.PurchaseFrameTemplate:Clone()
					purchaseFrame.Name = "PurchaseFrame_" .. item.Name
					purchaseFrame.Visible = true
					purchaseFrame.LayoutOrder = frame.LayoutOrder + 1
					purchaseFrame.Parent = State.ItemList

					State.currentPurchaseFrame = purchaseFrame
					State.currentPurchaseItem = item.Name

					Context.updatePurchaseFrame(purchaseFrame, item)

					-- Connect purchase buttons
					Context.connections:connect(purchaseFrame.Buttons.Buy.Activated, function()
						if item.Stock > 0 and not State.purchaseDebounce then
							State.purchaseDebounce = true
							PurchaseEvent:FireServer(item.Name, "Cash")
							task.wait(0.25)
							State.purchaseDebounce = false
						end
					end)

					Context.connections:connect(purchaseFrame.Buttons.RobuxBuy.Activated, function()
						if not State.purchaseDebounce then
							State.purchaseDebounce = true
							PurchaseEvent:FireServer(item.Name, "Robux")
							task.wait(0.25)
							State.purchaseDebounce = false
						end
					end)
				end)
				table.insert(buttonConnections[item.Name], connection)
			end
		end

		return frame
	end

	function Context.updateShopDisplay(stock, timer, isInitialLoad)
		State.currentStockList = stock

		-- Close purchase frame
		if State.currentPurchaseFrame then
			State.currentPurchaseFrame:Destroy()
			State.currentPurchaseFrame = nil
			State.currentPurchaseItem = nil
		end

		-- Sort items
		table.sort(stock, function(a, b)
			if a.IsLocked ~= b.IsLocked then
				return not a.IsLocked
			end

			if not a.IsLocked and not b.IsLocked then
				local aIsDecoration = a.IsDecoration or false
				local bIsDecoration = b.IsDecoration or false
				if aIsDecoration ~= bIsDecoration then
					return not aIsDecoration
				end
			end

			if a.Cost ~= b.Cost then
				return a.Cost < b.Cost
			end

			local rarityOrder = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5, Mythic = 6 }
			local aOrder = rarityOrder[a.Rarity] or 7
			local bOrder = rarityOrder[b.Rarity] or 7
			return aOrder < bOrder
		end)

		-- Clear existing items
		for _, child in pairs(State.ItemList:GetChildren()) do
			if child:IsA("Frame") and child.Name ~= "ItemTemplate" then
				Context.clearButtonConnections(child.Name)
				child:Destroy()
			end
		end

		-- Create items
		for i, item in ipairs(stock) do
			local frame = Context.createItemFrame(item)
			frame.LayoutOrder = i * 2
			frame.Parent = State.ItemList
		end

		Context.startResetCountdown(timer)

		if not isInitialLoad then
			local NotificationController =
				require(script.Parent.Parent.Parent:WaitForChild("ui"):WaitForChild("NotificationController"))
			NotificationController.showNotification("StockRefreshed", "Shop Restocked!")
		end
	end
end
