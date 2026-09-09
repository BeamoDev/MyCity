-- Completion: focused implementation for ConstructionTimer.
return function(Context)
	local State = Context.State
	local ConstructionTimer = Context.ConstructionTimer
	local TweenService = Context.TweenService
	local BuildingCompleteEvent = Context.BuildingCompleteEvent

	function ConstructionTimer.finishConstruction(
		player,
		plot,
		constructionSite,
		finalBuilding,
		size,
		isTutorial,
		skipAnimation,
		activeBuilders
	)
		if not constructionSite or not constructionSite.Parent or not constructionSite.PrimaryPart then
			return false
		end
		if player:GetAttribute("MyCityLeaving") then
			return false
		end
		if not plot or not finalBuilding or not finalBuilding.PrimaryPart or not player:FindFirstChild("Data") then
			return false
		end
		local constructionID = constructionSite:GetAttribute("ConstructionID")
		if not constructionID or State.completedConstructions[constructionID] then
			return false
		end
		local BuildingSystem = require(script.Parent.Parent.Parent.Parent.building.BuildingSystem)
		local BuildingConfig = require(script.Parent.Parent.Parent.Parent.Parent.config.BuildingConfig)
		local VFX = require(script.Parent.Parent.Parent.Parent.world.VFX)
		local ConstructionBuilder = require(script.Parent.Parent.ConstructionBuilder)
		activeBuilders = ConstructionBuilder.getActiveBuilders()
		local buildingType = constructionSite:GetAttribute("BuildingType")
		local buildingConfig = BuildingConfig[buildingType]
		if not buildingConfig then
			return false
		end
		local displayName = buildingConfig.DisplayName or buildingType
		local cframe = constructionSite.PrimaryPart.CFrame
		local level = constructionSite:GetAttribute("BuildingLevel") or 1
		local xp = constructionSite:GetAttribute("BuildingXP") or 0
		local isRobuxBuilding = constructionSite:GetAttribute("RobuxBuilding") == true
		local newBuilding = finalBuilding:Clone()
		newBuilding:SetPrimaryPartCFrame(cframe)
		newBuilding:SetAttribute("BuildingType", buildingType)
		newBuilding:SetAttribute("BuildingID", constructionID)
		newBuilding:SetAttribute("RobuxBuilding", isRobuxBuilding)
		newBuilding.Name = buildingType .. "_" .. constructionID
		BuildingSystem.setupBuildingConfig(newBuilding, buildingType, level, xp)
		-- Commit the new record and remove the old record without yielding.
		BuildingSystem.saveBuildingData(player, constructionID, buildingType, cframe, plot, level, xp, isRobuxBuilding)
		local tracker = player.Data.CurrentConstructions:FindFirstChild(constructionSite.Name)
		if tracker then
			tracker:Destroy()
		end
		State.completedConstructions[constructionID] = true
		local flag = constructionSite:FindFirstChild("TimerActive")
		if flag then
			flag.Value = false
		end
		newBuilding.Parent = plot.Buildings.Placed
		activeBuilders[player.UserId] = math.max(0, (activeBuilders[player.UserId] or 1) - 1)
		if player.Data.PlayerInfo.Tutorial.IsInTutorial.Value then
			require(script.Parent.Parent.Parent.Parent.progression.TutorialSystem).handleConstructionComplete(
				player,
				buildingType,
				constructionID
			)
		end
		if not isTutorial and not player.Data.PlayerInfo.Tutorial.IsInTutorial.Value then
			require(script.Parent.Parent.Parent.Parent.progression.PostTutorialQuest).onBuildingPlaced(
				player,
				newBuilding
			)
		end
		task.delay(60, function()
			State.completedConstructions[constructionID] = nil
		end)
		task.defer(function()
			if not newBuilding.Parent then
				return
			end
			ConstructionBuilder.updateBuilderCount(player, activeBuilders)
			BuildingSystem.addBuildingPrompts(newBuilding, player, buildingType)
			BuildingSystem.startBuildingXPLoop(newBuilding)
			BuildingSystem.updatePopulation(player)
			require(script.Parent.Parent.Parent.Parent.world.WeatherSystem).updateNewBuilding(newBuilding)
			local rarity = buildingConfig and buildingConfig.Rarity
			local playedSpecialVFX = false

			if rarity and (rarity == "Rare" or rarity == "Legendary") and not skipAnimation then
				if player and player.Parent and player.Character then
					playedSpecialVFX = VFX.CheckAndPlayRarityEffect(player, newBuilding, rarity)
				end
			end

			if not skipAnimation then
				if playedSpecialVFX then
					local riseTime = rarity == "Legendary" and 5 or 4
					local slowTweenInfo = TweenInfo.new(riseTime, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
					local tweenDistance = Context.calculateTweenDistance(size)

					local siteTweenGoal = {
						CFrame = constructionSite.PrimaryPart.CFrame - Vector3.new(0, tweenDistance * 2, 0),
					}
					local siteTween = TweenService:Create(constructionSite.PrimaryPart, slowTweenInfo, siteTweenGoal)

					newBuilding:SetPrimaryPartCFrame(newBuilding.PrimaryPart.CFrame - Vector3.new(0, tweenDistance, 0))
					local buildingTweenGoal = {
						CFrame = newBuilding.PrimaryPart.CFrame + Vector3.new(0, tweenDistance, 0),
					}
					local buildingTween = TweenService:Create(newBuilding.PrimaryPart, slowTweenInfo, buildingTweenGoal)

					siteTween:Play()
					buildingTween:Play()

					siteTween.Completed:Connect(function()
						if constructionSite and constructionSite.Parent then
							constructionSite:Destroy()
						end
					end)
				else
					Context.tweenBuildingTransition(constructionSite, newBuilding, size)
				end
			else
				if constructionSite and constructionSite.Parent then
					constructionSite:Destroy()
				end
			end

			BuildingCompleteEvent:FireClient(player, displayName)

			-- VFX effects
			local hitbox = newBuilding:FindFirstChild("Hitbox")
			if hitbox then
				local vfxAttachment = hitbox:FindFirstChild("VFX")
				if vfxAttachment then
					for _, particle in ipairs(vfxAttachment:GetChildren()) do
						if particle:IsA("ParticleEmitter") then
							particle.Enabled = true
						end
					end

					local achievementSFX = vfxAttachment:FindFirstChild("AchievementSFX")
					if achievementSFX then
						achievementSFX:Play()
					end

					task.delay(5, function()
						for _, particle in ipairs(vfxAttachment:GetChildren()) do
							if particle:IsA("ParticleEmitter") then
								particle.Enabled = false
							end
						end
						if achievementSFX and achievementSFX:IsA("Sound") then
							achievementSFX:Stop()
						end
					end)
				end
			end
		end)
		return true
	end
end
