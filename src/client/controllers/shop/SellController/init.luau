local Scope = require(game:GetService("ReplicatedStorage").shared.util.ConnectionScope)
local State = {}
local SellController = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
require(game:GetService("ReplicatedStorage"):WaitForChild("shared"):WaitForChild("Network")).wait()
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
State.playerGui = nil
State.sellMenu = nil
State.sellFrame = nil

State.equippedToolName = nil
State.equippedToolCost = nil
State.equippedToolIcon = nil
State.sellItemButton = nil
State.statusLabel = nil

State.constructBuildingFrame = nil
State.equipBuildingFrame = nil

State.currentTool = nil
State.canSell = false
State.currentUIState = "none"

local SellEvents = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Sell")
local SellItemEvent = SellEvents:WaitForChild("SellItem")
local OpenSellUIEvent = SellEvents:WaitForChild("OpenUI")
local UpdateUIEvent = ReplicatedStorage.Events.Sell:WaitForChild("SellUICurrentTool")
local CleanupPreviewEvent = ReplicatedStorage.Events.Movement:WaitForChild("CleanupPreview")

local Context = {
	State = State,
	connections = Scope.new(),
	SellController = SellController,
	Players = Players,
	ReplicatedStorage = ReplicatedStorage,
	TweenService = TweenService,
	SoundService = SoundService,
	player = player,
	SellEvents = SellEvents,
	SellItemEvent = SellItemEvent,
	OpenSellUIEvent = OpenSellUIEvent,
	UpdateUIEvent = UpdateUIEvent,
	CleanupPreviewEvent = CleanupPreviewEvent,
}
require(script:WaitForChild("Formatting"))(Context)
require(script:WaitForChild("PreviewCleanup"))(Context)
require(script:WaitForChild("Display"))(Context)
require(script:WaitForChild("RemoteBindings"))(Context)
require(script:WaitForChild("Lifecycle"))(Context)

SellController.clearConnections = function()
	Context.connections:clear()
end
return SellController
