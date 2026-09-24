local Scheduler = require(script.Parent.Parent.Parent.Parent.Parent.services.SimulationScheduler)
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
		local catalogue = require(script.Parent.Parent.Parent.Parent.Parent.config.BuildingConfig)
		local definition = catalogue[buildingType]
		if definition and definition.NoLevels then
			return
		end

		local configFolder = building:FindFirstChild("Config")
		if configFolder then
			local buildingLevel = configFolder:FindFirstChild("BuildingLevel")
			if buildingLevel and buildingLevel.Value >= 20 then
				Context.applySparkleEffect(building, buildingLevel.Value)
			end
		end

		local accrued = 0
		local cancel
		cancel = Scheduler.every(XP_GAIN_INTERVAL, function(elapsed)
			if State.buildingXPLoops[buildingId] ~= cancel then
				return false
			end
			do
				if not building or not building.Parent then
					State.buildingXPLoops[buildingId] = nil
					return false
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
							State.buildingXPLoops[buildingId] = nil
							return false
						end
						accrued += elapsed
						local ticks = math.floor(accrued / XP_GAIN_INTERVAL)
						accrued -= ticks * XP_GAIN_INTERVAL
						local xpMultiplier = BuildingXP.getXPMultiplierForBuilding(buildingType, owner)
						local xpToGive = math.floor(BASE_XP_PER_TICK * xpMultiplier) * ticks
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
		end)
		State.buildingXPLoops[buildingId] = cancel
	end

	function BuildingXP.stopBuildingXPLoop(buildingId)
		local loop = State.buildingXPLoops[buildingId]
		if loop then
			loop()
			State.buildingXPLoops[buildingId] = nil
		end
	end

	function BuildingXP.init(xpLoops, rebirthConfig)
		State.buildingXPLoops = xpLoops
		State.RebirthConfig = rebirthConfig
	end
end
