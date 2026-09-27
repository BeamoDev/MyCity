-- Buttons: focused implementation for UIController.
return function(Context)
	local State = Context.State
	local UIController = Context.UIController
	local Icon = Context.Icon
	local NotificationController = Context.NotificationController
	local TweenService = Context.TweenService
	local attentionRandom = Random.new()

	local function scaleFor(target)
		local scale = target:FindFirstChildOfClass("UIScale")
		if not scale then
			scale = Instance.new("UIScale")
			scale.Name = "BuilderPackAttentionScale"
			scale.Parent = target
		end
		return scale
	end

	local function playAttentionTween(target, info, goals)
		local tween = TweenService:Create(target, info, goals)
		table.insert(State.builderPackAttentionTweens, tween)
		tween:Play()
		tween.Completed:Wait()
		local index = table.find(State.builderPackAttentionTweens, tween)
		if index then
			table.remove(State.builderPackAttentionTweens, index)
		end
	end

	function Context.cleanupBuilderPackAttention()
		for _, tween in State.builderPackAttentionTweens or {} do
			tween:Cancel()
		end
		State.builderPackAttentionTweens = {}
		for target, original in State.builderPackAttentionOriginals or {} do
			if target.Parent then
				target.Rotation = original.rotation
				if original.scale.Parent then
					original.scale.Scale = original.scaleValue
				end
			end
		end
		State.builderPackAttentionOriginals = {}
	end

	function Context.setupBuilderPackAttention()
		Context.cleanupBuilderPackAttention()
		local button = State.ButtonFolder.Right:FindFirstChild("BuilderPack")
		local text = button and button:FindFirstChild("TextLabel1")
		local icon = button and button:FindFirstChild("Icon")
		if not button then
			return
		end

		local function register(target)
			if not (target and target:IsA("GuiObject")) then
				return nil
			end
			local scale = scaleFor(target)
			State.builderPackAttentionOriginals[target] = {
				rotation = target.Rotation,
				scale = scale,
				scaleValue = scale.Scale,
			}
			return scale
		end

		local textScale = register(text)
		local iconScale = register(icon)
		local grow = TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		local move = TweenInfo.new(0.20, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		local settle = TweenInfo.new(0.30, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

		if textScale then
			local original = State.builderPackAttentionOriginals[text]
			Context.connections:spawn(function()
				while text.Parent and button.Parent do
					task.wait(attentionRandom:NextNumber(7, 12))
					if button.Visible and text.Visible then
						playAttentionTween(textScale, grow, { Scale = original.scaleValue * 1.14 })
						playAttentionTween(text, move, { Rotation = -25 })
						playAttentionTween(text, move, { Rotation = -15 })
						playAttentionTween(text, move, { Rotation = -25 })
						playAttentionTween(text, settle, { Rotation = original.rotation })
						playAttentionTween(textScale, settle, { Scale = original.scaleValue })
					end
				end
			end)
		end

		if iconScale then
			local original = State.builderPackAttentionOriginals[icon]
			Context.connections:spawn(function()
				while icon.Parent and button.Parent do
					task.wait(attentionRandom:NextNumber(9, 15))
					if button.Visible and icon.Visible then
						playAttentionTween(iconScale, grow, { Scale = original.scaleValue * 1.16 })
						playAttentionTween(icon, move, { Rotation = original.rotation + 12 })
						playAttentionTween(icon, move, { Rotation = original.rotation - 8 })
						playAttentionTween(icon, settle, { Rotation = original.rotation })
						playAttentionTween(iconScale, settle, { Scale = original.scaleValue })
					end
				end
			end)
		end
	end

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
