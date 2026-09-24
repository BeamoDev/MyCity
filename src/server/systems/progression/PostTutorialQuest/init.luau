local State = {}
local PostTutorialQuest = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local events = ReplicatedStorage:WaitForChild("Events")
local questFolder = events:WaitForChild("PostTutorialQuest")
local evUpdate = questFolder:WaitForChild("UpdateQuest")
local evComplete = questFolder:WaitForChild("QuestComplete")
local evAllDone = questFolder:WaitForChild("AllQuestsDone")

local playerStates = {}
local placedBuildingIds = {}

-- Quest definitions with rewards (append-only; see QuestList).
local QUESTS = require(script:WaitForChild("QuestList"))

-- Helper functions

local Context = {
	State = State,
	PostTutorialQuest = PostTutorialQuest,
	Players = Players,
	ReplicatedStorage = ReplicatedStorage,
	Workspace = Workspace,
	events = events,
	questFolder = questFolder,
	evUpdate = evUpdate,
	evComplete = evComplete,
	evAllDone = evAllDone,
	playerStates = playerStates,
	placedBuildingIds = placedBuildingIds,
	QUESTS = QUESTS,
}
require(script:WaitForChild("State"))(Context)
require(script:WaitForChild("Progression"))(Context)
require(script:WaitForChild("Objectives"))(Context)
require(script:WaitForChild("Lifecycle"))(Context)

return PostTutorialQuest
