local Ownership = require(script.Parent.Parent.Parent.Parent.services.GamePassOwnership)
-- Calculation: focused implementation for IncomeSystem.
local Economy = require(script.Parent.Parent.BuildingEconomy)
return function(Context)
	local State = Context.State
	local IncomeSystem = Context.IncomeSystem
	local Workspace = Context.Workspace
	local MarketplaceService = Context.MarketplaceService
	local RebirthConfig = Context.RebirthConfig
	local CRIME_INCOME_PENALTY = Context.CRIME_INCOME_PENALTY
	local CRIME_THRESHOLD = Context.CRIME_THRESHOLD
	local playerFriendBoosts = Context.playerFriendBoosts
	local DOUBLE_CASH_GAMEPASS_ID = Context.DOUBLE_CASH_GAMEPASS_ID

	function Context.hasDoubleCashGamepass(player)
		return Ownership.has(player, DOUBLE_CASH_GAMEPASS_ID)
	end

	function Context.calculateCrimePenalty(crimePercent)
		if crimePercent <= CRIME_THRESHOLD then
			return 1 -- No penalty
		end

		local excessCrime = crimePercent - CRIME_THRESHOLD
		local penalty = 1 - (excessCrime * CRIME_INCOME_PENALTY)
		return math.max(penalty, 0.2) -- Minimum 20% of original income
	end

	function IncomeSystem.ensureBuildingConfig(building, buildingType)
		if not buildingType then
			buildingType = building:GetAttribute("BuildingType")
			if not buildingType then
				buildingType = string.match(building.Name, "^([^_]+)")
			end
		end

		local configFolder = building:FindFirstChild("Config")
		if not configFolder then
			configFolder = Instance.new("Folder")
			configFolder.Name = "Config"
			configFolder.Parent = building
		end

		local buildingNameValue = configFolder:FindFirstChild("BuildingName")
		if not buildingNameValue then
			buildingNameValue = Instance.new("StringValue")
			buildingNameValue.Name = "BuildingName"
			buildingNameValue.Value = buildingType or "Unknown"
			buildingNameValue.Parent = configFolder
		else
			buildingNameValue.Value = buildingType or buildingNameValue.Value
		end

		local collectedIncome = configFolder:FindFirstChild("CollectedIncome")
		if not collectedIncome then
			collectedIncome = Instance.new("IntValue")
			collectedIncome.Name = "CollectedIncome"
			collectedIncome.Value = 0
			collectedIncome.Parent = configFolder
		end

		local health = configFolder:FindFirstChild("Health")
		if not health then
			health = Instance.new("IntValue")
			health.Name = "Health"
			health.Value = 100
			health.Parent = configFolder
		end

		-- Ensure crime and happiness values exist
		local crimePercent = configFolder:FindFirstChild("CrimePercent")
		if not crimePercent then
			crimePercent = Instance.new("IntValue")
			crimePercent.Name = "CrimePercent"
			crimePercent.Value = 15 -- Default base crime rate
			crimePercent.Parent = configFolder
		end

		local happinessPercent = configFolder:FindFirstChild("HappinessPercent")
		if not happinessPercent then
			happinessPercent = Instance.new("IntValue")
			happinessPercent.Name = "HappinessPercent"
			happinessPercent.Value = 75 -- Default base happiness
			happinessPercent.Parent = configFolder
		end

		return configFolder, buildingType
	end

	function IncomeSystem.calculatePopulation(player)
		local BuildingConfig =
			require(script.Parent.Parent.Parent.Parent:WaitForChild("config"):WaitForChild("BuildingConfig"))
		local plotData = player:FindFirstChild("Data")
			and player.Data:FindFirstChild("PlotInfo")
			and player.Data.PlotInfo:FindFirstChild("Plot")
		if not plotData or plotData.Value == 0 then
			return 0
		end

		local plotNumber = plotData.Value
		local plot = Workspace.Plots:FindFirstChild("Plot" .. plotNumber)
		if not plot then
			return 0
		end

		local totalPopulation = 0
		local placedFolder = plot.Buildings:FindFirstChild("Placed")
		if placedFolder then
			for _, building in ipairs(placedFolder:GetChildren()) do
				local buildingType = building:GetAttribute("BuildingType")
				if not buildingType then
					local config = building:FindFirstChild("Config")
					if config and config:FindFirstChild("BuildingName") then
						buildingType = config.BuildingName.Value
					else
						buildingType = string.match(building.Name, "^([^_]+)")
					end
				end
				if buildingType then
					local buildingConfig = BuildingConfig[buildingType]
					if buildingConfig and buildingConfig.Population then
						local level = 1
						local config = building:FindFirstChild("Config")
						if config and config:FindFirstChild("BuildingLevel") then
							level = config.BuildingLevel.Value
						end

						totalPopulation += Economy.population(buildingConfig, config)
					end
				end
			end
		end

		local multipliers = RebirthConfig.getPlayerMultipliers(player)
		totalPopulation = math.floor(totalPopulation * multipliers.population)

		local leaderstats = player:FindFirstChild("leaderstats")
		local populationStat = leaderstats
			and player:FindFirstChild("Data")
			and player.Data.PlayerInfo:FindFirstChild("Population")
		if populationStat then
			local oldValue = populationStat.Value
			populationStat.Value = totalPopulation

			if oldValue ~= totalPopulation then
				if not player.Data.PlayerInfo.Tutorial.IsInTutorial.Value then
					local PostTutorialQuest = require(
						script.Parent.Parent.Parent:WaitForChild("progression"):WaitForChild("PostTutorialQuest")
					)
					PostTutorialQuest.onPopulationChanged(player)
				end
			end
		end

		return totalPopulation
	end

	function IncomeSystem.calculateAndStackBuildingIncome(player, elapsed)
		local BuildingConfig =
			require(script.Parent.Parent.Parent.Parent:WaitForChild("config"):WaitForChild("BuildingConfig"))
		local plotData = player:FindFirstChild("Data")
			and player.Data:FindFirstChild("PlotInfo")
			and player.Data.PlotInfo:FindFirstChild("Plot")
		if not plotData or plotData.Value == 0 then
			return 0
		end
		local totalIncome = 0
		local plotNumber = plotData.Value
		local plot = Workspace.Plots:FindFirstChild("Plot" .. plotNumber)
		if not plot then
			return 0
		end
		local placedFolder = plot.Buildings:FindFirstChild("Placed")
		if placedFolder then
			for _, building in ipairs(placedFolder:GetChildren()) do
				local configFolder, buildingType = IncomeSystem.ensureBuildingConfig(building)
				local buildingNameValue = configFolder:FindFirstChild("BuildingName")
				local collectedIncome = configFolder:FindFirstChild("CollectedIncome")
				local crimePercent = configFolder:FindFirstChild("CrimePercent")
				local happinessPercent = configFolder:FindFirstChild("HappinessPercent")

				if buildingNameValue and collectedIncome then
					local baseName = buildingNameValue.Value
					local buildingConfig = BuildingConfig[baseName]
					if buildingConfig and buildingConfig.Income and buildingConfig.Income > 0 then
						local finalIncome = Economy.income(buildingConfig, configFolder)
						collectedIncome.Value = collectedIncome.Value + finalIncome * (elapsed or 0)
						totalIncome = totalIncome + collectedIncome.Value
					end
				end
			end
		end

		-- Apply population boost
		local leaderstats = player:FindFirstChild("leaderstats")
		local populationStat = leaderstats
			and player:FindFirstChild("Data")
			and player.Data.PlayerInfo:FindFirstChild("Population")
		if populationStat and populationStat.Value > 0 then
			local boostMultiplier = 1 + (math.log(1 + populationStat.Value) / 10)
			totalIncome = totalIncome * boostMultiplier
		end

		-- Apply friend boost
		local friendBoost = player:GetAttribute("FriendBoost") or 0
		if friendBoost > 0 then
			totalIncome = totalIncome * (1 + friendBoost / 100)
		end

		-- Apply rebirth income multiplier directly
		local multipliers = RebirthConfig.getPlayerMultipliers(player)
		totalIncome = totalIncome * multipliers.income

		local playerInfo = player.Data:FindFirstChild("PlayerInfo")
		if playerInfo then
			local availableIncomeStat = playerInfo:FindFirstChild("AvailableIncome")
			if not availableIncomeStat then
				availableIncomeStat = Instance.new("IntValue")
				availableIncomeStat.Name = "AvailableIncome"
				availableIncomeStat.Parent = playerInfo
			end
			availableIncomeStat.Value = math.floor(totalIncome)
		end
		return totalIncome
	end
end
