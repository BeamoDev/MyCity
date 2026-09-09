local Init = {}
local EarlyLoading = require(script.Parent.EarlyLoading)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
require(game:GetService("ReplicatedStorage"):WaitForChild("shared"):WaitForChild("Network")).wait()
local UIEffects = require(game:GetService("ReplicatedStorage"):WaitForChild("shared"):WaitForChild("UIEffects"))
local NotificationController =
	require(script.Parent.Parent:WaitForChild("controllers"):WaitForChild("ui"):WaitForChild("NotificationController"))
local UIController, ShopController, TutorialController, SellController, FriendBoost, LikesHandler =
	{}, {}, {}, {}, {}, {}
local function loadControllers()
	UIController =
		require(script.Parent.Parent:WaitForChild("controllers"):WaitForChild("ui"):WaitForChild("UIController"))
	ShopController =
		require(script.Parent.Parent:WaitForChild("controllers"):WaitForChild("shop"):WaitForChild("ShopController"))
	TutorialController = require(
		script.Parent.Parent:WaitForChild("controllers"):WaitForChild("tutorial"):WaitForChild("TutorialController")
	)
	SellController =
		require(script.Parent.Parent:WaitForChild("controllers"):WaitForChild("shop"):WaitForChild("SellController"))
	FriendBoost =
		require(script.Parent.Parent:WaitForChild("controllers"):WaitForChild("social"):WaitForChild("FriendsBoost"))
	LikesHandler =
		require(script.Parent.Parent:WaitForChild("controllers"):WaitForChild("social"):WaitForChild("LikeSystem"))
end
local IntroController =
	require(script.Parent.Parent:WaitForChild("controllers"):WaitForChild("intro"):WaitForChild("IntroController"))
local player = Players.LocalPlayer
local currentHud = nil
local initializingThread = nil
local function stopInitializing()
	if
		initializingThread
		and initializingThread ~= coroutine.running()
		and coroutine.status(initializingThread) ~= "dead"
	then
		task.cancel(initializingThread)
	end
	initializingThread = nil
end
local function cleanupControllers()
	IntroController.cleanup()
	for _, controller in
		{
			UIController,
			NotificationController,
			ShopController,
			SellController,
			TutorialController,
			FriendBoost,
			LikesHandler,
		}
	do
		if controller.cleanup then
			controller.cleanup()
		end
		if controller.clearConnections then
			controller.clearConnections()
		end
	end
end
local initializedGuis = setmetatable({}, { __mode = "k" })

function Init.initialize(playerGui)
	if initializedGuis[playerGui] then
		return
	end
	initializedGuis[playerGui] = true
	stopInitializing()
	initializingThread = coroutine.running()
	if currentHud then
		cleanupControllers()
	end
	currentHud = playerGui
	playerGui.Destroying:Connect(function()
		if currentHud == playerGui then
			stopInitializing()
			cleanupControllers()
			currentHud = nil
		end
	end)
	NotificationController.prepare()
	-- Intro owns the authored overlay; it never initializes controllers a second time.
	if not IntroController.run(playerGui) then
		initializedGuis[playerGui] = nil
		initializingThread = nil
		return
	end
	loadControllers()
	playerGui.Enabled = false
	-- This module receives PlayerGui.HUD, which owns Frames and Buttons.
	playerGui:WaitForChild("Frames")
	playerGui:WaitForChild("Buttons")
	local tutorial = player:WaitForChild("Data"):WaitForChild("PlayerInfo"):WaitForChild("Tutorial")
	local tutorialStatus = tutorial:WaitForChild("IsInTutorial")
	player:WaitForChild("leaderstats")

	NotificationController.init(playerGui, true)
	UIController.init(playerGui)
	ShopController.init(playerGui)
	SellController.init(playerGui)
	FriendBoost.init(playerGui)
	LikesHandler.init(playerGui)

	UIController.initRebirthSystem()
	UIEffects.ApplyToAll(playerGui)

	-- Bind UI listeners first, then wait for the server to finish assigning the plot.
	while player:GetAttribute("MyCityLoaded") ~= true do
		player:GetAttributeChangedSignal("MyCityLoaded"):Wait()
	end
	ReplicatedStorage.Events.Loading.ClientReady:FireServer()
	local isInTutorial = tutorialStatus.Value
	if isInTutorial then
		TutorialController.init(playerGui)
	else
		UIController.setupNormalUI()
	end
	EarlyLoading.finish()
	playerGui.Enabled = true
	NotificationController.flush()
	ReplicatedStorage.Events.Loading.IntroFinished:FireServer()
	initializingThread = nil
end

return Init
