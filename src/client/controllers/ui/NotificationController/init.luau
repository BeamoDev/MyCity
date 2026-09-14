local Scope = require(game:GetService("ReplicatedStorage").shared.util.ConnectionScope)
local State = {}
local NotificationController = {}

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
require(game:GetService("ReplicatedStorage"):WaitForChild("shared"):WaitForChild("Network")).wait()
local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

State.playerGui = nil
State.notificationsFrame = nil
local activeNotifications = {}

local recentNotifications = {}

local MAX_NOTIFICATIONS = 3

local NOTIFICATION_DATA = {
	BuildingStole = { textColor = Color3.fromRGB(255, 90, 60), sound = "Error" },
	BuildingComplete = {
		textColor = Color3.fromRGB(255, 255, 83),
		sound = "NotificationLow",
		flashColor = Color3.fromRGB(255, 255, 83),
	},
	ComingSoon = {
		textColor = Color3.fromRGB(255, 255, 255), -- White text
		sound = "NotificationLow",
		flashColor = nil,
	},
	ItemBought = {
		textColor = Color3.fromRGB(81, 255, 78),
		sound = "CaChing",
		flashColor = Color3.fromRGB(81, 255, 78),
	},
	BuildingDeleted = {
		textColor = Color3.fromRGB(255, 69, 69),
		sound = "NotificationLow",
		flashColor = Color3.fromRGB(255, 69, 69),
	},
	NotYourPlot = {
		textColor = Color3.fromRGB(255, 69, 69),
		sound = "Error",
		flashColor = Color3.fromRGB(255, 69, 69),
	},
	PurchaseSuccessful = {
		textColor = Color3.fromRGB(26, 255, 0),
		sound = "CaChing",
		flashColor = Color3.fromRGB(26, 255, 0),
	},
	NotEnoughCash = {
		textColor = Color3.fromRGB(255, 69, 69),
		sound = "Error",
		flashColor = Color3.fromRGB(255, 69, 69),
	},
	MaxBuilt = {
		textColor = Color3.fromRGB(251, 255, 0),
		sound = "Error",
		flashColor = Color3.fromRGB(251, 255, 0),
	},
	CannotPlace = {
		textColor = Color3.fromRGB(255, 0, 0),
		sound = "Error",
		flashColor = Color3.fromRGB(255, 0, 0),
	},
	BuildingLimitReached = {
		textColor = Color3.fromRGB(255, 69, 69),
		sound = "Error",
		flashColor = nil,
	},
	TeleportError = {
		textColor = Color3.fromRGB(255, 69, 69),
		sound = "Error",
		flashColor = nil,
	},
	LevelUp = {
		textColor = Color3.fromRGB(255, 215, 0),
		sound = "Achievement",
		flashColor = Color3.fromRGB(255, 215, 0),
	},
	GroupReward = {
		textColor = Color3.fromRGB(81, 255, 78),
		sound = "Achievement",
		flashColor = Color3.fromRGB(81, 255, 78),
	},
}

local Context = {
	State = State,
	connections = Scope.new(),
	NotificationController = NotificationController,
	TweenService = TweenService,
	ReplicatedStorage = ReplicatedStorage,
	SoundService = SoundService,
	RunService = RunService,
	Players = Players,
	activeNotifications = activeNotifications,
	recentNotifications = recentNotifications,
	MAX_NOTIFICATIONS = MAX_NOTIFICATIONS,
	NOTIFICATION_DATA = NOTIFICATION_DATA,
}
require(script:WaitForChild("Layout"))(Context)
require(script:WaitForChild("Queue"))(Context)
require(script:WaitForChild("RemoteBindings"))(Context)
require(script:WaitForChild("Lifecycle"))(Context)

NotificationController.clearConnections = function()
	Context.connections:clear()
end
NotificationController.cleanup = NotificationController.clearAll
return NotificationController
