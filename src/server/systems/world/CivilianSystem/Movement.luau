local PathfindingService = game:GetService("PathfindingService")
local Config = require(script.Parent.Config)
local Geometry = require(script.Parent.Geometry)
local Animations = require(script.Parent.Animations)
local Movement = {}
local computing = false
local nextRequest = 0
local function flatDistance(a, b)
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end
local function pause(record, now, random, retry)
	record.path = nil
	record.humanoid:MoveTo(record.root.Position)
	record.pauseUntil = now + (if retry then 0.2 else random:NextNumber(Config.PauseMin, Config.PauseMax))
	Animations.moving(record, false)
end
local function setPath(record, points, now)
	record.path, record.index = points, 1
	record.lastProgress, record.bestDistance = now, math.huge
	record.nextMove = 0
end
local function plan(record, city, now, random)
	local destination = Geometry.wander(city.geometry, record.root.Position, record.radius, random)
		or Geometry.target(city.geometry, record.radius, random)
	if not destination or flatDistance(destination, record.root.Position) <= Config.ArrivalDistance then
		pause(record, now, random)
		return
	end
	if Geometry.segment(city.geometry, record.root.Position, destination, record.radius) then
		setPath(record, { destination }, now)
		return
	end
	if computing or now < nextRequest then
		return
	end
	computing, record.computing = true, true
	nextRequest = now + Config.PathInterval
	task.spawn(function()
		local ok, points = pcall(function()
			local path = PathfindingService:CreatePath({
				AgentRadius = record.radius,
				AgentHeight = record.height,
				AgentCanJump = false,
				AgentCanClimb = false,
				WaypointSpacing = 2,
			})
			local computed, err = pcall(function()
				path:ComputeAsync(record.root.Position, destination)
			end)
			if not computed then
				path:Destroy()
				error(err)
			end
			local waypoints = if path.Status == Enum.PathStatus.Success then path:GetWaypoints() else {}
			path:Destroy()
			local result, previous = {}, record.root.Position
			for _, waypoint in waypoints do
				local ground = Geometry.ground(city.geometry, waypoint.Position, record.radius)
				if
					not ground
					or math.abs(ground.Y - waypoint.Position.Y) > math.max(2, record.height)
					or not Geometry.segment(city.geometry, previous, ground, record.radius)
				then
					return nil
				end
				table.insert(result, ground)
				previous = ground
			end
			return if #result > 1 then result else nil
		end)
		computing, record.computing = false, false
		-- ComputeAsync yields: never attach a late path to a departed/replaced city.
		if not record.active or not city.active or not record.model.Parent then
			return
		end
		if ok and points then
			setPath(record, points, os.clock())
		else
			pause(record, os.clock(), random)
		end
	end)
end
function Movement.step(record, city, now, random)
	if not record.model.Parent or record.humanoid.Health <= 0 then
		return false
	end
	local position = record.root.Position
	-- Detect actual travel rather than resetting the watchdog every time a new target is selected.
	if not record.travelAnchor or flatDistance(position, record.travelAnchor) >= 0.5 then
		record.travelAnchor, record.lastTravel = position, now
		record.stuckRetries = 0
	end
	if now - record.lastTravel >= Config.MaxIdleSeconds then
		return false -- Replace an actor that cannot move, instead of keeping an idle statue.
	end
	local ground = Geometry.ground(city.geometry, position, record.radius)
	if not ground or math.abs(position.Y - ground.Y) > 20 then
		return false
	end
	if record.computing then
		return true
	end
	if not record.path then
		if now >= record.pauseUntil then
			plan(record, city, now, random)
		end
		return true
	end
	local target = record.path[record.index]
	if flatDistance(position, target) <= math.max(Config.ArrivalDistance, record.radius * 0.5) then
		record.index += 1
		target = record.path[record.index]
		record.lastProgress, record.bestDistance, record.nextMove = now, math.huge, 0
		if not target then
			pause(record, now, random)
			return true
		end
	end

	local distance = flatDistance(position, target)
	if distance < record.bestDistance - 0.1 then
		record.bestDistance, record.lastProgress = distance, now
	end
	if now - record.lastProgress > Config.StuckSeconds then
		record.stuckRetries = (record.stuckRetries or 0) + 1
		if record.stuckRetries >= Config.MaxStuckRetries then
			return false
		end
		record.humanoid.Sit, record.humanoid.PlatformStand = false, false
		record.humanoid.WalkSpeed = Config.WalkSpeed
		pause(record, now, random, true)
		return true
	end
	if now >= record.nextMove then
		if not Geometry.segment(city.geometry, position, target, record.radius) then
			pause(record, now, random)
			return true
		end

		record.humanoid.Sit, record.humanoid.PlatformStand = false, false
		record.humanoid.WalkSpeed = Config.WalkSpeed
		record.humanoid:MoveTo(target)
		record.nextMove = now + 0.45
	end
	local moved = record.lastPosition and flatDistance(position, record.lastPosition) > 0.015
	Animations.moving(record, moved == true)
	record.lastPosition = position
	return true
end
return Movement
