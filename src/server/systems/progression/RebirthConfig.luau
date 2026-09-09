-- RebirthConfig.lua
local RebirthConfig = {}

-- No max rebirth - infinite progression
RebirthConfig.Multipliers = {
	incomePerRebirth = 0.15,
	populationPerRebirth = 0.15,
	xpPerRebirth = 0.15,
}

-- Population requirement scaling
local BASE_POPULATION = 100
local MAX_POPULATION = 150000

function RebirthConfig.getStartingCash(rebirthLevel)
	return math.floor(10000 * (1 + rebirthLevel * 0.5))
end

function RebirthConfig.getRequiredPopulation(rebirthLevel)
	-- Preserve the original first 50 requirements, then keep growing. A retained
	-- city must not unlock infinitely many rebirths at the old plateau.
	if rebirthLevel > 50 then
		return math.ceil(RebirthConfig.getRequiredPopulation(50) * 1.15 ^ (rebirthLevel - 50))
	end
	if rebirthLevel <= 1 then
		return BASE_POPULATION
	end

	-- Use a logarithmic curve that approaches MAX_POPULATION asymptotically
	-- This creates fast growth early, then slows down significantly
	local progress = math.min(rebirthLevel / 50, 1) -- Normalize to 0-1 over 50 rebirths

	-- Use a curve that grows quickly at first then levels off
	local curve = 1 - math.exp(-3 * progress) -- Exponential approach to 1

	-- Scale between BASE and MAX
	local required = BASE_POPULATION + (MAX_POPULATION - BASE_POPULATION) * curve

	-- Round to nice numbers
	if required < 1000 then
		required = math.floor(required / 10) * 10
	elseif required < 10000 then
		required = math.floor(required / 100) * 100
	elseif required < 50000 then
		required = math.floor(required / 500) * 500
	else
		required = math.floor(required / 1000) * 1000
	end

	-- Ensure we never exceed max
	return math.min(required, MAX_POPULATION)
end

function RebirthConfig.canRebirth(player, currentRebirths)
	local nextRebirth = currentRebirths + 1
	local requiredPopulation = RebirthConfig.getRequiredPopulation(nextRebirth)

	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		return false, { population = requiredPopulation }, false
	end

	local population = player:FindFirstChild("Data") and player.Data.PlayerInfo:FindFirstChild("Population")
	if not population then
		return false, { population = requiredPopulation }, false
	end

	local meetsPopulation = population.Value >= requiredPopulation
	return meetsPopulation, { population = requiredPopulation }, meetsPopulation
end

function RebirthConfig.getPlayerMultipliers(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		return { income = 1, population = 1, xp = 1 }
	end

	local rebirths = leaderstats:FindFirstChild("Rebirths")
	if not rebirths then
		return { income = 1, population = 1, xp = 1 }
	end

	return RebirthConfig.getMultipliers(rebirths.Value)
end

function RebirthConfig.getMultipliers(rebirths)
	return {
		income = 1 + (rebirths * RebirthConfig.Multipliers.incomePerRebirth),
		population = 1 + (rebirths * RebirthConfig.Multipliers.populationPerRebirth),
		xp = 1 + (rebirths * RebirthConfig.Multipliers.xpPerRebirth),
	}
end

return RebirthConfig
