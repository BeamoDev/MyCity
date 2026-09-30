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
			local leaderstats = player:FindFirstChild("leaderstats")
			local Cash = leaderstats and leaderstats:FindFirstChild("Cash")
			if not Cash then
				return false
			end
			-- Apply 2x cash gamepass multiplier
			if doubleCash then
				totalIncome = totalIncome * 2
			end
			Cash.Value = Cash.Value + totalIncome

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

	local function animateCollectionButton(plotNumber)
		local plot = Workspace.Plots:FindFirstChild("Plot" .. plotNumber)
		local ui = plot and plot:FindFirstChild("UI")
		local collection = ui and ui:FindFirstChild("CollectIncome")
		local button = collection and collection:FindFirstChild("Button")
		if not (button and button:IsA("BasePart")) then return end

		local fixedPosition = button.Position
		local downTween = TweenService:Create(button, tweenInfo, { Position = fixedPosition + Vector3.new(0, -0.3, 0) })
		local upTween = TweenService:Create(button, tweenInfo, { Position = fixedPosition })
		local pressSound = button:FindFirstChild("Pressed")
		local releaseSound = button:FindFirstChild("Released")
		if pressSound then pressSound:Play() end
		downTween:Play()
		task.spawn(function()
			downTween.Completed:Wait()
			if releaseSound then releaseSound:Play() end
			upTween:Play()
			upTween.Completed:Wait()
			button.Position = fixedPosition
		end)
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
		animateCollectionButton(plotNumber)

		local doubleCash = Context.hasDoubleCashGamepass(player)
		local totalIncome = IncomeSystem.calculateAndStackBuildingIncome(player)

		if totalIncome <= 0 then
			buttonDebounces[debounceKey] = false
			return
		end

		-- Apply 2x cash gamepass multiplier
		if doubleCash then
			totalIncome = totalIncome * 2
		end

		local leaderstats = player:FindFirstChild("leaderstats")
		local Cash = leaderstats and leaderstats:FindFirstChild("Cash")
		if not Cash then
			buttonDebounces[debounceKey] = false
			return
		end
		Cash.Value = Cash.Value + totalIncome

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

		-- The timestamp debounce expires without holding the player mutation lock.
	end
end
