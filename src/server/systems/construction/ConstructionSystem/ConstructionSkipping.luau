local ConstructionSkipping = {}

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local plotsFolder = Workspace:WaitForChild("Plots")

local SKIP_TIME_PRODUCTS = {
	[1] = { Time = 300, ProductId = 3375059582 },
	[2] = { Time = 900, ProductId = 3375059694 },
	[3] = { Time = 1800, ProductId = 3375059795 },
	[4] = { Time = 3600, ProductId = 3375059899 },
	[5] = { Time = 7200, ProductId = 3375059969 },
	[6] = { Time = 21600, ProductId = 3375060077 },
	[7] = { Time = 100000000, ProductId = 3375060171 },
}

local activeTimers = {}

function ConstructionSkipping.addSkipBuildPrompt(player, constructionSite, activeTimersRef)
	local skipPrompt =
		game:GetService("ReplicatedStorage"):WaitForChild("Assets"):WaitForChild("Items"):FindFirstChild("SkipPrompt")
	if not skipPrompt then
		return
	end

	local prompt = skipPrompt:Clone()
	prompt.Parent = constructionSite.Hitbox

	-- Add owner attribute for client-side text updating
	prompt:SetAttribute("OwnerUserId", player.UserId)
	prompt.ActionText = "Skip" -- Default text

	local NewString = Instance.new("StringValue")
	NewString.Parent = constructionSite.Hitbox
	NewString.Name = "PromptVal"
	NewString.Value = "Construction"

	prompt.Triggered:Connect(function(plr)
		if player.UserId == plr.UserId then
			-- Owner logic - skip construction (existing code stays the same)
			local constructionID = constructionSite:GetAttribute("ConstructionID")
			local buildingType = constructionSite:GetAttribute("BuildingType")
			local identifier = buildingType .. "_" .. constructionID

			plr:SetAttribute("LastPromptedConstructionSite", identifier)

			local timerData = activeTimersRef[identifier]
			local actualRemainingTime = 0

			if timerData then
				actualRemainingTime = timerData.remainingTime
			else
				local currentConstructions = player.Data:FindFirstChild("CurrentConstructions")
				local tracker = currentConstructions and currentConstructions:FindFirstChild(identifier)
				if tracker then
					local ConstructionData = require(script.Parent:WaitForChild("ConstructionData"))
					local data = ConstructionData.loadConstructionData(tracker.Value)
					actualRemainingTime = data.timeLeft
				end
			end

			for _, config in ipairs(SKIP_TIME_PRODUCTS) do
				if actualRemainingTime <= config.Time then
					require(script.Parent.Parent.Parent.Parent.services.MarketPlaceHandler.PurchaseIntents).open(
						player,
						config.ProductId,
						{ Kind = "Skip", Identifier = identifier }
					)
					return
				end
			end
		else
			require(script.Parent.Parent.Parent.Parent.services.MarketPlaceHandler.PurchaseIntents).open(
				plr,
				3375062345,
				{
					Kind = "Steal",
					OwnerId = player.UserId,
					Identifier = constructionSite.Name,
					Construction = true,
				}
			)
		end
	end)
end

function ConstructionSkipping.skipConstruction(player, constructionSiteIdentifier)
	local buildingType, constructionID = string.match(constructionSiteIdentifier, "^([^_]+)_(.+)$")
	if not buildingType or not constructionID then
		return false
	end

	local plotData = player:FindFirstChild("Data")
		and player.Data:FindFirstChild("PlotInfo")
		and player.Data.PlotInfo:FindFirstChild("Plot")
	if not plotData or plotData.Value == 0 then
		return false
	end

	local plot = plotsFolder:FindFirstChild("Plot" .. plotData.Value)
	if not plot then
		return false
	end

	local buildingsFolder = plot:FindFirstChild("Buildings")
	if not buildingsFolder then
		return false
	end
	local constructionFolder = buildingsFolder:FindFirstChild("Construction")
	if not constructionFolder then
		return false
	end

	local constructionSite = nil
	for _, site in pairs(constructionFolder:GetChildren()) do
		if
			site:GetAttribute("BuildingType") == buildingType
			and site:GetAttribute("ConstructionID") == constructionID
		then
			constructionSite = site
			break
		end
	end

	if not constructionSite then
		return false
	end

	local BuildingConfig =
		require(script.Parent.Parent.Parent.Parent:WaitForChild("config"):WaitForChild("BuildingConfig"))
	local buildingConfig = BuildingConfig[buildingType]
	if not buildingConfig then
		return false
	end

	local finalBuilding = game:GetService("ServerStorage").Buildings:FindFirstChild(buildingType)
	if not finalBuilding then
		return false
	end

	local ConstructionTimer = require(script.Parent:WaitForChild("ConstructionTimer"))
	local success = ConstructionTimer.finishConstruction(
		player,
		plot,
		constructionSite,
		finalBuilding,
		buildingConfig.Size,
		false,
		true,
		nil
	)

	activeTimers[constructionSiteIdentifier] = nil

	return success == true
end

function ConstructionSkipping.init(activeTimersRef)
	activeTimers = activeTimersRef
end

return ConstructionSkipping
