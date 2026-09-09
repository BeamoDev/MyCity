-- Aggregation: focused implementation for BuildingStats.
return function(Context)
	local State = Context.State
	local BuildingStats = Context.BuildingStats
	local BUILDING_RANGES = Context.BUILDING_RANGES

	function BuildingStats.getBuildingStats(building, plot, snapshot)
		local configFolder = building:FindFirstChild("Config")
		if not configFolder then
			return nil
		end

		snapshot = snapshot or Context.createSnapshot(plot)
		local stats = {}

		stats.level = configFolder:FindFirstChild("BuildingLevel") and configFolder.BuildingLevel.Value or 1
		stats.xp = configFolder:FindFirstChild("BuildingXP") and configFolder.BuildingXP.Value or 0
		stats.health = configFolder:FindFirstChild("Health") and configFolder.Health.Value or 100

		-- Calculate all percentages
		stats.crimePercent = Context.calculateCrimePercent(building, plot, snapshot)
		stats.fireSafetyPercent = Context.calculateFireSafetyPercent(building, plot, snapshot)
		stats.healthPercent = Context.calculateHealthPercent(building, plot, snapshot) -- ADD THIS
		stats.happinessPercent = Context.calculateHappinessPercent(
			building,
			plot,
			stats.crimePercent,
			stats.fireSafetyPercent,
			stats.healthPercent,
			snapshot
		)

		local buildingType = building:GetAttribute("BuildingType")
		if BUILDING_RANGES[buildingType] then
			stats.radius = BUILDING_RANGES[buildingType]
		end

		return stats
	end

	-- Update all building stats in a plot

	function BuildingStats.updateBuildingStats(building, plot, snapshot)
		local config = building:FindFirstChild("Config")
		if not config then
			return
		end
		local stats = BuildingStats.getBuildingStats(building, plot, snapshot)
		for field, value in
			{
				CrimePercent = stats.crimePercent,
				FireSafetyPercent = stats.fireSafetyPercent,
				HappinessPercent = stats.happinessPercent,
				HealthPercent = stats.healthPercent,
			}
		do
			local target = config:FindFirstChild(field)
			if target and target.Value ~= value then
				target.Value = value
			end
		end
	end
	function BuildingStats.updatePlotStats(plot, checkpoint)
		local snapshot = Context.createSnapshot(plot)
		for _, building in snapshot.buildings do
			if checkpoint then
				checkpoint()
			end
			if building.Parent then
				BuildingStats.updateBuildingStats(building, plot, snapshot)
			end
		end
	end
end
