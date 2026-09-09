-- Input: focused implementation for Session.
return function(Context)
	local State = Context.State
	local RunService = Context.RunService
	local UserInputService = Context.UserInputService
	local SoundService = Context.SoundService
	local tool = Context.tool
	local player = Context.player
	local state = Context.state

	-- Mouse/Touch drag handling

	function Context.handleDragPosition(screenPosition)
		local camera = workspace.CurrentCamera or Context.camera
		local ray = camera:ScreenPointToRay(screenPosition.X, screenPosition.Y)
		local raycastParams = RaycastParams.new()
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude
		raycastParams.FilterDescendantsInstances = { state.previewBuilding, Context.player.Character }

		local result = workspace:Raycast(ray.Origin, ray.Direction * 1000, raycastParams)
		if result then
			state.targetPosition = Context.snapToGrid(result.Position)
		end
	end

	-- Prepare preview model

	function Context.rotatePreview()
		if not state.previewBuilding then
			return
		end

		state.rotationAngle = (state.rotationAngle + 90) % 360

		local base = state.previewBuilding:FindFirstChild("Base") or state.previewBuilding:FindFirstChild("Hitbox")
		if not base then
			return
		end

		local sfx = SoundService:FindFirstChild("SFX")
		local rotateSound = sfx and sfx:FindFirstChild("RotateSound")
		if rotateSound then
			rotateSound:Play()
		end
		state.motionTargetAngle = (state.motionTargetAngle or 0) + 90
		-- Re-snap the intended destination with the rotated footprint, not a mid-tween position.
		state.targetPosition = Context.snapToGrid(state.targetPosition or base.Position)

		Context.updateBuildingVisuals()
	end

	function Context.setupControls()
		-- Mouse/Touch drag
		state.connections.inputBegan = UserInputService.InputBegan:Connect(function(input, processed)
			if processed then
				return
			end

			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				state.isDragging = true
				Context.handleDragPosition(input.Position)
			end
		end)

		state.connections.inputChanged = UserInputService.InputChanged:Connect(function(input)
			if not state.isDragging then
				return
			end

			if
				input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch
			then
				Context.handleDragPosition(input.Position)
			end
		end)

		state.connections.inputEnded = UserInputService.InputEnded:Connect(function(input)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				state.isDragging = false
			end
		end)

		-- Keyboard rotation
		state.connections.rotate = UserInputService.InputBegan:Connect(function(input, processed)
			if processed then
				return
			end
			if input.KeyCode == Enum.KeyCode.R then
				Context.rotatePreview()
			end
		end)

		-- Mobile UI controls
		local placementMobileGui = Context.placementMobileGui
		if placementMobileGui then
			local mobileFrame = placementMobileGui:FindFirstChild("PlacementMobile")
			if mobileFrame then
				local rotateButton = mobileFrame:FindFirstChild("Rotate")
				local placeButton = mobileFrame:FindFirstChild("Place")
				local cancelButton = mobileFrame:FindFirstChild("Cancel")

				if rotateButton then
					state.connections.mobileRotate =
						rotateButton.Button.MouseButton1Click:Connect(Context.rotatePreview)
				end

				if placeButton then
					state.connections.mobilePlace = placeButton.Button.MouseButton1Click:Connect(Context.placeBuilding)
				end

				if cancelButton then
					state.connections.mobileCancel = cancelButton.Button.MouseButton1Click:Connect(function()
						Context.cleanup()
						tool.Parent = player.Backpack
					end)
				end
			end
		end

		-- Smooth movement loop
		state.connections.renderStep = RunService.RenderStepped:Connect(Context.smoothMoveToTarget)
	end

	-- Tool equipped
end
