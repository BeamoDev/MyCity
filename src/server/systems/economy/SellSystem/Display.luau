-- Display: focused implementation for SellSystem.
return function(Context)
	local State = Context.State
	local SellSystem = Context.SellSystem
	local UpdateUIEvent = Context.UpdateUIEvent

	function SellSystem.updateSellUI(player)
		local tool = player.Character and player.Character:FindFirstChildWhichIsA("Tool")

		if not tool then
			UpdateUIEvent:FireClient(player, nil, 0, 0, false, "Equip a building tool")
			return
		end

		local canSell, reason = SellSystem.canSellTool(player, tool)
		local BuildingConfig =
			require(script.Parent.Parent.Parent.Parent:WaitForChild("config"):WaitForChild("BuildingConfig"))
		local buildingConfig = BuildingConfig[tool.Name]

		if not buildingConfig then
			UpdateUIEvent:FireClient(player, tool, 0, 0, false, "Unknown building type")
			return
		end

		local sellValue = 0
		local statusText = reason

		if canSell then
			local level = 1
			local xp = 0
			local mutation = ""

			local toolLevel = tool:FindFirstChild("BuildingLevel")
			local toolXP = tool:FindFirstChild("BuildingXP")
			local toolMutation = tool:FindFirstChild("Mutation")

			if toolLevel then
				level = toolLevel.Value
			end
			if toolXP then
				xp = toolXP.Value
			end
			if toolMutation then
				mutation = toolMutation.Value
			end

			sellValue = SellSystem.calculateSellValue(tool.Name, level, xp, mutation)

			local profit = sellValue - buildingConfig.Cost
			local profitPercent = (profit / buildingConfig.Cost) * 100
			statusText = string.format("+$%d (%.0f%% profit)", profit, profitPercent)
		end

		UpdateUIEvent:FireClient(player, tool, sellValue, buildingConfig.ImageId, canSell, statusText)
	end
end
