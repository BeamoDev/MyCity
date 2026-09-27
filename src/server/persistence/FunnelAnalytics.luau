local FunnelAnalytics = {}

local AnalyticsService = game:GetService("AnalyticsService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TutorialConfig = require(script.Parent.Parent.config.TutorialConfig)

-- Track active player sessions
local playerSessions = {}
local PROGRESSION_FUNNEL = "NewPlayerProgression_v1"
local PROGRESSION_FUNNEL_VERSION = 1
local TUTORIAL_LAST_STEP = 13
local QUEST_COUNT = 35

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

local function progressionValues(player)
	local info = player:FindFirstChild("Data") and player.Data:FindFirstChild("PlayerInfo")
	if not info then
		return nil
	end
	return info:FindFirstChild("ProgressionFunnelVersion"), info:FindFirstChild("ProgressionFunnelId")
end

local function isEnrolled(player)
	local version, funnelId = progressionValues(player)
	return version
		and funnelId
		and version.Value == PROGRESSION_FUNNEL_VERSION
		and type(funnelId.Value) == "string"
		and funnelId.Value ~= ""
end

-- One lifetime funnel: first join, tutorial, then the append-only post-tutorial quest chain.
function FunnelAnalytics.trackProgressionStep(player, stepNumber, stepName)
	if player.UserId == TutorialConfig.OwnerUserId then
		return false
	end
	stepNumber = math.floor(tonumber(stepNumber) or 0)
	if stepNumber < 1 or stepNumber > 49 or type(stepName) ~= "string" or not isEnrolled(player) then
		return false
	end
	local session = playerSessions[player.UserId]
	if session and stepNumber <= (session.progressionStep or 0) then
		return true
	end
	local _, funnelId = progressionValues(player)
	local ok, err = pcall(
		AnalyticsService.LogFunnelStepEvent,
		AnalyticsService,
		player,
		PROGRESSION_FUNNEL,
		funnelId.Value,
		stepNumber,
		stepName
	)
	if not ok then
		warn("[Progression Analytics]", err)
		return false
	end
	if session then
		session.progressionStep = math.max(session.progressionStep or 0, stepNumber)
	end
	print(string.format("[Progression Funnel] %s - Step %d: %s", player.Name, stepNumber, stepName))
	return true
end

function FunnelAnalytics.prepareProgression(player)
	if player.UserId == TutorialConfig.OwnerUserId then
		return false
	end
	FunnelAnalytics.initPlayer(player)
	local version, funnelId = progressionValues(player)
	if not version or not funnelId then
		return false
	end
	if version.Value == 0 then
		-- Do not inject established profiles halfway through a new-player funnel.
		if not player:GetAttribute("MyCityNewProfile") then
			return false
		end
		version.Value = PROGRESSION_FUNNEL_VERSION
		funnelId.Value = HttpService:GenerateGUID(false)
	elseif version.Value ~= PROGRESSION_FUNNEL_VERSION then
		return false
	elseif funnelId.Value == "" then
		funnelId.Value = HttpService:GenerateGUID(false)
	end

	FunnelAnalytics.trackProgressionStep(player, 1, "PlayerJoined")

	-- Recover the highest milestone proven by durable tutorial/quest state after a rejoin.
	local info = player.Data.PlayerInfo
	local tutorial = info.Tutorial
	local stage = tutorial.ServerStage.Value
	local tutorialStepByStage = { [0] = 1, [1] = 3, [2] = 5, [3] = 6, [4] = 7, [5] = 9, [6] = 11, [7] = 12 }
	local provenStep = tutorialStepByStage[stage] or 1
	if not tutorial.IsInTutorial.Value then
		provenStep = TUTORIAL_LAST_STEP
	end
	if provenStep > 1 then
		FunnelAnalytics.trackProgressionStep(player, provenStep, FunnelAnalytics.stepName(provenStep))
	end
	return true
end

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

local TUTORIAL_STEP_NAMES = {
	[1] = "PlayerJoined",
	[2] = "TutorialStarted",
	[3] = "BankToolReceived",
	[4] = "BankEquipped",
	[5] = "BankPlaced",
	[6] = "BankConstructed",
	[7] = "FirstIncomeCollected",
	[8] = "TutorialShopOpened",
	[9] = "TutorialShackPurchased",
	[10] = "ShackEquipped",
	[11] = "TutorialShackPlaced",
	[12] = "TutorialShackConstructed",
	[13] = "TutorialCompleted",
}

function FunnelAnalytics.stepName(step)
	if TUTORIAL_STEP_NAMES[step] then
		return TUTORIAL_STEP_NAMES[step]
	end
	if step == 49 then
		return "AllProgressionCompleted"
	end
	return "ProgressionStep_" .. tostring(step)
end

-- Tutorial namespace - the first thirteen steps of the lifetime funnel.
FunnelAnalytics.Tutorial = {}

function FunnelAnalytics.Tutorial.Started(player)
	FunnelAnalytics.trackProgressionStep(player, 2, TUTORIAL_STEP_NAMES[2])
end

function FunnelAnalytics.Tutorial.BankGiven(player)
	FunnelAnalytics.trackProgressionStep(player, 3, TUTORIAL_STEP_NAMES[3])

end

function FunnelAnalytics.Tutorial.BankEquipped(player)
	FunnelAnalytics.trackProgressionStep(player, 4, TUTORIAL_STEP_NAMES[4])
end

function FunnelAnalytics.Tutorial.BankPlaced(player)
	FunnelAnalytics.trackProgressionStep(player, 5, TUTORIAL_STEP_NAMES[5])
end

function FunnelAnalytics.Tutorial.BankBuilt(player)
	FunnelAnalytics.trackProgressionStep(player, 6, TUTORIAL_STEP_NAMES[6])
end

function FunnelAnalytics.Tutorial.IncomeCollected(player)
	FunnelAnalytics.trackProgressionStep(player, 7, TUTORIAL_STEP_NAMES[7])
end

function FunnelAnalytics.Tutorial.ShopOpened(player)
	FunnelAnalytics.trackProgressionStep(player, 8, TUTORIAL_STEP_NAMES[8])
end

function FunnelAnalytics.Tutorial.ShackPurchased(player)
	FunnelAnalytics.trackProgressionStep(player, 9, TUTORIAL_STEP_NAMES[9])
end

function FunnelAnalytics.Tutorial.ShackEquipped(player)
	FunnelAnalytics.trackProgressionStep(player, 10, TUTORIAL_STEP_NAMES[10])
end

function FunnelAnalytics.Tutorial.ShackPlaced(player)
	FunnelAnalytics.trackProgressionStep(player, 11, TUTORIAL_STEP_NAMES[11])
end

function FunnelAnalytics.Tutorial.ShackBuilt(player)
	FunnelAnalytics.trackProgressionStep(player, 12, TUTORIAL_STEP_NAMES[12])
end

function FunnelAnalytics.Tutorial.Completed(player)
	FunnelAnalytics.trackProgressionStep(player, 13, TUTORIAL_STEP_NAMES[13])
end

FunnelAnalytics.Quest = {}

function FunnelAnalytics.Quest.Completed(player, questIndex, questId)
	questIndex = math.floor(tonumber(questIndex) or 0)
	if questIndex < 1 or questIndex > QUEST_COUNT or type(questId) ~= "string" then
		return false
	end
	return FunnelAnalytics.trackProgressionStep(
		player,
		TUTORIAL_LAST_STEP + questIndex,
		string.format("Q%02d_%s", questIndex, questId)
	)
end

function FunnelAnalytics.Quest.Reconcile(player, questProgression, allCompleted, questId)
	questProgression = math.clamp(math.floor(tonumber(questProgression) or 0), 0, QUEST_COUNT)
	if questProgression > 0 and type(questId) == "string" then
		FunnelAnalytics.trackProgressionStep(
			player,
			TUTORIAL_LAST_STEP + questProgression,
			string.format("Q%02d_%s", questProgression, questId)
		)
	end
	if allCompleted and questProgression >= QUEST_COUNT then
		FunnelAnalytics.Quest.AllCompleted(player)
	end
end

function FunnelAnalytics.Quest.AllCompleted(player)
	return FunnelAnalytics.trackProgressionStep(player, 49, "AllProgressionCompleted")
end

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
