-- Lifecycle: focused implementation for BuildingXP.
return function(Context)
	local State = Context.State
	local BuildingXP = Context.BuildingXP
	local XP_GAIN_INTERVAL = Context.XP_GAIN_INTERVAL
	local BASE_XP_PER_TICK = Context.BASE_XP_PER_TICK

	function BuildingXP.startBuildingXPLoop(building)
		local buildingId = building:GetAttribute("BuildingID")
		if not buildingId then
			return
		end

		BuildingXP.stopBuildingXPLoop(buildingId)

		local buildingType = building:GetAttribute("BuildingType")
		if not buildingType then
			return
		end

		local configFolder = building:FindFirstChild("Config")
		if configFolder then
			local buildingLevel = configFolder:FindFirstChild("BuildingLevel")
			if buildingLevel and buildingLevel.Value >= 20 then
				Context.applySparkleEffect(building, buildingLevel.Value)
			end
		end

		State.buildingXPLoops[buildingId] = task.spawn(function()
			while building and building.Parent do
				task.wait(XP_GAIN_INTERVAL)

				if not building or not building.Parent then
					break
				end

				local parentFolder = building.Parent
				if parentFolder and parentFolder.Name == "Placed" then
					-- Get the building owner to apply correct multipliers
					local BuildingSystem = require(script.Parent.Parent)
					local owner = BuildingSystem.getBuildingOwner(building)
					if
						owner
						and owner:GetAttribute("MyCityLoaded") == true
						and not owner:GetAttribute("MyCityLeaving")
					then
						local config = building:FindFirstChild("Config")
						local level = config and config:FindFirstChild("BuildingLevel")
						if level and level.Value >= Context.MAX_LEVEL then
							break
						end
						local xpMultiplier = BuildingXP.getXPMultiplierForBuilding(buildingType, owner)
						local xpToGive = math.floor(BASE_XP_PER_TICK * xpMultiplier)
						BuildingXP.addXPToBuilding(building, xpToGive)

						local currentBuildings = owner.Data:FindFirstChild("CurrentBuildings")
						if currentBuildings then
							local buildingID = building:GetAttribute("BuildingID")
							local saveEntry = currentBuildings:FindFirstChild(buildingType .. "_" .. buildingID)
							if saveEntry then
								local parts = string.split(saveEntry.Value, ",")
								if #parts >= 9 then
									local config = building:FindFirstChild("Config")
									if config then
										local level = config:FindFirstChild("BuildingLevel")
										local xp = config:FindFirstChild("BuildingXP")
										if level and xp then
											parts[8] = tostring(level.Value)
											parts[9] = tostring(xp.Value)
											saveEntry.Value = table.concat(parts, ",")
										end
									end
								end
							end
						end
					end
				end
			end

			State.buildingXPLoops[buildingId] = nil
		end)
	end

	function BuildingXP.stopBuildingXPLoop(buildingId)
		local loop = State.buildingXPLoops[buildingId]
		if loop then
			task.cancel(loop)
			State.buildingXPLoops[buildingId] = nil
		end
	end

	function BuildingXP.init(xpLoops, rebirthConfig)
		State.buildingXPLoops = xpLoops
		State.RebirthConfig = rebirthConfig
	end
end
