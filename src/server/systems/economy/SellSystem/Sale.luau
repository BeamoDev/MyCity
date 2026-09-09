-- Sale: focused implementation for SellSystem.
return function(Context)
	local State = Context.State
	local SellSystem = Context.SellSystem
	local ReplicatedStorage = Context.ReplicatedStorage
	local SellEvents = Context.SellEvents

	function SellSystem.sellBuilding(player, buildingType)
		local tool = player.Character and player.Character:FindFirstChildWhichIsA("Tool")

		if not tool or tool.Name ~= buildingType then
			SellEvents.ErrorEvent:FireClient(player, "Tool mismatch")
			return false
		end

		local canSell, reason = SellSystem.canSellTool(player, tool)
		if not canSell then
			if reason == "Must place building first" then
				SellEvents.MustBuildBuilding:FireClient(player)
			else
				SellEvents.ErrorEvent:FireClient(player, reason)
			end
			return false
		end

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

		local sellValue = SellSystem.calculateSellValue(buildingType, level, xp, mutation)

		local BuildingConfig =
			require(script.Parent.Parent.Parent.Parent:WaitForChild("config"):WaitForChild("BuildingConfig"))
		local buildingConfig = BuildingConfig[buildingType]
		local originalCost = buildingConfig and buildingConfig.Cost or 0
		local profit = sellValue - originalCost

		local leaderstats = player:FindFirstChild("leaderstats")
		local cash = leaderstats and leaderstats:FindFirstChild("Cash")
		if cash then
			cash.Value = cash.Value + sellValue
		end

		ReplicatedStorage.Events.Movement.CleanupPreview:FireClient(player)

		tool:Destroy()
		require(script.Parent.Parent.InventorySystem).saveInventory(player)

		SellEvents.SoldWithProfit:FireClient(player, sellValue, buildingType, profit, level)

		ReplicatedStorage.Events.Movement.CleanupPreview:FireClient(player)

		return true
	end
end
