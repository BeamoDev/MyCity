local bindAlert = require(script.Parent.ClaimAlerts)
-- DailyRewards: focused implementation for UIController.
return function(Context)
	local State = Context.State
	local ReplicatedStorage = Context.ReplicatedStorage

	function Context.setupDailyRewardUI()
		local setAlert = bindAlert(State.ButtonFolder, "DailyReward", Context.connections)
		if not State.DailyRewardFrame then
			return
		end

		local frame = State.DailyRewardFrame:FindFirstChild("Frame") or State.DailyRewardFrame
		local contentFrame = frame:FindFirstChild("Content")
		if not contentFrame then
			return
		end

		local boundButtons = setmetatable({}, { __mode = "k" })
		local activeTimerThread = nil
		local deadline
		local lastRequest = -math.huge
		local function request()
			if os.clock() - lastRequest >= 2 then
				lastRequest = os.clock()
				ReplicatedStorage.Events.DailyRewards.RequestUpdate:FireServer()
			end
		end
		-- Eligibility must keep refreshing even when the reward panel is closed.
		Context.connections:spawn(function()
			while true do
				task.wait(1)
				if deadline and os.clock() >= deadline then
					request()
				end
			end
		end)

		-- Listen for updates from server
		Context.connections:connect(ReplicatedStorage.Events.DailyRewards.UpdateUI.OnClientEvent, function(data)
			setAlert(data.canClaim == true and not data.claimedDays[data.currentDay])
			deadline = if not data.canClaim then os.clock() + math.max(0, data.timeUntilNext) else nil
			-- Kill any existing timer thread
			if activeTimerThread then
				task.cancel(activeTimerThread)
				activeTimerThread = nil
			end

			-- Update each day
			for i = 1, 7 do
				local dayFrame = contentFrame:FindFirstChild("Day" .. i)
				if dayFrame then
					local claimSection = dayFrame:FindFirstChild("Claim")
					local claimedSection = dayFrame:FindFirstChild("Claimed")
					local timerSection = dayFrame:FindFirstChild("Timer")

					if claimSection then
						claimSection.Visible = false
					end
					if claimedSection then
						claimedSection.Visible = false
					end
					if timerSection then
						timerSection.Visible = false
					end

					-- Handle state - only show relevant section
					if data.claimedDays[i] then
						-- Already claimed - show claimed overlay
						if claimedSection then
							claimedSection.Visible = true
						end
					elseif i == data.currentDay then
						-- Current day
						if data.canClaim then
							-- Can claim now - show claim button with sunrays
							if claimSection then
								claimSection.Visible = true
								local claimButton = claimSection:FindFirstChild("ClaimButton")

								if claimButton and not boundButtons[claimButton] then
									boundButtons[claimButton] = true
									-- Remove old connections before adding new one
									Context.connections:connect(claimButton.Activated, function()
										ReplicatedStorage.Events.DailyRewards.ClaimReward:FireServer()
									end)
								end
							end
						else
							if timerSection then
								timerSection.Visible = true
								local timeLabel = timerSection:FindFirstChild("Time")

								local timeLeft = data.timeUntilNext
								local deadline = os.clock() + timeLeft

								activeTimerThread = Context.connections:spawn(function()
									while timeLeft > 0 and timerSection.Visible do
										if timeLabel then
											local hours = math.floor(timeLeft / 3600)
											local minutes = math.floor((timeLeft % 3600) / 60)
											local seconds = math.floor(timeLeft % 60)
											timeLabel.Text = string.format("%02d:%02d:%02d", hours, minutes, seconds)
										end

										task.wait(1)
										timeLeft = math.max(0, math.ceil(deadline - os.clock()))
									end

									if timeLabel and timerSection.Visible then
										timeLabel.Text = "Ready!"
									end

									request()

									activeTimerThread = nil
								end)
							end
						end
					end
				end
			end
		end)

		Context.connections:connect(State.DailyRewardFrame:GetPropertyChangedSignal("Visible"), function()
			if State.DailyRewardFrame.Visible then
				request()
			end
		end)
	end
end
