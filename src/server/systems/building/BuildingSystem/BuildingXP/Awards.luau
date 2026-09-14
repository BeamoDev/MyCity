-- Awards: focused implementation for BuildingXP.
return function(Context)
	local State = Context.State
	local BuildingXP = Context.BuildingXP
	local ReplicatedStorage = Context.ReplicatedStorage
	local MAX_LEVEL = Context.MAX_LEVEL

	function BuildingXP.addXPToBuilding(building, xpAmount)
		local configFolder = building:FindFirstChild("Config")
		if not configFolder then
			return false
		end

		local buildingLevel = configFolder:FindFirstChild("BuildingLevel")
		local buildingXP = configFolder:FindFirstChild("BuildingXP")

		if not buildingLevel or not buildingXP then
			return false
		end
		if buildingLevel.Value >= MAX_LEVEL then
			return false
		end

		if type(xpAmount) ~= "number" or xpAmount ~= xpAmount or xpAmount <= 0 or xpAmount == math.huge then
			return false
		end
		local oldLevel = buildingLevel.Value
		local oldXP = buildingXP.Value

		buildingXP.Value = oldXP + xpAmount

		local newLevel = BuildingXP.getLevelFromTotalXP(buildingXP.Value)

		if newLevel > oldLevel and newLevel <= MAX_LEVEL then
			buildingLevel.Value = newLevel

			-- Update happiness when building levels up
			local plot = building.Parent and building.Parent.Parent and building.Parent.Parent.Parent
			if plot then
				local BuildingStats = require(script.Parent.Parent:WaitForChild("BuildingStats"))
				BuildingStats.updateBuildingStats(building, plot)
			end

			-- Apply sparkle effects and send notifications for tier milestones
			local BuildingSystem = require(script.Parent.Parent)
			local owner = BuildingSystem.getBuildingOwner(building)

			local tier
			if newLevel >= 100 and oldLevel < 100 then
				tier = "PINK TIER!"
			elseif newLevel >= 40 and oldLevel < 40 then
				tier = "DIAMOND TIER!"
			elseif newLevel >= 20 and oldLevel < 20 then
				tier = "GOLD TIER!"
			end
			if tier then
				Context.applySparkleEffect(building, newLevel)
			end
			local tutorial = owner and owner:FindFirstChild("Data") and owner.Data.PlayerInfo:FindFirstChild("Tutorial")
			if owner and not (tutorial and tutorial.IsInTutorial.Value) then
				local event = ReplicatedStorage.Events.Notifications:FindFirstChild("BuildingLevelUp")
				if event then
					event:FireClient(owner, building:GetAttribute("BuildingType") or "Building", newLevel, tier)
				end
			end

			return true, newLevel
		end

		return false, buildingLevel.Value
	end
end
