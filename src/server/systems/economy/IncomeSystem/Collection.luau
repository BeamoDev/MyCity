-- Collection: focused implementation for IncomeSystem.
return function(Context)
	local State = Context.State
	local IncomeSystem = Context.IncomeSystem
	local Workspace = Context.Workspace
	local ReplicatedStorage = Context.ReplicatedStorage
	local TweenService = Context.TweenService
	local tweenInfo = Context.tweenInfo
	local collectIncomeEvent = Context.collectIncomeEvent
	local errorEvent = Context.errorEvent
	local buttonDebounces = Context.buttonDebounces
	local plotOwners = Context.plotOwners

	function IncomeSystem.collectPendingIncome(player)
		local doubleCash = Context.hasDoubleCashGamepass(player)
		local totalIncome = IncomeSystem.calculateAndStackBuildingIncome(player)

		if totalIncome > 0 then
			-- Apply 2x cash gamepass multiplier
			if doubleCash then
				totalIncome = totalIncome * 2
			end

			local leaderstats = player:FindFirstChild("leaderstats")
			local Cash = leaderstats and leaderstats:FindFirstChild("Cash")
			if Cash then
				Cash.Value = Cash.Value + totalIncome
			end

			IncomeSystem.resetBuildingIncome(player)
		end
	end

	function IncomeSystem.resetBuildingIncome(player)
		local plotData = player:FindFirstChild("Data")
			and player.Data:FindFirstChild("PlotInfo")
			and player.Data.PlotInfo:FindFirstChild("Plot")
		if not plotData or plotData.Value == 0 then
			return
		end

		local plotNumber = plotData.Value
		local plot = Workspace.Plots:FindFirstChild("Plot" .. plotNumber)
		if not plot then
			return
		end

		local placedFolder = plot.Buildings:FindFirstChild("Placed")
		if placedFolder then
			for _, building in ipairs(placedFolder:GetChildren()) do
				local configFolder = building:FindFirstChild("Config")
				if configFolder then
					local collectedIncome = configFolder:FindFirstChild("CollectedIncome")
					if collectedIncome then
						collectedIncome.Value = 0
					end
				end
			end
		end

		local playerInfo = player.Data:FindFirstChild("PlayerInfo")
		if playerInfo then
			local availableIncomeStat = playerInfo:FindFirstChild("AvailableIncome")
			if availableIncomeStat then
				availableIncomeStat.Value = 0
			end
		end
	end

	function IncomeSystem.clearPlotOwnership(player)
		local plotData = player:FindFirstChild("Data")
			and player.Data:FindFirstChild("PlotInfo")
			and player.Data.PlotInfo:FindFirstChild("Plot")
		if plotData and plotData.Value > 0 then
			plotOwners[plotData.Value] = nil
		end
	end

	function IncomeSystem.setPlotOwnership(player, plotNumber)
		if plotNumber and plotNumber > 0 then
			plotOwners[plotNumber] = player
			task.spawn(function()
				task.wait(0.5)
				Context.setupUIForPlot(plotNumber)
			end)
		end
	end

	function Context.handleIncomeCollection(player, plotNumber)
		local debounceKey = player.UserId .. "_collection"
		local expires = tonumber(buttonDebounces[debounceKey]) or 0
		if os.clock() < expires then
			return
		end
		buttonDebounces[debounceKey] = os.clock() + 1

		local plotData = player:FindFirstChild("Data")
			and player.Data:FindFirstChild("PlotInfo")
			and player.Data.PlotInfo:FindFirstChild("Plot")

		if not plotData or plotData.Value ~= plotNumber then
			errorEvent:FireClient(player, "This button doesn't belong to your plot!")
			buttonDebounces[debounceKey] = false
			return
		end

		if plotOwners[plotNumber] ~= player then
			errorEvent:FireClient(player, "This plot is not currently assigned to you!")
			buttonDebounces[debounceKey] = false
			return
		end

		local doubleCash = Context.hasDoubleCashGamepass(player)
		local totalIncome = IncomeSystem.calculateAndStackBuildingIncome(player)

		if totalIncome <= 0 then
			errorEvent:FireClient(player, "No income to collect!")
			buttonDebounces[debounceKey] = false
			return
		end

		-- Apply 2x cash gamepass multiplier
		if doubleCash then
			totalIncome = totalIncome * 2
		end

		local leaderstats = player:FindFirstChild("leaderstats")
		local Cash = leaderstats:FindFirstChild("Cash")
		if Cash then
			Cash.Value = Cash.Value + totalIncome
		end

		-- Cash credit and income reset belong together, before optional quest/UI work.
		IncomeSystem.resetBuildingIncome(player)
		local questSignals = require(script.Parent.Parent.Parent.Parent.services.QuestSignals)
		questSignals.emit(player, "income", totalIncome)
		questSignals.emit(player, "collect", 1)
		local PostTutorialQuest =
			require(script.Parent.Parent.Parent:WaitForChild("progression"):WaitForChild("PostTutorialQuest"))
		PostTutorialQuest.onIncomeCollected(player)

		require(script.Parent.Parent.Parent.progression.TutorialSystem).handleIncomeCollection(player)
		collectIncomeEvent:FireClient(player, totalIncome)

		local plot = Workspace.Plots:FindFirstChild("Plot" .. plotNumber)
		if plot then
			local UI = plot:FindFirstChild("UI") and plot.UI:FindFirstChild("CollectIncome")
			if UI then
				local button = UI:FindFirstChild("Button")
				if button then
					local fixedPosition = button.Position
					local clickOffset = Vector3.new(0, -0.3, 0)

					local pressSound = button:FindFirstChild("Pressed")
					local releaseSound = button:FindFirstChild("Released")

					if pressSound and releaseSound then
						local downGoal = { Position = fixedPosition + clickOffset }
						local upGoal = { Position = fixedPosition }

						local downTween = TweenService:Create(button, tweenInfo, downGoal)
						local upTween = TweenService:Create(button, tweenInfo, upGoal)

						pressSound:Play()
						downTween:Play()

						task.spawn(function()
							downTween.Completed:Wait()
							releaseSound:Play()
							upTween:Play()
							upTween.Completed:Wait()
							button.Position = fixedPosition
						end)
					end
				end
			end
		end

		-- The timestamp debounce expires without holding the player mutation lock.
	end
end
