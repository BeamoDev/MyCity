local BuildingPlacement = {}
local Validation = require(script.Parent.BuildingValidation)

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MAX_BUILDERS = 7
local ownsGamePass = nil
local generateUniqueID = nil

function BuildingPlacement.isValidPlacement(player, previewCFrame, tool)
	if not Validation.placement(player, previewCFrame, tool) then
		return false
	end
	local plotData = player:FindFirstChild("Data")
		and player.Data:FindFirstChild("PlotInfo")
		and player.Data.PlotInfo:FindFirstChild("Plot")
	if not plotData then
		return false
	end

	local plotNumber = plotData.Value
	local plot = Workspace.Plots:FindFirstChild("Plot" .. plotNumber)
	if not plot then
		return false
	end

	local isInTutorial = player.Data.PlayerInfo.Tutorial.IsInTutorial.Value
	local definition = require(script.Parent.Parent.Parent.Parent.config.BuildingConfig)[tool.Name]
	local needsBuilder = not tool.IsValid.Value and definition and (definition.BuildTime or 0) > 0
	if not isInTutorial and needsBuilder then
		local ConstructionSystem =
			require(script.Parent.Parent.Parent:WaitForChild("construction"):WaitForChild("ConstructionSystem"))

		local buildersByPlayer = ConstructionSystem.getActiveBuilders() or {}
		local currentBuilders = buildersByPlayer[player.UserId] or 0
		local maxBuilders = ownsGamePass(player) and MAX_BUILDERS + 1 or MAX_BUILDERS

		game.ReplicatedStorage.Events.UI.UpdateBuilderUI:FireClient(player, currentBuilders, maxBuilders)

		if currentBuilders >= maxBuilders then
			game.ReplicatedStorage.Events.UI.UpdateBuilderUI:FireClient(player, currentBuilders, maxBuilders)
			game.ReplicatedStorage.Events.Notifications.BuilderLimitReached:FireClient(player)
			return false
		end
	end

	return true -- Spatial and ownership checks are handled by BuildingValidation.
end

function BuildingPlacement.placeBuilding(player, cframe, tool, buildingName)
	if not Validation.placement(player, cframe, tool) or buildingName ~= tool.Name then
		return false
	end

	local BuildingConfig =
		require(script.Parent.Parent.Parent.Parent:WaitForChild("config"):WaitForChild("BuildingConfig"))
	local plotData = player:FindFirstChild("Data")
		and player.Data:FindFirstChild("PlotInfo")
		and player.Data.PlotInfo:FindFirstChild("Plot")
	if not plotData or plotData.Value == 0 then
		return false
	end

	local plotNumber = plotData.Value
	local plot = Workspace.Plots:FindFirstChild("Plot" .. plotNumber)
	if not plot then
		return false
	end

	local buildingConfig = BuildingConfig[buildingName]
	if not buildingConfig then
		return false
	end

	local buildingModel = game:GetService("ServerStorage"):FindFirstChild("Buildings")
		and game:GetService("ServerStorage").Buildings:FindFirstChild(buildingName)
	if not buildingModel then
		return false
	end

	local isInTutorial = player.Data.PlayerInfo.Tutorial.IsInTutorial.Value
	local isTutorialBank = isInTutorial and buildingName == "Bank"

	local level = 1
	local xp = 0

	local isCollectedBuilding = tool:FindFirstChild("IsValid") and tool.IsValid.Value == true
	-- Fix: Check for Robux building attribute properly
	local isRobuxBuilding = tool:GetAttribute("RobuxBuilding") == true

	if isCollectedBuilding then
		local toolLevel = tool:FindFirstChild("BuildingLevel")
		local toolXP = tool:FindFirstChild("BuildingXP")

		if toolLevel then
			level = toolLevel.Value
		end
		if toolXP then
			xp = toolXP.Value
		end
	end

	local shouldPlaceInstantly = isCollectedBuilding or not buildingConfig.BuildTime or buildingConfig.BuildTime <= 0

	if shouldPlaceInstantly then
		return require(script.Parent.PlacementCommit).instant(
			player,
			cframe,
			tool,
			buildingName,
			buildingModel,
			plot,
			level,
			xp,
			isRobuxBuilding,
			generateUniqueID()
		)
	end

	local ConstructionSystem =
		require(script.Parent.Parent.Parent:WaitForChild("construction"):WaitForChild("ConstructionSystem"))
	local activeBuilders = ConstructionSystem.getActiveBuilders and ConstructionSystem.getActiveBuilders() or {}
	local currentBuilders = activeBuilders[player.UserId] or 0
	local maxBuilders = ownsGamePass(player) and (MAX_BUILDERS + 1) or MAX_BUILDERS

	if not isInTutorial and not isTutorialBank and currentBuilders >= maxBuilders then
		ReplicatedStorage.Events.Notifications.BuilderLimitReached:FireClient(player)
		return false
	end

	-- Fix: Pass the Robux flag to construction system
	local success = ConstructionSystem.startConstruction(
		player,
		plot,
		buildingName,
		cframe,
		buildingConfig,
		isTutorialBank,
		level,
		xp,
		isRobuxBuilding
	)

	if success then
		tool:Destroy()
		if isTutorialBank then
			ReplicatedStorage.Events.Tutorial.WaitToBuild:FireClient(player)
		end
	end

	return success
end

function BuildingPlacement.init(gamePassChecker, uniqueIDGenerator)
	ownsGamePass = gamePassChecker
	generateUniqueID = uniqueIDGenerator
end

return BuildingPlacement
