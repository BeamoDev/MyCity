-- The post-tutorial quest chain, in order. Saved progress is the index of the highest completed
-- quest, so NEVER reorder or remove entries; only append new quests at the end.
--
-- kind:
--   collect      income collections (counted as they happen)
--   construct    non-road buildings completed/placed (counted as they happen)
--   buildings    non-road buildings in the city now (minRarity: count only that rarity or better)
--   roads        road pieces in the city now
--   population   current population
--   cash         current cash
--   rebirths     total rebirths
--   land         owned land tiles
-- reward: { type = "cash", amount = n } or { type = "building", building = "<BuildingConfig name>" }
local function cash(amount)
	return { type = "cash", amount = amount }
end
local function building(name)
	return { type = "building", building = name }
end

return {
	-- Original five (keep first, in this order).
	{ id = "collect_income", kind = "collect", title = "Collect Income", required = 1, reward = cash(500) },
	{ id = "construct_buildings", kind = "construct", title = "Construct 3 buildings", required = 3, reward = cash(1000) },
	{ id = "buildings_total", kind = "buildings", title = "Have 8 buildings placed", required = 8, reward = building("SheriffOffice") },
	{ id = "place_roads", kind = "roads", title = "Place 5 road pieces", required = 5, reward = cash(2000) },
	{ id = "population", kind = "population", title = "Reach 100 population", required = 100, reward = building("Apartments") },

	-- Growing town.
	{ id = "collect_10", kind = "collect", title = "Collect income 10 times", required = 10, reward = cash(1500) },
	{ id = "roads_15", kind = "roads", title = "Place 15 road pieces", required = 15, reward = cash(2500) },
	{ id = "construct_5", kind = "construct", title = "Construct 5 more buildings", required = 5, reward = cash(3000) },
	{ id = "population_300", kind = "population", title = "Reach 300 population", required = 300, reward = building("CozyHouse") },
	{ id = "buildings_15", kind = "buildings", title = "Have 15 buildings placed", required = 15, reward = cash(5000) },
	{ id = "land_6", kind = "land", title = "Own 6 land tiles", required = 6, reward = cash(6000) },
	{ id = "population_650", kind = "population", title = "Reach 650 population", required = 650, reward = building("FireStation") },
	{ id = "cash_25k", kind = "cash", title = "Have $25,000 cash", required = 25000, reward = building("RowHouses") },
	{ id = "collect_25", kind = "collect", title = "Collect income 25 times", required = 25, reward = cash(8000) },
	{
		id = "uncommon_3",
		kind = "buildings",
		minRarity = "Uncommon",
		title = "Have 3 Uncommon or better buildings",
		required = 3,
		reward = cash(10000),
	},

	-- Busy city.
	{ id = "roads_30", kind = "roads", title = "Place 30 road pieces", required = 30, reward = cash(10000) },
	{ id = "population_1200", kind = "population", title = "Reach 1,200 population", required = 1200, reward = building("PoliceStation") },
	{ id = "construct_15", kind = "construct", title = "Construct 15 more buildings", required = 15, reward = cash(15000) },
	{ id = "land_10", kind = "land", title = "Own 10 land tiles", required = 10, reward = cash(20000) },
	{ id = "rebirth_1", kind = "rebirths", title = "Rebirth once", required = 1, reward = cash(25000) },
	{ id = "buildings_25", kind = "buildings", title = "Have 25 buildings placed", required = 25, reward = cash(25000) },
	{ id = "population_2000", kind = "population", title = "Reach 2,000 population", required = 2000, reward = building("Hotel") },
	{
		id = "rare_2",
		kind = "buildings",
		minRarity = "Rare",
		title = "Have 2 Rare or better buildings",
		required = 2,
		reward = cash(40000),
	},
	{ id = "collect_50", kind = "collect", title = "Collect income 50 times", required = 50, reward = cash(40000) },
	{ id = "cash_150k", kind = "cash", title = "Have $150,000 cash", required = 150000, reward = building("School") },

	-- Metropolis.
	{ id = "population_3200", kind = "population", title = "Reach 3,200 population", required = 3200, reward = cash(60000) },
	{ id = "land_16", kind = "land", title = "Own 16 land tiles", required = 16, reward = cash(75000) },
	{ id = "construct_30", kind = "construct", title = "Construct 30 more buildings", required = 30, reward = cash(80000) },
	{ id = "rebirth_3", kind = "rebirths", title = "Reach 3 rebirths", required = 3, reward = building("Hospital") },
	{ id = "population_5000", kind = "population", title = "Reach 5,000 population", required = 5000, reward = cash(120000) },
	{ id = "buildings_40", kind = "buildings", title = "Have 40 buildings placed", required = 40, reward = cash(150000) },
	{
		id = "epic_1",
		kind = "buildings",
		minRarity = "Epic",
		title = "Have an Epic or better building",
		required = 1,
		reward = cash(200000),
	},
	{ id = "population_7500", kind = "population", title = "Reach 7,500 population", required = 7500, reward = building("Mansion") },
	{ id = "rebirth_5", kind = "rebirths", title = "Reach 5 rebirths", required = 5, reward = cash(300000) },
	{ id = "population_11000", kind = "population", title = "Reach 11,000 population", required = 11000, reward = cash(500000) },
}
