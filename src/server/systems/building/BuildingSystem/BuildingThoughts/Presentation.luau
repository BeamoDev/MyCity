-- Presentation: focused implementation for BuildingThoughts.
return function(Context)
	local State = Context.State
	local TweenService = Context.TweenService
	local RunService = Context.RunService
	local THOUGHT_DURATION = Context.THOUGHT_DURATION
	local FADE_DURATION = Context.FADE_DURATION
	local THOUGHTS = Context.THOUGHTS

	function Context.showThought(building)
		if not building or not building.Parent then
			return
		end

		local hitbox = building:FindFirstChild("Hitbox")
		if not hitbox then
			return
		end

		if State.activeThoughts[building] then
			return
		end

		local configFolder = building:FindFirstChild("Config")
		if not configFolder then
			return
		end

		local crimePercent = configFolder:FindFirstChild("CrimePercent")
		local happinessPercent = configFolder:FindFirstChild("HappinessPercent")
		local fireSafetyPercent = configFolder:FindFirstChild("FireSafetyPercent")
		local healthPercent = configFolder:FindFirstChild("HealthPercent")

		if not crimePercent or not happinessPercent or not fireSafetyPercent then
			return
		end

		-- Default health to 50 if not found (for backwards compatibility)
		local healthValue = healthPercent and healthPercent.Value or 50

		local category =
			Context.getThoughtCategory(crimePercent.Value, happinessPercent.Value, fireSafetyPercent.Value, healthValue)
		local messages = THOUGHTS[category]
		local message = messages[math.random(1, #messages)]

		local speechBubble = game:GetService("ReplicatedStorage")
			:WaitForChild("Assets")
			:WaitForChild("Items")
			:FindFirstChild("SpeechBubble")
		if not speechBubble then
			return
		end

		local bubble = speechBubble:Clone()
		bubble.Parent = hitbox
		bubble.Enabled = true

		local bubbleImage = bubble.SpeechBubble:FindFirstChild("Bubble")
		local messageLabel = bubble.SpeechBubble:FindFirstChild("Message")

		if not bubbleImage or not messageLabel then
			bubble:Destroy()
			return
		end

		messageLabel.Text = message

		bubbleImage.ImageTransparency = 1
		messageLabel.TextTransparency = 1
		bubble.StudsOffset = Vector3.new(0, 2, 0)

		local thoughtData = {
			bubble = bubble,
			building = building,
			statsConnection = nil,
			endTime = tick() + THOUGHT_DURATION,
		}

		State.activeThoughts[building] = thoughtData

		-- Fade in animation
		local fadeInBubble = TweenService:Create(
			bubbleImage,
			TweenInfo.new(FADE_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ ImageTransparency = 0.3 }
		)

		local fadeInText = TweenService:Create(
			messageLabel,
			TweenInfo.new(FADE_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ TextTransparency = 0 }
		)

		local moveUp = TweenService:Create(
			bubble,
			TweenInfo.new(FADE_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ StudsOffset = Vector3.new(0, 3, 0) }
		)

		fadeInBubble:Play()
		fadeInText:Play()
		moveUp:Play()

		-- Listen for stat changes
		thoughtData.statsConnection = RunService.Heartbeat:Connect(function()
			if not building or not building.Parent or not bubble or not bubble.Parent then
				if thoughtData.statsConnection then
					thoughtData.statsConnection:Disconnect()
				end
				State.activeThoughts[building] = nil
				return
			end

			local newCategory = Context.getThoughtCategory(
				crimePercent.Value,
				happinessPercent.Value,
				fireSafetyPercent.Value,
				healthValue
			)
			if newCategory ~= category then
				category = newCategory
				local newMessages = THOUGHTS[category]
				local newMessage = newMessages[math.random(1, #newMessages)]
				messageLabel.Text = newMessage
			end
		end)

		task.wait(THOUGHT_DURATION)

		if State.activeThoughts[building] and bubble and bubble.Parent then
			local fadeOutBubble = TweenService:Create(
				bubbleImage,
				TweenInfo.new(FADE_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ ImageTransparency = 1 }
			)

			local fadeOutText = TweenService:Create(
				messageLabel,
				TweenInfo.new(FADE_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ TextTransparency = 1 }
			)

			local moveDown = TweenService:Create(
				bubble,
				TweenInfo.new(FADE_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ StudsOffset = Vector3.new(0, 2, 0) }
			)

			fadeOutBubble:Play()
			fadeOutText:Play()
			moveDown:Play()

			task.wait(FADE_DURATION)

			if bubble and bubble.Parent then
				bubble:Destroy()
			end
		end

		if thoughtData.statsConnection then
			thoughtData.statsConnection:Disconnect()
		end
		State.activeThoughts[building] = nil
	end
end
