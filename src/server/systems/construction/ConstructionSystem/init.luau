local ConstructionSystem = {}

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Import sub-modules
local ConstructionTimer = require(script:WaitForChild("ConstructionTimer"))
local ConstructionData = require(script:WaitForChild("ConstructionData"))
local ConstructionSkipping = require(script:WaitForChild("ConstructionSkipping"))
local ConstructionBuilder = require(script:WaitForChild("ConstructionBuilder"))
local ConstructionVFX = require(script:WaitForChild("ConstructionVFX"))

local plotsFolder = Workspace:WaitForChild("Plots")
local BUILDER_GAMEPASS_ID = 1407360513
local MAX_BUILDERS = 7

local completedConstructions = {}
local activeTimers = {}
local activeBuilders = {}

-- Expose sub-module functions
function ConstructionSystem.syncPlayer(player)
	ConstructionTimer.syncPlayer(player)
	ConstructionBuilder.updateBuilderCount(player, activeBuilders)
end
ConstructionSystem.getActiveBuilders = ConstructionBuilder.getActiveBuilders
ConstructionSystem.skipConstruction = ConstructionSkipping.skipConstruction
ConstructionSystem.finishConstruction = ConstructionTimer.finishConstruction
ConstructionSystem.startConstructionTimer = ConstructionTimer.startConstructionTimer
ConstructionSystem.loadPlayerConstructions = ConstructionData.loadPlayerConstructions
function ConstructionSystem.clearPlayerConstructions(player)
	for identifier, timer in activeTimers do
		local site = timer.constructionSite
		if site and site:GetAttribute("OwnerUserId") == player.UserId then
			if timer.timerActive then
				timer.timerActive.Value = false
			end
			activeTimers[identifier] = nil
		end
	end
	activeBuilders[player.UserId] = nil
	ConstructionData.clearPlayerConstructions(player)
end

local function createConstruction(
	player,
	plot,
	buildingName,
	cframe,
	buildingConfig,
	isTutorial,
	level,
	xp,
	isRobuxBuilding,
	transaction
)
	local currentBuilders = activeBuilders[player.UserId] or 0
	local maxBuilders = ConstructionBuilder.getMaxBuilders(player)
	if not require(script.Parent.Parent.security.RequestGuard).ready(player) then
		return false
	end
	currentBuilders = activeBuilders[player.UserId] or 0
	local isInTutorial = player.Data.PlayerInfo.Tutorial.IsInTutorial.Value

	if not isInTutorial then
		if currentBuilders >= maxBuilders then
			ReplicatedStorage.Events.Notifications.BuilderLimitReached:FireClient(player)
			return false
		end
	end

	local constructionModel = ReplicatedStorage.Assets:FindFirstChild("Constructions")
		and ReplicatedStorage.Assets.Constructions:FindFirstChild(buildingConfig.Size)
	if not constructionModel then
		return false
	end

	local buildingModel = game:GetService("ServerStorage"):FindFirstChild("Buildings")
		and game:GetService("ServerStorage").Buildings:FindFirstChild(buildingName)
	if not buildingModel then
		return false
	end

	local constructionSite = constructionModel:Clone()
	transaction.site = constructionSite
	constructionSite:SetPrimaryPartCFrame(cframe)
	constructionSite.Parent = plot.Buildings:FindFirstChild("Construction")

	if isRobuxBuilding then
		constructionSite:SetAttribute("RobuxBuilding", true)
	end

	activeBuilders[player.UserId] = (activeBuilders[player.UserId] or 0) + 1
	transaction.reserved = true
	task.defer(ConstructionBuilder.updateBuilderCount, player, activeBuilders)

	if constructionSite:FindFirstChild("Base") and constructionSite.Base:FindFirstChild("Ambience") then
		constructionSite.Base.Ambience.Playing = true
	end

	local constructionID = ConstructionData.generateUniqueID()
	constructionSite:SetAttribute("BuildingType", buildingName)
	constructionSite:SetAttribute("ConstructionID", constructionID)
	constructionSite.Name = buildingName .. "_" .. constructionID

	ConstructionTimer.startConstructionTimer(
		player,
		plot,
		constructionSite,
		buildingModel,
		buildingConfig.BuildTime,
		nil,
		false,
		isTutorial,
		level,
		xp,
		activeTimers,
		completedConstructions,
		activeBuilders,
		isRobuxBuilding
	)

	-- Gameplay milestones happen only after the timer and saved tracker exist.
	if isInTutorial then
		require(script.Parent.Parent.progression.TutorialSystem).handleBuildingPlacement(
			player,
			buildingName,
			constructionSite:GetAttribute("ConstructionID")
		)
	else
		require(script.Parent.Parent.progression.PostTutorialQuest).onConstructionStarted(player, buildingName)
	end
	task.defer(ConstructionVFX.applyPlacementVFX, constructionSite)
	ReplicatedStorage.Events.Notifications.PlaceSound:FireClient(player)
	return true
end

function ConstructionSystem.startConstruction(
	player,
	plot,
	buildingName,
	cframe,
	buildingConfig,
	isTutorial,
	level,
	xp,
	isRobuxBuilding
)
	local transaction = {}
	local ok, result = pcall(
		createConstruction,
		player,
		plot,
		buildingName,
		cframe,
		buildingConfig,
		isTutorial,
		level,
		xp,
		isRobuxBuilding,
		transaction
	)
	if ok and result then
		return true
	end
	if transaction.site then
		local folder = player:FindFirstChild("Data") and player.Data:FindFirstChild("CurrentConstructions")
		local tracker = folder and folder:FindFirstChild(transaction.site.Name)
		if tracker then
			tracker:Destroy()
		end
		transaction.site:Destroy()
	end
	if transaction.reserved then
		activeBuilders[player.UserId] = math.max(0, (activeBuilders[player.UserId] or 1) - 1)
	end
	if not ok then
		warn("[Construction] Placement rolled back:", result)
	end
	return false
end

function ConstructionSystem.init()
	-- Initialize sub-modules
	ConstructionTimer.init(activeTimers, completedConstructions)
	ConstructionData.init()
	ConstructionSkipping.init(activeTimers)
	ConstructionBuilder.init(activeBuilders, BUILDER_GAMEPASS_ID, MAX_BUILDERS)
	ConstructionVFX.init()

	-- Cleanup completed constructions periodically
	task.spawn(function()
		while true do
			task.wait(300)
			table.clear(completedConstructions)
		end
	end)

	-- Update builder counts periodically
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in pairs(Players:GetPlayers()) do
				ConstructionBuilder.updateBuilderCount(player, activeBuilders)
			end
		end
	end)
end

return ConstructionSystem
