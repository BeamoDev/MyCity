-- Lifecycle: focused implementation for UIController.
return function(Context)
	local State = Context.State
	local UIController = Context.UIController
	local player = Context.player
	local Camera = Context.Camera
	local blurEffect = Context.blurEffect
	local DEFAULT_CAMERA_FIELD_OF_VIEW = Context.DEFAULT_CAMERA_FIELD_OF_VIEW

	function UIController.init(gui)
		State.playerGui = gui
		State.FramesFolder = State.playerGui.Frames
		State.ButtonFolder = State.playerGui.Buttons
		State.HUD = State.playerGui
		Context.setupDailyQuests()

		if blurEffect then
			blurEffect.Size = 0
		end

		if Camera then
			Camera.FieldOfView = DEFAULT_CAMERA_FIELD_OF_VIEW
		end

		State.ShopFrame = State.FramesFolder.Shop
		State.SellFrame = State.FramesFolder.SellTool
		State.ItemShopFrame = State.FramesFolder.ItemShop
		State.SettingsFrame = State.FramesFolder.Settings
		State.ConstructionsFrame = State.FramesFolder.Construction
		State.GroupRewardFrame = State.FramesFolder:FindFirstChild("GroupReward")
		State.CityNameFrame = State.FramesFolder:FindFirstChild("CityName")
		State.BuildingDataFrame = State.FramesFolder:FindFirstChild("BuildingData")
		State.WorldsFrame = State.FramesFolder:FindFirstChild("Worlds")
		State.RebirthFrame = State.FramesFolder:FindFirstChild("Rebirth")
		State.questUI = State.FramesFolder.Parent:FindFirstChild("TutorialQuests")
		State.DailyRewardFrame = State.FramesFolder:FindFirstChild("DailyReward")
		State.weatherFrame = State.playerGui.Weather
		State.BuilderPackFrame = State.FramesFolder.BuilderPack

		Context.setupConstructionDisplay()
		Context.setupSettingsControls()
		Context.setupBuilderDisplay()
		Context.setupMobilePlacement()
		Context.setupTravelButtons()
		Context.connectButtonEvents()
		Context.connectRemoteEvents()
		Context.setupBuildingDataUI()
		Context.updateCashDisplay()
		Context.setupTopbarButtons()

		if State.CityNameFrame then
			Context.setupCityNameUI()
		end

		if State.DailyRewardFrame then
			Context.setupDailyRewardUI()
		end

		local function initializeCityNamePrompts()
			task.wait(2)
			Context.setupPlotPrompts()
		end

		if player.Character then
			Context.connections:spawn(initializeCityNamePrompts)
		end

		UIController.updateTutorialStatus(Context.checkTutorialStatus())

		Context.connections:connect(player.CharacterAdded, initializeCityNamePrompts)
		UIController.checkAndShowGroupPrompt()
	end

	function UIController.cleanup()
		Context.connections:clear()
		Context.cleanupPresentation()
		Context.cleanupQuestUI()
		Context.cleanupDailyQuests()
		Context.cleanupConstructionDisplay()
		Context.cleanupSettingsControls()
		Context.cleanupCashDisplay()

		if State.settingsIcon then
			State.settingsIcon:destroy()
			State.settingsIcon = nil
		end

		if State.dailyRewardConnection then
			State.dailyRewardConnection:Disconnect()
			State.dailyRewardConnection = nil
		end

		for plot, prompt in pairs(State.editPrompts) do
			if prompt and prompt.Parent then
				prompt:Destroy()
			end
		end
		State.editPrompts = {}
	end

	function UIController.getFrames()
		return {
			Shop = State.ShopFrame,
			Sell = State.SellFrame,
			ItemShop = State.ItemShopFrame,
			Settings = State.SettingsFrame,
			Constructions = State.ConstructionsFrame,
			GroupReward = State.GroupRewardFrame,
			CityName = State.CityNameFrame,
			BuilderPack = State.BuilderPackFrame,
			BuildingData = State.BuildingDataFrame,
			Worlds = State.WorldsFrame,
			Rebirth = State.RebirthFrame,
			DailyReward = State.DailyRewardFrame,
		}
	end
end
