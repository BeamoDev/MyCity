-- Renderer: focused implementation for Controller.
return function(Context)
	local State = Context.State
	local UserInputService = Context.UserInputService
	local TweenService = Context.TweenService
	local TextService = Context.TextService
	local GamepadButtonImage = Context.GamepadButtonImage
	local KeyboardButtonImage = Context.KeyboardButtonImage
	local KeyboardButtonIconMapping = Context.KeyboardButtonIconMapping
	local KeyCodeToTextMapping = Context.KeyCodeToTextMapping

	function Context.createPrompt(prompt, inputType, gui)
		local tweensForButtonHoldBegin = {}
		local tweensForButtonHoldEnd = {}
		local tweensForFadeOut = {}
		local tweensForFadeIn = {}
		local tweenInfoInFullDuration =
			TweenInfo.new(prompt.HoldDuration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
		local tweenInfoOutHalfSecond = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local tweenInfoFast = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local tweenInfoQuick = TweenInfo.new(0.06, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
		local tweenInfoInstant = TweenInfo.new(0, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)

		local promptUI = nil
		local assets = game:GetService("ReplicatedStorage"):WaitForChild("Assets")
		local promptTheme = prompt:GetAttribute("Theme")
		if promptTheme then
			local themedPromptUI = assets:FindFirstChild(promptTheme)
			if themedPromptUI and themedPromptUI:IsA("BillboardGui") then
				promptUI = themedPromptUI:Clone()
			end
		end

		if promptUI == nil then
			promptUI = assets:WaitForChild("Default"):Clone()
		end

		promptUI.Enabled = true

		local frame = promptUI.PromptFrame
		local inputFrame = frame.InputFrame
		local actionText = frame.ActionText

		-- Tweens for Frame and children
		local backgroundTransparency = frame.BackgroundTransparency
		local imageTransparency = frame.ImageTransparency
		frame.BackgroundTransparency = 1
		frame.ImageTransparency = 1
		-- TODO consolidate this with the other tweens for image labels, theres some duplication
		-- TODO make these functions somehow consolidate the properties objects?
		table.insert(
			tweensForButtonHoldBegin,
			TweenService:Create(
				frame,
				tweenInfoFast,
				{ Size = UDim2.fromScale(0.5, 1), BackgroundTransparency = 1, ImageTransparency = 1 }
			)
		)
		table.insert(
			tweensForButtonHoldEnd,
			TweenService:Create(frame, tweenInfoFast, {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = backgroundTransparency,
				ImageTransparency = imageTransparency,
			})
		)
		table.insert(
			tweensForFadeOut,
			TweenService:Create(
				frame,
				tweenInfoFast,
				{ Size = UDim2.fromScale(0.5, 1), BackgroundTransparency = 1, ImageTransparency = 1 }
			)
		)
		table.insert(
			tweensForFadeIn,
			TweenService:Create(frame, tweenInfoFast, {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = backgroundTransparency,
				ImageTransparency = imageTransparency,
			})
		)

		local function setupUIStrokeTweens(uiStroke)
			local transparency = uiStroke.Transparency
			uiStroke.Transparency = 1
			table.insert(tweensForButtonHoldBegin, TweenService:Create(uiStroke, tweenInfoFast, { Transparency = 1 }))
			table.insert(
				tweensForButtonHoldEnd,
				TweenService:Create(uiStroke, tweenInfoFast, { Transparency = transparency })
			)
			table.insert(tweensForFadeOut, TweenService:Create(uiStroke, tweenInfoFast, { Transparency = 1 }))
			table.insert(tweensForFadeIn, TweenService:Create(uiStroke, tweenInfoFast, { Transparency = transparency }))
		end

		local function setupGUIObjectTweens(guiObject)
			local guiObjectBackgroundTransparency = guiObject.BackgroundTransparency
			guiObject.BackgroundTransparency = 1
			table.insert(
				tweensForButtonHoldBegin,
				TweenService:Create(guiObject, tweenInfoFast, { BackgroundTransparency = 1 })
			)
			table.insert(
				tweensForButtonHoldEnd,
				TweenService:Create(
					guiObject,
					tweenInfoFast,
					{ BackgroundTransparency = guiObjectBackgroundTransparency }
				)
			)
			table.insert(
				tweensForFadeOut,
				TweenService:Create(guiObject, tweenInfoFast, { BackgroundTransparency = 1 })
			)
			table.insert(
				tweensForFadeIn,
				TweenService:Create(
					guiObject,
					tweenInfoFast,
					{ BackgroundTransparency = guiObjectBackgroundTransparency }
				)
			)
		end

		local function setupTextLabelTweens(textLabel)
			local textTransparency = textLabel.TextTransparency
			local textStrokeTransparency = textLabel.TextStrokeTransparency
			textLabel.TextTransparency = 1
			textLabel.TextStrokeTransparency = 1
			table.insert(
				tweensForButtonHoldBegin,
				TweenService:Create(textLabel, tweenInfoFast, { TextTransparency = 1, TextStrokeTransparency = 1 })
			)
			table.insert(
				tweensForButtonHoldEnd,
				TweenService:Create(
					textLabel,
					tweenInfoFast,
					{ TextTransparency = textTransparency, TextStrokeTransparency = textStrokeTransparency }
				)
			)
			table.insert(
				tweensForFadeOut,
				TweenService:Create(textLabel, tweenInfoFast, { TextTransparency = 1, TextStrokeTransparency = 1 })
			)
			table.insert(
				tweensForFadeIn,
				TweenService:Create(
					textLabel,
					tweenInfoFast,
					{ TextTransparency = textTransparency, TextStrokeTransparency = textStrokeTransparency }
				)
			)
		end

		local function setupImageLabelTweens(imageLabel)
			local imageTransparency = imageLabel.ImageTransparency
			imageLabel.ImageTransparency = 1
			table.insert(
				tweensForButtonHoldBegin,
				TweenService:Create(imageLabel, tweenInfoFast, { ImageTransparency = 1 })
			)
			table.insert(
				tweensForButtonHoldEnd,
				TweenService:Create(imageLabel, tweenInfoFast, { ImageTransparency = imageTransparency })
			)
			table.insert(tweensForFadeOut, TweenService:Create(imageLabel, tweenInfoFast, { ImageTransparency = 1 }))
			table.insert(
				tweensForFadeIn,
				TweenService:Create(imageLabel, tweenInfoFast, { ImageTransparency = imageTransparency })
			)
		end

		local function setupUnexpectedChildTweens(child)
			if child:IsA("UIStroke") then
				setupUIStrokeTweens(child)
			elseif child:IsA("UIGradient") then
				-- The Transparency property of UIGradients is not tweenable
			elseif child:IsA("GuiObject") then
				setupGUIObjectTweens(child)

				if child:IsA("TextLabel") then
					setupTextLabelTweens(child)
				elseif child:IsA("ImageLabel") then
					setupImageLabelTweens(child)
				end
			end

			for _, grandChild in pairs(child:GetChildren()) do
				setupUnexpectedChildTweens(grandChild)
			end
		end

		-- Key is UI object, value is whether or not we should tween out the children of it in the same manner
		local expectedFrameChildren = { [inputFrame] = false, [actionText] = true }
		for _, child in pairs(frame:GetChildren()) do
			if expectedFrameChildren[child] == nil then
				-- Unexpected child of the frame and direct children elements
				setupUnexpectedChildTweens(child)
			elseif expectedFrameChildren[child] == true then
				for _, grandChild in pairs(child:GetChildren()) do
					-- All children of ActionText or ObjectText
					setupUnexpectedChildTweens(grandChild)
				end
			end
		end

		-- Tweens for InputFrame
		local resizeableInputFrame = inputFrame.Frame
		local inputFrameScaler = resizeableInputFrame.UIScale
		local inputFrameScaleFactor = inputType == Enum.ProximityPromptInputType.Touch and 1.6 or 1.33
		table.insert(
			tweensForButtonHoldBegin,
			TweenService:Create(inputFrameScaler, tweenInfoFast, { Scale = inputFrameScaleFactor })
		)
		table.insert(tweensForButtonHoldEnd, TweenService:Create(inputFrameScaler, tweenInfoFast, { Scale = 1 }))

		-- Tweens for ActionText and ObjectText
		setupTextLabelTweens(actionText)

		local buttonFrame = resizeableInputFrame.ButtonFrame

		local function setupButtonFrameTweens()
			local buttonFrameBackgroundTransparency = buttonFrame.BackgroundTransparency
			local buttonFrameImageTransparency = buttonFrame.ImageTransparency

			table.insert(
				tweensForFadeOut,
				TweenService:Create(buttonFrame, tweenInfoQuick, { BackgroundTransparency = 1, ImageTransparency = 1 })
			)
			table.insert(
				tweensForFadeIn,
				TweenService:Create(buttonFrame, tweenInfoQuick, {
					BackgroundTransparency = buttonFrameBackgroundTransparency,
					ImageTransparency = buttonFrameImageTransparency,
				})
			)

			for _, child in pairs(buttonFrame:getChildren()) do
				if child:IsA("UIStroke") then
					local transparency = child.Transparency
					table.insert(tweensForFadeOut, TweenService:Create(child, tweenInfoQuick, { Transparency = 1 }))
					table.insert(
						tweensForFadeIn,
						TweenService:Create(child, tweenInfoQuick, { Transparency = transparency })
					)
				end
				-- Currently not supporting any other children other than UIStroke
			end
		end
		setupButtonFrameTweens()

		local buttonImage = resizeableInputFrame.ButtonImage
		local buttonText = resizeableInputFrame.ButtonText
		local icon = resizeableInputFrame.ButtonTextImage

		local function setupButtonTextTweens()
			local textTransparency = buttonText.TextTransparency
			local textStrokeTransparency = buttonText.TextStrokeTransparency
			local textBackgroundTransparency = buttonText.BackgroundTransparency
			buttonText.BackgroundTransparency = 1
			buttonText.TextStrokeTransparency = 1
			buttonText.TextTransparency = 1
			table.insert(
				tweensForFadeOut,
				TweenService:Create(
					buttonText,
					tweenInfoQuick,
					{ TextTransparency = 1, TextStrokeTransparency = 1, BackgroundTransparency = 1 }
				)
			)
			table.insert(
				tweensForFadeIn,
				TweenService:Create(buttonText, tweenInfoQuick, {
					TextTransparency = textTransparency,
					TextStrokeTransparency = textStrokeTransparency,
					BackgroundTransparency = textBackgroundTransparency,
				})
			)

			for _, child in pairs(buttonText:getChildren()) do
				if child:IsA("UIStroke") then
					local transparency = child.Transparency
					table.insert(tweensForFadeOut, TweenService:Create(child, tweenInfoQuick, { Transparency = 1 }))
					table.insert(
						tweensForFadeIn,
						TweenService:Create(child, tweenInfoQuick, { Transparency = transparency })
					)
				end
				-- Currently not supporting any other children other than UIStroke
			end
		end

		local function setupButtonImageTweens()
			local buttonImageTransparency = buttonImage.ImageTransparency
			local buttonImageBackgroundTransparency = buttonImage.BackgroundTransparency
			buttonImage.BackgroundTransparency = 1
			buttonImage.ImageTransparency = 1
			table.insert(
				tweensForFadeOut,
				TweenService:Create(buttonImage, tweenInfoQuick, { ImageTransparency = 1, BackgroundTransparency = 1 })
			)
			table.insert(
				tweensForFadeIn,
				TweenService:Create(buttonImage, tweenInfoQuick, {
					ImageTransparency = buttonImageTransparency,
					BackgroundTransparency = buttonImageBackgroundTransparency,
				})
			)
		end

		local function setupIconTweens()
			local iconBackgroundTransparency = icon.BackgroundTransparency
			local iconImageTransparency = icon.ImageTransparency
			icon.BackgroundTransparency = 1
			icon.ImageTransparency = 1
			table.insert(
				tweensForFadeOut,
				TweenService:Create(icon, tweenInfoQuick, { ImageTransparency = 1, BackgroundTransparency = 1 })
			)
			table.insert(
				tweensForFadeIn,
				TweenService:Create(
					icon,
					tweenInfoQuick,
					{ ImageTransparency = iconImageTransparency, BackgroundTransparency = iconBackgroundTransparency }
				)
			)
		end

		if inputType == Enum.ProximityPromptInputType.Gamepad then
			if GamepadButtonImage[prompt.GamepadKeyCode] then
				setupIconTweens()
				icon.Image = GamepadButtonImage[prompt.GamepadKeyCode]

				-- Hide ButtonText and ButtonImage, show ButtonTextImage
				buttonText.Visible = false
				buttonImage.Visible = false
				icon.Visible = true
			end
		elseif inputType == Enum.ProximityPromptInputType.Touch then
			setupButtonImageTweens()
			buttonImage.Image = "rbxasset://textures/ui/Controls/TouchTapIcon.png"

			-- Hide ButtonText and ButtonTextImage, show ButtonImage
			buttonText.Visible = false
			icon.Visible = false
			buttonImage.Visible = true
		else
			setupButtonImageTweens()

			-- Show ButtonImage
			buttonImage.Visible = true

			local buttonTextString = UserInputService:GetStringForKeyCode(prompt.KeyboardKeyCode)

			local buttonTextImage = KeyboardButtonImage[prompt.KeyboardKeyCode]
			if buttonTextImage == nil then
				buttonTextImage = KeyboardButtonIconMapping[buttonTextString]
			end

			if buttonTextImage == nil then
				local keyCodeMappedText = KeyCodeToTextMapping[prompt.KeyboardKeyCode]
				if keyCodeMappedText then
					buttonTextString = keyCodeMappedText
				end
			end

			if buttonTextImage then
				setupIconTweens()
				icon.Image = buttonTextImage

				--  Hide ButtonText, show ButtonTextImage
				buttonText.Visible = false
				icon.Visible = true
			elseif buttonTextString ~= nil and buttonTextString ~= "" then
				if string.len(buttonTextString) > 2 then
					buttonText.TextSize = math.round(buttonText.TextSize * 6 / 7)
				end
				setupButtonTextTweens()
				buttonText.Text = buttonTextString

				-- Hide ButtonTextImage, show ButtonText
				icon.Visible = false
				buttonText.Visible = true
			else
				error(
					"ProximityPrompt '"
						.. prompt.Name
						.. "' has an unsupported keycode for rendering UI: "
						.. tostring(prompt.KeyboardKeyCode)
				)
			end
		end

		if inputType == Enum.ProximityPromptInputType.Touch or prompt.ClickablePrompt then
			local button = promptUI.TextButton

			local buttonDown = false

			button.InputBegan:Connect(function(input)
				if
					(
						input.UserInputType == Enum.UserInputType.Touch
						or input.UserInputType == Enum.UserInputType.MouseButton1
					) and input.UserInputState ~= Enum.UserInputState.Change
				then
					prompt:InputHoldBegin()
					buttonDown = true
				end
			end)
			button.InputEnded:Connect(function(input)
				if
					input.UserInputType == Enum.UserInputType.Touch
					or input.UserInputType == Enum.UserInputType.MouseButton1
				then
					if buttonDown then
						buttonDown = false
						prompt:InputHoldEnd()
					end
				end
			end)

			promptUI.Active = true
		end

		if prompt.HoldDuration > 0 then
			local circleBar = resizeableInputFrame.ProgressBar
			Context.setUpCircularProgressBar(circleBar)
			table.insert(
				tweensForButtonHoldBegin,
				TweenService:Create(circleBar.Progress, tweenInfoInFullDuration, { Value = 1 })
			)
			table.insert(
				tweensForButtonHoldEnd,
				TweenService:Create(circleBar.Progress, tweenInfoInstant, { Value = 0 })
			)
		end

		local holdBeganConnection
		local holdEndedConnection
		local triggeredConnection
		local triggerEndedConnection

		if prompt.HoldDuration > 0 then
			holdBeganConnection = prompt.PromptButtonHoldBegan:Connect(function()
				for _, tween in ipairs(tweensForButtonHoldBegin) do
					tween:Play()
				end
			end)

			holdEndedConnection = prompt.PromptButtonHoldEnded:Connect(function()
				for _, tween in ipairs(tweensForButtonHoldEnd) do
					tween:Play()
				end
			end)
		end

		triggeredConnection = prompt.Triggered:Connect(function()
			for _, tween in ipairs(tweensForFadeOut) do
				tween:Play()
			end
		end)

		triggerEndedConnection = prompt.TriggerEnded:Connect(function()
			for _, tween in ipairs(tweensForFadeIn) do
				tween:Play()
			end
		end)

		local function updateUIFromPrompt()
			-- todo: Use AutomaticSize instead of GetTextSize when that feature becomes available
			local actionTextParams = Instance.new("GetTextBoundsParams")
			actionTextParams.Text = prompt.ActionText
			actionTextParams.Font = actionText.FontFace
			actionTextParams.Size = actionText.TextSize
			actionTextParams.Width = 1000
			local actionTextSize = TextService:GetTextBoundsAsync(actionTextParams)

			local maxTextWidth = math.max(actionTextSize.X)
			local promptHeight = 72
			local promptWidth = 72
			local textPaddingLeft = 72

			if prompt.ActionText ~= nil and prompt.ActionText ~= "" then
				promptWidth = maxTextWidth + textPaddingLeft + 24
			end

			local actionTextYOffset = 25

			actionText.Position = UDim2.new(0.5, textPaddingLeft - promptWidth / 2, 0, actionTextYOffset)

			actionText.Text = prompt.ActionText
			actionText.AutoLocalize = prompt.AutoLocalize
			actionText.RootLocalizationTable = prompt.RootLocalizationTable

			promptUI.Size = UDim2.fromOffset(promptWidth, promptHeight)
			promptUI.SizeOffset = Vector2.new(
				prompt.UIOffset.X / promptUI.Size.Width.Offset,
				prompt.UIOffset.Y / promptUI.Size.Height.Offset
			)
		end

		local changedConnection = prompt.Changed:Connect(updateUIFromPrompt)
		updateUIFromPrompt()

		promptUI.Adornee = prompt.Parent
		promptUI.Parent = gui

		for _, tween in ipairs(tweensForFadeIn) do
			tween:Play()
		end

		local cleaned = false
		local function cleanup()
			if cleaned then
				return
			end
			cleaned = true
			if holdBeganConnection then
				holdBeganConnection:Disconnect()
			end

			if holdEndedConnection then
				holdEndedConnection:Disconnect()
			end

			triggeredConnection:Disconnect()
			triggerEndedConnection:Disconnect()
			changedConnection:Disconnect()

			for _, tween in ipairs(tweensForFadeOut) do
				tween:Play()
			end

			wait(0.2)

			promptUI:Destroy()
		end

		return cleanup
	end
end
