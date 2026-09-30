-- Roads supply capacity; completed buildings and population add demand.
local Density = {}

function Density.desired(roads, buildings, population, perCityLimit)
	roads = math.max(0, tonumber(roads) or 0)
	buildings = math.max(0, tonumber(buildings) or 0)
	population = math.max(0, tonumber(population) or 0)
	if roads < 2 then
		return 0
	end

	local roadCapacity = math.max(1, math.floor(roads / 2))
	local roadDemand = math.max(1, math.floor(roads / 4))
	local developmentDemand = math.floor(buildings / 8)
	local populationDemand = math.floor(math.sqrt(population) / 30)
	return math.min(perCityLimit, roadCapacity, roadDemand + developmentDemand + populationDemand)
end

function Density.allocate(desired, globalLimit, perCityLimit)
	local result, remaining = {}, globalLimit
	for index in desired do
		result[index] = 0
	end
	for _ = 1, perCityLimit do
		for index, count in desired do
			if remaining > 0 and result[index] < count then
				result[index] += 1
				remaining -= 1
			end
		end
	end
	return result
end

return Density
