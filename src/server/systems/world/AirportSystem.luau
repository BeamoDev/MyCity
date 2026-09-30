-- Server-owned airport traffic. Placed Airport models only provide named Attachment routes;
-- aircraft spawning, movement, cleanup and scheduling live here instead of inside the asset.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local AirportSystem = {}

local ARRIVAL_NAMES = {
	"A1_ApproachPoint",
	"A1_TouchdownPoint",
	"A1_BrakingPoint",
	"A1_TaxiPoint1",
	"A1_TaxiPoint2",
	"A1_TaxiPoint3",
	"A1_TaxiPoint4",
	"A1_TaxiPoint5",
	"A1_TaxiPoint6",
	"A1_TaxiPoint7",
	"A1_TaxiPoint8",
	"A1_GatePoint",
}
local DEPARTURE_NAMES = {
	"D1_GatePoint",
	"D1_TaxiPoint6",
	"D1_TaxiPoint5",
	"D1_TaxiPoint4",
	"D1_TaxiPoint3",
	"D1_TaxiPoint2",
	"D1_TaxiPoint1",
	"D1_TakeoffStart",
	"D1_LiftoffPoint",
	"D1_DeparturePoint",
}

local DEFAULT_YAW = 180 -- Previous +90 correction plus the requested additional 90 degrees right.
local DEFAULT_PITCH = -90 -- Imported aircraft needs its front pitched down into the route plane.
local GATE_WAIT = 10
local CYCLE_WAIT_MIN = 12
local CYCLE_WAIT_MAX = 24
local UPDATE_STEP = 1 / 30
local ROUTE_Y_OFFSET = -0.2

local started = false
local entries = {}
local connections = {}
local warned = {}
local readyConnections = setmetatable({}, { __mode = "k" })

local function warnOnce(key, message)
	if warned[key] then
		return
	end
	warned[key] = true
	warn("[AirportSystem] " .. message)
end

local function waitWhileActive(entry, duration)
	local finish = os.clock() + duration
	while entry.active and entry.airport:IsDescendantOf(Workspace) and os.clock() < finish do
		task.wait(math.min(0.25, math.max(0, finish - os.clock())))
	end
	return entry.active and entry.airport:IsDescendantOf(Workspace)
end

local function findAttachment(airport, name)
	local attachment = airport:FindFirstChild(name, true)
	return if attachment and attachment:IsA("Attachment") then attachment else nil
end

local function resolveRoute(airport, names)
	local route = {}
	for _, name in names do
		local attachment = findAttachment(airport, name)
		if not attachment then
			return nil, name
		end
		table.insert(route, attachment)
	end
	return route, nil
end

local function safeDirection(fromPosition, toPosition, fallback)
	local direction = toPosition - fromPosition
	if direction.Magnitude < 0.001 then
		return fallback or Vector3.new(0, 0, -1)
	end
	return direction.Unit
end

function AirportSystem.routeFrame(position, direction, yawDegrees, pitchDegrees, flightPitchDegrees)
	if direction.Magnitude < 0.001 then
		direction = Vector3.new(0, 0, -1)
	end
	return CFrame.lookAt(position, position + direction.Unit)
		* CFrame.Angles(math.rad(flightPitchDegrees or 0), 0, 0)
		* CFrame.Angles(math.rad(pitchDegrees or 0), math.rad(yawDegrees), 0)
end

local function routePosition(attachment)
	return attachment.WorldPosition + Vector3.new(0, ROUTE_Y_OFFSET, 0)
end

local function groundPhase(name)
	return name:find("Braking") or name:find("Taxi") or name:find("Gate") or name:find("TakeoffStart")
end

local function horizontalDirection(direction, fallback)
	local horizontal = Vector3.new(direction.X, 0, direction.Z)
	if horizontal.Magnitude < 0.001 and fallback then
		horizontal = Vector3.new(fallback.X, 0, fallback.Z)
	end
	return if horizontal.Magnitude >= 0.001 then horizontal.Unit else Vector3.new(0, 0, -1)
end

local function smootherStep(value)
	value = math.clamp(value, 0, 1)
	return value * value * value * (value * (value * 6 - 15) + 10)
end

local function motionProfile(targetName, alpha)
	if targetName:find("Touchdown") then
		-- Ease cleanly from the spawned approach into touchdown instead of arriving abruptly.
		return 0.5 - 0.5 * math.cos(math.pi * alpha)
	elseif targetName:find("Braking") then
		-- Cover distance quickly at first, then continuously bleed speed to zero.
		return 1 - (1 - alpha) ^ 3
	elseif targetName:find("Gate") or targetName:find("TakeoffStart") then
		return smootherStep(alpha)
	end
	return alpha
end

local function flarePitch(targetName, alpha)
	if targetName:find("Touchdown") then
		return 7 * smootherStep((alpha - 0.55) / 0.45)
	elseif targetName:find("Braking") then
		return 7 * (1 - smootherStep(alpha))
	end
	return 0
end

AirportSystem.motionProfile = motionProfile
AirportSystem.flarePitch = flarePitch

local function speedFor(targetName)
	if targetName:find("Touchdown") then
		return 2
	elseif targetName:find("Braking") then
		return 1.5
	elseif targetName:find("Taxi") then
		return 0.2
	elseif targetName:find("Gate") then
		return 0.2
	elseif targetName:find("TakeoffStart") then
		return 1.5
	elseif targetName:find("Liftoff") then
		return 2
	elseif targetName:find("Departure") then
		return 2
	end
	return 2
end

AirportSystem.speedFor = speedFor

local function minimumDuration(targetName)
	if targetName:find("Touchdown") then
		return 6
	elseif targetName:find("Braking") then
		return 6
	elseif targetName:find("Taxi") then
		return 4
	elseif targetName:find("Gate") then
		return 5
	elseif targetName:find("TakeoffStart") then
		return 6
	elseif targetName:find("Liftoff") or targetName:find("Departure") then
		return 6
	end
	return 5
end

AirportSystem.minimumDuration = minimumDuration

local function orientationValue(template, airport, name, default)
	local value = template:GetAttribute(name)
	if typeof(value) ~= "number" then
		value = airport:GetAttribute(name)
	end
	return if typeof(value) == "number" then value else default
end

local function cleanPlane(plane)
	for _, item in plane:GetDescendants() do
		if item:IsA("BasePart") then
			item.Anchored = true
			item.CanCollide = false
			item.CanTouch = false
			item.CanQuery = false
			item.Massless = true
		elseif item:IsA("BaseScript") then
			item.Disabled = true
		elseif item:IsA("ProximityPrompt") or item:IsA("ClickDetector") then
			item:Destroy()
		end
	end
end

local function planeTemplates()
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("Planes")
	if not folder then
		return nil, nil
	end
	local templates = {}
	for _, item in folder:GetChildren() do
		if item:IsA("Model") then
			table.insert(templates, item)
		end
	end
	return folder, templates
end

local function moveSegment(entry, plane, target, following, yaw, pitch)
	local startPosition = plane:GetPivot().Position
	local targetPosition = routePosition(target)
	local outgoing
	if following then
		local nextPosition = routePosition(following)
		if (nextPosition - targetPosition).Magnitude >= 0.001 then
			outgoing = (nextPosition - targetPosition).Unit
		end
	end
	local incoming = safeDirection(startPosition, targetPosition, outgoing or entry.lastDirection)
	outgoing = outgoing or incoming
	if groundPhase(target.Name) then
		incoming = horizontalDirection(incoming, entry.lastDirection)
		outgoing = horizontalDirection(outgoing, incoming)
	end
	local distance = (targetPosition - startPosition).Magnitude
	local duration = math.max(distance / math.max(speedFor(target.Name), 0.1), minimumDuration(target.Name))
	if duration <= 0.001 then
		plane:PivotTo(AirportSystem.routeFrame(targetPosition, outgoing, yaw, pitch))
		return true
	end

	local began = os.clock()
	while entry.active and plane.Parent and entry.airport:IsDescendantOf(Workspace) do
		local alpha = math.clamp((os.clock() - began) / duration, 0, 1)
		local motionAlpha = motionProfile(target.Name, alpha)
		local position = startPosition:Lerp(targetPosition, motionAlpha)
		-- Blend toward the next leg near a waypoint so taxi/runway turns do not snap.
		local turnAlpha = math.clamp((alpha - 0.65) / 0.35, 0, 1)
		turnAlpha = turnAlpha * turnAlpha * (3 - 2 * turnAlpha)
		local direction = incoming:Lerp(outgoing, turnAlpha)
		if direction.Magnitude < 0.001 then
			direction = incoming
		end
		plane:PivotTo(AirportSystem.routeFrame(position, direction, yaw, pitch, flarePitch(target.Name, alpha)))
		if alpha >= 1 then
			entry.lastDirection = outgoing
			return true
		end
		task.wait(UPDATE_STEP)
	end
	return false
end

local function animateRoute(entry, plane, route, firstTarget, yaw, pitch, isArrival)
	for index = firstTarget, #route do
		local target = route[index]
		if not target.Parent or not moveSegment(entry, plane, target, route[index + 1], yaw, pitch) then
			return false
		end
		local authoredPause = target:GetAttribute("Pause")
		local pause = if typeof(authoredPause) == "number" and authoredPause >= 0
			then authoredPause
			else if isArrival and target.Name:find("GatePoint") then GATE_WAIT else 0
		if pause > 0 and not waitWhileActive(entry, pause) then
			return false
		end
	end
	return true
end

local function destroyPlane(entry)
	if entry.plane then
		entry.plane:Destroy()
		entry.plane = nil
	end
end

local function run(entry)
	local _, templates = planeTemplates()
	if not templates or #templates == 0 then
		warnOnce("templates", "ReplicatedStorage.Assets.Planes has no plane Models")
		return
	end

	while entry.active and entry.airport:IsDescendantOf(Workspace) do
		local template = templates[math.random(1, #templates)]
		local plane = template:Clone()
		cleanPlane(plane)
		plane.Name = "AirportPlane"
		plane.Parent = entry.folder
		entry.plane = plane
		local yaw = orientationValue(template, entry.airport, "PlaneYaw", DEFAULT_YAW)
		local pitch = orientationValue(template, entry.airport, "PlanePitch", DEFAULT_PITCH)
		local first, second = entry.arrival[1], entry.arrival[2]
		entry.lastDirection = safeDirection(routePosition(first), routePosition(second))
		plane:PivotTo(
			AirportSystem.routeFrame(routePosition(first), entry.lastDirection, yaw, pitch)
		)

		local landed = animateRoute(entry, plane, entry.arrival, 2, yaw, pitch, true)
		local departed = landed and animateRoute(entry, plane, entry.departure, 1, yaw, pitch, false)
		destroyPlane(entry)
		if not departed or not waitWhileActive(entry, math.random(CYCLE_WAIT_MIN, CYCLE_WAIT_MAX)) then
			break
		end
	end
	destroyPlane(entry)
end

local function airportFor(item)
	local current = item
	while current and current ~= Workspace do
		if current:IsA("Model") and current:GetAttribute("BuildingType") == "Airport" then
			-- Construction sites also carry BuildingType, but do not contain flight routes.
			-- Only the completed model under Buildings.Placed may start airport traffic.
			return if current.Parent and current.Parent.Name == "Placed" then current else nil
		end
		current = current.Parent
	end
	return nil
end

local function readyOwner(airport)
	local placed = airport.Parent
	local buildings = placed and placed.Parent
	local plot = buildings and buildings.Parent
	local cityId = plot and tonumber(plot:GetAttribute("CityId"))
	local owner = cityId and Players:GetPlayerByUserId(cityId)
	return owner and owner:GetAttribute("MyCityLoaded") == true
		and not owner:GetAttribute("MyCityLeaving")
end

local function remove(airport)
	local entry = entries[airport]
	if not entry then
		return
	end
	entry.active = false
	destroyPlane(entry)
	entries[airport] = nil
end

local function add(airport)
	if not airport or entries[airport] or not readyOwner(airport) then
		return
	end
	for _, item in airport:GetDescendants() do
		if item:IsA("BaseScript") then
			item.Disabled = true
		end
	end
	local arrival, missingArrival = resolveRoute(airport, ARRIVAL_NAMES)
	local departure, missingDeparture = resolveRoute(airport, DEPARTURE_NAMES)
	if not arrival or not departure then
		warnOnce(airport, airport:GetFullName() .. " is missing " .. tostring(missingArrival or missingDeparture))
		return
	end
	local folder = airport:FindFirstChild("RuntimePlanes")
	if folder and not folder:IsA("Folder") then
		folder:Destroy()
		folder = nil
	end
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "RuntimePlanes"
		folder.Parent = airport
	end
	local entry = { airport = airport, arrival = arrival, departure = departure, folder = folder, active = true }
	entries[airport] = entry
	task.spawn(run, entry)
end

local function startForPlayer(player)
	if player:GetAttribute("MyCityLoaded") ~= true or player:GetAttribute("MyCityLeaving") then return end
	local data = player:FindFirstChild("Data")
	local info = data and data:FindFirstChild("PlotInfo")
	local plotNumber = info and info:FindFirstChild("Plot")
	local plots = Workspace:FindFirstChild("Plots")
	local plot = plots and plotNumber and plots:FindFirstChild("Plot" .. plotNumber.Value)
	if not plot or tostring(plot:GetAttribute("CityId")) ~= tostring(player.UserId) then return end
	local buildings = plot:FindFirstChild("Buildings")
	local placed = buildings and buildings:FindFirstChild("Placed")
	if placed then
		for _, model in placed:GetChildren() do
			if model:GetAttribute("BuildingType") == "Airport" then add(model) end
		end
	end
end

local function watchPlayer(player)
	if readyConnections[player] then return end
	readyConnections[player] = player:GetAttributeChangedSignal("MyCityLoaded"):Connect(function()
		if player:GetAttribute("MyCityLoaded") then task.defer(startForPlayer, player) end
	end)
	if player:GetAttribute("MyCityLoaded") then task.defer(startForPlayer, player) end
end

local function disableLegacyTemplateController()
	local buildings = ServerStorage:FindFirstChild("Buildings")
	local airport = buildings and buildings:FindFirstChild("Airport")
	if not airport then
		return
	end
	for _, item in airport:GetDescendants() do
		if item:IsA("BaseScript") then
			item.Disabled = true
		end
	end
end

function AirportSystem.init()
	if started then
		return
	end
	started = true
	disableLegacyTemplateController()
	table.insert(connections, Players.PlayerAdded:Connect(watchPlayer))
	for _, player in Players:GetPlayers() do watchPlayer(player) end
	table.insert(connections, Players.PlayerRemoving:Connect(function(player)
		local connection = readyConnections[player]
		if connection then connection:Disconnect() end
		readyConnections[player] = nil
	end))
	for _, item in Workspace:GetDescendants() do
		add(airportFor(item))
	end
	table.insert(connections, Workspace.DescendantAdded:Connect(function(item)
		add(airportFor(item))
	end))
	table.insert(connections, Workspace.DescendantRemoving:Connect(function(item)
		if entries[item] then
			remove(item)
		end
	end))
end

return AirportSystem
