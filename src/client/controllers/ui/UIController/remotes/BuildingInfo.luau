-- RemoteBindings: focused implementation for UIController.
return function(Context)
	local State = Context.State
	local UIController = Context.UIController
	local TweenService = Context.TweenService
	local ReplicatedStorage = Context.ReplicatedStorage
	local ProximityPromptService = Context.ProximityPromptService
	local Icon = Context.Icon
	local player = Context.player
	local questEvents = Context.questEvents

	function Context.connectBuildingInfo()
		-- Enhanced client-side building UI handler
		Context.connections:connect(
			ReplicatedStorage.Events.UI.ShowBuildingUI.OnClientEvent,
			function(buildingData, building)
				-- Block during tutorial
				if Context.checkTutorialStatus() then
					return
				end
				if not State.BuildingDataFrame or not buildingData then
					return
				end
				if not building or not building.Parent then
					return
				end

				if State.BuildingDataFrame.Parent.Parent.Enabled == false then
					return
				end

				State.currentBuildingToCollect = building
				local frameElement = State.BuildingDataFrame:FindFirstChild("Frame") or State.BuildingDataFrame

				if buildingData.IsSimple then
					local headerElement = frameElement.NoData:FindFirstChild("BuildingName")
					headerElement.Text = buildingData.Name or "Building"

					local imageElement = frameElement.NoData:FindFirstChild("BuildingImage")
					if imageElement and imageElement:IsA("ImageLabel") then
						if buildingData.ImageId and buildingData.ImageId ~= 0 then
							imageElement.Image = "rbxassetid://" .. tostring(buildingData.ImageId)
						else
							imageElement.Image = ""
						end
					end

					frameElement.NoData.Visible = true
					frameElement.Data.Visible = false
					UIController.openUIFrame(State.BuildingDataFrame)
					return
				else
					print("continueing")
				end

				frameElement.NoData.Visible = false
				frameElement.Data.Visible = true

				local DataDisplay = frameElement:FindFirstChild("Data")

				local headerElement = DataDisplay:FindFirstChild("BuildingName")
				headerElement.Text = buildingData.Name or "Building"

				local imageElement = DataDisplay:FindFirstChild("BuildingImage")
				if imageElement and imageElement:IsA("ImageLabel") then
					if buildingData.ImageId and buildingData.ImageId ~= 0 then
						imageElement.Image = "rbxassetid://" .. tostring(buildingData.ImageId)
					else
						imageElement.Image = ""
					end
				end

				-- Income display
				local incomeContainer = DataDisplay.Data:FindFirstChild("Income")
				if incomeContainer then
					local incomeLabel = incomeContainer:FindFirstChild("Label")
					incomeLabel.Text = "Income: " .. Context.formatNumberShort(buildingData.Income or 0) .. "/s"
				end

				-- Level display
				local levelContainer = DataDisplay.Data:FindFirstChild("Level")
				if levelContainer then
					local levelLabel = levelContainer:FindFirstChild("Label")
					levelLabel.Text = "Level: " .. tostring(buildingData.Level or 1)
				end

				local populationContainer = DataDisplay.Data:FindFirstChild("Population")
				if populationContainer then
					local populationLabel = populationContainer:FindFirstChild("Label")
					populationLabel.Text = "Population: " .. tostring(buildingData.Population or 0)
				end

				local rarityElement = frameElement.Data:FindFirstChild("BuildingRarity")
				if rarityElement and rarityElement:IsA("TextLabel") then
					local rarity = buildingData.Rarity or "Common"
					rarityElement.Text = rarity

					if rarity == "Common" then
						rarityElement.TextColor3 = Color3.fromRGB(212, 212, 212) -- Light gray
					elseif rarity == "Uncommon" then
						rarityElement.TextColor3 = Color3.fromRGB(85, 255, 85) -- Green
					elseif rarity == "Rare" then
						rarityElement.TextColor3 = Color3.fromRGB(85, 170, 255) -- Blue
					elseif rarity == "Epic" then
						rarityElement.TextColor3 = Color3.fromRGB(212, 0, 212) -- Purple
					elseif rarity == "Legendary" then
						rarityElement.TextColor3 = Color3.fromRGB(255, 170, 0) -- Orange
					elseif rarity == "Mythic" then
						rarityElement.TextColor3 = Color3.fromRGB(255, 85, 255) -- Pink/Magenta
					else
						-- Default to common if rarity not found
						rarityElement.TextColor3 = Color3.fromRGB(212, 212, 212)
					end
				end

				local crimeContainer = DataDisplay.Data:FindFirstChild("Crime")
				if crimeContainer then
					local crimeLabel = crimeContainer:FindFirstChild("Label")
					local crimePercent = buildingData.CrimePercent or 15
					crimeLabel.Text = "Crime: " .. tostring(crimePercent) .. "%"

					if crimePercent <= 20 then
						crimeLabel.TextColor3 = Color3.fromRGB(100, 255, 100) -- Green - Safe
					elseif crimePercent <= 40 then
						crimeLabel.TextColor3 = Color3.fromRGB(255, 255, 100) -- Yellow - Moderate
					elseif crimePercent <= 60 then
						crimeLabel.TextColor3 = Color3.fromRGB(255, 165, 0) -- Orange - High
					else
						crimeLabel.TextColor3 = Color3.fromRGB(255, 100, 100) -- Red - Dangerous
					end
				end

				local fireSafetyContainer = DataDisplay.Data:FindFirstChild("FireSafety")
				if fireSafetyContainer then
					local fireSafetyLabel = fireSafetyContainer:FindFirstChild("Label")
					local fireSafety = buildingData.FireSafetyPercent or 80
					fireSafetyLabel.Text = "Fire Safety: " .. tostring(fireSafety) .. "%"
					-- Color code based on fire safety level
					if fireSafety >= 80 then
						fireSafetyLabel.TextColor3 = Color3.fromRGB(100, 255, 100) -- Green - Safe
					elseif fireSafety >= 60 then
						fireSafetyLabel.TextColor3 = Color3.fromRGB(255, 255, 100) -- Yellow - Moderate
					elseif fireSafety >= 40 then
						fireSafetyLabel.TextColor3 = Color3.fromRGB(255, 165, 0) -- Orange - Low
					else
						fireSafetyLabel.TextColor3 = Color3.fromRGB(255, 100, 100) -- Red - Dangerous
					end
				end

				local healthContainer = DataDisplay.Data:FindFirstChild("Health")
				if healthContainer then
					local healthLabel = healthContainer:FindFirstChild("Label")
					local healthPercent = buildingData.HealthPercent or 50
					healthLabel.Text = "Health: " .. tostring(healthPercent) .. "%"

					-- Color code based on health level
					if healthPercent >= 80 then
						healthLabel.TextColor3 = Color3.fromRGB(100, 255, 100) -- Green - Healthy
					elseif healthPercent >= 60 then
						healthLabel.TextColor3 = Color3.fromRGB(255, 255, 100) -- Yellow - Moderate
					elseif healthPercent >= 40 then
						healthLabel.TextColor3 = Color3.fromRGB(255, 165, 0) -- Orange - Poor
					else
						healthLabel.TextColor3 = Color3.fromRGB(255, 100, 100) -- Red - Critical
					end
				end

				local happinessContainer = DataDisplay.Data:FindFirstChild("Happiness")
				if happinessContainer then
					local happinessLabel = happinessContainer:FindFirstChild("Label")
					local happiness = buildingData.HappinessPercent or 75
					happinessLabel.Text = "Happiness: " .. tostring(happiness) .. "%"
					-- Color code based on happiness level
					if happiness >= 80 then
						happinessLabel.TextColor3 = Color3.fromRGB(100, 255, 100) -- Green - Happy
					elseif happiness >= 60 then
						happinessLabel.TextColor3 = Color3.fromRGB(255, 255, 100) -- Yellow - Neutral
					elseif happiness >= 40 then
						happinessLabel.TextColor3 = Color3.fromRGB(255, 165, 0) -- Orange - Unhappy
					else
						happinessLabel.TextColor3 = Color3.fromRGB(255, 100, 100) -- Red - Very Unhappy
					end
				end

				local radiusContainer = DataDisplay.Data:FindFirstChild("Radius")
				if radiusContainer then
					local radiusLabel = radiusContainer:FindFirstChild("Label")
					if buildingData.Radius then
						radiusLabel.Text = "Range: " .. tostring(buildingData.Radius) .. " studs"
						radiusContainer.Visible = true

						crimeContainer.Visible = false
						fireSafetyContainer.Visible = false
					else
						radiusContainer.Visible = false

						crimeContainer.Visible = true
						fireSafetyContainer.Visible = true
					end
				end

				UIController.openUIFrame(State.BuildingDataFrame)
			end
		)
	end
end
