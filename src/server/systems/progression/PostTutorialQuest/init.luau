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

-- Quest definitions with rewards
local QUESTS = {
	{
		id = "collect_income",
		title = "Collect Income",
		required = 1,
		reward = { type = "cash", amount = 500 },
	},
	{
		id = "construct_buildings",
		title = "Construct 3 buildings",
		required = 3,
		reward = { type = "cash", amount = 1000 },
	},
	{
		id = "buildings_total",
		title = "Have 8 buildings placed",
		required = 8,
		reward = { type = "building", building = "SheriffOffice" },
	},
	{
		id = "place_roads",
		title = "Place 5 road pieces",
		required = 5,
		reward = { type = "cash", amount = 2000 },
	},
	{
		id = "population",
		title = "Reach 100 population",
		required = 100,
		reward = { type = "building", building = "Apartments" },
	},
}

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
