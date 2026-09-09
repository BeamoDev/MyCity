local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Validation = require(script.Parent.BuildingValidation)
local Config = require(script.Parent.BuildingConfig)
local Data = require(script.Parent.BuildingData)
local Commit = {}

function Commit.instant(player, cframe, tool, buildingName, template, plot, level, xp, paid, buildingId)
	if not Validation.placement(player, cframe, tool) then
		return false
	end
	local building = template:Clone()
	building:SetPrimaryPartCFrame(cframe)
	building.Name = buildingName .. "_" .. buildingId
	building:SetAttribute("BuildingType", buildingName)
	building:SetAttribute("BuildingID", buildingId)
	building:SetAttribute("RobuxBuilding", paid)
	Config.setupBuildingConfig(building, buildingName, level, xp)
	-- No API calls/yields between recording the building and consuming its tool.
	Data.saveBuildingData(player, buildingId, buildingName, cframe, plot, level, xp, paid)
	building.Parent = plot.Buildings.Placed
	tool:Destroy()
	local Tutorial = require(script.Parent.Parent.Parent.progression.TutorialSystem)
	if player.Data.PlayerInfo.Tutorial.IsInTutorial.Value then
		Tutorial.handleBuildingPlacement(player, buildingName, buildingId)
		Tutorial.handleConstructionComplete(player, buildingName, buildingId)
	end
	task.defer(function()
		if not building.Parent then
			return
		end
		if not player.Data.PlayerInfo.Tutorial.IsInTutorial.Value then
			require(script.Parent.Parent.Parent.progression.PostTutorialQuest).onBuildingPlaced(player, building)
		end
		require(script.Parent.BuildingPrompts).addBuildingPrompts(building, player, buildingName)
		require(script.Parent.BuildingXP).startBuildingXPLoop(building)
		require(script.Parent.BuildingStats).updatePlotStats(plot)
		require(script.Parent.Parent.Parent.economy.IncomeSystem).calculatePopulation(player)
		require(script.Parent.Parent.Parent.world.WeatherSystem).updateNewBuilding(building)
		ReplicatedStorage.Events.Notifications.PlaceSound:FireClient(player)
	end)
	return true
end

return Commit
