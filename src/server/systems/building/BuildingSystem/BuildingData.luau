local BuildingData = {}

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local plotsFolder = Workspace:WaitForChild("Plots")
local generateUniqueID = nil
local RestoreBudget = require(script.Parent.Parent.Parent.Parent.services.RestoreBudget)

function BuildingData.getPlotRelativePosition(worldPosition, plot)
	local plotCenter = plot:FindFirstChild("Center")
	if not plotCenter then
		return worldPosition
	end

	local relativePosition = worldPosition - plotCenter.Position

	local plotNumber = tonumber(plot.Name:match("Plot(%d+)"))
	if plotNumber and plotNumber >= 5 and plotNumber <= 8 then
		relativePosition = Vector3.new(-relativePosition.X, relativePosition.Y, -relativePosition.Z)
	end

	return relativePosition
end

function BuildingData.getWorldPositionFromRelative(relativePosition, plot)
	local plotCenter = plot:FindFirstChild("Center")
	if not plotCenter then
		return relativePosition
	end

	local plotNumber = tonumber(plot.Name:match("Plot(%d+)"))
	if plotNumber and plotNumber >= 5 and plotNumber <= 8 then
		relativePosition = Vector3.new(-relativePosition.X, relativePosition.Y, -relativePosition.Z)
	end

	local worldPosition = plotCenter.Position + relativePosition
	return worldPosition
end

function BuildingData.getRotationForPlot(orientation, plot)
	local plotNumber = tonumber(plot.Name:match("Plot(%d+)"))
	if plotNumber and plotNumber >= 5 and plotNumber <= 8 then
		return Vector3.new(orientation.X, orientation.Y + 180, orientation.Z)
	end
	return orientation
end

function BuildingData.getRotationFromPlot(orientation, plot)
	local plotNumber = tonumber(plot.Name:match("Plot(%d+)"))
	if plotNumber and plotNumber >= 5 and plotNumber <= 8 then
		return Vector3.new(orientation.X, orientation.Y - 180, orientation.Z)
	end
	return orientation
end

function BuildingData.saveBuildingData(player, buildingID, buildingType, cframe, plot, level, xp, isRobuxBuilding)
	local currentBuildings = player.Data:FindFirstChild("CurrentBuildings")
	if not currentBuildings then
		return
	end

	local position = cframe.Position
	local orientationX, orientationY, orientationZ = cframe:ToEulerAnglesXYZ()
	local orientation = Vector3.new(math.deg(orientationX), math.deg(orientationY), math.deg(orientationZ))

	local relativePosition = BuildingData.getPlotRelativePosition(position, plot)
	local adjustedOrientation = BuildingData.getRotationForPlot(orientation, plot)

	-- Add Robux flag as 10th parameter
	local saveData = string.format(
		"%.2f,%.2f,%.2f,%.1f,%.1f,%.1f,%d,%d,%d,%s",
		relativePosition.X,
		relativePosition.Y,
		relativePosition.Z,
		adjustedOrientation.X,
		adjustedOrientation.Y,
		adjustedOrientation.Z,
		100,
		level or 1,
		xp or 0,
		isRobuxBuilding and "true" or "false" -- Add Robux flag
	)

	local buildingStat = currentBuildings:FindFirstChild(buildingType .. "_" .. buildingID)
		or Instance.new("StringValue")
	buildingStat.Name = buildingType .. "_" .. buildingID
	buildingStat.Value = saveData
	buildingStat.Parent = currentBuildings
end

local function loadBuildingData(dataString)
	local parts = string.split(dataString, ",")
	return {
		position = Vector3.new(tonumber(parts[1]) or 0, tonumber(parts[2]) or 1.25, tonumber(parts[3]) or 0),
		rotation = Vector3.new(tonumber(parts[4]) or 0, tonumber(parts[5]) or 0, tonumber(parts[6]) or 0),
		health = tonumber(parts[7]) or 100,
		level = tonumber(parts[8]) or 1,
		xp = tonumber(parts[9]) or 0,
		isRobuxBuilding = parts[10] == "true",
		needsUpdate = parts[10] ~= "true" and parts[10] ~= "false",
	}
end

function BuildingData.loadPlayerBuildings(player)
	local BuildingConfig =
		require(script.Parent.Parent.Parent.Parent:WaitForChild("config"):WaitForChild("BuildingConfig"))
	local currentBuildings = player:FindFirstChild("Data") and player.Data:FindFirstChild("CurrentBuildings")
	local plotInfo = player:FindFirstChild("Data") and player.Data:FindFirstChild("PlotInfo")
	local currentPlot = plotInfo and plotInfo:FindFirstChild("Plot") and plotInfo.Plot.Value

	local plot = plotsFolder:FindFirstChild("Plot" .. tostring(currentPlot))
	local placedBuildings = plot and plot.Buildings:FindFirstChild("Placed")

	assert(currentBuildings and placedBuildings, "Missing saved buildings or assigned plot")
	local Config = require(script.Parent.BuildingConfig)
	local Prompts = require(script.Parent.BuildingPrompts)
	local XP = require(script.Parent.BuildingXP)
	local Weather = require(script.Parent.Parent.Parent.world.WeatherSystem)
	local models = game:GetService("ServerStorage"):FindFirstChild("Buildings")

	for _, buildingData in ipairs(currentBuildings:GetChildren()) do
		if buildingData:IsA("StringValue") then
			RestoreBudget.checkpoint(player)
			local buildingType, buildingID = string.match(buildingData.Name, "^([^_]+)_(.+)$")
			if not buildingType or not buildingID then
				buildingType = string.match(buildingData.Name, "^[^%d_]+")
				if buildingType and BuildingConfig[buildingType] then
					buildingID = generateUniqueID()
					buildingData.Name = buildingType .. "_" .. buildingID
				else
					error("Unrecognized saved building: " .. buildingData.Name)
				end
			end

			if not BuildingConfig[buildingType] then
				error("Unknown saved building type: " .. tostring(buildingType))
			end

			local data = loadBuildingData(buildingData.Value)

			local worldPosition = BuildingData.getWorldPositionFromRelative(data.position, plot)
			local worldRotation = BuildingData.getRotationFromPlot(data.rotation, plot)

			local buildingModel = models and models:FindFirstChild(buildingType)
			assert(buildingModel and buildingModel.PrimaryPart, "Missing authored building: " .. buildingType)
			if buildingModel then
				local newBuilding = buildingModel:Clone()
				newBuilding:SetPrimaryPartCFrame(
					CFrame.new(worldPosition)
						* CFrame.Angles(math.rad(worldRotation.X), math.rad(worldRotation.Y), math.rad(worldRotation.Z))
				)

				-- Set Robux flag if applicable
				if data.isRobuxBuilding then
					newBuilding:SetAttribute("RobuxBuilding", true)
				end

				newBuilding:SetAttribute("BuildingType", buildingType)
				newBuilding:SetAttribute("BuildingID", buildingID)
				newBuilding.Name = buildingType .. "_" .. buildingID

				Config.setupBuildingConfig(newBuilding, buildingType, data.level, data.xp)
				-- Publish fully configured models so observers never see an anonymous building.
				Weather.updateNewBuilding(newBuilding)
				Prompts.addBuildingPrompts(newBuilding, player, buildingType)
				newBuilding.Parent = placedBuildings
				XP.startBuildingXPLoop(newBuilding)

				-- UPDATE: If save data needs updating, resave it with correct format
				if data.needsUpdate then
					-- Resave the building data with the proper format including Robux flag
					BuildingData.saveBuildingData(
						player,
						buildingID,
						buildingType,
						CFrame.new(worldPosition)
							* CFrame.Angles(
								math.rad(worldRotation.X),
								math.rad(worldRotation.Y),
								math.rad(worldRotation.Z)
							),
						plot,
						data.level,
						data.xp,
						data.isRobuxBuilding
					)
				end
			end
		end
	end

	-- PlayerLifecycle finalizes stats once, including offline-completed constructions.
end

function BuildingData.init(uniqueIDGenerator)
	generateUniqueID = uniqueIDGenerator
end

return BuildingData
