local State = {}
local ConstructionTimer = {}

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local GAME_PASS_ID2 = 1406735933
local UpdateConstructionsEvent = ReplicatedStorage.Events.UI.UpdateConstructionUI
local BuildingCompleteEvent = ReplicatedStorage.Events.Notifications.BuildingComplete

State.activeTimers = {}
State.completedConstructions = {}

local Context = {
	State = State,
	ConstructionTimer = ConstructionTimer,
	TweenService = TweenService,
	ReplicatedStorage = ReplicatedStorage,
	MarketplaceService = MarketplaceService,
	GAME_PASS_ID2 = GAME_PASS_ID2,
	UpdateConstructionsEvent = UpdateConstructionsEvent,
	BuildingCompleteEvent = BuildingCompleteEvent,
}
require(script:WaitForChild("Visuals"))(Context)
require(script:WaitForChild("Completion"))(Context)
require(script:WaitForChild("Timing"))(Context)
require(script:WaitForChild("PlayerView"))(Context)
require(script:WaitForChild("Lifecycle"))(Context)

return ConstructionTimer
