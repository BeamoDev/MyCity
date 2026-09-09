-- Restoration: focused implementation for ConstructionData.
local RestoreBudget = require(script.Parent.Parent.Parent.Parent.Parent.services.RestoreBudget)
return function(Context)
	local State = Context.State
	local ConstructionData = Context.ConstructionData
	local ReplicatedStorage = Context.ReplicatedStorage
	local plotsFolder = Context.plotsFolder

	function ConstructionData.loadPlayerConstructions(player)
		local BuildingConfig =
			require(script.Parent.Parent.Parent.Parent.Parent:WaitForChild("config"):WaitForChild("BuildingConfig"))
		local currentConstructions = player:FindFirstChild("Data")
			and player.Data:FindFirstChild("CurrentConstructions")
		if not currentConstructions then
			print("[ConstructionData] No current constructions found")
			return
		end

		local plotData = player:FindFirstChild("Data")
			and player.Data:FindFirstChild("PlotInfo")
			and player.Data.PlotInfo:FindFirstChild("Plot")
		local plot = plotsFolder:FindFirstChild("Plot" .. (plotData and plotData.Value or 0))

		if not plot then
			print("[ConstructionData] No plot found")
			return
		end

		for _, constructionData in ipairs(currentConstructions:GetChildren()) do
			if constructionData:IsA("StringValue") then
				RestoreBudget.checkpoint(player)
				local buildingType, constructionID = string.match(constructionData.Name, "^([^_]+)_(.+)$")
				if not buildingType or not constructionID then
					error("Unknown saved construction: " .. constructionData.Name)
				end

				local buildingConfig = BuildingConfig[buildingType]
				if not buildingConfig then
					error("Unknown saved construction: " .. constructionData.Name)
				end

				assert(
					game:GetService("ServerStorage").Buildings:FindFirstChild(buildingType),
					"Missing authored building: " .. buildingType
				)
				local data = ConstructionData.loadConstructionData(constructionData.Value)
				local currentTime = os.time()
				local elapsedTime = math.max(0, currentTime - data.lastUpdated)
				data.timeLeft = data.timeLeft - elapsedTime

				local worldPosition = Context.getWorldPositionFromRelative(data.position, plot)
				local worldRotation = Context.getRotationFromPlot(data.rotation, plot)

				if data.timeLeft <= 0 then
					-- Construction completed while offline
					local buildingModel = game:GetService("ServerStorage").Buildings:FindFirstChild(buildingType)
					if buildingModel then
						local BuildingSystem = require(
							script.Parent.Parent.Parent.Parent:WaitForChild("building"):WaitForChild("BuildingSystem")
						)

						local newBuilding = buildingModel:Clone()
						local cframe = CFrame.new(worldPosition)
							* CFrame.Angles(
								math.rad(worldRotation.X),
								math.rad(worldRotation.Y),
								math.rad(worldRotation.Z)
							)
						newBuilding:SetPrimaryPartCFrame(cframe)

						-- Set Robux flag if applicable
						if data.isRobuxBuilding then
							newBuilding:SetAttribute("RobuxBuilding", true)
						end

						local DayNightCycle = require(
							script.Parent.Parent.Parent.Parent:WaitForChild("world"):WaitForChild("WeatherSystem")
						)
						DayNightCycle.updateNewBuilding(newBuilding)

						local newBuildingID = constructionID
						newBuilding:SetAttribute("BuildingType", buildingType)
						newBuilding:SetAttribute("BuildingID", newBuildingID)
						newBuilding.Name = buildingType .. "_" .. newBuildingID

						BuildingSystem.setupBuildingConfig(newBuilding, buildingType, data.level, data.xp)
						-- Pass Robux flag to saveBuildingData
						BuildingSystem.saveBuildingData(
							player,
							newBuildingID,
							buildingType,
							cframe,
							plot,
							data.level,
							data.xp,
							data.isRobuxBuilding
						)
						BuildingSystem.addBuildingPrompts(newBuilding, player, buildingType)
						newBuilding.Parent = plot.Buildings:FindFirstChild("Placed")
						BuildingSystem.startBuildingXPLoop(newBuilding)

						constructionData:Destroy()
						require(script.Parent.Parent.Parent.Parent.progression.TutorialSystem).handleConstructionComplete(
							player,
							buildingType,
							newBuildingID
						)
					end
				else
					-- Continue construction
					local constructionModel = ReplicatedStorage.Assets:FindFirstChild("Constructions")
						and ReplicatedStorage.Assets.Constructions:FindFirstChild(data.size)

					assert(
						constructionModel and constructionModel.PrimaryPart,
						"Missing authored construction: " .. data.size
					)
					if constructionModel then
						local constructionSite = constructionModel:Clone()
						constructionSite:SetPrimaryPartCFrame(
							CFrame.new(worldPosition)
								* CFrame.Angles(
									math.rad(worldRotation.X),
									math.rad(worldRotation.Y),
									math.rad(worldRotation.Z)
								)
						)
						constructionSite.Parent = plot.Buildings:FindFirstChild("Construction")

						-- Set Robux flag if applicable
						if data.isRobuxBuilding then
							constructionSite:SetAttribute("RobuxBuilding", true)
						end

						if
							constructionSite:FindFirstChild("Base")
							and constructionSite.Base:FindFirstChild("Ambience")
						then
							constructionSite.Base.Ambience.Playing = true
						end

						constructionSite:SetAttribute("BuildingType", buildingType)
						constructionSite:SetAttribute("ConstructionID", constructionID)
						constructionSite.Name = buildingType .. "_" .. constructionID

						local ConstructionTimer = require(script.Parent.Parent:WaitForChild("ConstructionTimer"))
						ConstructionTimer.startConstructionTimer(
							player,
							plot,
							constructionSite,
							game:GetService("ServerStorage").Buildings:FindFirstChild(buildingType),
							buildingConfig.BuildTime,
							data.timeLeft,
							true,
							false,
							data.level,
							data.xp,
							nil,
							nil,
							{},
							data.isRobuxBuilding -- Pass Robux flag
						)
					end
				end
			end
		end

		local ConstructionBuilder = require(script.Parent.Parent:WaitForChild("ConstructionBuilder"))
		ConstructionBuilder.updateBuilderCount(player, {})
	end
end
