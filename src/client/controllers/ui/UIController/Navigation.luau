-- Navigation: focused implementation for UIController.
return function(Context)
	local State = Context.State
	local UIController = Context.UIController
	local TweenService = Context.TweenService
	local player = Context.player
	local Camera = Context.Camera
	local blurEffect = Context.blurEffect
	local TWEEN_INFO = Context.TWEEN_INFO
	local DEFAULT_CAMERA_FIELD_OF_VIEW = Context.DEFAULT_CAMERA_FIELD_OF_VIEW
	local ZOOMED_FOV = Context.ZOOMED_FOV
	local MAX_BLUR = Context.MAX_BLUR
	local function present(frame, visible)
		if frame == State.DailyQuestFrame then
			Context.Transitions.cancel(frame)
			frame.Position = UDim2.fromScale(0.5, 0.5)
			frame.Size = UDim2.fromScale(1, 1)
			frame.Visible = visible
		else
			Context.Transitions.panel(frame, visible)
		end
	end

	function Context.checkTutorialStatus()
		local data = player:FindFirstChild("Data")
		if data then
			local playerInfo = data:FindFirstChild("PlayerInfo")
			if playerInfo then
				local tutorialValue = playerInfo.Tutorial:FindFirstChild("IsInTutorial")
				if tutorialValue then
					return tutorialValue.Value
				end
			end
		end
		return false
	end

	-- Update tutorial status

	function UIController.updateTutorialStatus(status)
		State.isInTutorial = status
		if State.HUD then
			State.HUD.CashDisplay.Visible = not status
			State.HUD.FriendBoost.Visible = not status
		end
	end

	function Context.tweenUIFrame(frame, targetPosition, targetSize)
		TweenService:Create(frame, TWEEN_INFO, { Position = targetPosition }):Play()
		TweenService:Create(frame, TWEEN_INFO, { Size = targetSize }):Play()
	end

	function Context.tweenBlur(targetSize)
		if blurEffect then
			TweenService:Create(blurEffect, TWEEN_INFO, { Size = targetSize }):Play()
		end
	end

	function Context.tweenCameraFOV(targetFOV)
		TweenService:Create(Camera, TWEEN_INFO, { FieldOfView = targetFOV }):Play()
	end

	function UIController.clearStuckEffects()
		if blurEffect then
			blurEffect.Size = 0
		end

		if Camera then
			Camera.FieldOfView = DEFAULT_CAMERA_FIELD_OF_VIEW
		end

		State.isTweening = false
		if State.DailyQuestFrame then
			present(State.DailyQuestFrame, false)
		end
		State.currentOpenFrame = nil

		if State.FramesFolder then
			for _, frame in pairs(State.FramesFolder:GetChildren()) do
				if frame:IsA("Frame") and frame.Visible then
					local isTutorialFrame = frame.Name == "StageOne"
						or frame.Name == "StageTwo"
						or frame.Name == "StageThree"
						or frame.Name == "TutorialItemShop"
					if not (Context.checkTutorialStatus() and isTutorialFrame) then
						Context.Transitions.immediate(frame, false)
					end
				end
			end
		end
	end

	function UIController.openUIFrame(frame)
		-- Block all frame openings during tutorial except tutorial frames
		if Context.checkTutorialStatus() then
			-- Allow tutorial frames to open
			local tutorialFrames = {
				"StageOne",
				"StageTwo",
				"StageThree",
				"TutorialItemShop", -- Add TutorialItemShop to allowed frames
			}

			local isTutorialFrame = false
			for _, tutorialFrameName in ipairs(tutorialFrames) do
				if frame.Name == tutorialFrameName then
					isTutorialFrame = true
					break
				end
			end

			if not isTutorialFrame then
				-- Reset any stuck effects before returning
				Context.tweenBlur(0)
				Context.tweenCameraFOV(DEFAULT_CAMERA_FIELD_OF_VIEW)
				State.isTweening = false
				return -- Block non-tutorial frames
			end
		end

		if State.currentOpenFrame == frame and frame.Visible and frame.Size.X.Scale > 0 and frame.Size.Y.Scale > 0 then
			return
		end

		State.isTweening = true

		if State.currentOpenFrame and State.currentOpenFrame ~= frame then
			present(State.currentOpenFrame, false)
		end

		present(frame, true)
		State.currentOpenFrame = frame

		game.SoundService.SFX.Swoosh:Play()

		Context.tweenBlur(MAX_BLUR)
		Context.tweenCameraFOV(ZOOMED_FOV)

		Context.connections:delay(0.3, function()
			State.isTweening = false
		end)
	end

	function UIController.closeUIFrame(frame)
		if frame ~= State.currentOpenFrame then
			return
		end

		State.isTweening = true

		State.currentOpenFrame = nil
		present(frame, false)
		Context.tweenBlur(0)
		Context.tweenCameraFOV(DEFAULT_CAMERA_FIELD_OF_VIEW)

		game.SoundService.SFX.Swoosh:Play()

		Context.connections:delay(0.3, function()
			State.isTweening = false
		end)
	end

	function UIController.toggleUIFrame(frame)
		if State.isTweening then
			return
		end

		-- Block during tutorial for non-tutorial frames
		if Context.checkTutorialStatus() then
			local tutorialFrames = {
				"StageOne",
				"StageTwo",
				"StageThree",
				"TutorialItemShop", -- Add TutorialItemShop here too
			}

			local isTutorialFrame = false
			for _, tutorialFrameName in ipairs(tutorialFrames) do
				if frame.Name == tutorialFrameName then
					isTutorialFrame = true
					break
				end
			end

			if not isTutorialFrame then
				-- Reset any stuck effects before returning
				Context.tweenBlur(0)
				Context.tweenCameraFOV(DEFAULT_CAMERA_FIELD_OF_VIEW)
				State.isTweening = false
				return
			end
		end

		if frame.Visible then
			UIController.closeUIFrame(frame)
		else
			UIController.openUIFrame(frame)
		end
	end

	function UIController.flashScreen(color)
		local flashFrame = State.playerGui.CoverFX
		flashFrame.BackgroundColor3 = color
		flashFrame.BackgroundTransparency = 1

		local fadeInTween = TweenService:Create(
			flashFrame,
			TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ BackgroundTransparency = 0.9 }
		)

		local fadeOutTween = TweenService:Create(
			flashFrame,
			TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ BackgroundTransparency = 1 }
		)

		Context.connections:connect(fadeInTween.Completed, function()
			fadeOutTween:Play()
		end)

		fadeInTween:Play()
	end

	function UIController.setupNormalUI()
		UIController.setGameplayUIVisible(true)
		if State.playerGui and State.playerGui:FindFirstChild("NotificationCenter") then
			State.playerGui.NotificationCenter.Visible = true
		end

		Context.updateCashDisplay()
	end
end
