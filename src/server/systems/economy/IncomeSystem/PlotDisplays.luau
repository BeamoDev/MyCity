-- PlotDisplays: focused implementation for IncomeSystem.
return function(Context)
	local State = Context.State
	local Players = Context.Players
	local plotsFolder = Context.plotsFolder
	local updateInterval = Context.updateInterval
	local buttonDebounces = Context.buttonDebounces
	local plotOwners = Context.plotOwners
	local activeConnections = Context.activeConnections
	local proximityPrompts = Context.proximityPrompts

	function Context.formatNumberShort(num)
		if num >= 1000000000 then
			return string.format("$%.1fB", num / 1000000000)
		elseif num >= 1000000 then
			return string.format("$%.1fM", num / 1000000)
		elseif num >= 1000 then
			return string.format("$%.1fK", num / 1000)
		else
			return "$" .. tostring(math.floor(num))
		end
	end

	-- Calculate crime penalty for income

	function Context.setupUIForPlot(plotNumber)
		local plot = plotsFolder:FindFirstChild("Plot" .. plotNumber)
		if not plot then
			return
		end

		local UI = plot:FindFirstChild("UI") and plot.UI:FindFirstChild("CollectIncome")
		if not UI or not UI:IsA("Model") then
			return
		end

		local hitbox = UI:FindFirstChild("Hitbox")
		local buttonPart = UI:FindFirstChild("Button")

		if not hitbox or not buttonPart then
			return
		end

		if activeConnections[plotNumber] then
			for _, connection in pairs(activeConnections[plotNumber]) do
				if connection then
					connection:Disconnect()
				end
			end
		end
		activeConnections[plotNumber] = {}

		if proximityPrompts[plotNumber] then
			proximityPrompts[plotNumber]:Destroy()
			proximityPrompts[plotNumber] = nil
		end

		local existingPrompt = hitbox:FindFirstChild("IncomePrompt")
		if existingPrompt then
			existingPrompt:Destroy()
		end

		if hitbox:IsA("BasePart") then
			hitbox.CanTouch = true
			hitbox.CanCollide = false
			hitbox.CanQuery = true

			local touchConnection = hitbox.Touched:Connect(function(hit)
				local character = hit.Parent
				local humanoid = character:FindFirstChildOfClass("Humanoid")
				if not humanoid then
					return
				end

				local player = Players:GetPlayerFromCharacter(character)
				if player and plotOwners[plotNumber] == player then
					local touchKey = player.UserId .. "_touch"
					if not buttonDebounces[touchKey] then
						buttonDebounces[touchKey] = true
						require(script.Parent.Parent.Parent.security.RequestGuard).run(
							player,
							"Income",
							Context.handleIncomeCollection,
							plotNumber
						)
						task.wait(2)
						buttonDebounces[touchKey] = false
					end
				end
			end)
			table.insert(activeConnections[plotNumber], touchConnection)
		end
	end

	function Context.setupUIs()
		for _, plot in ipairs(plotsFolder:GetChildren()) do
			local plotNum = tonumber(plot.Name:match("Plot(%d+)")) or 0
			Context.setupUIForPlot(plotNum)
		end
	end

	function Context.updatePlotUI()
		if not State.CityNameSystem then
			State.CityNameSystem =
				require(script.Parent.Parent.Parent:WaitForChild("world"):WaitForChild("CityNameSystem"))
		end

		while true do
			for _, plot in ipairs(plotsFolder:GetChildren()) do
				local plotNum = tonumber(plot.Name:match("Plot(%d+)")) or 0
				local assignedPlayer = plotOwners[plotNum]

				local PlotCollect = plot.UI:FindFirstChild("CollectIncome")
				if PlotCollect then
					local button = PlotCollect:FindFirstChild("Button")
					local base = PlotCollect:FindFirstChild("Base")

					-- Handle button appearance and particles based on assignment
					if button then
						if assignedPlayer and assignedPlayer.Parent then
							-- Player assigned - make button green and visible
							button.Color = Color3.fromRGB(0, 255, 0)
							button.Transparency = 0
						else
							-- No player - make button gray and semi-transparent
							button.Color = Color3.fromRGB(218, 218, 218)
							button.Transparency = 0.6
						end
					end

					-- Handle particle effects
					if base then
						local attachment = base:FindFirstChild("Attachment")
						if attachment then
							local flare = attachment:FindFirstChild("Flare")
							local wave = attachment:FindFirstChild("Wave")

							if assignedPlayer and assignedPlayer.Parent then
								-- Enable particles when player assigned
								if flare then
									flare.Enabled = true
								end
								if wave then
									wave.Enabled = true
								end
							else
								-- Disable particles when no player
								if flare then
									flare.Enabled = false
								end
								if wave then
									wave.Enabled = false
								end
							end
						end
					end

					-- Handle income display
					local surfaceGui = button and button:FindFirstChild("ButtonInfo")
					if surfaceGui then
						local incomeLabel = surfaceGui:FindFirstChild("IncomeAvailable")
						if incomeLabel and assignedPlayer and assignedPlayer.Parent then
							local playerInfo = assignedPlayer:FindFirstChild("Data")
								and assignedPlayer.Data:FindFirstChild("PlayerInfo")
							local availableIncome = playerInfo and playerInfo:FindFirstChild("AvailableIncome")

							if availableIncome then
								incomeLabel.Text = Context.formatNumberShort(availableIncome.Value)

								local hitbox = PlotCollect:FindFirstChild("Hitbox")
								if hitbox then
									local prompt = hitbox:FindFirstChild("IncomePrompt")
									if prompt then
										prompt.ObjectText = Context.formatNumberShort(availableIncome.Value)
										prompt.Enabled = availableIncome.Value > 0
									end
								end
							else
								incomeLabel.Text = "$0"
							end
						elseif incomeLabel then
							incomeLabel.Text = "Unassigned"
						end
					end
				end

				-- Rest of the function remains the same...
				local citySign = plot.UI:FindFirstChild("CitySign")

				if citySign then
					local body = citySign:FindFirstChild("Body")
					if body then
						local surfaceGui = body:FindFirstChild("SurfaceGui")
						if surfaceGui then
							local frame = surfaceGui:FindFirstChild("Frame")
							if frame then
								local cityNameLabel = frame:FindFirstChild("CityName")
								if cityNameLabel then
									if assignedPlayer and assignedPlayer.Parent then
										local savedCityName = nil
										if State.CityNameSystem then
											savedCityName = State.CityNameSystem.getCityName(assignedPlayer)
										end

										if savedCityName and savedCityName ~= "" then
											cityNameLabel.Text = savedCityName
										else
											cityNameLabel.Text = assignedPlayer.Name .. "'s City!"
										end
									else
										cityNameLabel.Text = "Unassigned"
									end
								end

								local populationLabel = frame:FindFirstChild("Population")
								if populationLabel then
									if assignedPlayer and assignedPlayer.Parent then
										local leaderstats = assignedPlayer:FindFirstChild("leaderstats")
										local populationStat = leaderstats
											and assignedPlayer:FindFirstChild("Data")
											and assignedPlayer.Data.PlayerInfo:FindFirstChild("Population")

										if populationStat then
											populationLabel.Text = "Population: " .. populationStat.Value
										else
											populationLabel.Text = "Population: 0"
										end
									else
										populationLabel.Text = "Population: 0"
									end
								end
							end
						end
					end
				end
			end
			task.wait(updateInterval)
		end
	end
end
