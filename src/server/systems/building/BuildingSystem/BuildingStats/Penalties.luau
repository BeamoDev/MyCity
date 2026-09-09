-- Penalties: focused implementation for BuildingStats.
return function(Context)
	local State = Context.State
	local BuildingStats = Context.BuildingStats
	local CRIME_INCOME_PENALTY = Context.CRIME_INCOME_PENALTY
	local FIRE_INCOME_PENALTY = Context.FIRE_INCOME_PENALTY

	function BuildingStats.getHealthPenalty(healthPercent)
		if healthPercent >= 80 then
			return 1
		end
		if healthPercent >= 60 then
			return 0.99
		end
		if healthPercent >= 40 then
			return 0.97
		end
		return 0.95
	end

	-- Get income penalties

	function BuildingStats.getCrimePenalty(crimePercent)
		if crimePercent <= 20 then
			return 1
		end
		local excessCrime = crimePercent - 20
		local penalty = 1 - (excessCrime * CRIME_INCOME_PENALTY)
		return math.max(penalty, 0.2)
	end

	function BuildingStats.getFireSafetyPenalty(fireSafetyPercent)
		if fireSafetyPercent >= 60 then
			return 1
		end
		local safetyDeficit = 60 - fireSafetyPercent
		local penalty = 1 - (safetyDeficit * FIRE_INCOME_PENALTY)
		return math.max(penalty, 0.3)
	end

	function BuildingStats.init()
		-- Initialization if needed
	end
end
