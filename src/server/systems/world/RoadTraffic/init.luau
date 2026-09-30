-- Cosmetic cars on player-built roads. The server plans immutable multi-waypoint trips from each
-- city's road graph and publishes them to ReplicatedStorage.Runtime.AmbientTraffic, where the client
-- AmbientTrafficController renders them (same pipeline and car templates as the highway).
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Graph = require(script.Graph)
local Density = require(script.Density)

local RoadTraffic = {}
local Config = {
	Templates = "CarTemplates",
	Speed = 8 / 3, -- studs per second (3x slower than the original 8)
	MaxPerCity = 12,
	GlobalLimit = 72,
	MaxPieces = 12, -- pieces driven per trip before the car leaves
	Interval = 1, -- seconds between city updates
	VisitChance = 0.5, -- share of highway cars that turn into a connected city
	ConnectDistance = 20, -- a player's road end within this of the slip roads' plot ends connects
	ConnectHeight = 40, -- and within this vertically; cars ramp smoothly between the two heights
	HighwayReach = 20, -- EnterPlot/ExitPlot must be this close to a highway lane line
}
RoadTraffic.Config = Config

local started = false
local cities = {} -- plot -> { dirty, pieces, cars = { {folder, ends} } }
local templates, lifts = {}, {}
local folder
local serial, total = 0, 0

local function groundAt(position, model)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { model }
	local hit = Workspace:Raycast(position + Vector3.new(0, 4, 0), Vector3.new(0, -8, 0), params)
	return if hit then hit.Position.Y else position.Y
end

-- Height from a template's PrimaryPart centre down to its lowest point, so wheels sit on the road.
local function liftOf(template)
	if lifts[template] == nil then
		local primary = template.PrimaryPart or template:FindFirstChildWhichIsA("BasePart", true)
		local ok, frame, size = pcall(template.GetBoundingBox, template)
		lifts[template] = if ok and primary then primary.Position.Y - (frame.Position.Y - size.Y / 2) else 0
	end
	return lifts[template]
end

local Visits = {
	Graph = Graph,
	Config = Config,
	cities = cities,
	groundAt = groundAt,
	liftOf = liftOf,
}
require(script.Visits)(Visits)
-- Called by highway traffic when it spawns a car; returns waypoint CFrames for a city visit or nil.
function RoadTraffic.divert(current, trips, template)
	if not started then
		return nil
	end
	local ok, frames = pcall(Visits.divert, current, trips, template)
	if not ok then
		warn("[RoadTraffic] Visit planning failed:", frames)
		return nil
	end
	return frames
end

local function retire(city, index)
	local car = city.cars[index]
	car.folder:Destroy()
	table.remove(city.cars, index)
	total -= 1
end

local function clear(city)
	for index = #city.cars, 1, -1 do
		retire(city, index)
	end
end

local function roadsOf(plot)
	local buildings = plot:FindFirstChild("Buildings")
	local placed = buildings and buildings:FindFirstChild("Placed")
	local roads = {}
	for _, model in (if placed then placed:GetChildren() else {}) do
		if Graph.isRoad(model) then
			table.insert(roads, model)
		end
	end
	return roads
end

local function populationOf(plot)
	local cityId = tonumber(plot:GetAttribute("CityId"))
	local player = cityId and Players:GetPlayerByUserId(cityId)
	local data = player and player:FindFirstChild("Data")
	local info = data and data:FindFirstChild("PlayerInfo")
	local population = info and info:FindFirstChild("Population")
	return if population and type(population.Value) == "number" then population.Value else 0
end

local function readyForAmbient(plot)
	local cityId = tonumber(plot:GetAttribute("CityId"))
	local player = cityId and Players:GetPlayerByUserId(cityId)
	return player ~= nil and player:GetAttribute("MyCityLoaded") == true
		and not player:GetAttribute("MyCityLeaving")
end

local function developmentOf(plot, city)
	if city.developmentDirty then
		city.developmentDirty = false
		local buildings = plot:FindFirstChild("Buildings")
		local placed = buildings and buildings:FindFirstChild("Placed")
		local count = 0
		for _, model in (if placed then placed:GetChildren() else {}) do
			if model:IsA("Model") and not Graph.isRoad(model) then
				count += 1
			end
		end
		city.buildings = count
	end
	return Density.desired(#city.pieces, city.buildings, populationOf(plot), Config.MaxPerCity)
end

local function spawnCar(plot, city)
	local template = templates[math.random(1, #templates)]
	local points = Graph.plan(city.pieces, math.random, Config.MaxPieces)
	if not points then
		return
	end
	-- RoadYaw (degrees) overrides; otherwise match how highway cars are oriented, once one has spawned.
	local yaw = template:GetAttribute("RoadYaw") or template.Parent:GetAttribute("RoadYaw")
	local correction = if yaw then nil else Visits.correction
	local frames = Graph.frames(points, liftOf(template), yaw or 0, correction)
	local length = Graph.length(frames)
	if #frames < 2 or length < 1 then
		return
	end
	local duration = length / Config.Speed
	serial += 1
	local trip = Instance.new("Folder")
	trip.Name = "Road_" .. plot.Name .. "_" .. serial
	trip:SetAttribute("TemplateFolder", Config.Templates)
	trip:SetAttribute("TemplateName", template.Name)
	trip:SetAttribute("TemplateId", template:GetAttribute("TemplateId"))
	trip:SetAttribute("Points", #frames)
	for index, frame in frames do
		trip:SetAttribute("P" .. index, frame)
	end
	trip:SetAttribute("First", frames[1])
	trip:SetAttribute("Last", frames[#frames])
	trip:SetAttribute("Duration", duration)
	trip:SetAttribute("Started", Workspace:GetServerTimeNow())
	trip.Parent = folder
	table.insert(city.cars, { folder = trip, ends = os.clock() + duration })
	total += 1
end

local function refresh(plot, city)
	if city.dirty then
		city.dirty = false
		-- Roads changed: current trips may cross removed pieces, so replan from scratch.
		clear(city)
		city.pieces = Graph.build(roadsOf(plot), groundAt)
		Visits.report(plot, city)
	end
	local now = os.clock()
	for index = #city.cars, 1, -1 do
		if now >= city.cars[index].ends then
			retire(city, index)
		end
	end
end

local function watch(plot)
	if cities[plot] then
		return
	end
	local city = { dirty = true, developmentDirty = true, buildings = 0, pieces = {}, cars = {} }
	cities[plot] = city
	local function bind(placed)
		local function changed(model)
			city.developmentDirty = true
			if Graph.isRoad(model) then
				city.dirty = true
			end
		end
		placed.ChildAdded:Connect(changed)
		placed.ChildRemoved:Connect(changed)
	end
	local buildings = plot:WaitForChild("Buildings", 10)
	local placed = buildings and buildings:WaitForChild("Placed", 10)
	if placed then
		bind(placed)
	end
end

function RoadTraffic.init()
	if started then
		return
	end
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local source = assets and assets:FindFirstChild(Config.Templates)
	local plots = Workspace:FindFirstChild("Plots")
	if source then
		templates = require(ReplicatedStorage.shared.visuals.AmbientModel).templates(source)
	end
	if #templates == 0 or not plots then
		warn("[RoadTraffic] Missing Assets." .. Config.Templates .. " car models or Workspace.Plots")
		return
	end
	started = true
	print(string.format("[RoadTraffic] Started: %d car models, %d plots", #templates, #plots:GetChildren()))
	local runtime = ReplicatedStorage:FindFirstChild("Runtime")
	if not runtime then
		runtime = Instance.new("Folder")
		runtime.Name, runtime.Parent = "Runtime", ReplicatedStorage
	end
	folder = runtime:FindFirstChild("AmbientTraffic")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name, folder.Parent = "AmbientTraffic", runtime
	end
	for _, plot in plots:GetChildren() do
		task.spawn(watch, plot)
	end
	plots.ChildAdded:Connect(function(plot)
		task.spawn(watch, plot)
	end)
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < Config.Interval then
			return
		end
		elapsed = 0
		local active, desired = {}, {}
		for plot, city in cities do
			if plot.Parent then
				table.insert(active, { plot = plot, city = city })
				if readyForAmbient(plot) then
					refresh(plot, city)
					table.insert(desired, developmentOf(plot, city))
				else
					-- Build the graph only once the authoritative city is ready.
					city.dirty, city.developmentDirty = true, true
					table.insert(desired, 0)
				end
			else
				clear(city)
				cities[plot] = nil
			end
		end
		local targets = Density.allocate(desired, Config.GlobalLimit, Config.MaxPerCity)
		-- Retire globally before adding work, then grow gradually across cities.
		for index, entry in active do
			local city = entry.city
			for carIndex = #city.cars, targets[index] + 1, -1 do
				retire(city, carIndex)
			end
			entry.plot:SetAttribute("AmbientCarTarget", targets[index])
		end
		for index, entry in active do
			local city = entry.city
			if #city.cars < targets[index] and total < Config.GlobalLimit then
				local ok, err = pcall(spawnCar, entry.plot, city)
				if not ok then
					warn("[RoadTraffic] Spawn failed:", err)
				end
			end
		end
	end)
end

return RoadTraffic
