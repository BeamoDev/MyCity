local FunnelAnalytics = {}

local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TutorialConfig = require(script.Parent.Parent.config.TutorialConfig)

-- Track active player sessions
local playerSessions = {}

-- Playtime milestones in seconds
local PLAYTIME_MILESTONES = {
	60, -- 1 minute
	120, -- 2 minutes
	180, -- 3 minutes
	300, -- 5 minutes
	600, -- 10 minutes
	900, -- 15 minutes
	1800, -- 30 minutes
	3600, -- 1 hour
}

-- Initialize player session
function FunnelAnalytics.initPlayer(player)
	if playerSessions[player.UserId] then
		return
	end
	playerSessions[player.UserId] = {
		joinTime = tick(),
		completedMilestones = {},
	}

	FunnelAnalytics.startPlaytimeTracking(player)
end

-- Tutorial funnel tracking (uses OnboardingFunnelStepEvent)
function FunnelAnalytics.trackTutorialStep(player, stepNumber, stepName)
	if TutorialConfig.ReplayEveryJoin and player.UserId == TutorialConfig.OwnerUserId then
		return
	end
	local ok, err = pcall(AnalyticsService.LogOnboardingFunnelStepEvent, AnalyticsService, player, stepNumber, stepName)
	if not ok then
		warn("[Tutorial Analytics]", err)
	end

	print(string.format("[Tutorial Funnel] %s - Step %d: %s", player.Name, stepNumber, stepName))
end

--[[
-- Quest progression tracking
function FunnelAnalytics.trackQuestProgress(player, questName, step, stepName)
	-- Ensure step is a valid number
	step = tonumber(step) or 0

	AnalyticsService:LogProgressionEvent(
		player,
		{
			progressionPathName = questName,
			level = step,
			levelName = stepName or ("Step_" .. tostring(step))
		}
	)

	print(string.format("[Quest Progress] %s - %s: Step %d - %s", 
		player.Name, questName, step, stepName or "Unknown"))
end]]

-- Playtime milestone tracking
function FunnelAnalytics.startPlaytimeTracking(player)
	local connection
	local nextCheck = 0
	connection = RunService.Heartbeat:Connect(function()
		if os.clock() < nextCheck then
			return
		end
		nextCheck = os.clock() + 1
		if not player.Parent then
			connection:Disconnect()
			playerSessions[player.UserId] = nil
			return
		end

		local session = playerSessions[player.UserId]
		if not session then
			connection:Disconnect()
			return
		end

		if os.clock() < (session.retryAt or 0) then
			return
		end
		local playtime = tick() - session.joinTime

		for _, milestone in ipairs(PLAYTIME_MILESTONES) do
			if playtime >= milestone and not session.completedMilestones[milestone] then
				local ok =
					pcall(AnalyticsService.LogCustomEvent, AnalyticsService, player, "PlaytimeMilestone", milestone)
				if not ok then
					session.retryAt = os.clock() + 60
					break
				end
				session.completedMilestones[milestone] = true

				print(string.format("[Playtime] %s reached %d seconds", player.Name, milestone))
			end
		end
	end)
end

-- Tutorial namespace - all tutorial events go through OnboardingFunnelStepEvent
FunnelAnalytics.Tutorial = {}

function FunnelAnalytics.Tutorial.Started(player)
	FunnelAnalytics.trackTutorialStep(player, 1, "TutorialStarted")
end

function FunnelAnalytics.Tutorial.BankGiven(player)
	FunnelAnalytics.trackTutorialStep(player, 2, "BankToolReceived")
end

function FunnelAnalytics.Tutorial.BankPlaced(player)
	FunnelAnalytics.trackTutorialStep(player, 3, "BankPlaced")
end

function FunnelAnalytics.Tutorial.BankBuilt(player)
	FunnelAnalytics.trackTutorialStep(player, 4, "BankConstructed")
end

function FunnelAnalytics.Tutorial.IncomeCollected(player)
	FunnelAnalytics.trackTutorialStep(player, 5, "FirstIncomeCollected")
end

function FunnelAnalytics.Tutorial.ShopOpened(player)
	FunnelAnalytics.trackTutorialStep(player, 6, "TutorialShopOpened")
end

function FunnelAnalytics.Tutorial.ShackPurchased(player)
	-- This is a tutorial step, not a real purchase
	FunnelAnalytics.trackTutorialStep(player, 7, "TutorialShackPurchased")
end

function FunnelAnalytics.Tutorial.ShackPlaced(player)
	FunnelAnalytics.trackTutorialStep(player, 8, "TutorialShackPlaced")
end

function FunnelAnalytics.Tutorial.Completed(player)
	FunnelAnalytics.trackTutorialStep(player, 9, "TutorialCompleted")
end

--[[
-- Post-tutorial quest namespace
FunnelAnalytics.Quest = {}

function FunnelAnalytics.Quest.Started(player)
	FunnelAnalytics.trackQuestProgress(player, "PostTutorialQuest", 0, "QuestStarted")
end

function FunnelAnalytics.Quest.BuildingPlaced(player, buildingCount)
	FunnelAnalytics.trackQuestProgress(player, "PostTutorialQuest", buildingCount, "Buildings_" .. buildingCount)
end

function FunnelAnalytics.Quest.Completed(player)
	FunnelAnalytics.trackQuestProgress(player, "PostTutorialQuest", 5, "QuestCompleted_MansionReward")
end
]]

-- Initialize
local initialized = false
function FunnelAnalytics.init()
	if initialized then
		return
	end
	initialized = true
	Players.PlayerAdded:Connect(function(player)
		FunnelAnalytics.initPlayer(player)
	end)

	for _, player in Players:GetPlayers() do
		FunnelAnalytics.initPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		playerSessions[player.UserId] = nil
	end)
end

return FunnelAnalytics
