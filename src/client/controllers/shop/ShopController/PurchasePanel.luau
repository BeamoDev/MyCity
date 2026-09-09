-- PurchasePanel: focused implementation for ShopController.
return function(Context)
	local State = Context.State
	local buttonConnections = Context.buttonConnections

	function Context.clearButtonConnections(itemName)
		if buttonConnections[itemName] then
			for _, connection in pairs(buttonConnections[itemName]) do
				connection:Disconnect()
			end
			buttonConnections[itemName] = nil
		end
	end

	function Context.updatePurchaseFrame(purchaseFrame, item)
		local cashBuyButton = purchaseFrame.Buttons:FindFirstChild("Buy")
		if cashBuyButton then
			local cashPriceLabel = cashBuyButton:FindFirstChild("TextLabel") or cashBuyButton:FindFirstChild("Cost")
			if cashPriceLabel then
				if item.Stock == 0 then
					cashBuyButton.Visible = false
					cashBuyButton.Active = false
				else
					cashPriceLabel.Text = Context.formatCash(item.Cost)

					cashBuyButton.Visible = true
					cashBuyButton.Active = true
				end
			end
		end

		local robuxBuyButton = purchaseFrame.Buttons:FindFirstChild("RobuxBuy")
		if robuxBuyButton then
			local robuxPriceLabel = robuxBuyButton:FindFirstChild("TextLabel") or robuxBuyButton:FindFirstChild("Cost")
			if robuxPriceLabel then
				local robuxPrice = Context.getPriceTier(item.Cost)
				robuxPriceLabel.Text = tostring(robuxPrice) .. " R$"
			end
		end
	end
end
