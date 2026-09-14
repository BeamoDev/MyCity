local DayNightCycle = {}
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

-- Constants
local DAY_DURATION = 600 -- 600
local NIGHT_DURATION = 240 -- 240
local TRANSITION_TIME = 6

-- Window colors for night time
local NIGHT_WINDOW_COLORS = {
	Color3.fromRGB(255, 255, 100), -- Warm yellow
	Color3.fromRGB(255, 200, 50), -- Orange-yellow
	Color3.fromRGB(255, 186, 90), -- Dark/off
	Color3.fromRGB(255, 186, 90), -- Cool blue
	Color3.fromRGB(255, 150, 150), -- Warm pink
}

-- State
local currentTimeOfDay = "Day"
local timeRemaining = DAY_DURATION
local isTransitioning = false

-- RemoteEvent
local timeUpdateRemote = ReplicatedStorage.Events.Weather.TimeUpdate

-- Store original window properties
local windowOriginalProperties = {}

local function storeWindowProperties(window)
	if not windowOriginalProperties[window] then
		windowOriginalProperties[window] = {
			Material = window.Material,
			Color = window.Color,
		}
	end
end

local function setWindowNight(window, forceYellow)
	storeWindowProperties(window)
	window.Material = Enum.Material.Neon
	window.Transparency = 0.6

	if forceYellow then
		window.Color = Color3.fromRGB(255, 255, 100)
	else
		if math.random() > 0.3 then
			window.Color = NIGHT_WINDOW_COLORS[math.random(1, #NIGHT_WINDOW_COLORS)]
		else
			window.Color = Color3.fromRGB(20, 20, 20)
		end
	end
end

local function setWindowDay(window)
	local original = windowOriginalProperties[window]
	if original then
		window.Material = original.Material
		window.Color = original.Color
		window.Transparency = 0
	end
end

local function updateBuildingWindows(building, isNight)
	local isYellow = building.Name:lower():find("airport")
		or building.Name:lower():find("hospital")
		or building.Name:lower():find("petronas")
		or building.Name:lower():find("skytower")
		or building.Name:lower():find("empire")
		or building.Name:lower():find("usbank")
		or building.Name:lower():find("chinabank")
		or building.Name:lower():find("condo")
		or building.Name:lower():find("absolute")
		or building.Name:lower():find("taipei")
		or building.Name:lower():find("police")
		or building.Name:lower():find("fire") ~= nil

	for _, part in pairs(building:GetDescendants()) do
		if part:IsA("MeshPart") then
			local name = part.Name:lower()
			if name:find("lights") or name:find("windows") then
				if isNight then
					setWindowNight(part, isYellow)
				else
					setWindowDay(part)
				end
			end
		end
	end
end

local function updateAllBuildingWindows(isNight)
	-- Update regular plot buildings
	for _, plot in pairs(Workspace.Plots:GetChildren()) do
		local placedFolder = plot.Buildings:FindFirstChild("Placed")
		if placedFolder then
			for _, building in pairs(placedFolder:GetChildren()) do
				updateBuildingWindows(building, isNight)
			end
		end
	end

	-- Update TutorialShowcase buildings
	local tutorialShowcase = Workspace:FindFirstChild("TutorialShowcase")
	if tutorialShowcase then
		local showcaseBuildings = tutorialShowcase:FindFirstChild("Buildings")
		if showcaseBuildings then
			local showcasePlaced = showcaseBuildings:FindFirstChild("Placed")
			if showcasePlaced then
				for _, building in pairs(showcasePlaced:GetChildren()) do
					updateBuildingWindows(building, isNight)
				end
			end
		end
	end
end

local function transitionToNight()
	isTransitioning = true
	currentTimeOfDay = "Night"

	-- Tween Lighting properties
	local tweenInfo = TweenInfo.new(TRANSITION_TIME, Enum.EasingStyle.Linear)

	local clockTween = TweenService:Create(Lighting, tweenInfo, {
		ClockTime = 5,
		Ambient = Color3.new(0.392157, 0.392157, 0.392157),
	})

	local atmosphereTween = TweenService:Create(Lighting.Atmosphere, tweenInfo, {
		Density = 0.55,
	})
	-- Play tweens
	clockTween:Play()
	atmosphereTween:Play()

	-- Update windows midway
	task.spawn(function()
		task.wait(TRANSITION_TIME / 2)
		updateAllBuildingWindows(true)
	end)

	task.wait(TRANSITION_TIME)
	isTransitioning = false
	timeRemaining = NIGHT_DURATION
end

local function transitionToDay()
	isTransitioning = true
	currentTimeOfDay = "Day"

	-- Tween Lighting properties
	local tweenInfo = TweenInfo.new(TRANSITION_TIME, Enum.EasingStyle.Linear)

	local clockTween = TweenService:Create(Lighting, tweenInfo, {
		ClockTime = 14.5,
		Ambient = Color3.new(0.529412, 0.529412, 0.529412),
	})

	local atmosphereTween = TweenService:Create(Lighting.Atmosphere, tweenInfo, {
		Density = 0.45,
	})

	-- Play tweens
	clockTween:Play()
	atmosphereTween:Play()

	-- Update windows midway
	task.spawn(function()
		task.wait(TRANSITION_TIME / 2)
		updateAllBuildingWindows(false)
	end)

	task.wait(TRANSITION_TIME)
	isTransitioning = false
	timeRemaining = DAY_DURATION
end

-- Export for other modules to check current time
function DayNightCycle.isNightTime()
	return currentTimeOfDay == "Night"
end

-- Export for buildings to update their windows when placed
function DayNightCycle.updateNewBuilding(building)
	if currentTimeOfDay == "Night" then
		updateBuildingWindows(building, true)
	end
end

local function updateClients()
	for _, player in pairs(Players:GetPlayers()) do
		timeUpdateRemote:FireClient(player, currentTimeOfDay, timeRemaining)
	end
end

local started = false
function DayNightCycle.init()
	if started then
		return
	end
	started = true
	Lighting.ClockTime = 14.5
	currentTimeOfDay = "Day"
	timeRemaining = DAY_DURATION

	task.spawn(function()
		while true do
			local elapsed = task.wait(1)
			if not isTransitioning then
				timeRemaining = math.max(0, timeRemaining - elapsed)
				if timeRemaining <= 0 then
					if currentTimeOfDay == "Day" then
						transitionToNight()
					else
						transitionToDay()
					end
				end
				updateClients()
			end
		end
	end)

	Players.PlayerAdded:Connect(function(player)
		task.wait(2)
		timeUpdateRemote:FireClient(player, currentTimeOfDay, timeRemaining)
	end)
end

return DayNightCycle
