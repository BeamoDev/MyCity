local State = {}
local IncomeSystem = {}

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")

local plotsFolder = Workspace:WaitForChild("Plots")
local updateInterval = 1
local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

local collectIncomeEvent = ReplicatedStorage.Events.Notifications:WaitForChild("CollectIncome")
local errorEvent = ReplicatedStorage.Events.Notifications:WaitForChild("ErrorEvent")

local RebirthConfig = require(script.Parent.Parent:WaitForChild("progression"):WaitForChild("RebirthConfig"))

-- Crime system configuration
local CRIME_INCOME_PENALTY = 0.02 -- 2% income loss per 1% crime above 20%
local CRIME_THRESHOLD = 20 -- Crime percentage where penalties start

-- INCOME SYSTEM CONFIG FOLDER CONTENTS TABLE
local INCOME_CONFIG_CONTENTS = {
	"BuildingName", -- StringValue: Name of the building type
	"BuildingLevel", -- IntValue: Current level (1-99)
	"BuildingXP", -- IntValue: Current XP for leveling
	"Health", -- IntValue: Building health (default 100)
	"CollectedIncome", -- IntValue: Accumulated income to collect
	"CrimePercent", -- IntValue: Crime percentage (0-100)
	"HappinessPercent", -- IntValue: Happiness percentage (0-100)
}

local playerFriendBoosts = {}
local buttonDebounces = {}
local plotOwners = {}
local activeConnections = {}
local proximityPrompts = {}

State.CityNameSystem = nil

local DOUBLE_CASH_GAMEPASS_ID = 1406723890

local Context = {
	State = State,
	IncomeSystem = IncomeSystem,
	Workspace = Workspace,
	ReplicatedStorage = ReplicatedStorage,
	TweenService = TweenService,
	Players = Players,
	RunService = RunService,
	MarketplaceService = MarketplaceService,
	plotsFolder = plotsFolder,
	updateInterval = updateInterval,
	tweenInfo = tweenInfo,
	collectIncomeEvent = collectIncomeEvent,
	errorEvent = errorEvent,
	RebirthConfig = RebirthConfig,
	CRIME_INCOME_PENALTY = CRIME_INCOME_PENALTY,
	CRIME_THRESHOLD = CRIME_THRESHOLD,
	INCOME_CONFIG_CONTENTS = INCOME_CONFIG_CONTENTS,
	playerFriendBoosts = playerFriendBoosts,
	buttonDebounces = buttonDebounces,
	plotOwners = plotOwners,
	activeConnections = activeConnections,
	proximityPrompts = proximityPrompts,
	DOUBLE_CASH_GAMEPASS_ID = DOUBLE_CASH_GAMEPASS_ID,
}
require(script:WaitForChild("Calculation"))(Context)
require(script:WaitForChild("Collection"))(Context)
require(script:WaitForChild("PlotDisplays"))(Context)
require(script:WaitForChild("BuildingAlerts"))(Context)
require(script:WaitForChild("Lifecycle"))(Context)

return IncomeSystem
