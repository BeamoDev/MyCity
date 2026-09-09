-- Buttons: focused implementation for UIController.
return function(Context)
	local State = Context.State
	local UIController = Context.UIController
	local Icon = Context.Icon
	local NotificationController = Context.NotificationController

	function Context.connectButtonEvents()
		Context.connections:connect(State.ButtonFolder.Left.Shop.MouseButton1Down, function()
			if Context.checkTutorialStatus() then
				return
			end
			UIController.toggleUIFrame(State.ShopFrame)
		end)

		--ButtonFolder.Right.Worlds.MouseButton1Down:Connect(function()
		---	if checkTutorialStatus() then return end
		--	UIController.toggleUIFrame(WorldsFrame)
		--end)

		Context.connections:connect(State.ButtonFolder.Right.Rebirth.MouseButton1Down, function()
			if Context.checkTutorialStatus() then
				return
			end
			UIController.toggleUIFrame(State.RebirthFrame)
			State.ButtonFolder.Right.Rebirth:FindFirstChild("Alert").Visible = false
		end)

		Context.connections:connect(State.ButtonFolder.Left.DailyReward.MouseButton1Down, function()
			if Context.checkTutorialStatus() then
				return
			end
			UIController.toggleUIFrame(State.DailyRewardFrame)
		end)

		Context.connections:connect(State.ButtonFolder.Right.BuilderPack.MouseButton1Down, function()
			UIController.toggleUIFrame(State.BuilderPackFrame)
		end)

		Context.connections:connect(State.BuilderPackFrame.Frame.X.MouseButton1Down, function()
			UIController.closeUIFrame(State.BuilderPackFrame)
		end)

		Context.connections:connect(State.DailyRewardFrame.Frame.X.MouseButton1Down, function()
			UIController.closeUIFrame(State.DailyRewardFrame)
		end)

		Context.connections:connect(State.ConstructionsFrame.Frame.X.MouseButton1Down, function()
			UIController.closeUIFrame(State.ConstructionsFrame)
		end)

		Context.connections:connect(State.RebirthFrame.Frame.X.MouseButton1Down, function()
			UIController.closeUIFrame(State.RebirthFrame)
		end)

		Context.connections:connect(State.SettingsFrame.Frame.X.MouseButton1Down, function()
			UIController.closeUIFrame(State.SettingsFrame)
		end)

		Context.connections:connect(State.ShopFrame.Frame.X.MouseButton1Down, function()
			UIController.closeUIFrame(State.ShopFrame)
		end)

		Context.connections:connect(State.ItemShopFrame.Frame.X.MouseButton1Down, function()
			UIController.closeUIFrame(State.ItemShopFrame)
		end)

		Context.connections:connect(State.SellFrame.Frame.X.MouseButton1Down, function()
			UIController.closeUIFrame(State.SellFrame)
		end)

		Context.connections:connect(State.GroupRewardFrame.Frame.Okay.MouseButton1Down, function()
			UIController.closeUIFrame(State.GroupRewardFrame)
		end)

		Context.connections:connect(State.FramesFolder.Settings.Frame.Status.MouseButton1Down, function()
			if Context.checkTutorialStatus() then
				return
			end
			UIController.toggleUIFrame(State.ConstructionsFrame)
		end)
	end

	function Context.setupTopbarButtons()
		-- Create settings icon
		State.settingsIcon = Icon
			.new()
			:setImage("rbxassetid://134895166323593") -- Settings gear icon
			:setOrder(1)
			:bindToggleItem(State.SettingsFrame)
			:setCaption("Settings")

		-- Handle toggle events
		Context.connections:connect(State.settingsIcon.toggled, function(isSelected)
			if Context.checkTutorialStatus() then
				State.settingsIcon:deselect()
				return
			end

			if isSelected then
				UIController.openUIFrame(State.SettingsFrame)
			else
				UIController.closeUIFrame(State.SettingsFrame)
			end
		end)

		-- Also update icon state when frame is closed via X button
		Context.connections:connect(State.SettingsFrame.Frame.X.MouseButton1Down, function()
			UIController.closeUIFrame(State.SettingsFrame)
			if State.settingsIcon then
				State.settingsIcon:deselect()
			end
		end)
	end
end
