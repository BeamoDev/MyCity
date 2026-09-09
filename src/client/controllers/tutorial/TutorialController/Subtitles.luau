-- Subtitles: focused implementation for TutorialController.
return function(Context)
	local State = Context.State
	local TweenService = Context.TweenService

	local activeTweens = {}
	local completion
	function Context.clearSubtitleTweens()
		if completion then
			completion:Disconnect()
			completion = nil
		end
		for _, tween in activeTweens do
			tween:Cancel()
		end
		table.clear(activeTweens)
	end
	local function track(tween)
		table.insert(activeTweens, tween)
		return tween
	end
	local function createTween(...)
		return track(TweenService:Create(...))
	end
	function Context.updateTutorialText(text)
		Context.clearSubtitleTweens()
		if not State.TutorialFrame then
			return
		end

		local statusMessage = State.TutorialFrame:FindFirstChild("StatusMessage")
		if not statusMessage then
			return
		end

		if text == "" or text == nil then
			createTween(
				State.TutorialFrame,
				TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Position = UDim2.new(0.5, 0, -0.2, 0) }
			):Play()
			return
		end

		local sfx = game:GetService("SoundService"):FindFirstChild("SFX")
		local pop = sfx and sfx:FindFirstChild("Popin")
		if pop and pop:IsA("Sound") then
			pop:Play()
		end

		local originalPosition = UDim2.new(0.5, 0, 0.22, 0)
		local upPosition = UDim2.new(0.5, 0, 0.18, 0)

		local fadeOut = createTween(
			statusMessage,
			TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ TextTransparency = 1 }
		)

		local strokeOut
		local stroke = statusMessage:FindFirstChild("UIStroke")
		if stroke then
			strokeOut = createTween(
				stroke,
				TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Transparency = 1 }
			)
		end

		local moveUp = createTween(
			State.TutorialFrame,
			TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Position = upPosition }
		)

		fadeOut:Play()
		if strokeOut then
			strokeOut:Play()
		end
		moveUp:Play()

		completion = Context.connections:connect(moveUp.Completed, function()
			if completion then
				completion:Disconnect()
				completion = nil
			end
			statusMessage.Text = text

			local moveDown = createTween(
				State.TutorialFrame,
				TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Position = originalPosition }
			)

			local fadeIn = createTween(
				statusMessage,
				TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ TextTransparency = 0 }
			)

			local strokeIn
			if stroke then
				strokeIn = createTween(
					stroke,
					TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ Transparency = 0 }
				)
			end

			moveDown:Play()
			fadeIn:Play()
			if strokeIn then
				strokeIn:Play()
			end
		end)
	end

	function Context.showcaseShopItems()
		local tutorialShop = State.FramesFolder:FindFirstChild("TutorialItemShop")
		if not tutorialShop then
			return
		end

		local scrollingFrame = tutorialShop.Frame:FindFirstChild("ScrollingFrame")
		if not scrollingFrame then
			return
		end

		local purchaseFrame = scrollingFrame:FindFirstChild("PurchaseFrame")
		if not purchaseFrame then
			return
		end

		tutorialShop.Parent.Visible = true

		purchaseFrame.Visible = false
		scrollingFrame.CanvasPosition = Vector2.new(0, 0)

		task.wait(0.5)
		Context.updateTutorialText("Each building provides taxes and population!")
		task.wait(3)

		purchaseFrame.Visible = true
		Context.updateTutorialText("Buy a Shack!")
	end
end
