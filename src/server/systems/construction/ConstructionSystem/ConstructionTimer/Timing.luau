-- Timing: focused implementation for ConstructionTimer.
return function(Context)
	local State = Context.State
	local ConstructionTimer = Context.ConstructionTimer
	local ReplicatedStorage = Context.ReplicatedStorage
	local UpdateConstructionsEvent = Context.UpdateConstructionsEvent

	function ConstructionTimer.startConstructionTimer(
		player,
		plot,
		constructionSite,
		finalBuilding,
		totalConstructionTime,
		remainingTime,
		isLoading,
		isTutorial,
		level,
		xp,
		activeTimersRef,
		completedConstructionsRef,
		activeBuilders,
		isRobuxBuilding
	)
		activeTimersRef = (type(activeTimersRef) == "table") and activeTimersRef or State.activeTimers
		completedConstructionsRef = (type(completedConstructionsRef) == "table") and completedConstructionsRef
			or State.completedConstructions
		activeBuilders = require(script.Parent.Parent.ConstructionBuilder).getActiveBuilders()

		local BuildingConfig =
			require(script.Parent.Parent.Parent.Parent.Parent:WaitForChild("config"):WaitForChild("BuildingConfig"))
		local ConstructionData = require(script.Parent.Parent:WaitForChild("ConstructionData"))
		local ConstructionSkipping = require(script.Parent.Parent:WaitForChild("ConstructionSkipping"))

		local buildingType = constructionSite:GetAttribute("BuildingType")
		local constructionID = constructionSite:GetAttribute("ConstructionID")
		local identifier = buildingType .. "_" .. constructionID

		local buildingConfig = BuildingConfig[buildingType]
		if not buildingConfig then
			return
		end

		local displayName = buildingConfig.DisplayName or buildingType

		constructionSite:SetAttribute("BuildingLevel", level or 1)
		constructionSite:SetAttribute("BuildingXP", xp or 0)

		if isRobuxBuilding then
			constructionSite:SetAttribute("RobuxBuilding", true)
		end

		local hasSpeedBoost = not isTutorial and Context.ownsHalfConstructionSpeedGamePass(player)
		if hasSpeedBoost then
			totalConstructionTime = math.floor(totalConstructionTime / 2)
			if remainingTime then
				remainingTime = math.min(remainingTime, totalConstructionTime)
			end
		end

		constructionSite:SetAttribute("OwnerUserId", player.UserId)
		local timerValue = 0
		local timerFlag = Instance.new("BoolValue")
		timerFlag.Name = "TimerActive"
		timerFlag.Value = true
		timerFlag.Parent = constructionSite

		if not isLoading and totalConstructionTime > 0 then
			local isInTutorial = player.Data.PlayerInfo.Tutorial.IsInTutorial.Value
			if not isInTutorial then
				ReplicatedStorage.Events.Notifications.BuildingStarted:FireClient(player, displayName) -- Use displayName
			end
		end

		-- Add construction info billboard
		local constructionInfo = game:GetService("ReplicatedStorage")
			:WaitForChild("Assets")
			:WaitForChild("Items")
			:FindFirstChild("ConstructionInfo")
		if constructionInfo and constructionSite:FindFirstChild("Base") then
			local infoBillboard = constructionInfo:Clone()
			infoBillboard.Parent = constructionSite.Base
			infoBillboard.Enabled = true
		end

		local size = buildingConfig.Size
		local position = constructionSite.PrimaryPart.Position
		local orientationX, orientationY, orientationZ = constructionSite.PrimaryPart.CFrame:ToEulerAnglesXYZ()
		local orientation = Vector3.new(math.deg(orientationX), math.deg(orientationY), math.deg(orientationZ))
		local rarity = buildingConfig.Rarity

		remainingTime = remainingTime or totalConstructionTime
		local elapsedTime = totalConstructionTime - remainingTime
		timerValue = elapsedTime

		ConstructionSkipping.addSkipBuildPrompt(player, constructionSite, activeTimersRef)

		UpdateConstructionsEvent:FireClient(player, "start", {
			Id = identifier,
			Name = displayName,
			Duration = remainingTime,
			TotalDuration = totalConstructionTime,
		})

		if activeTimersRef then
			activeTimersRef[identifier] = {
				remainingTime = remainingTime,
				displayName = displayName,
				totalTime = totalConstructionTime,
				timerActive = timerFlag,
				constructionSite = constructionSite,
			}
		end

		if not isLoading then
			-- Pass the Robux flag to saveConstructionData
			ConstructionData.saveConstructionData(
				player,
				constructionID,
				buildingType,
				remainingTime,
				position,
				orientation,
				size,
				plot,
				level,
				xp,
				isRobuxBuilding
			)
		end

		local ConstructionBuilder = require(script.Parent.Parent:WaitForChild("ConstructionBuilder"))
		if not isLoading then
			task.defer(ConstructionBuilder.updateBuilderCount, player, activeBuilders)
		end

		task.spawn(function()
			Context.updateConstructionBillboard(constructionSite, remainingTime, rarity, displayName)

			while timerValue < totalConstructionTime do
				local elapsed = task.wait(1)
				if player:GetAttribute("MyCityLeaving") then
					activeTimersRef[identifier] = nil
					return
				end
				if not constructionSite or not constructionSite.Parent then
					break
				end

				if not constructionSite:FindFirstChild("TimerActive") or not constructionSite.TimerActive.Value then
					break
				end

				timerValue = timerValue + elapsed
				remainingTime = math.max(0, totalConstructionTime - timerValue)

				if activeTimersRef[identifier] then
					activeTimersRef[identifier].remainingTime = remainingTime
				end

				-- Update save data
				local currentConstructions = player:FindFirstChild("Data")
					and player.Data:FindFirstChild("CurrentConstructions")
				if currentConstructions then
					local tracker = currentConstructions:FindFirstChild(identifier)
					if tracker then
						local data = ConstructionData.loadConstructionData(tracker.Value)
						tracker.Value = string.format(
							"%.0f,%.2f,%.2f,%.2f,%.1f,%.1f,%.1f,%s,%d,%d,%d,%s",
							remainingTime,
							data.position.X,
							data.position.Y,
							data.position.Z,
							data.rotation.X,
							data.rotation.Y,
							data.rotation.Z,
							data.size,
							os.time(),
							level or 1,
							xp or 0,
							tostring(isRobuxBuilding == true)
						)
					end
				end

				Context.updateConstructionBillboard(constructionSite, remainingTime, rarity, displayName)

				if remainingTime <= 0 then
					break
				end
			end

			if activeTimersRef then
				activeTimersRef[identifier] = nil
			end

			UpdateConstructionsEvent:FireClient(player, "remove", {
				Id = identifier,
				Name = displayName,
			})

			if not constructionSite or not constructionSite.Parent then
				return
			end

			if not player or not player.Parent then
				return
			end

			if not plot or not plot.Parent then
				return
			end

			ConstructionTimer.finishConstruction(
				player,
				plot,
				constructionSite,
				finalBuilding,
				size,
				isTutorial,
				false,
				activeBuilders
			)
		end)
	end
end
