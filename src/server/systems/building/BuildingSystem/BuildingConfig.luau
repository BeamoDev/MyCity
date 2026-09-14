local BuildingConfig = {}
local Validation = require(script.Parent.BuildingValidation)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- BUILDING CONFIG FOLDER CONTENTS TABLE
local BUILDING_CONFIG_CONTENTS = {
	"BuildingName",
	"BuildingLevel",
	"BuildingXP",
	"Health",
	"CollectedIncome",
	"CrimePercent",
	"HappinessPercent",
	"FireSafetyPercent",
	"HealthPercent", -- ADD THIS
}

local BASE_CRIME_RATE = 15
local BASE_FIRE_SAFETY = 50
local BASE_HAPPINESS = 75
local BASE_HEALTH_PERCENT = 50

function BuildingConfig.setupBuildingConfig(building, buildingType, level, xp)
	local configFolder = building:FindFirstChild("Config")
	if not configFolder then
		configFolder = Instance.new("Folder")
		configFolder.Name = "Config"
		configFolder.Parent = building
	end

	-- Create all config folder contents based on BUILDING_CONFIG_CONTENTS table
	local buildingNameValue = configFolder:FindFirstChild("BuildingName")
	if not buildingNameValue then
		buildingNameValue = Instance.new("StringValue")
		buildingNameValue.Name = "BuildingName"
		buildingNameValue.Parent = configFolder
	end
	buildingNameValue.Value = buildingType

	local buildingLevel = configFolder:FindFirstChild("BuildingLevel")
	if not buildingLevel then
		buildingLevel = Instance.new("IntValue")
		buildingLevel.Name = "BuildingLevel"
		buildingLevel.Parent = configFolder
	end
	buildingLevel.Value = level or 1

	local buildingXP = configFolder:FindFirstChild("BuildingXP")
	if not buildingXP then
		buildingXP = Instance.new("IntValue")
		buildingXP.Name = "BuildingXP"
		buildingXP.Parent = configFolder
	end
	buildingXP.Value = xp or 0

	local health = configFolder:FindFirstChild("Health")
	if not health then
		health = Instance.new("IntValue")
		health.Name = "Health"
		health.Parent = configFolder
	end
	health.Value = 100

	local collectedIncome = configFolder:FindFirstChild("CollectedIncome")
	if not collectedIncome then
		collectedIncome = Instance.new("IntValue")
		collectedIncome.Name = "CollectedIncome"
		collectedIncome.Value = 0
		collectedIncome.Parent = configFolder
	end

	-- NEW: Crime, Happiness, and Fire Safety percentages
	local crimePercent = configFolder:FindFirstChild("CrimePercent")
	if not crimePercent then
		crimePercent = Instance.new("IntValue")
		crimePercent.Name = "CrimePercent"
		crimePercent.Parent = configFolder
	end
	crimePercent.Value = BASE_CRIME_RATE

	local happinessPercent = configFolder:FindFirstChild("HappinessPercent")
	if not happinessPercent then
		happinessPercent = Instance.new("IntValue")
		happinessPercent.Name = "HappinessPercent"
		happinessPercent.Parent = configFolder
	end
	happinessPercent.Value = BASE_HAPPINESS

	local fireSafetyPercent = configFolder:FindFirstChild("FireSafetyPercent")
	if not fireSafetyPercent then
		fireSafetyPercent = Instance.new("IntValue")
		fireSafetyPercent.Name = "FireSafetyPercent"
		fireSafetyPercent.Parent = configFolder
	end
	fireSafetyPercent.Value = BASE_FIRE_SAFETY

	local healthPercent = configFolder:FindFirstChild("HealthPercent")
	if not healthPercent then
		healthPercent = Instance.new("IntValue")
		healthPercent.Name = "HealthPercent"
		healthPercent.Parent = configFolder
	end
	healthPercent.Value = BASE_HEALTH_PERCENT

	return configFolder
end

function BuildingConfig.collectBuilding(player, building)
	if not Validation.ownsBuilding(player, building) then
		return false
	end
	local isRobuxBuilding = building:GetAttribute("RobuxBuilding") == true
	local buildingType = building:GetAttribute("BuildingType")
	local buildingID = building:GetAttribute("BuildingID")

	if not buildingType then
		return false
	end

	local BuildingXP = require(script.Parent:WaitForChild("BuildingXP"))

	local configFolder = building:FindFirstChild("Config")
	local level = 1
	local xp = 0

	if configFolder then
		local buildingLevel = configFolder:FindFirstChild("BuildingLevel")
		local buildingXP = configFolder:FindFirstChild("BuildingXP")

		if buildingLevel then
			level = buildingLevel.Value
		end
		if buildingXP then
			xp = buildingXP.Value
		end
	end

	local BuildingStealing = require(script.Parent.BuildingStealing)
	local tool = BuildingStealing.createToolWithBuilding(buildingType, true, level, xp)
	local backpack = player:FindFirstChild("Backpack")
	if not tool or not backpack then
		if tool then
			tool:Destroy()
		end
		return false
	end
	-- Commit removal only after the replacement tool is ready.
	BuildingXP.stopBuildingXPLoop(buildingID)
	local mutation = building:FindFirstChild("Mutation")
	if mutation and mutation:IsA("StringValue") then
		local value = tool:FindFirstChild("Mutation") or Instance.new("StringValue")
		value.Name, value.Value, value.Parent = "Mutation", mutation.Value, tool
	end
	tool:SetAttribute("RobuxBuilding", isRobuxBuilding)
	tool.Parent = backpack
	local currentBuildings = player.Data:FindFirstChild("CurrentBuildings")
	if currentBuildings then
		local saveEntry = currentBuildings:FindFirstChild(buildingType .. "_" .. buildingID)
		if saveEntry then
			saveEntry:Destroy()
		end
	end

	-- Update crime and happiness for the plot after building removal
	local plot = building.Parent and building.Parent.Parent and building.Parent.Parent.Parent
	if plot then
		building:Destroy()
		local BuildingStats = require(script.Parent:WaitForChild("BuildingStats"))
		BuildingStats.updatePlotStats(plot)
	else
		building:Destroy()
	end

	local notificationText = string.format("Picked up Level %d %s!", level, buildingType)

	local collectEvent = ReplicatedStorage.Events.Notifications:FindFirstChild("BuildingCollected")
	if collectEvent then
		collectEvent:FireClient(player, notificationText)
	end

	local BuildingSystem = require(script.Parent)
	local IncomeSystem = require(script.Parent.Parent.Parent:WaitForChild("economy"):WaitForChild("IncomeSystem"))
	BuildingSystem.updatePopulation(player)
	IncomeSystem.calculateAndStackBuildingIncome(player)

	ReplicatedStorage.Events.UI.CloseBuildingInfo:FireClient(player)

	return true
end

function BuildingConfig.moveBuilding(player, building)
	-- Always allow collecting, regardless of tutorial status
	BuildingConfig.collectBuilding(player, building)
end

function BuildingConfig.deleteBuilding(player, building)
	-- Removing a city building always returns its level/XP/paid state to inventory.
	return BuildingConfig.collectBuilding(player, building)
end

function BuildingConfig.init()
	-- Any initialization needed for building config
end

return BuildingConfig
