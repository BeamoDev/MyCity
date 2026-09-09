-- Progression: focused implementation for BuildingXP.
return function(Context)
	local State = Context.State
	local BuildingXP = Context.BuildingXP
	local MAX_LEVEL = Context.MAX_LEVEL
	local BASE_XP_REQUIREMENT = Context.BASE_XP_REQUIREMENT
	local XP_SCALING_FACTOR = Context.XP_SCALING_FACTOR
	local XP_MULTIPLIERS = Context.XP_MULTIPLIERS

	function BuildingXP.getXPRequiredForLevel(level)
		if level <= 1 then
			return 0
		end
		if level > MAX_LEVEL then
			return math.huge
		end

		return math.floor(BASE_XP_REQUIREMENT * (XP_SCALING_FACTOR ^ (level - 1)))
	end

	function BuildingXP.getTotalXPForLevel(level)
		if level <= 1 then
			return 0
		end
		if level > MAX_LEVEL then
			return math.huge
		end

		local totalXP = 0
		for i = 2, level do
			totalXP = totalXP + BuildingXP.getXPRequiredForLevel(i)
		end
		return totalXP
	end

	function BuildingXP.getLevelFromTotalXP(totalXP)
		if totalXP <= 0 then
			return 1
		end

		local level = 1
		local currentXP = 0

		while level < MAX_LEVEL do
			local nextLevelXP = BuildingXP.getXPRequiredForLevel(level + 1)
			if currentXP + nextLevelXP > totalXP then
				break
			end
			currentXP = currentXP + nextLevelXP
			level = level + 1
		end

		return level
	end

	function BuildingXP.getXPMultiplierForBuilding(buildingType, player)
		local BuildingConfig =
			require(script.Parent.Parent.Parent.Parent.Parent:WaitForChild("config"):WaitForChild("BuildingConfig"))
		local buildingInfo = BuildingConfig[buildingType]
		if not buildingInfo then
			return 1
		end
		local cost = buildingInfo.Cost
		local highestTier = 0
		for tier, multiplier in pairs(XP_MULTIPLIERS) do
			if cost >= tier and tier > highestTier then
				highestTier = tier
			end
		end
		local baseMultiplier = XP_MULTIPLIERS[highestTier] or 1
		-- Apply rebirth XP multiplier directly
		local multipliers = State.RebirthConfig.getPlayerMultipliers(player)
		return baseMultiplier * multipliers.xp
	end
end
