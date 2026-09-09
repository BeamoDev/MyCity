return function(toolArg, initializedToolsArg, cooldownArg)
	local State = {}
	local Session = {}
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	require(game:GetService("ReplicatedStorage"):WaitForChild("shared"):WaitForChild("Network")).wait()
	local RunService = game:GetService("RunService")
	local TweenService = game:GetService("TweenService")
	local Workspace = game:GetService("Workspace")
	local Players = game:GetService("Players")
	local UserInputService = game:GetService("UserInputService")
	local SoundService = game:GetService("SoundService")

	local GRID_SIZE = 1
	local LOCKED_Y_AXIS = 1.25
	local COLLISION_CHECK_MARGIN = 0.1
	local VALID_COLOR = Color3.fromRGB(88, 255, 76)
	local INVALID_COLOR = Color3.fromRGB(255, 74, 74)
	local PLACEMENT_DEBOUNCE_TIME = 1.5
	local SPAWN_DISTANCE = 10 -- Distance in front of player to spawn preview

	local initializedTools = initializedToolsArg
	local cooldown = cooldownArg
	local tool = toolArg
	if initializedTools[tool] then
		return
	end
	initializedTools[tool] = true
	local player = Players.LocalPlayer
	while player:GetAttribute("MyCityLoaded") ~= true do
		player:GetAttributeChangedSignal("MyCityLoaded"):Wait()
	end
	local character = player.Character or player.CharacterAdded:Wait()
	local mouse = player:GetMouse()
	local camera = workspace.CurrentCamera

	local state = {
		rotationAngle = 0,
		previewBuilding = nil,
		selectionbox = nil,
		canPlace = false,
		isEquipped = false,
		connections = {},
		tileHighlights = {},
		isDragging = false,
		targetPosition = nil,
		arrowsGui = nil,
		baseSelection = nil,
		plotBounds = nil, -- Store plot boundaries
	}

	local playerGui = player:WaitForChild("PlayerGui")
	local HUD = playerGui:WaitForChild("HUD")
	local placementMobileGui = HUD:WaitForChild("MobilePlacement", 5)
	if not tool.Parent then
		initializedTools[tool] = nil
		return
	end

	-- UI Management

	local Access = require(script.Parent.Parent.PlacementAccess)
	local Context = {
		checkPlacementAccess = function(plot)
			return Access.check(player, plot, tool)
		end,
		State = State,
		Session = Session,
		ReplicatedStorage = ReplicatedStorage,
		RunService = RunService,
		TweenService = TweenService,
		Workspace = Workspace,
		Players = Players,
		UserInputService = UserInputService,
		SoundService = SoundService,
		GRID_SIZE = GRID_SIZE,
		LOCKED_Y_AXIS = LOCKED_Y_AXIS,
		COLLISION_CHECK_MARGIN = COLLISION_CHECK_MARGIN,
		VALID_COLOR = VALID_COLOR,
		INVALID_COLOR = INVALID_COLOR,
		PLACEMENT_DEBOUNCE_TIME = PLACEMENT_DEBOUNCE_TIME,
		SPAWN_DISTANCE = SPAWN_DISTANCE,
		initializedTools = initializedTools,
		cooldown = cooldown,
		tool = tool,
		player = player,
		character = character,
		mouse = mouse,
		camera = camera,
		state = state,
		playerGui = playerGui,
		HUD = HUD,
		placementMobileGui = placementMobileGui,
	}
	require(script:WaitForChild("Hud"))(Context)
	require(script:WaitForChild("Geometry"))(Context)
	require(script:WaitForChild("Collision"))(Context)
	require(script:WaitForChild("Preview"))(Context)
	require(script:WaitForChild("Motion"))(Context)
	require(script:WaitForChild("Input"))(Context)
	require(script:WaitForChild("Placement"))(Context)
	require(script:WaitForChild("Lifecycle"))(Context)

	Session.start()
	return Session
end
