local State = {}
local BuildingStats = {}
local Snapshot = require(script.Snapshot)
local Catalog = require(script.Parent.Parent.Parent.Parent.config.BuildingConfig)

-- Configuration constants
local BASE_CRIME_RATE = 0
local MAX_CRIME_RATE = 85
local BASE_HAPPINESS = 75
local BASE_FIRE_SAFETY = 80
local MIN_FIRE_SAFETY = 20
local CRIME_INCOME_PENALTY = 0.01
local FIRE_INCOME_PENALTY = 0.008
local DECORATION_HAPPINESS_RANGE = 30 -- Range for decoration happiness boost
local DECORATION_HAPPINESS_BOOST = 15 -- Max happiness boost from single decoration

local BUILDING_RANGES = {
	["PoliceStation"] = 30,
	["FireStation"] = 30,
	["Hospital"] = 30, -- ADD THIS
	["SheriffOffice"] = 20,
	["FireShed"] = 20,
	["Clinic"] = 20, -- ADD THIS
}

-- Calculate happiness boost from nearby decorations

local Context = {
	State = State,
	Snapshot = Snapshot,
	createSnapshot = function(plot)
		return Snapshot.create(plot, Catalog, BUILDING_RANGES)
	end,
	BuildingStats = BuildingStats,
	BASE_CRIME_RATE = BASE_CRIME_RATE,
	MAX_CRIME_RATE = MAX_CRIME_RATE,
	BASE_HAPPINESS = BASE_HAPPINESS,
	BASE_FIRE_SAFETY = BASE_FIRE_SAFETY,
	MIN_FIRE_SAFETY = MIN_FIRE_SAFETY,
	CRIME_INCOME_PENALTY = CRIME_INCOME_PENALTY,
	FIRE_INCOME_PENALTY = FIRE_INCOME_PENALTY,
	DECORATION_HAPPINESS_RANGE = DECORATION_HAPPINESS_RANGE,
	DECORATION_HAPPINESS_BOOST = DECORATION_HAPPINESS_BOOST,
	BUILDING_RANGES = BUILDING_RANGES,
}
require(script:WaitForChild("Health"))(Context)
require(script:WaitForChild("Safety"))(Context)
require(script:WaitForChild("Happiness"))(Context)
require(script:WaitForChild("Aggregation"))(Context)
require(script:WaitForChild("Penalties"))(Context)

return BuildingStats
