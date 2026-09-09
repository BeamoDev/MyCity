-- Display: focused implementation for RebirthSystem.
return function(Context)
	local State = Context.State
	local RebirthSystem = Context.RebirthSystem
	local RebirthConfig = Context.RebirthConfig
	local BuildingConfig = Context.BuildingConfig
	local updateRebirthUI_ = Context.updateRebirthUI_

	function Context.getOrCreateLeaderRebirths(leaderstats)
		local v = leaderstats:FindFirstChild("Rebirths")
		if v then
			return v
		end

		v = leaderstats:WaitForChild("Rebirths", 5)
		if v then
			return v
		end

		v = Instance.new("IntValue")
		v.Name = "Rebirths"
		v.Value = 0
		v.Parent = leaderstats
		return v
	end

	function RebirthSystem.updateRebirthUI(player)
		local ld = player:FindFirstChild("leaderstats")
		if not ld then
			return
		end

		local rebirths = ld:FindFirstChild("Rebirths")
		if not rebirths then
			return
		end

		local canRebirth, requirements, meetsPopulation = RebirthConfig.canRebirth(player, rebirths.Value)
		local multipliers = RebirthConfig.getMultipliers(rebirths.Value)
		local nextMultipliers = RebirthConfig.getMultipliers(rebirths.Value + 1)

		-- Get unlocked buildings from BuildingConfig
		local unlockedBuildings = {}
		local nextRebirthLevel = rebirths.Value + 1

		for buildingName, info in pairs(BuildingConfig) do
			if info.RebirthRequired == nextRebirthLevel then
				table.insert(unlockedBuildings, {
					name = info.DisplayName or buildingName,
					imageId = info.ImageId or 0,
				})
			end
		end

		table.sort(unlockedBuildings, function(a, b)
			return a.name < b.name
		end)

		updateRebirthUI_:FireClient(player, {
			currentRebirths = rebirths.Value,
			startingCash = RebirthConfig.getStartingCash(rebirths.Value + 1),
			preservesCity = true,
			canRebirth = canRebirth,
			requirements = requirements,
			meetsPopulation = meetsPopulation,
			multipliers = multipliers,
			nextMultipliers = nextMultipliers,
			isMaxRebirth = false, -- Never max since infinite
			unlockedBuildings = unlockedBuildings,
		})
	end
end
