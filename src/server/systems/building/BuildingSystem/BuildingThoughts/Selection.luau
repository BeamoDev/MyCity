-- Selection: focused implementation for BuildingThoughts.
return function(Context)
	local State = Context.State
	local plotsFolder = Context.plotsFolder
	local MAX_CONCURRENT_THOUGHTS = Context.MAX_CONCURRENT_THOUGHTS

	function Context.getThoughtCategory(crimePercent, happinessPercent, fireSafetyPercent, healthPercent)
		-- Very direct priority: tell player exactly what they need
		if crimePercent > 40 then
			return "crime" -- Need police
		elseif fireSafetyPercent < 50 then
			return "fire" -- Need fire station
		elseif healthPercent < 50 then
			return "health" -- Need hospital
		elseif happinessPercent < 60 then
			return "unhappy" -- Need trees/decorations
		elseif happinessPercent >= 85 and crimePercent <= 20 and fireSafetyPercent >= 80 and healthPercent >= 80 then
			return "happy"
		else
			return "neutral"
		end
	end

	function Context.isResidentialBuilding(building)
		local BuildingConfig =
			require(script.Parent.Parent.Parent.Parent.Parent:WaitForChild("config"):WaitForChild("BuildingConfig"))
		local buildingType = building:GetAttribute("BuildingType")

		if not buildingType then
			return false
		end

		local config = BuildingConfig[buildingType]
		if not config then
			return false
		end

		if config.Industry == "Residential" and not config.IsDecoration then
			return true
		end

		return false
	end

	function Context.selectRandomBuildings()
		local allResidentialBuildings = {}

		-- Collect all residential buildings
		for _, plot in pairs(plotsFolder:GetChildren()) do
			local placedFolder = plot.Buildings:FindFirstChild("Placed")
			if placedFolder then
				for _, building in pairs(placedFolder:GetChildren()) do
					if Context.isResidentialBuilding(building) then
						table.insert(allResidentialBuildings, building)
					end
				end
			end
		end

		if #allResidentialBuildings == 0 then
			return
		end

		-- Calculate how many thoughts to show
		local maxThoughts = math.max(1, math.floor(#allResidentialBuildings * MAX_CONCURRENT_THOUGHTS))
		local currentThoughtCount = 0

		for _, data in pairs(State.activeThoughts) do
			currentThoughtCount = currentThoughtCount + 1
		end

		local thoughtsToAdd = maxThoughts - currentThoughtCount

		if thoughtsToAdd <= 0 then
			return
		end

		-- Randomly select buildings
		local availableBuildings = {}
		for _, building in ipairs(allResidentialBuildings) do
			if not State.activeThoughts[building] then
				table.insert(availableBuildings, building)
			end
		end

		for i = 1, math.min(thoughtsToAdd, #availableBuildings) do
			local randomIndex = math.random(1, #availableBuildings)
			local building = availableBuildings[randomIndex]

			task.spawn(function()
				Context.showThought(building)
			end)

			table.remove(availableBuildings, randomIndex)
		end
	end
end
