-- Lifecycle: focused implementation for IncomeSystem.
return function(Context)
	local State = Context.State
	local IncomeSystem = Context.IncomeSystem
	local Players = Context.Players
	local playerFriendBoosts = Context.playerFriendBoosts
	local buttonDebounces = Context.buttonDebounces
	local activeConnections = Context.activeConnections
	local proximityPrompts = Context.proximityPrompts
	local lastAccrual = setmetatable({}, { __mode = "k" })

	function Context.updateIncomeAndPopulationForAllPlayers()
		while true do
			for _, player in ipairs(Players:GetPlayers()) do
				local data = player:FindFirstChild("Data")
				if data and player:GetAttribute("MyCityLoaded") and not player:GetAttribute("MyCityLeaving") then
					local now = os.clock()
					local previous = lastAccrual[player] or now
					local seconds = math.max(0, math.floor(now - previous))
					lastAccrual[player] = previous + seconds
					IncomeSystem.calculateAndStackBuildingIncome(player, seconds)
					IncomeSystem.calculatePopulation(player)
				else
					lastAccrual[player] = nil
				end
			end
			task.wait(1)
		end
	end

	function IncomeSystem.setupPlayerIncome(player)
		local playerInfo = player.Data:WaitForChild("PlayerInfo")
		local availableIncomeStat = playerInfo:FindFirstChild("AvailableIncome")
		if not availableIncomeStat then
			availableIncomeStat = Instance.new("IntValue")
			availableIncomeStat.Name = "AvailableIncome"
			availableIncomeStat.Parent = playerInfo
		end
		availableIncomeStat.Value = 0

		playerFriendBoosts[player.UserId] = 0
		IncomeSystem.calculatePopulation(player)

		local plotData = player:FindFirstChild("Data")
			and player.Data:FindFirstChild("PlotInfo")
			and player.Data.PlotInfo:FindFirstChild("Plot")
		if plotData and plotData.Value > 0 then
			IncomeSystem.setPlotOwnership(player, plotData.Value)
		end
	end

	function IncomeSystem.cleanupPlayer(player)
		lastAccrual[player] = nil
		IncomeSystem.clearPlotOwnership(player)
		playerFriendBoosts[player.UserId] = nil

		for key, _ in pairs(buttonDebounces) do
			if string.find(key, tostring(player.UserId)) then
				buttonDebounces[key] = nil
			end
		end

		local plotData = player:FindFirstChild("Data")
			and player.Data:FindFirstChild("PlotInfo")
			and player.Data.PlotInfo:FindFirstChild("Plot")
		if plotData and plotData.Value > 0 then
			local plotNum = plotData.Value

			if activeConnections[plotNum] then
				for _, connection in pairs(activeConnections[plotNum]) do
					if connection then
						connection:Disconnect()
					end
				end
				activeConnections[plotNum] = nil
			end

			if proximityPrompts[plotNum] then
				proximityPrompts[plotNum]:Destroy()
				proximityPrompts[plotNum] = nil
			end
		end
	end

	function IncomeSystem.init()
		State.CityNameSystem = require(script.Parent.Parent.Parent:WaitForChild("world"):WaitForChild("CityNameSystem"))

		task.spawn(function()
			Context.setupUIs()
			task.spawn(Context.updateIncomeAndPopulationForAllPlayers)
			task.spawn(Context.updatePlotUI)
			task.spawn(Context.showBuildingIncomeAlerts)
		end)
	end

	IncomeSystem.updatePopulation = IncomeSystem.calculatePopulation
end
