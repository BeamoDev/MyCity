-- Camera: focused implementation for TutorialController.
return function(Context)
	local State = Context.State
	local TutorialController = Context.TutorialController
	local TweenService = Context.TweenService
	local RunService = Context.RunService
	local player = Context.player
	local tutorialState = Context.tutorialState
	local orbitSnapshot, zoomThread, zoomTween

	function Context.setupOrbitCamera(buildingType, isConstruction)
		Context.cleanupCameraOrbit()
		local playerPlot = Context.getPlayerPlot()
		local buildings = playerPlot and playerPlot:FindFirstChild("Buildings")
		local folder = buildings and buildings:FindFirstChild(if isConstruction then "Construction" else "Placed")
		if not folder then
			return
		end
		local targetId = player:GetAttribute("Tutorial" .. buildingType .. "TargetId")

		local targetBuilding = nil
		for _, building in pairs(folder:GetChildren()) do
			if
				building:GetAttribute("BuildingType") == buildingType
				and (
					not targetId
					or (building:GetAttribute("BuildingID") or building:GetAttribute("ConstructionID")) == targetId
				)
			then
				targetBuilding = building
				break
			end
		end

		if not targetBuilding then
			warn("[TutorialController]", buildingType, "not found for orbit")
			return
		end

		local buildingBase = targetBuilding:FindFirstChild("Base") or targetBuilding:FindFirstChild("Hitbox")
		if not buildingBase then
			return
		end

		-- Different settings based on building type
		local settings = {
			Bank = {
				focusOffset = Vector3.new(0, 3, 0),
				startRadius = 8,
				startHeight = 2,
				endRadius = 12,
				endHeight = 4,
				startFOV = 55,
				endFOV = 65,
				orbitSpeed = math.rad(20),
				zoomDelay = 7,
				zoomDuration = 3.5,
			},
			Shack = {
				focusOffset = Vector3.new(0, 2, 0),
				startRadius = 8,
				startHeight = 3,
				endRadius = 10,
				endHeight = 4,
				startFOV = 60,
				endFOV = 65,
				orbitSpeed = math.rad(25),
				zoomDelay = 2,
				zoomDuration = 2.5,
			},
		}

		local config = settings[buildingType] or settings.Bank
		local focusPoint = buildingBase.Position + config.focusOffset

		local camera = game.Workspace.CurrentCamera
		if not camera then
			return
		end
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		orbitSnapshot = {
			camera = camera,
			cameraType = camera.CameraType,
			subject = camera.CameraSubject,
			cframe = camera.CFrame,
			fov = camera.FieldOfView,
			root = root,
			anchored = root and root.Anchored,
		}
		camera.CameraType = Enum.CameraType.Scriptable
		camera.FieldOfView = config.startFOV

		local currentRadius = config.startRadius
		local currentHeight = config.startHeight
		local orbitAngle = 0
		local isZoomingOut = false
		local zoomStartTime = 0

		if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
			player.Character.HumanoidRootPart.Anchored = true
		end

		zoomThread = Context.connections:spawn(function()
			task.wait(config.zoomDelay)
			isZoomingOut = true
			zoomStartTime = tick()

			zoomTween = TweenService:Create(
				camera,
				TweenInfo.new(config.zoomDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
				{ FieldOfView = config.endFOV }
			)
			zoomTween:Play()

			task.wait(config.zoomDuration)
			isZoomingOut = false
			currentRadius = config.endRadius
			currentHeight = config.endHeight
			task.wait(3) -- Extra viewing time
		end)

		tutorialState.cameraOrbitConnection = Context.connections:connect(RunService.RenderStepped, function(deltaTime)
			orbitAngle = orbitAngle + config.orbitSpeed * deltaTime

			if isZoomingOut then
				local elapsed = tick() - zoomStartTime
				local progress = math.min(elapsed / config.zoomDuration, 1)
				local easedProgress = 1 - (1 - progress) * (1 - progress)

				currentRadius = config.startRadius + (config.endRadius - config.startRadius) * easedProgress
				currentHeight = config.startHeight + (config.endHeight - config.startHeight) * easedProgress
			end

			local x = math.cos(orbitAngle) * currentRadius
			local z = math.sin(orbitAngle) * currentRadius

			camera.CFrame = CFrame.lookAt(focusPoint + Vector3.new(x, currentHeight, z), focusPoint)
		end)
	end

	function Context.cleanupCameraOrbit()
		if tutorialState.cameraOrbitConnection then
			tutorialState.cameraOrbitConnection:Disconnect()
			tutorialState.cameraOrbitConnection = nil
		end

		if zoomThread and zoomThread ~= coroutine.running() and coroutine.status(zoomThread) ~= "dead" then
			task.cancel(zoomThread)
			Context.connections.threads[zoomThread] = nil
		end
		zoomThread = nil
		if zoomTween then
			zoomTween:Cancel()
			zoomTween = nil
		end
		local original = orbitSnapshot
		orbitSnapshot = nil
		if not original then
			return
		end
		if original.root and original.root.Parent then
			original.root.Anchored = original.anchored
		end
		original.camera.CameraType = original.cameraType
		original.camera.CameraSubject = original.subject
		original.camera.CFrame = original.cframe
		original.camera.FieldOfView = original.fov
	end

	function Context.cleanupIncomeHover()
		local playerPlot = Context.getPlayerPlot()
		if playerPlot then
			local incomeButton = playerPlot.UI.CollectIncome
			if incomeButton and incomeButton:FindFirstChild("Hover") then
				local hoverInfo = incomeButton.Hover:FindFirstChild("HoverInfo")
				if hoverInfo then
					hoverInfo.Enabled = false
				end
			end
		end
	end

	-- Update the cleanupTutorial function (around line 133):
end
