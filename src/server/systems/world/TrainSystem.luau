local TrainSystem = {}

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local CONFIG = {
	MAX_TRAINS = 3,
	TRAIN_SPEED = 0.1,
	SPAWN_INTERVAL = { min = 20, max = 40 },
	TRAVEL_TIME = 40,
}

local activeTrains = {}
local trainConnections = {}
local spawnPoints = {}
local trainTemplate = nil
local isRunning = false
local activeTrainsFolder = nil

local function loadTrainTemplate()
	trainTemplate = ReplicatedStorage.Assets.Trains:FindFirstChild("Train")
	if trainTemplate then
		return true
	else
		return false
	end
end

local function setupSpawnPoints()
	local trainSystem = Workspace.Map.Enviorment:FindFirstChild("TrainSystem")

	if not trainSystem then
		return
	end

	local points = trainSystem:FindFirstChild("Points")
	if points then
		local point1 = points:FindFirstChild("Point1")
		local point2 = points:FindFirstChild("Point2")
		local point3 = points:FindFirstChild("Point3")
		local point4 = points:FindFirstChild("Point4")

		spawnPoints = {
			{
				start = point3,
				finish = point4,
				rotation = CFrame.Angles(0, math.rad(90), 0),
			},
			{
				start = point1,
				finish = point2,
				rotation = CFrame.Angles(0, math.rad(90), 0),
			},
		}
	end
end

local function createTrain(route)
	if not trainTemplate then
		return nil
	end

	if not route.start then
		return nil
	end

	local train = trainTemplate:Clone()

	if not train.PrimaryPart then
		local possiblePart = train:FindFirstChild("Base") or train:FindFirstChildWhichIsA("BasePart")
		if possiblePart then
			train.PrimaryPart = possiblePart
		else
			return nil
		end
	end

	local spawnCFrame = route.start.CFrame * route.rotation
	train:SetPrimaryPartCFrame(spawnCFrame)

	if activeTrainsFolder then
		train.Parent = activeTrainsFolder
	else
		train.Parent = Workspace
	end

	return train
end

local function moveTrain(train, route)
	if not train then
		return
	end

	if not train.PrimaryPart then
		return
	end

	if not route.start or not route.finish then
		return
	end

	local trainData = {
		train = train,
		startPos = route.start.Position,
		endPos = route.finish.Position,
	}

	table.insert(activeTrains, trainData)

	local tweenInfo = TweenInfo.new(CONFIG.TRAVEL_TIME, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)

	local endCFrame = route.finish.CFrame * route.rotation
	local tween = TweenService:Create(train.PrimaryPart, tweenInfo, { CFrame = endCFrame })

	local connection
	connection = RunService.Heartbeat:Connect(function()
		if train.Parent and train.PrimaryPart then
			train:SetPrimaryPartCFrame(train.PrimaryPart.CFrame)
		else
			connection:Disconnect()
		end
	end)

	trainConnections[train] = connection
	tween:Play()

	tween.Completed:Connect(function()
		if connection then
			connection:Disconnect()
		end

		if train.Parent then
			train:Destroy()
		end

		trainConnections[train] = nil

		local index = table.find(activeTrains, trainData)
		if index then
			table.remove(activeTrains, index)
		end
	end)
end

local function spawnLoop()
	while isRunning do
		if #activeTrains < CONFIG.MAX_TRAINS and #spawnPoints > 0 then
			local routeIndex = math.random(1, #spawnPoints)
			local route = spawnPoints[routeIndex]

			if route.start and route.finish then
				local train = createTrain(route)
				if train then
					moveTrain(train, route)
				end
			end
		end

		local waitTime = math.random(CONFIG.SPAWN_INTERVAL.min * 10, CONFIG.SPAWN_INTERVAL.max * 10) / 10
		task.wait(waitTime)
	end
end

function TrainSystem.init()
	local trainSystemFolder = Workspace.Map.Enviorment:FindFirstChild("TrainSystem")
	if not trainSystemFolder then
		return
	end

	activeTrainsFolder = trainSystemFolder:FindFirstChild("ActiveTrains")
	if not activeTrainsFolder then
		activeTrainsFolder = Instance.new("Folder")
		activeTrainsFolder.Name = "ActiveTrains"
		activeTrainsFolder.Parent = trainSystemFolder
	end

	if not loadTrainTemplate() then
		return
	end

	setupSpawnPoints()

	if #spawnPoints == 0 then
		return
	end

	isRunning = true
	task.spawn(spawnLoop)
end

function TrainSystem.stop()
	isRunning = false

	for train, connection in pairs(trainConnections) do
		if connection then
			connection:Disconnect()
		end
		if train and train.Parent then
			train:Destroy()
		end
	end

	trainConnections = {}
	activeTrains = {}
end

return TrainSystem
