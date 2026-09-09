local Scope = require(game:GetService("ReplicatedStorage").shared.util.ConnectionScope)
local State = {}
local TutorialController = {}

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
require(game:GetService("ReplicatedStorage"):WaitForChild("shared"):WaitForChild("Network")).wait()
local Players = game:GetService("Players")

local player = Players.LocalPlayer
State.playerGui = nil
State.ButtonFolder = nil
State.FramesFolder = nil
State.UIController = nil

State.TutorialStageOne = nil
State.TutorialStageTwo = nil
State.TutorialFrame = nil

local tutorialState = {
	isActive = false,
	currentStage = 0,
	connections = {},
	cameraOrbitConnection = nil,
	beamInstance = nil,
	playerAnchor = nil,
	anchorAttachment = nil,
	tileHighlights = {}, -- Add tile highlights tracking
}

-- Helper function to get player plot

local Context = {
	State = State,
	connections = Scope.new(),
	TutorialController = TutorialController,
	TweenService = TweenService,
	RunService = RunService,
	ReplicatedStorage = ReplicatedStorage,
	Players = Players,
	player = player,
	tutorialState = tutorialState,
}
require(script:WaitForChild("Highlights"))(Context)
require(script:WaitForChild("Subtitles"))(Context)
require(script:WaitForChild("Guidance"))(Context)
require(script:WaitForChild("Camera"))(Context)
require(script:WaitForChild("Stages"))(Context)
require(script:WaitForChild("Lifecycle"))(Context)

TutorialController.clearConnections = function()
	Context.connections:clear()
end
TutorialController.cleanup = Context.cleanupTutorial
return TutorialController
