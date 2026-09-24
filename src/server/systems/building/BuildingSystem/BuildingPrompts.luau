local BuildingPrompts = {}

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RarityColors = require(ReplicatedStorage.shared.ui.RarityColors)

local STEAL_BUILDING_PRODUCT_ID = 3375062345
local CRIME_INCOME_PENALTY = 0.02
local BASE_CRIME_RATE = 15
local BASE_HAPPINESS = 75
local MAX_LEVEL = 99

function BuildingPrompts.addBuildingPrompts(building, player, buildingName)
	local BuildingConfig =
		require(script.Parent.Parent.Parent.Parent:WaitForChild("config"):WaitForChild("BuildingConfig"))

	local CollectPrompt = game:GetService("ReplicatedStorage")
		:WaitForChild("Assets")
		:WaitForChild("Items")
		:WaitForChild("CollectPrompt")
		:Clone()
	CollectPrompt.Parent = building.Hitbox

	local NewString = Instance.new("StringValue")
	NewString.Parent = building.Hitbox
	NewString.Name = "PromptVal"
	NewString.Value = "Building"

	CollectPrompt.ActionText = "Info"
	CollectPrompt:SetAttribute("OwnerUserId", player.UserId)

	local function updatePromptForPlayer(viewingPlayer)
		if viewingPlayer.UserId ~= player.UserId then
			CollectPrompt.ActionText = "Steal"
		else
			CollectPrompt.ActionText = "Info"
		end
	end

	local BuildingInfo = game:GetService("ReplicatedStorage")
		:WaitForChild("Assets")
		:WaitForChild("Items")
		:WaitForChild("BuildingInfo")
		:Clone()
	BuildingInfo.Parent = building.Hitbox

	local config = BuildingConfig[buildingName]
	if not config then
		warn("Building config not found for: " .. buildingName)
		return
	end

	local displayName = config.DisplayName or buildingName
	BuildingInfo.Container.BuildingName.Text = displayName

	BuildingInfo.Container.BuildingName.TextColor3 = RarityColors[config.Rarity] or RarityColors.Common

	local progressBar = BuildingInfo.Container:FindFirstChild("ProgressBar")
	local hasLevels = not config.NoLevels
	if not hasLevels then
		-- Roads have no level system: remove the level text and XP bar from their billboard.
		for _, name in { "BuildingLevel", "ProgressBar" } do
			local item = BuildingInfo.Container:FindFirstChild(name)
			if item then
				item:Destroy()
			end
		end
		progressBar = nil
	end

	local function updateBuildingLevel()
		if not hasLevels then
			return
		end
		local configFolder = building:FindFirstChild("Config")
		if configFolder then
			local BuildingXP = require(script.Parent:WaitForChild("BuildingXP"))
			local buildingLevel = configFolder:FindFirstChild("BuildingLevel")
			local buildingXP = configFolder:FindFirstChild("BuildingXP")
			local buildingLevelLabel = BuildingInfo.Container:FindFirstChild("BuildingLevel")
			local crimePercent = configFolder:FindFirstChild("CrimePercent")
			local happinessPercent = configFolder:FindFirstChild("HappinessPercent")

			local currentLevel = buildingLevel and buildingLevel.Value or 1
			local currentXP = buildingXP and buildingXP.Value or 0
			local currentCrime = crimePercent and crimePercent.Value or BASE_CRIME_RATE
			local currentHappiness = happinessPercent and happinessPercent.Value or BASE_HAPPINESS

			buildingLevelLabel.Text = "Level " .. currentLevel

			if currentLevel >= 20 then
				buildingLevelLabel.TextColor3 = Color3.fromRGB(0, 162, 255)
				buildingLevelLabel.Text = "Level " .. currentLevel .. " 💎"
			end

			if currentLevel < MAX_LEVEL then
				local xpForCurrentLevel = BuildingXP.getTotalXPForLevel(currentLevel)
				local xpForNextLevel = BuildingXP.getTotalXPForLevel(currentLevel + 1)
				local xpNeededForNextLevel = xpForNextLevel - xpForCurrentLevel
				local xpProgressInCurrentLevel = currentXP - xpForCurrentLevel

				local progressPercentage = math.clamp(xpProgressInCurrentLevel / xpNeededForNextLevel, 0, 1)

				local fillBar = progressBar:FindFirstChild("FillBar")
				if fillBar then
					-- Replicate the target once; server tweens stream intermediate GUI values.
					fillBar.Size = UDim2.new(progressPercentage, 0, 1, 0)

					if progressPercentage >= 0.9 then
						fillBar.BackgroundColor3 = Color3.fromRGB(100, 255, 100)
					elseif progressPercentage >= 0.5 then
						fillBar.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
					else
						fillBar.BackgroundColor3 = Color3.fromRGB(255, 180, 0)
					end
				end

				progressBar.Visible = true
			else
				local fillBar = progressBar:FindFirstChild("FillBar")
				if fillBar then
					fillBar.Size = UDim2.new(1, 0, 1, 0)
					fillBar.BackgroundColor3 = Color3.fromRGB(255, 100, 255)
				end
				buildingLevelLabel.Text = "Level " .. currentLevel .. " (MAX)"
				buildingLevelLabel.TextColor3 = Color3.fromRGB(255, 100, 255)
			end
		end
	end

	updateBuildingLevel()

	local configFolder = building:FindFirstChild("Config")
	if configFolder and hasLevels then
		local buildingLevel = configFolder:FindFirstChild("BuildingLevel")
		local buildingXP = configFolder:FindFirstChild("BuildingXP")
		local crimePercent = configFolder:FindFirstChild("CrimePercent")
		local happinessPercent = configFolder:FindFirstChild("HappinessPercent")

		if buildingLevel then
			buildingLevel:GetPropertyChangedSignal("Value"):Connect(updateBuildingLevel)
		end

		if buildingXP then
			buildingXP:GetPropertyChangedSignal("Value"):Connect(updateBuildingLevel)
		end
	end

	CollectPrompt.PromptShown:Connect(function(promptPlayer)
		updatePromptForPlayer(promptPlayer)
	end)

	CollectPrompt.Triggered:Connect(function(plr)
		if plr.UserId == player.UserId then
			local buildingData = {}

			if plr.Data.PlayerInfo.Tutorial.IsInTutorial.Value == true then
				return
			end

			if config then
				buildingData.Name = displayName -- Use DisplayName for UI
				buildingData.ImageId = config.ImageId or 0
				buildingData.Rarity = config.Rarity or "Common"

				-- Check if it's a decoration or ONLY infrastructure roads (not all infrastructure)
				-- Special buildings like Stadium, Airport, PowerStation are NOT simple
				local isRoad = buildingName:find("Road") ~= nil
				buildingData.IsSimple = config.IsDecoration or isRoad

				if not buildingData.IsSimple then
					-- Regular building with full stats
					local plot = building.Parent and building.Parent.Parent and building.Parent.Parent.Parent
					local BuildingStats = require(script.Parent:WaitForChild("BuildingStats"))
					local stats = BuildingStats.getBuildingStats(building, plot)

					local configFolder = building:FindFirstChild("Config")
					if configFolder then
						buildingData.Level = configFolder:FindFirstChild("BuildingLevel")
								and configFolder.BuildingLevel.Value
							or 1

						if stats then
							buildingData.CrimePercent = stats.crimePercent
							buildingData.FireSafetyPercent = stats.fireSafetyPercent
							buildingData.HappinessPercent = stats.happinessPercent
							buildingData.HealthPercent = stats.healthPercent -- ADD THIS
							if stats.radius then
								buildingData.Radius = stats.radius
							end
						end

						local Economy = require(script.Parent.Parent.Parent.economy.BuildingEconomy)
						buildingData.Income = Economy.income(config, configFolder)
						buildingData.Population = Economy.population(config, configFolder)
					else
						buildingData.Level = 1
						buildingData.Income = config.Income or 0
						buildingData.Population = config.Population or 0

						if stats then
							buildingData.CrimePercent = stats.crimePercent
							buildingData.FireSafetyPercent = stats.fireSafetyPercent
							buildingData.HappinessPercent = stats.happinessPercent
							buildingData.HealthPercent = stats.healthPercent -- ADD THIS
							if stats.radius then
								buildingData.Radius = stats.radius
							end
						else
							buildingData.CrimePercent = 15
							buildingData.FireSafetyPercent = 80
							buildingData.HappinessPercent = 75
							buildingData.HealthPercent = 50 -- ADD THIS
						end
					end
				end

				local pendingValue = Instance.new("ObjectValue")
				pendingValue.Name = "PendingBuildingUI_" .. plr.UserId
				pendingValue.Value = building
				pendingValue.Parent = building

				game:GetService("Debris"):AddItem(pendingValue, 10)
			end

			ReplicatedStorage.Events.UI.ShowBuildingUI:FireClient(plr, buildingData, building)
		else
			-- Stealing logic remains the same
			if not building or not building.Parent then
				ReplicatedStorage.Events.Movement.Unauthorized:FireClient(plr, "Building no longer exists")
				return
			end

			local BuildingStealing = require(script.Parent:WaitForChild("BuildingStealing"))
			local canSteal, ownerOrReason = BuildingStealing.canStealBuilding(plr, building)

			if canSteal then
				require(script.Parent.Parent.Parent.Parent.services.MarketPlaceHandler.PurchaseIntents).open(
					plr,
					STEAL_BUILDING_PRODUCT_ID,
					{
						Kind = "Steal",
						OwnerId = ownerOrReason.UserId,
						Identifier = building.Name,
						Construction = false,
					}
				)
			else
				ReplicatedStorage.Events.Movement.Unauthorized:FireClient(plr, ownerOrReason)
			end
		end
	end)
end

function BuildingPrompts.init()
	-- Any initialization needed for prompts
end

return BuildingPrompts
