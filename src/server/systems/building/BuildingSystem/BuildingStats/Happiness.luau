-- Happiness: focused implementation for BuildingStats.
return function(Context)
	local State = Context.State
	local BASE_HAPPINESS = Context.BASE_HAPPINESS
	local DECORATION_HAPPINESS_RANGE = Context.DECORATION_HAPPINESS_RANGE
	local DECORATION_HAPPINESS_BOOST = Context.DECORATION_HAPPINESS_BOOST

	function Context.getDecorationHappinessBoost(building, plot, snapshot)
		local position = Context.Snapshot.position(building)
		if not position then
			return 0
		end
		snapshot = snapshot or Context.createSnapshot(plot)
		local total = 0
		for _, entry in snapshot.decorations do
			local distance = (position - entry.position).Magnitude
			if distance <= DECORATION_HAPPINESS_RANGE then
				total += DECORATION_HAPPINESS_BOOST * (1 - distance / DECORATION_HAPPINESS_RANGE)
			end
		end
		return math.min(total, 40)
	end

	function Context.calculateHappinessPercent(building, plot, crimePercent, fireSafetyPercent, healthPercent, snapshot)
		local happiness = BASE_HAPPINESS

		-- Crime affects happiness negatively
		happiness = happiness - (crimePercent * 0.5)

		-- Fire safety affects happiness positively
		if fireSafetyPercent >= 80 then
			happiness = happiness + ((fireSafetyPercent - 80) * 0.2)
		elseif fireSafetyPercent < 60 then
			happiness = happiness - ((60 - fireSafetyPercent) * 0.3)
		end

		-- Health affects happiness
		if healthPercent >= 80 then
			happiness = happiness + ((healthPercent - 80) * 0.25)
		elseif healthPercent < 60 then
			happiness = happiness - ((60 - healthPercent) * 0.25)
		end

		-- Building level affects happiness positively
		local configFolder = building:FindFirstChild("Config")
		if configFolder then
			local buildingLevel = configFolder:FindFirstChild("BuildingLevel")
			if buildingLevel then
				happiness = happiness + (buildingLevel.Value * 0.3)
			end
		end

		-- Add decoration happiness boost
		local decorationBoost = Context.getDecorationHappinessBoost(building, plot, snapshot)
		happiness = happiness + decorationBoost

		return math.floor(math.clamp(happiness, 0, 100))
	end

	-- Get comprehensive building statistics
end
