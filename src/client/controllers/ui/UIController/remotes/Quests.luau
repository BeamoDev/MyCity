-- Render the latest server snapshot; old completion effects cannot overwrite it.
return function(Context)
	local State, events = Context.State, Context.questEvents
	local version, fillTween = 0, nil
	local latest
	local positionTween
	local shown = false
	local notificationTween
	local function positionNotifications(immediate)
		if notificationTween then
			notificationTween:Cancel()
			notificationTween = nil
		end
		local frame = State.playerGui and State.playerGui:FindFirstChild("NotificationCenter")
		if not frame then
			return
		end
		local visible = not immediate and State.questUI and State.questUI.Visible
		local target = UDim2.fromScale(0.5, if visible then 0.28 else 0.15)
		if immediate then
			frame.Position = target
		else
			notificationTween = Context.TweenService:Create(
				frame,
				TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Position = target }
			)
			notificationTween:Play()
		end
	end
	local function sound(name)
		local folder = game:GetService("SoundService"):FindFirstChild("SFX")
		local value = folder and folder:FindFirstChild(name)
		if value and value:IsA("Sound") then
			value:Play()
		end
	end
	local function fill(amount)
		if fillTween then
			fillTween:Cancel()
		end
		local bar = State.questUI and State.questUI:FindFirstChild("ProgressBar")
		local target = bar and bar:FindFirstChild("FillBar")
		if target then
			fillTween = Context.TweenService:Create(target, TweenInfo.new(0.25), { Size = UDim2.fromScale(amount, 1) })
			fillTween:Play()
		end
	end
	local function render(title, progress, required, reward)
		local ui = State.questUI
		if not ui then
			return
		end
		local data = Context.player:FindFirstChild("Data")
		if
			State.isInTutorial
			or (data and data.PlayerInfo.Tutorial.IsInTutorial.Value)
			or Context.player:GetAttribute("MyCityHudTransition")
		then
			if positionTween then
				positionTween:Cancel()
				positionTween = nil
			end
			shown = false
			ui.Visible = false
			return
		end
		local first = not shown or not ui.Visible
		shown = true
		ui.Visible = true
		local label = ui:FindFirstChild("QuestTitle")
		if label then
			label.RichText = true
			label.Text = string.format('%s  <font color="rgb(0,255,0)">(%d/%d)</font>', title, progress, required)
		end
		fill(math.clamp(if required > 0 then progress / required else 0, 0, 1))
		local section = ui:FindFirstChild("RewardSection")
		if section then
			for _, name in { "MansionIcon", "CashIcon", "ApartmentsIcon" } do
				local icon = section:FindFirstChild(name)
				if icon then
					icon.Visible = reward ~= nil
						and (
							(name == "CashIcon" and reward.type == "cash")
							or (name == "ApartmentsIcon" and reward.building == "Apartments")
							or (name == "MansionIcon" and reward.building == "SheriffOffice")
						)
				end
			end
			local info = section:FindFirstChild("Reward")
			if info and reward then
				info.Text = if reward.type == "cash" then "$" .. tostring(reward.amount) else reward.building
			end
		end
		if not first and not positionTween then
			ui.Position = UDim2.fromScale(0.5, 0.21)
		end
		if first then
			if positionTween then
				positionTween:Cancel()
			end
			ui.Position = UDim2.fromScale(0.5, -0.2)
			positionTween = Context.TweenService:Create(
				ui,
				TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Position = UDim2.fromScale(0.5, 0.21) }
			)
			positionTween:Play()
			local currentTween = positionTween
			Context.connections:delay(0.35, function()
				if positionTween == currentTween then
					positionTween = nil
				end
			end)
			sound("NotificationLow")
		end
	end
	function Context.refreshQuestUI()
		if latest then
			render(table.unpack(latest))
		end
	end
	function Context.cleanupQuestUI()
		positionNotifications(true)
		if positionTween then
			positionTween:Cancel()
			positionTween = nil
		end
		if fillTween then
			fillTween:Cancel()
			fillTween = nil
		end
		latest = nil
		version += 1
	end
	function Context.connectQuests()
		latest = nil
		shown = false
		positionNotifications(true)
		if State.questUI then
			Context.connections:connect(State.questUI:GetPropertyChangedSignal("Visible"), function()
				positionNotifications(false)
			end)
			if State.questUI.Visible then
				positionNotifications(false)
			end
		end
		local tutorial = Context.player.Data.PlayerInfo.Tutorial.IsInTutorial
		Context.connections:connect(tutorial:GetPropertyChangedSignal("Value"), Context.refreshQuestUI)
		Context.connections:connect(events.UpdateQuest.OnClientEvent, function(title, progress, required, _, _, reward)
			version += 1
			latest = { title, progress, required, reward }
			Context.refreshQuestUI()
		end)
		Context.connections:connect(events.QuestComplete.OnClientEvent, function()
			-- The next snapshot arrives immediately; celebration never writes quest text later.
			Context.UIController.flashScreen(Color3.fromRGB(120, 220, 120))
			sound("Achievement")
		end)
		Context.connections:connect(events.AllQuestsDone.OnClientEvent, function(alreadyCompleted)
			version += 1
			latest = nil
			local current = version
			local ui = State.questUI
			if not ui then
				return
			end
			if alreadyCompleted then
				if positionTween then
					positionTween:Cancel()
					positionTween = nil
				end
				ui.Visible = false
				return
			end
			local label = ui:FindFirstChild("QuestTitle")
			if label then
				label.Text = "All quests complete!"
			end
			fill(1)
			Context.connections:delay(3, function()
				if current == version and ui.Parent then
					ui.Visible = false
				end
			end)
		end)
	end
end
