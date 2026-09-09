local BuildingStealing = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local generateUniqueID = nil

function BuildingStealing.canStealBuilding(stealerPlayer, building)
	if not building or not building.Parent then
		return false, "Invalid building"
	end

	local BuildingSystem = require(script.Parent)
	local owner = BuildingSystem.getBuildingOwner(building)
	if not owner then
		return false, "Building has no owner"
	end

	if owner.UserId == stealerPlayer.UserId then
		return false, "Cannot steal your own building"
	end

	if building.Parent.Name == "Construction" then
		return false, "Cannot steal buildings under construction"
	end

	return true, owner
end

function BuildingStealing.stealBuilding(stealerPlayer, building, originalOwner)
	if not building or not building.Parent then
		warn("[STEAL] Invalid building")
		return false
	end

	if not originalOwner or not originalOwner.Parent then
		warn("[STEAL] Invalid original owner")
		return false
	end

	if not stealerPlayer or not stealerPlayer.Parent then
		warn("[STEAL] Invalid stealer player")
		return false
	end

	local buildingType = building:GetAttribute("BuildingType")
	local buildingID = building:GetAttribute("BuildingID")

	if not buildingType then
		warn("[STEAL] Building has no type")
		return false
	end

	local level = 1
	local xp = 0
	local configFolder = building:FindFirstChild("Config")
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

	if buildingID then
		local BuildingXP = require(script.Parent:WaitForChild("BuildingXP"))
		BuildingXP.stopBuildingXPLoop(buildingID)
	end

	local originalOwnerBuildings = originalOwner.Data:FindFirstChild("CurrentBuildings")
	if originalOwnerBuildings and buildingID then
		local saveEntry = originalOwnerBuildings:FindFirstChild(buildingType .. "_" .. buildingID)
		if saveEntry then
			saveEntry:Destroy()
		end
	end

	local tool
	local success = pcall(function()
		tool = BuildingStealing.createToolWithBuilding(buildingType, true, level, xp)
	end)

	if not success or not tool then
		warn("[STEAL] Failed to create tool")
		return false
	end

	local backpack = stealerPlayer:FindFirstChild("Backpack")
	if not backpack then
		backpack = stealerPlayer:WaitForChild("Backpack", 5)
	end

	if backpack then
		tool.Parent = backpack
	else
		warn("[STEAL] No backpack found")
		tool:Destroy()
		return false
	end

	building:Destroy()

	-- Update crime and happiness for the plot after building removal
	local plot = workspace.Plots:FindFirstChild("Plot" .. originalOwner.Data.PlotInfo.Plot.Value)
	if plot then
		local BuildingStats = require(script.Parent:WaitForChild("BuildingStats"))
		BuildingStats.updatePlotStats(plot)
	end

	task.spawn(function()
		pcall(function()
			local BuildingSystem = require(script.Parent)
			local IncomeSystem =
				require(script.Parent.Parent.Parent:WaitForChild("economy"):WaitForChild("IncomeSystem"))
			BuildingSystem.updatePopulation(originalOwner)
			IncomeSystem.calculateAndStackBuildingIncome(originalOwner)
		end)
	end)

	local StealEvents = ReplicatedStorage.Events:FindFirstChild("StealBuilding")
	if StealEvents then
		local stolenEvent = StealEvents:FindFirstChild("Stole")
		local receivedEvent = StealEvents:FindFirstChild("Recieved")

		if stolenEvent then
			stolenEvent:FireClient(originalOwner, {
				thief = stealerPlayer.Name,
				building = buildingType,
				level = level,
			})
		end

		if receivedEvent then
			receivedEvent:FireClient(stealerPlayer, {
				owner = originalOwner.Name,
				building = buildingType,
				level = level,
			})
		end
	end

	return true
end

BuildingStealing.createToolWithBuilding = require(script.Parent.Parent.Parent.Parent.services.ToolFactory).create

function BuildingStealing.init(uniqueIDGenerator)
	generateUniqueID = uniqueIDGenerator
end

return BuildingStealing
