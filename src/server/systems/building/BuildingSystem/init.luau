local Ownership = require(script.Parent.Parent.Parent.services.GamePassOwnership)
local BuildingSystem = {}
local Guard = require(script.Parent.Parent.security.RequestGuard)

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Import sub-modules
local BuildingXP = require(script:WaitForChild("BuildingXP"))
local BuildingConfig = require(script:WaitForChild("BuildingConfig"))
local BuildingStats = require(script:WaitForChild("BuildingStats"))
local BuildingPlacement = require(script:WaitForChild("BuildingPlacement"))
local BuildingPrompts = require(script:WaitForChild("BuildingPrompts"))
local BuildingData = require(script:WaitForChild("BuildingData"))
local BuildingStealing = require(script:WaitForChild("BuildingStealing"))

local IncomeSystem = require(script.Parent.Parent:WaitForChild("economy"):WaitForChild("IncomeSystem"))
local RebirthConfig = require(script.Parent.Parent:WaitForChild("progression"):WaitForChild("RebirthConfig"))

local plotsFolder = Workspace:WaitForChild("Plots")
local MAX_BUILDERS = 7
local GAME_PASS_ID = 1407360513
local STEAL_BUILDING_PRODUCT_ID = 3375062345

local buildingXPLoops = {}

local function generateUniqueID()
	return HttpService:GenerateGUID(false):sub(1, 12) .. "_" .. tostring(os.time())
end

local function ownsGamePass(player)
	return Ownership.has(player, GAME_PASS_ID)
end

-- Expose sub-module functions through main module
BuildingSystem.getXPRequiredForLevel = BuildingXP.getXPRequiredForLevel
BuildingSystem.getTotalXPForLevel = BuildingXP.getTotalXPForLevel
BuildingSystem.getLevelFromTotalXP = BuildingXP.getLevelFromTotalXP
BuildingSystem.getXPMultiplierForBuilding = BuildingXP.getXPMultiplierForBuilding
BuildingSystem.addXPToBuilding = BuildingXP.addXPToBuilding
BuildingSystem.startBuildingXPLoop = BuildingXP.startBuildingXPLoop
BuildingSystem.stopBuildingXPLoop = BuildingXP.stopBuildingXPLoop

BuildingSystem.updatePlotStats = BuildingStats.updatePlotStats

BuildingSystem.isValidPlacement = BuildingPlacement.isValidPlacement
BuildingSystem.placeBuilding = BuildingPlacement.placeBuilding

BuildingSystem.addBuildingPrompts = BuildingPrompts.addBuildingPrompts

BuildingSystem.setupBuildingConfig = BuildingConfig.setupBuildingConfig
BuildingSystem.collectBuilding = BuildingConfig.collectBuilding
BuildingSystem.moveBuilding = BuildingConfig.moveBuilding
BuildingSystem.deleteBuilding = BuildingConfig.deleteBuilding

BuildingSystem.saveBuildingData = BuildingData.saveBuildingData
BuildingSystem.loadPlayerBuildings = BuildingData.loadPlayerBuildings
BuildingSystem.getPlotRelativePosition = BuildingData.getPlotRelativePosition
BuildingSystem.getWorldPositionFromRelative = BuildingData.getWorldPositionFromRelative
BuildingSystem.getRotationForPlot = BuildingData.getRotationForPlot
BuildingSystem.getRotationFromPlot = BuildingData.getRotationFromPlot

BuildingSystem.canStealBuilding = BuildingStealing.canStealBuilding
BuildingSystem.stealBuilding = BuildingStealing.stealBuilding
BuildingSystem.createToolWithBuilding = BuildingStealing.createToolWithBuilding

function BuildingSystem.getBuildingOwner(building)
	local placed = building and building.Parent
	local buildings = placed and placed.Parent
	local plot = buildings and buildings.Parent
	if not plot or placed.Name ~= "Placed" or plot.Parent ~= plotsFolder then
		return nil
	end
	local id = tonumber(plot:GetAttribute("CityId"))
	local owner = id and Players:GetPlayerByUserId(id)
	local data = owner and owner:FindFirstChild("Data")
	local info = data and data:FindFirstChild("PlotInfo")
	local number = info and info:FindFirstChild("Plot")
	if number and plotsFolder:FindFirstChild("Plot" .. number.Value) == plot then
		return owner
	end
	return nil
end

function BuildingSystem.updatePopulation(player)
	return IncomeSystem.calculatePopulation(player)
end

function BuildingSystem.init()
	local levelUpEvent = ReplicatedStorage.Events.Notifications:FindFirstChild("BuildingLevelUp")

	-- Initialize sub-modules
	BuildingXP.init(buildingXPLoops, RebirthConfig)
	BuildingStats.init()
	BuildingPlacement.init(ownsGamePass, generateUniqueID)
	BuildingPrompts.init()
	BuildingConfig.init()
	BuildingData.init(generateUniqueID)
	BuildingStealing.init(generateUniqueID)

	ReplicatedStorage.Functions.PlaceBlock.OnServerInvoke = function(player, cframe, tool)
		return Guard.run(player, "Place", function(plr)
			if not BuildingSystem.isValidPlacement(plr, cframe, tool) then
				return false
			end
			return BuildingSystem.placeBuilding(plr, cframe, tool, tool.Name)
		end)
	end
	ReplicatedStorage.Events.Movement.Delete.OnServerEvent:Connect(function(player, building)
		Guard.run(player, "Delete", BuildingSystem.deleteBuilding, building)
	end)
	ReplicatedStorage.Events.Movement.Move.OnServerEvent:Connect(function(player, building)
		Guard.run(player, "Move", BuildingSystem.moveBuilding, building)
	end)
	ReplicatedStorage.Events.Movement.CollectBuilding.OnServerEvent:Connect(function(player, building)
		Guard.run(player, "Collect", BuildingSystem.collectBuilding, building)
	end)
	local BuildingThoughts = require(script:WaitForChild("BuildingThoughts"))
	BuildingThoughts.init()

	Players.PlayerRemoving:Connect(function(player)
		local plotData = player:FindFirstChild("Data")
			and player.Data:FindFirstChild("PlotInfo")
			and player.Data.PlotInfo:FindFirstChild("Plot")
		if plotData and plotData.Value > 0 then
			local plot = workspace.Plots:FindFirstChild("Plot" .. plotData.Value)
			if plot then
				local placedFolder = plot.Buildings:FindFirstChild("Placed")
				if placedFolder then
					for _, building in pairs(placedFolder:GetChildren()) do
						local buildingID = building:GetAttribute("BuildingID")
						if buildingID then
							BuildingSystem.stopBuildingXPLoop(buildingID)
						end
					end
				end
			end
		end
	end)

	-- Crime, fire safety, and happiness update loop
	task.spawn(function()
		while true do
			task.wait(30) -- Update every 30 seconds
			for _, plot in pairs(plotsFolder:GetChildren()) do
				BuildingStats.updatePlotStats(plot)
				task.wait()
			end
		end
	end)
end

return BuildingSystem
