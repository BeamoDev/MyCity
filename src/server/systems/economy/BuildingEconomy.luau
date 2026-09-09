-- Shared by accrual and building information: one formula for each displayed rate.
local Economy = {}
local function value(config, name, default)
	local item = config and config:FindFirstChild(name)
	return if item then item.Value else default
end

function Economy.income(definition, config)
	local level = math.clamp(value(config, "BuildingLevel", 1), 1, 99)
	local crime = math.clamp(value(config, "CrimePercent", 15), 0, 100)
	local happiness = math.clamp(value(config, "HappinessPercent", 75), 0, 100)
	local base = math.floor((definition.Income or 0) * (1 + math.log(level) / math.log(99)))
	local crimeMultiplier = math.max(0.2, 1 - math.max(0, crime - 20) * 0.02)
	return math.floor(base * crimeMultiplier * (0.8 + happiness / 100 * 0.4))
end

function Economy.population(definition, config)
	local level = math.clamp(value(config, "BuildingLevel", 1), 1, 99)
	local happiness = math.clamp(value(config, "HappinessPercent", 75), 0, 100)
	return math.floor((definition.Population or 0) * (1 + (level - 1) * 0.1) * (0.5 + happiness / 100 * 0.75))
end

return Economy
