local fs, luau, r = require("@lune/fs"), require("@lune/luau"), require("@lune/roblox")
local function load(path, env)
	return luau.load(fs.readFile(path), { environment = env })()
end
local function item(class, name, parent)
	local object = r.Instance.new(class)
	object.Name, object.Parent = name, parent
	return object
end
local calls = {}
r.implementMethod("Model", "GetPivot", function(model)
	return model.PrimaryPart.CFrame * (model:GetAttribute("TestPivot") or r.CFrame.identity)
end)
r.implementMethod("Model", "PivotTo", function(model, cf)
	local delta = cf * model:GetPivot():Inverse()
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CFrame = delta * part.CFrame
		end
	end
	model:SetAttribute("TestMoves", (model:GetAttribute("TestMoves") or 0) + 1)
end)
local now = 100
r.implementMethod("Workspace", "GetServerTimeNow", function()
	return now
end)
local world = item("Workspace", "Workspace")
local map = item("Folder", "Map", world)
local environment = item("Folder", "Enviorment", map)
local rep = item("Folder", "ReplicatedStorage")
local assets = item("Folder", "Assets", rep)
local function setup(name, folderName, templateName, definitions)
	local system = item("Folder", name, environment)
	local points = item("Folder", "Points", system)
	for _, def in definitions do
		local point = item("Part", def[1], points)
		point.Position = def[2]
		point.CFrame = r.CFrame.new(def[2])
	end
	local folder = item("Folder", folderName, assets)
	local model = item("Model", templateName, folder)
	local root = item("Part", "Base", model)
	root.CFrame = r.CFrame.new(0, 3, 0)
	root.Anchored = false
	local car = item("Part", "Carriage", model)
	car.CFrame = r.CFrame.new(0, 3, 12)
	car.Anchored = false
	model.PrimaryPart = root
	model:SetAttribute("TestPivot", r.CFrame.new(0, 0, 2))
	item("Script", "OldMover", model)
	item("ProximityPrompt", "OldPrompt", root)
	return system, model
end
local trains, original = setup("TrainSystem", "Trains", "Train", {
	{ "Point3", r.Vector3.new(0, 0, 0) },
	{ "Point4", r.Vector3.new(0, 0, 200) },
	{ "Point1", r.Vector3.new(10, 0, 0) },
	{ "Point2", r.Vector3.new(10, 0, 200) },
})
local road = setup("RoadSystem", "CarTemplates", "Car", {
	{ "Point3", r.Vector3.new(20, 0, 0) },
	{ "Point4", r.Vector3.new(20, 0, 200) },
	{ "Point6", r.Vector3.new(30, 0, 200) },
	{ "Point5", r.Vector3.new(30, 0, 0) },
})
local subscriptions, callback = 0, nil
local heartbeat = {
	Connect = function(_, fn)
		subscriptions += 1
		callback = fn
		return {
			Disconnect = function()
				subscriptions -= 1
				callback = nil
			end,
		}
	end,
}
local env = {
	Instance = r.Instance,
	CFrame = r.CFrame,
	Vector3 = r.Vector3,
	require = function(m)
		return m
	end,
	game = {
		GetService = function(_, name)
			return ({ RunService = { Heartbeat = heartbeat }, Workspace = world, ReplicatedStorage = rep })[name]
		end,
	},
}
local path = "src/server/systems/world/AmbientTraffic/"
local modelModule = load("src/shared/visuals/AmbientModel.luau", env)
local routes = load(path .. "Routes.luau", env)
env.script = { Model = modelModule, Routes = routes }
local traffic = load(path .. "init.luau", env)
local diverts = 0
-- City visits are covered by test_road_traffic; here highway cars always stay on the highway.
local roadTraffic = { divert = function(current, trips)
	assert(current and #trips == 2 and current.first and current.last, "Divert got the car's trips")
	diverts += 1
	return nil
end }
env.script = { Parent = { AmbientTraffic = traffic, RoadTraffic = roadTraffic } }
local train = load("src/server/systems/world/TrainSystem.luau", env)
local cars = load("src/server/systems/world/HighwayTrafficSystem.luau", env)
train.init()
cars.init()
train.init()
cars.init()
assert(subscriptions == 1, "Duplicate/per-vehicle movement connections")
local tripMath = load("src/shared/visuals/AmbientTrip.luau", {})
local function tick(dt)
	now += dt
	callback(dt)
end
local function list(kind)
	local result = {}
	for _, entry in rep.Runtime.AmbientTraffic:GetChildren() do
		assert(entry:IsA("Folder") and #entry:GetChildren() == 0, "Server replicated vehicle geometry")
		if entry:GetAttribute("TemplateFolder") == kind then
			table.insert(result, entry)
		end
	end
	return result
end
tick(0)
assert(#list("Trains") == 1 and #list("CarTemplates") == 1)
local descriptor = list("Trains")[1]
local first, last = descriptor:GetAttribute("First"), descriptor:GetAttribute("Last")
local started, duration = descriptor:GetAttribute("Started"), descriptor:GetAttribute("Duration")
local active, pivot = modelModule.create(original, world, first)
assert(not active:FindFirstChild("OldMover") and not active.Base:FindFirstChild("OldPrompt"))
assert(original:FindFirstChild("OldMover") and not original.Base.Anchored)
local offset = active.Base.CFrame:ToObjectSpace(active.Carriage.CFrame)
local start = active.Base.CFrame
for i = 1, 120 do
	tick(1 / 60)
	local target, finished = tripMath.position(first, last, duration, started, now)
	assert(not finished)
	active:PivotTo(target * pivot)
	local current = active.Base.CFrame:ToObjectSpace(active.Carriage.CFrame)
	assert((current.Position - offset.Position).Magnitude < 0.001, "Train carriages drifted")
end
assert(active:GetAttribute("TestMoves") == 121)
assert(math.abs((active.Base.CFrame.Position - start.Position).Magnitude - 10) < 0.01)
assert(descriptor:GetAttribute("First") == first and descriptor:GetAttribute("Started") == started)
local halfway = tripMath.position(first, last, duration, started, started + duration / 2)
assert((halfway.Position - first:Lerp(last, 0.5).Position).Magnitude < 0.001, "Late join restarted the route")
local _, expired = tripMath.position(first, last, duration, started, started + duration + 10)
assert(expired)
assert(tripMath.position(first, last, 0, started, now) == nil)
assert(tripMath.position(first, last, 0 / 0, started, now) == nil)
for _, part in active:GetDescendants() do
	if part:IsA("BasePart") then
		assert(part.Anchored and not part.CanCollide and not part.CanQuery and not part.CanTouch)
	end
end
for _ = 1, 180 do
	tick(1)
	assert(#list("Trains") <= 2 and #list("CarTemplates") <= 25)
end
tick(500)
assert(#list("Trains") <= 1 and #list("CarTemplates") <= 1)
train.stop()
assert(subscriptions == 1 and #list("Trains") == 0)
cars.stop()
assert(subscriptions == 0 and #list("CarTemplates") == 0)
train.init()
tick(0)
assert(#list("Trains") == 1 and subscriptions == 1)
train.stop()
assert(subscriptions == 0)
assert(diverts > 0, "Highway spawns never offered a city visit")
print(
	"PASS: server sends immutable trips only; client rigid motion, late join, expiry, sanitizing, route caps, delayed frames and restart cleanup"
)
