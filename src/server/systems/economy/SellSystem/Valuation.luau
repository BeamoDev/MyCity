-- Valuation: focused implementation for SellSystem.
return function(Context)
	local State = Context.State
	local SellSystem = Context.SellSystem
	local BASE_PROFIT_MARGINS = Context.BASE_PROFIT_MARGINS
	local LEVEL_VALUE_SCALING = Context.LEVEL_VALUE_SCALING
	local XP_VALUE_SCALING = Context.XP_VALUE_SCALING
	local MUTATION_BONUSES = Context.MUTATION_BONUSES
	local SPECIAL_BUILDING_MULTIPLIERS = Context.SPECIAL_BUILDING_MULTIPLIERS

	function SellSystem.canSellTool(player, tool)
		if not tool then
			return false, "No tool equipped"
		end

		local isValid = tool:FindFirstChild("IsValid")
		if not isValid or not isValid.Value then
			return false, "Must place building first"
		end

		return true, ""
	end

	function SellSystem.calculateSellValue(buildingType, level, xp, mutation)
		local BuildingConfig =
			require(script.Parent.Parent.Parent.Parent:WaitForChild("config"):WaitForChild("BuildingConfig"))
		local buildingConfig = BuildingConfig[buildingType]
		if not buildingConfig then
			return 0
		end

		local originalCost = buildingConfig.Cost
		local rarity = buildingConfig.Rarity or "Common"

		local baseMultiplier = BASE_PROFIT_MARGINS[rarity] or 1.15

		local levelBonus = (level - 1) * (LEVEL_VALUE_SCALING[rarity] or 0.08)

		local xpBonus = 0
		if xp > 0 and level < 99 then
			local BuildingSystem =
				require(script.Parent.Parent.Parent:WaitForChild("building"):WaitForChild("BuildingSystem"))
			local currentLevelXP = BuildingSystem.getTotalXPForLevel(level)
			local nextLevelXP = BuildingSystem.getTotalXPForLevel(level + 1)
			local xpProgress = (xp - currentLevelXP) / (nextLevelXP - currentLevelXP)
			xpBonus = xpProgress * XP_VALUE_SCALING
		end

		local mutationBonus = 0
		if mutation and mutation ~= "" then
			mutationBonus = MUTATION_BONUSES[mutation] or 0.15
		end

		local specialMultiplier = SPECIAL_BUILDING_MULTIPLIERS[buildingType] or 1.0

		local totalMultiplier = baseMultiplier
			* (1 + levelBonus)
			* (1 + xpBonus)
			* (1 + mutationBonus)
			* specialMultiplier

		local sellValue = math.floor(originalCost * totalMultiplier + 0.5)

		local minimumValue = math.floor(originalCost * 1.1)
		sellValue = math.max(sellValue, minimumValue)

		return sellValue
	end

	function SellSystem.getDetailedSellBreakdown(buildingType, level, xp, mutation)
		local BuildingConfig =
			require(script.Parent.Parent.Parent.Parent:WaitForChild("config"):WaitForChild("BuildingConfig"))
		local buildingConfig = BuildingConfig[buildingType]
		if not buildingConfig then
			return nil
		end

		local originalCost = buildingConfig.Cost
		local rarity = buildingConfig.Rarity or "Common"
		local sellValue = SellSystem.calculateSellValue(buildingType, level, xp, mutation)

		local breakdown = {
			OriginalCost = originalCost,
			SellValue = sellValue,
			Profit = sellValue - originalCost,
			ProfitPercent = ((sellValue - originalCost) / originalCost) * 100,
			Rarity = rarity,
			Level = level,
			Mutation = mutation or "None",
			Bonuses = {},
		}

		local baseProfit = (BASE_PROFIT_MARGINS[rarity] - 1) * 100
		table.insert(breakdown.Bonuses, { Type = "Base " .. rarity, Value = baseProfit .. "%" })

		if level > 1 then
			local levelBonus = (level - 1) * (LEVEL_VALUE_SCALING[rarity] or 0.08) * 100
			table.insert(breakdown.Bonuses, { Type = "Level " .. level, Value = string.format("%.1f%%", levelBonus) })
		end

		if xp > 0 and level < 99 then
			local BuildingSystem =
				require(script.Parent.Parent.Parent:WaitForChild("building"):WaitForChild("BuildingSystem"))
			local currentLevelXP = BuildingSystem.getTotalXPForLevel(level)
			local nextLevelXP = BuildingSystem.getTotalXPForLevel(level + 1)
			local xpProgress = (xp - currentLevelXP) / (nextLevelXP - currentLevelXP)
			local xpBonus = xpProgress * XP_VALUE_SCALING * 100
			if xpBonus > 0 then
				table.insert(breakdown.Bonuses, { Type = "XP Progress", Value = string.format("%.1f%%", xpBonus) })
			end
		end

		if mutation and mutation ~= "" then
			local mutationBonus = (MUTATION_BONUSES[mutation] or 0.15) * 100
			table.insert(breakdown.Bonuses, { Type = mutation .. " Mutation", Value = mutationBonus .. "%" })
		end

		if SPECIAL_BUILDING_MULTIPLIERS[buildingType] then
			local specialBonus = (SPECIAL_BUILDING_MULTIPLIERS[buildingType] - 1) * 100
			table.insert(breakdown.Bonuses, { Type = "Special Building", Value = specialBonus .. "%" })
		end

		return breakdown
	end
end
