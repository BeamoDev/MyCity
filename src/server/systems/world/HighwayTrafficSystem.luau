local HighwayTrafficSystem = {}

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CONFIG = {
	MAX_CARS = 25,
	CAR_SPEED = 5,
	SPAWN_INTERVAL = { min = 1, max = 4 }, -- Random spawn timing
	LANE_OFFSET_RANGE = 1.8, -- How much cars can vary within their lane
}

local activeCars = {}
local carConnections = {}
local spawnPoints = {}
local carTemplates = {}
local isRunning = false
local activeCarsFolder = nil

local function loadCarTemplates()
	local templateFolder = ReplicatedStorage.Assets:FindFirstChild("CarTemplates")
	if not templateFolder then
		warn("CarTemplates folder not found")
		return
	end

	for _, car in pairs(templateFolder:GetChildren()) do
		if car:IsA("Model") then
			table.insert(carTemplates, car)
		end
	end
end

local function setupSpawnPoints()
	local highway = Workspace.Map.Enviorment:FindFirstChild("RoadSystem")
	if not highway then
		return
	end

	local points = highway:FindFirstChild("Points")
	if points then
		spawnPoints = {
			{
				start = points:FindFirstChild("Point3"),
				finish = points:FindFirstChild("Point4"),
				direction = "forward",
				rotation = CFrame.Angles(0, math.rad(-90), 0),
			},
			{
				start = points:FindFirstChild("Point6"),
				finish = points:FindFirstChild("Point5"),
				direction = "reverse",
				rotation = CFrame.Angles(0, math.rad(90), 0),
			},
		}
	end
end

local function createCar(lane)
	if #carTemplates == 0 then
		return nil
	end

	local template = carTemplates[math.random(1, #carTemplates)]
	local car = template:Clone()

	-- Random offset within lane for variety
	local laneOffset = math.random(-CONFIG.LANE_OFFSET_RANGE * 10, CONFIG.LANE_OFFSET_RANGE * 10) / 10
	local spawnCFrame = lane.start.CFrame * CFrame.new(laneOffset, 0, 0) * lane.rotation

	car:SetPrimaryPartCFrame(spawnCFrame)
	car.Parent = activeCarsFolder

	-- Make anchored and non-collidable
	for _, part in pairs(car:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
		end
	end

	return car
end

local function moveCar(car, lane)
	if not car or not lane.start or not lane.finish then
		return
	end

	local carData = {
		car = car,
		targetPos = lane.finish.Position,
		speed = CONFIG.CAR_SPEED, --+ math.random(-1, 1) -- Slight speed variation
	}

	table.insert(activeCars, carData)

	local connection
	connection = RunService.Heartbeat:Connect(function(deltaTime)
		if not car:IsDescendantOf(Workspace) then
			connection:Disconnect()
			carConnections[car] = nil

			local index = table.find(activeCars, carData)
			if index then
				table.remove(activeCars, index)
			end
			return
		end

		local currentPos = car.PrimaryPart.Position
		local direction = (carData.targetPos - currentPos).Unit
		local moveDistance = carData.speed * deltaTime

		-- Check if reached end
		if (currentPos - carData.targetPos).Magnitude <= 5 then
			-- Remove car at end of highway
			car:Destroy()
			connection:Disconnect()

			local index = table.find(activeCars, carData)
			if index then
				table.remove(activeCars, index)
			end
		else
			-- Simple forward movement
			local newPos = currentPos + direction * moveDistance
			local lookAtCFrame = CFrame.lookAt(newPos, newPos + direction)
			car:SetPrimaryPartCFrame(lookAtCFrame)
		end
	end)

	carConnections[car] = connection
end

local function spawnLoop()
	while isRunning do
		if #activeCars < CONFIG.MAX_CARS and #spawnPoints > 0 then
			-- Pick random lane
			local lane = spawnPoints[math.random(1, #spawnPoints)]

			if lane.start and lane.finish then
				local car = createCar(lane)
				if car then
					moveCar(car, lane)
				end
			end
		end

		-- Random interval between spawns
		task.wait(math.random(CONFIG.SPAWN_INTERVAL.min * 10, CONFIG.SPAWN_INTERVAL.max * 10) / 10)
	end
end

function HighwayTrafficSystem.init()
	activeCarsFolder = Workspace.Map.Enviorment.RoadSystem:FindFirstChild("ActiveCars")

	loadCarTemplates()
	setupSpawnPoints()

	if #carTemplates == 0 then
		warn("No car templates found")
		return
	end

	isRunning = true
	task.spawn(spawnLoop)
end

function HighwayTrafficSystem.stop()
	isRunning = false

	for car, connection in pairs(carConnections) do
		if connection then
			connection:Disconnect()
		end
		if car and car.Parent then
			car:Destroy()
		end
	end

	carConnections = {}
	activeCars = {}

	print("Highway traffic stopped")
end

return HighwayTrafficSystem
