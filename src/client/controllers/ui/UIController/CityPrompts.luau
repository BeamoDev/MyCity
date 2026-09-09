-- CityPrompts: focused implementation for UIController.
return function(Context)
	local State = Context.State
	local UIController = Context.UIController
	local ReplicatedStorage = Context.ReplicatedStorage
	local NotificationController = Context.NotificationController
	local player = Context.player
	local GROUP_ID = Context.GROUP_ID
	local GROUP_PROMPT_DELAY = Context.GROUP_PROMPT_DELAY
	local plotsFolder = Context.plotsFolder

	function Context.createEditPrompt(plot)
		local citySign = plot.UI:FindFirstChild("CitySign")
		if not citySign or not citySign:FindFirstChild("Body") then
			return
		end

		local existingPrompt = citySign.Body:FindFirstChild("EditSignPrompt")
		if existingPrompt then
			existingPrompt:Destroy()
		end

		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "EditSignPrompt"
		prompt.ActionText = "Edit Sign"
		prompt.MaxActivationDistance = 15
		prompt.HoldDuration = 0
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
		prompt.RequiresLineOfSight = false
		prompt.Parent = citySign.Body
		prompt.Style = Enum.ProximityPromptStyle.Custom

		Context.connections:connect(prompt.Triggered, function(triggeringPlayer)
			if triggeringPlayer ~= player then
				return
			end
			-- Block during tutorial
			if Context.checkTutorialStatus() then
				return
			end

			local plotData = player:FindFirstChild("Data")
				and player.Data:FindFirstChild("PlotInfo")
				and player.Data.PlotInfo:FindFirstChild("Plot")
			if not plotData then
				return
			end

			local plotNumber = tonumber(plot.Name:match("Plot(%d+)"))
			if plotData.Value == plotNumber then
				State.currentEditingPlot = plot
				ReplicatedStorage.Events.CitySign.RequestCityNameEdit:FireServer()
			else
				NotificationController.showNotification("NotYourPlot", "Not Your Sign!")
			end
		end)

		return prompt
	end

	function Context.setupPlotPrompts()
		for _, plot in pairs(plotsFolder:GetChildren()) do
			if plot:IsA("Folder") or plot:IsA("Model") then
				local prompt = Context.createEditPrompt(plot)
				if prompt then
					State.editPrompts[plot] = prompt
				end
			end
		end
	end

	function UIController.checkAndShowGroupPrompt()
		local function checkGroupStatus()
			wait(GROUP_PROMPT_DELAY)
			-- Don't show during tutorial
			if Context.checkTutorialStatus() then
				return
			end

			local isInGroup = false
			local success = pcall(function()
				isInGroup = player:IsInGroup(GROUP_ID)
			end)

			if not success then
				warn("[UIController] Failed to check group status")
				return
			end

			if not isInGroup then
				if State.GroupRewardFrame then
					UIController.openUIFrame(State.GroupRewardFrame)
				else
					warn("[UIController] GroupReward frame not found")
				end
			end
		end

		Context.connections:spawn(checkGroupStatus)
	end

	function Context.setupCityNameUI()
		if not State.CityNameFrame then
			return
		end

		local textBox = State.CityNameFrame.Frame:FindFirstChild("TextBox")
		local enterButton = State.CityNameFrame.Frame:FindFirstChild("Submit")
		local revertButton = State.CityNameFrame.Frame:FindFirstChild("Revert")
		local charCounter = State.CityNameFrame.Frame:FindFirstChild("CharCounter")

		if not textBox then
			return
		end

		if textBox and charCounter then
			Context.connections:connect(textBox:GetPropertyChangedSignal("Text"), function()
				local textLength = string.len(textBox.Text)
				charCounter.Text = textLength .. "/50"

				if textLength > 50 then
					textBox.Text = string.sub(textBox.Text, 1, 50)
					charCounter.TextColor3 = Color3.fromRGB(255, 100, 100)
				else
					charCounter.TextColor3 = Color3.fromRGB(200, 200, 200)
				end
			end)
		end

		local function closeCityNameUI()
			UIController.closeUIFrame(State.CityNameFrame)
			if textBox then
				textBox.Text = ""
			end
			State.currentEditingPlot = nil
		end

		if enterButton then
			Context.connections:connect(enterButton.MouseButton1Click, function()
				local cityName = textBox.Text
				if string.len(cityName) > 0 then
					ReplicatedStorage.Events.CitySign.UpdateCityName:FireServer(cityName)
				end
				closeCityNameUI()
			end)
		end

		Context.connections:connect(State.CityNameFrame.Frame:FindFirstChild("X").MouseButton1Click, function()
			closeCityNameUI()
		end)

		if revertButton then
			Context.connections:connect(revertButton.MouseButton1Click, function()
				ReplicatedStorage.Events.CitySign.UpdateCityName:FireServer(player.Name .. "'s City!")
				closeCityNameUI()
			end)
		end
	end
end
