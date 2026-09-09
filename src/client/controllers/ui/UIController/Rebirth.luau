-- Rebirth: focused implementation for UIController.
return function(Context)
	local State = Context.State
	local UIController = Context.UIController
	local TweenService = Context.TweenService
	local ReplicatedStorage = Context.ReplicatedStorage
	local NotificationController = Context.NotificationController
	local player = Context.player

	function Context.updateRebirthUI(data)
		if not State.RebirthFrame or not data then
			return
		end
		State.currentRebirthData = data
		local right = State.ButtonFolder and State.ButtonFolder:FindFirstChild("Right")
		local button = right and right:FindFirstChild("Rebirth")
		local alert = button and button:FindFirstChild("Alert")
		if alert then
			alert.Visible = data.canRebirth == true
		end

		local frame = State.RebirthFrame:FindFirstChild("Frame") or State.RebirthFrame
		if not frame then
			return
		end

		local cashNow = frame:FindFirstChild("CashNow")
		local cashNext = frame:FindFirstChild("CashNext")

		if cashNow then
			cashNow.Text = "x " .. string.format("%.2f", data.multipliers.income)
		end

		if cashNext then
			cashNext.Text = "x " .. string.format("%.2f", data.nextMultipliers.income)
		end

		local popNow = frame:FindFirstChild("PopulationNow")
		local popNext = frame:FindFirstChild("PopulationNext")

		if popNow then
			popNow.Text = "x " .. string.format("%.2f", data.multipliers.population)
		end

		if popNext then
			popNext.Text = "x " .. string.format("%.2f", data.nextMultipliers.population)
		end

		local rebirthButton = frame:FindFirstChild("Rebirth")
		if rebirthButton then
			if data.canRebirth then
				rebirthButton.GreenGradient.Enabled = true
				rebirthButton.GreyGrad.Enabled = false

				rebirthButton.UIStroke.Color = Color3.new(0.121569, 0.415686, 0.156863)
				rebirthButton.TextLabel.UIStroke.Color = Color3.new(0.121569, 0.415686, 0.156863)

				rebirthButton.Active = true
				rebirthButton.AutoButtonColor = true
			else
				rebirthButton.GreenGradient.Enabled = false
				rebirthButton.GreyGrad.Enabled = true

				rebirthButton.UIStroke.Color = Color3.new(0.313725, 0.313725, 0.313725)
				rebirthButton.TextLabel.UIStroke.Color = Color3.new(0.313725, 0.313725, 0.313725)

				rebirthButton.Active = true
				rebirthButton.AutoButtonColor = false
			end
		end

		local progressBar = frame:FindFirstChild("Progress")
		if progressBar then
			local fill = progressBar:FindFirstChild("Fill")
			local goalAmount = frame:FindFirstChild("GoalAmount")

			if data.requirements then
				local currentPop = player.Data.PlayerInfo.Population.Value
				local requiredPop = data.requirements.population
				local progress = math.min(currentPop / requiredPop, 1)

				if fill then
					TweenService:Create(
						fill,
						TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
						{ Size = UDim2.new(progress, 0, 1, 0) }
					):Play()

					if progress >= 1 then
						fill.BackgroundColor3 = Color3.fromRGB(85, 255, 85)
					elseif progress >= 0.75 then
						fill.BackgroundColor3 = Color3.fromRGB(255, 255, 85)
					elseif progress >= 0.5 then
						fill.BackgroundColor3 = Color3.fromRGB(255, 200, 85)
					else
						fill.BackgroundColor3 = Color3.fromRGB(255, 255, 85)
					end
				end

				if goalAmount then
					goalAmount.Text = Context.formatPopulation(currentPop)
						.. "/"
						.. Context.formatPopulation(requiredPop)
				end
			end
		end
	end

	function Context.setupRebirthUI()
		if not State.RebirthFrame then
			return
		end

		local frame = State.RebirthFrame:FindFirstChild("Frame") or State.RebirthFrame
		if not frame then
			return
		end

		local rebirthButton = frame:FindFirstChild("Rebirth")

		Context.connections:connect(rebirthButton.Activated, function()
			if State.currentRebirthData then
				if State.currentRebirthData.canRebirth then
					Context.showRebirthConfirmation(State.currentRebirthData)
				else
					if State.currentRebirthData.requirements then
						NotificationController.showNotification(
							"NotEnoughCash",
							"Need "
								.. Context.formatPopulation(State.currentRebirthData.requirements.population)
								.. " population!"
						)
					elseif State.currentRebirthData.isMaxRebirth then
						NotificationController.showNotification("NotEnoughCash", "Maximum rebirth level reached!")
					end
				end
			end
		end)
	end

	function Context.connectRebirthEvents()
		local events = ReplicatedStorage:WaitForChild("Events")
		local rebirthFolder = events:WaitForChild("Rebirth")

		State.rebirthRemotes = {
			RequestRebirth = rebirthFolder:WaitForChild("RequestRebirth"),
			RebirthSuccess = rebirthFolder:WaitForChild("RebirthSuccess"),
			RebirthFailed = rebirthFolder:WaitForChild("RebirthFailed"),
			UpdateRebirthUI = rebirthFolder:WaitForChild("UpdateRebirthUI"),
		}

		Context.connections:connect(State.rebirthRemotes.UpdateRebirthUI.OnClientEvent, function(data)
			Context.updateRebirthUI(data)
		end)

		Context.connections:connect(State.rebirthRemotes.RebirthSuccess.OnClientEvent, function(newRebirthCount)
			NotificationController.showNotification("LevelUp", "Rebirth " .. tostring(newRebirthCount) .. " Achieved!")

			UIController.flashScreen(Color3.fromRGB(255, 215, 0))

			if game.SoundService.SFX:FindFirstChild("BuildingComplete") then
				game.SoundService.SFX.BuildingComplete:Play()
			end
		end)

		Context.connections:connect(State.rebirthRemotes.RebirthFailed.OnClientEvent, function(reason)
			NotificationController.showNotification("NotEnoughCash", reason or "Population requirement not met!")
		end)

		Context.connections:connect(
			player
				:WaitForChild("Data")
				:WaitForChild("PlayerInfo")
				:WaitForChild("Population")
				:GetPropertyChangedSignal("Value"),
			function() end
		)
	end

	function UIController.initRebirthSystem()
		Context.setupRebirthUI()
		Context.connectRebirthEvents()
	end
end
