local Scope = require(game:GetService("ReplicatedStorage").shared.util.ConnectionScope)
local State = {}
local UIController = {}
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
require(game:GetService("ReplicatedStorage"):WaitForChild("shared"):WaitForChild("Network")).wait()
local Lighting = game:GetService("Lighting")
local MarketPlace = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local Icon = require(ReplicatedStorage:WaitForChild("TopbarPlus"):WaitForChild("Icon"))
State.settingsIcon = nil

local Workspace = game:GetService("Workspace")
local NotificationController = require(script.Parent:WaitForChild("NotificationController"))
local player = Players.LocalPlayer
local Camera = workspace.CurrentCamera

State.playerGui = nil
State.FramesFolder = nil
State.ButtonFolder = nil
State.HUD = nil
State.rebirthRemotes = nil
State.currentRebirthData = nil
State.ShopFrame = nil
State.SellFrame = nil
State.ItemShopFrame = nil
State.SettingsFrame = nil
State.ConstructionsFrame = nil
State.GroupRewardFrame = nil
State.CityNameFrame = nil
State.BuildingDataFrame = nil
State.WorldsFrame = nil
State.RebirthFrame = nil
State.ConfirmRebirthFrame = nil
State.confirmYesConnection = nil
State.confirmNoConnection = nil
State.currentBuildingToCollect = nil
State.questUI = nil
State.deleteButtonConnection = nil
State.collectButtonConnection = nil
State.DailyRewardFrame = nil
State.dailyRewardCountdown = nil
State.dailyRewardConnection = nil
State.BuilderPackFrame = nil
State.weatherFrame = nil

State.lastRequestTime = 0
local REQUEST_COOLDOWN = 0.5
local GROUP_ID = 1050526813
local GROUP_PROMPT_DELAY = 180
local blurEffect = Lighting:FindFirstChild("Blur")
local plotsFolder = Workspace:WaitForChild("Plots")
State.editPrompts = {}
State.currentEditingPlot = nil
State.UpdateCityNameEvent = nil
local TWEEN_INFO = TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
local DEFAULT_CAMERA_FIELD_OF_VIEW = 70
local ZOOMED_FOV = DEFAULT_CAMERA_FIELD_OF_VIEW - 10
local MAX_BLUR = 24
local LD_PRODUCTID = 3290862879
State.currentOpenFrame = nil
State.isTweening = false
State.cashUpdateConnection = nil

State.comboMultiplier = 1
State.comboTimer = 0
State.lastActionTime = 0

local questEvents = ReplicatedStorage:WaitForChild("Events"):WaitForChild("PostTutorialQuest")

-- Tutorial blocking flag
State.isInTutorial = false

-- Function to check if player is in tutorial

local Context = {
	State = State,
	connections = Scope.new(),
	UIController = UIController,
	TweenService = TweenService,
	Players = Players,
	ReplicatedStorage = ReplicatedStorage,
	Lighting = Lighting,
	MarketPlace = MarketPlace,
	RunService = RunService,
	UserInputService = UserInputService,
	ProximityPromptService = ProximityPromptService,
	Icon = Icon,
	Workspace = Workspace,
	NotificationController = NotificationController,
	player = player,
	Camera = Camera,
	REQUEST_COOLDOWN = REQUEST_COOLDOWN,
	GROUP_ID = GROUP_ID,
	GROUP_PROMPT_DELAY = GROUP_PROMPT_DELAY,
	blurEffect = blurEffect,
	plotsFolder = plotsFolder,
	TWEEN_INFO = TWEEN_INFO,
	DEFAULT_CAMERA_FIELD_OF_VIEW = DEFAULT_CAMERA_FIELD_OF_VIEW,
	ZOOMED_FOV = ZOOMED_FOV,
	MAX_BLUR = MAX_BLUR,
	LD_PRODUCTID = LD_PRODUCTID,
	questEvents = questEvents,
}
require(script:WaitForChild("Presentation"))(Context)
require(script:WaitForChild("Navigation"))(Context)
require(script:WaitForChild("Displays"))(Context)
require(script:WaitForChild("CashDisplay"))(Context)
require(script:WaitForChild("CityPrompts"))(Context)
require(script:WaitForChild("RebirthConfirmation"))(Context)
require(script:WaitForChild("Rebirth"))(Context)
require(script:WaitForChild("Buttons"))(Context)
require(script:WaitForChild("DailyRewards"))(Context)
require(script:WaitForChild("DailyQuests"))(Context)
require(script:WaitForChild("BuildingActions"))(Context)
require(script:WaitForChild("RemoteBindings"))(Context)
require(script:WaitForChild("Construction"))(Context)
require(script:WaitForChild("Settings"))(Context)
require(script:WaitForChild("BuilderDisplay"))(Context)
require(script:WaitForChild("TravelButtons"))(Context)
require(script:WaitForChild("MobileScale"))(Context)
local MobilePlacement = require(script.Parent.Parent.placement.MobilePlacement)
Context.setupMobilePlacement = function()
	MobilePlacement.bind(State.HUD, Context.connections, ReplicatedStorage.Events.Movement.CleanupPreview)
end
require(script:WaitForChild("Lifecycle"))(Context)

UIController.clearConnections = function()
	Context.connections:clear()
end
return UIController
