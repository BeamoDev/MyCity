-- KingdomWars animation defaults with a slower city walking pace; counts are cosmetic only.
local Config = {
	PerCityLimit = 10,
	ServerLimit = 80,
	WalkSpeed = 1.5,
	PauseMin = 0.35,
	PauseMax = 0.9,
	SyncInterval = 1,
	StepInterval = 0.1,
	PathInterval = 0.25,
	StuckSeconds = 2.4,
	ArrivalDistance = 1.1,
	MaxStuckRetries = 3,
	MaxIdleSeconds = 15,
	AnimationIds = {
		R6 = { Idle = "rbxassetid://180435571", Walk = "rbxassetid://180426354" },
		R15 = { Idle = "rbxassetid://507766666", Walk = "rbxassetid://507777826" },
	},
}
function Config.desired(buildings, roads, population)
	buildings = math.max(0, tonumber(buildings) or 0)
	roads = math.max(0, tonumber(roads) or 0)
	population = math.max(0, tonumber(population) or 0)
	if buildings <= 0 and roads <= 0 and population <= 0 then
		return 0
	end
	local development = math.floor(buildings / 3)
	local streetActivity = math.floor(roads / 5)
	local residents = math.floor(math.sqrt(population) / 12)
	return math.min(Config.PerCityLimit, math.max(1, 1 + development + streetActivity + residents))
end
-- Share the global budget across cities instead of starving later players.
function Config.allocate(counts)
	local result, remaining = {}, Config.ServerLimit
	for i in counts do
		result[i] = 0
	end
	for _ = 1, Config.PerCityLimit do
		for i, count in counts do
			if remaining > 0 and result[i] < count then
				result[i] += 1
				remaining -= 1
			end
		end
	end
	return result
end
return Config
