local Ownership = require(script.Parent.Parent.Parent.Parent.services.GamePassOwnership)
local ConstructionBuilder = {}

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local plotsFolder = Workspace:WaitForChild("Plots")
local UpdateBuilderUIEvent = ReplicatedStorage.Events.UI:WaitForChild("UpdateBuilderUI")

local BUILDER_GAMEPASS_ID = 1407360513
local MAX_BUILDERS = 7
local activeBuilders = {}

local function ownsBuilderGamePass(player)
	return Ownership.has(player, BUILDER_GAMEPASS_ID)
end

function ConstructionBuilder.getMaxBuilders(player)
	return ownsBuilderGamePass(player) and (MAX_BUILDERS + 1) or MAX_BUILDERS
end

function ConstructionBuilder.getActiveBuilders()
	return activeBuilders
end

function ConstructionBuilder.updateBuilderCount(player, activeBuildersRef)
	activeBuildersRef = activeBuilders
	if not player or not player.Parent then
		return
	end

	local plotData = player:FindFirstChild("Data")
		and player.Data:FindFirstChild("PlotInfo")
		and player.Data.PlotInfo:FindFirstChild("Plot")

	if not plotData or plotData.Value == 0 then
		activeBuildersRef[player.UserId] = 0
		UpdateBuilderUIEvent:FireClient(player, 0, ConstructionBuilder.getMaxBuilders(player))
		return
	end

	local plot = plotsFolder:FindFirstChild("Plot" .. plotData.Value)
	if not plot then
		activeBuildersRef[player.UserId] = 0
		UpdateBuilderUIEvent:FireClient(player, 0, ConstructionBuilder.getMaxBuilders(player))
		return
	end

	local buildingsFolder = plot:FindFirstChild("Buildings")
	if not buildingsFolder then
		activeBuildersRef[player.UserId] = 0
		UpdateBuilderUIEvent:FireClient(player, 0, ConstructionBuilder.getMaxBuilders(player))
		return
	end

	local constructionFolder = buildingsFolder:FindFirstChild("Construction")
	if not constructionFolder then
		activeBuildersRef[player.UserId] = 0
		UpdateBuilderUIEvent:FireClient(player, 0, ConstructionBuilder.getMaxBuilders(player))
		return
	end

	local count = 0
	for _, construction in pairs(constructionFolder:GetChildren()) do
		if construction:FindFirstChild("TimerActive") and construction.TimerActive.Value then
			count += 1
		end
	end

	activeBuildersRef[player.UserId] = count
	UpdateBuilderUIEvent:FireClient(player, count, ConstructionBuilder.getMaxBuilders(player))
end

function ConstructionBuilder.init(activeBuildersRef, builderGamepassId, maxBuilders)
	activeBuilders = activeBuildersRef
	BUILDER_GAMEPASS_ID = builderGamepassId or BUILDER_GAMEPASS_ID
	MAX_BUILDERS = maxBuilders or MAX_BUILDERS
end

return ConstructionBuilder
