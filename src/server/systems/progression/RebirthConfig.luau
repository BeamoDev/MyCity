-- RebirthConfig.lua
local RebirthConfig = {}

-- No max rebirth - infinite progression
RebirthConfig.Multipliers = {
	incomePerRebirth = 0.15,
	populationPerRebirth = 0.15,
	xpPerRebirth = 0.15,
}

-- Population requirement scaling

function RebirthConfig.getStartingCash(rebirthLevel)
	return math.floor(10000 * (1 + rebirthLevel * 0.5))
end

function RebirthConfig.getRequiredPopulation(rebirthLevel)
	-- Gentle early steps, converging to the former level-50 requirement.
	local early = { 100, 300, 650, 1200, 2000, 3200, 5000, 7500, 11000, 16000 }
	rebirthLevel = math.max(1, math.floor(rebirthLevel))
	if rebirthLevel <= #early then
		return early[rebirthLevel]
	end
	if rebirthLevel <= 50 then
		return math.floor((16000 + (142000 - 16000) * ((rebirthLevel - 10) / 40) ^ 1.15) / 100) * 100
	end
	return math.ceil(142000 * 1.15 ^ (rebirthLevel - 50))
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

	local meetsPopulation = population.Value < math.huge and population.Value >= requiredPopulation
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
