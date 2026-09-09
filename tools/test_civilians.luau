local fs = require("@lune/fs")
local luau = require("@lune/luau")
local r = require("@lune/roblox")
local basePath = "src/server/systems/world/CivilianSystem/"
local function load(name, env)
	return luau.load(fs.readFile(basePath .. name .. ".luau"), { environment = env or {} })()
end
local config = load("Config")
assert(config.desired(0) == 0 and config.desired(1) == 1 and config.desired(4) == 2 and config.desired(1000) == 8)
local quotas = config.allocate({ 8, 8, 8, 8, 8, 8 })
local total = 0
for _, quota in quotas do
	assert(quota == 4)
	total += quota
end
assert(total == 24)
assert(
	config.AnimationIds.R6.Walk == "rbxassetid://180426354" and config.AnimationIds.R15.Walk == "rbxassetid://507777826"
)
local geometry = load("Geometry", { Vector3 = r.Vector3 })
local storage = r.Instance.new("Folder")
local function part(name, position, size)
	local value = r.Instance.new("Part")
	value.Name, value.Size, value.CFrame, value.Parent = name, size, r.CFrame.new(position), storage
	return value
end
local tile = part("Tile", r.Vector3.new(0, 1, 0), r.Vector3.new(20, 0.5, 20))
local building = part("Base", r.Vector3.new(0, 2, 0), r.Vector3.new(4, 1, 4))
local snapshot = { tiles = { tile }, obstacles = { building }, buildings = { building } }
assert(geometry.ground(snapshot, r.Vector3.new(4, 50, 0), 0.5).Y == 1.25)
assert(not geometry.ground(snapshot, r.Vector3.new(0, 1, 0), 0.5), "Spawn inside building")
assert(not geometry.ground(snapshot, r.Vector3.new(9.8, 1, 0), 0.5), "NPC footprint outside owned land")
assert(
	not geometry.segment(snapshot, r.Vector3.new(-4, 1.25, 0), r.Vector3.new(4, 1.25, 0), 0.5),
	"Walked through building"
)
assert(geometry.segment(snapshot, r.Vector3.new(-4, 1.25, 4), r.Vector3.new(4, 1.25, 4), 0.5))
local random = {
	NextInteger = function(_, low)
		return low
	end,
	NextNumber = function(_, low, high)
		return (low + high) / 2
	end,
}
assert(geometry.target(snapshot, 0.5, random), "Could not choose a building-side destination")
local origin = r.Vector3.new(-4, 1.25, 4)
local nearby = geometry.wander(snapshot, origin, 0.5, random)
assert(nearby and geometry.segment(snapshot, origin, nearby, 0.5), "No safe nearby walking route")
local function folder(name, parent)
	local value = r.Instance.new("Folder")
	value.Name, value.Parent = name, parent
	return value
end
local plot = folder("Plot", storage)
tile.Parent = folder("Owned", folder("Land", plot))
local buildings = folder("Buildings", plot)
local placed = folder("Placed", buildings)
local construction = folder("Construction", buildings)
local function model(name, parent, base)
	local value = r.Instance.new("Model")
	value.Name, value.Parent = name, parent
	base.Parent = value
	return value
end
model("Bank", placed, building)
local road = part("Base", r.Vector3.new(5, 1.3, 0), r.Vector3.new(3, 0.2, 8))
model("RoadStraight", placed, road)
local unfinished = part("Base", r.Vector3.new(-5, 1.3, 0), r.Vector3.new(3, 0.2, 8))
model("RoadCorner", construction, unfinished)
local roads = geometry.snapshot(plot)
assert(#roads.walkways == 1 and #roads.obstacles == 2 and roads.count == 2)
assert(geometry.ground(roads, road.CFrame.Position, 0.5), "Finished road blocked civilians")
assert(not geometry.ground(roads, unfinished.CFrame.Position, 0.5), "Unfinished road must remain blocked")
assert(not geometry.ground(roads, building.CFrame.Position, 0.5), "Building must remain blocked")
local gap = {
	tiles = {
		part("Left", r.Vector3.new(-4, 1, 0), r.Vector3.new(4, 0.5, 8)),
		part("Right", r.Vector3.new(4, 1, 0), r.Vector3.new(4, 0.5, 8)),
	},
	obstacles = {},
}
assert(not geometry.segment(gap, r.Vector3.new(-4, 1, 0), r.Vector3.new(4, 1, 0), 0.5), "Path crossed unowned gap")

-- Execute the real scheduler with fake actors so counts/cleanup don't need physics.
local function signal()
	local list = {}
	return {
		Connect = function(_, fn)
			table.insert(list, fn)
		end,
		Fire = function(_, ...)
			for _, fn in list do
				fn(...)
			end
		end,
	}
end
local function node(t)
	t = t or {}
	function t:FindFirstChild(name)
		return self[name]
	end
	function t:GetAttribute(name)
		return self[name]
	end
	function t:SetAttribute(name, value)
		self[name] = value
	end
	function t:Destroy()
		self.Parent = nil
	end
	return t
end
local heartbeat, leaving = signal(), signal()
local players, plots = {}, node({})
for i = 1, 6 do
	players[i] = node({
		UserId = i,
		Parent = true,
		MyCityLoaded = true,
		Data = node({ PlotInfo = node({ Plot = { Value = i } }) }),
	})
	plots["Plot" .. i] = node({ CityId = i, count = 16, Parent = true })
end
local now, spawned, removed, steps = 0, 0, 0, 0
local fakeRig = {
	describe = function(template)
		return if template then { radius = 0.5 } else nil
	end,
	create = function(_, folder, owner)
		spawned += 1
		return { active = true, owner = owner, model = node({ Parent = folder }) }
	end,
	destroy = function(record)
		assert(record.active, "Double destruction")
		record.active = false
		record.model:Destroy()
		removed += 1
	end,
}
local services = {
	Players = {
		GetPlayers = function()
			return players
		end,
		PlayerRemoving = leaving,
	},
	ServerStorage = node({ Civilian = {} }),
	Workspace = node({ Plots = plots }),
	RunService = { Heartbeat = heartbeat },
}
local system = load("init", {
	script = {
		Config = config,
		Geometry = {
			snapshot = function(plot)
				return { count = plot.count }
			end,
			target = function()
				return r.Vector3.zero
			end,
		},
		Rig = fakeRig,
		Movement = {
			step = function()
				steps += 1
				return true
			end,
		},
	},
	require = function(module)
		return module
	end,
	game = {
		GetService = function(_, name)
			return services[name]
		end,
	},
	Instance = {
		new = function()
			return node({})
		end,
	},
	Random = {
		new = function()
			return random
		end,
	},
	os = {
		clock = function()
			return now
		end,
	},
	warn = function(...)
		error("Unexpected civilian warning")
	end,
})
system.init()
system.init()
local function tick()
	now += 1.1
	heartbeat:Fire(1.1)
end
for _ = 1, 6 do
	tick()
end
assert(spawned == 24 and removed == 0, "Duplicate start or incorrect global cap")
plots.Plot1.count = 0
tick()
assert(removed == 4 and spawned - removed <= 24, "Population failed to shrink")
players[2].MyCityLeaving = true
tick()
local before = removed
leaving:Fire(players[2])
leaving:Fire(players[2])
assert(removed == before, "Departure cleanup not idempotent")
plots.Plot3.CityId = 999
tick()
assert(spawned - removed <= 24)
-- No civilians may remain bound to a city reassigned to someone else.
local beforeSteps = steps
for _, player in players do
	player.MyCityLeaving = true
end
tick()
assert(spawned == removed and steps == beforeSteps)
print(
	"PASS: civilian count growth/shrink, fair server cap, duplicate start, owner departure/plot reuse; owned-land/obstacle/gap geometry; KingdomWars animation IDs"
)

-- Execute movement direct routes and asynchronous path cancellation.
local queue = {}
local pathCalls, animations, moveCalls = 0, {}, 0
local routeClear = true
local segmentChecks = 0
local destination = r.Vector3.new(5, 1.25, 0)
local movement = load("Movement", {
	script = {
		Parent = {
			Config = config,
			Geometry = {
				wander = function()
					return if routeClear then destination else nil
				end,
				target = function()
					return destination
				end,
				ground = function(_, point)
					return r.Vector3.new(point.X, 1.25, point.Z)
				end,
				segment = function()
					segmentChecks += 1
					return routeClear
				end,
			},
			Animations = {
				moving = function(_, value)
					table.insert(animations, value)
				end,
			},
		},
	},
	require = function(module)
		return module
	end,
	game = {
		GetService = function()
			return {
				CreatePath = function()
					pathCalls += 1
					return {
						ComputeAsync = function()
							coroutine.yield()
						end,
						Status = "Success",
						Destroy = function() end,
						GetWaypoints = function()
							return { { Position = r.Vector3.new(0, 1.25, 0) }, { Position = destination } }
						end,
					}
				end,
			}
		end,
	},
	Vector3 = r.Vector3,
	Enum = { PathStatus = { Success = "Success" } },
	os = {
		clock = function()
			return 10
		end,
	},
	task = {
		spawn = function(fn)
			local thread = coroutine.create(fn)
			table.insert(queue, thread)
			assert(coroutine.resume(thread))
		end,
	},
})
local function actor()
	return {
		active = true,
		model = { Parent = true },
		root = { Position = r.Vector3.new(0, 2, 0) },
		humanoid = {
			Health = 100,
			MoveTo = function()
				moveCalls += 1
			end,
		},
		radius = 0.5,
		height = 3,
		pauseUntil = 0,
	}
end
local city = { active = true, geometry = {} }
local record = actor()
assert(movement.step(record, city, 0, random) and record.path)
assert(movement.step(record, city, 0.1, random) and moveCalls == 1)
local checksAfterMove = segmentChecks
for _, timestamp in { 0.2, 0.3, 0.4, 0.5 } do
	movement.step(record, city, timestamp, random)
end
assert(segmentChecks == checksAfterMove, "Repeated segment scan between movement commands")
routeClear = false
movement.step(record, city, 0.6, random)
assert(not record.path, "New obstacle did not stop next movement command")
routeClear = true
record = actor()
movement.step(record, city, 0, random)
movement.step(record, city, 0.1, random)

movement.step(record, city, 3, random)
assert(not record.path and record.pauseUntil > 3, "Stuck NPC must stop/retry instead of walking forever")
for _, timestamp in { 3.3, 3.4, 6, 6.3, 6.4 } do
	assert(movement.step(record, city, timestamp, random))
end
assert(not movement.step(record, city, 9, random), "Repeatedly stuck civilian was never replaced")

record = actor()
record.humanoid.Sit, record.humanoid.PlatformStand = true, true
movement.step(record, city, 0, random)
movement.step(record, city, 0.1, random)
assert(not record.humanoid.Sit and not record.humanoid.PlatformStand)
assert(record.humanoid.WalkSpeed == config.WalkSpeed)
record.root.Position = r.Vector3.new(4.1, 2, 0)
assert(movement.step(record, city, 1, random))
assert(not record.path and record.pauseUntil < 2, "Normal Humanoid stopping distance was treated as stuck")
destination = r.Vector3.new(-3, 1.25, 0)
assert(movement.step(record, city, 2, random) and record.path, "Civilian did not resume walking after arrival")
assert(record.lastTravel == 1 and record.stuckRetries == 0, "Actual travel did not reset inactivity")
assert(
	not movement.step(record, city, 1 + config.MaxIdleSeconds, random),
	"Inactivity watchdog was reset by a new target"
)
routeClear = false
local old = actor()
movement.step(old, city, 10, random)
assert(old.computing and pathCalls == 1)
local waiting = actor()
movement.step(waiting, city, 10, random)
assert(pathCalls == 1, "Unbounded concurrent path computations")
old.active = false
routeClear = true
assert(coroutine.resume(queue[1]))
assert(not old.path, "Late path resurrected a departed NPC")
print("PASS: walking, idle/stuck recovery, bounded path computation, late-path cancellation")
