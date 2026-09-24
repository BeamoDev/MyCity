local fs, luau, r = require("@lune/fs"), require("@lune/luau"), require("@lune/roblox")
local function load(path, env)
	return luau.load(fs.readFile(path), { environment = env or {} })()
end
local env = { Vector3 = r.Vector3, CFrame = r.CFrame, Instance = r.Instance, Enum = r.Enum }
local Graph = load("src/server/systems/world/RoadTraffic/Graph.luau", env)
local Trip = load("src/shared/visuals/AmbientTrip.luau", {})
local V, C = r.Vector3.new, r.CFrame.new

local function child(parent, class, name)
	local v = r.Instance.new(class)
	v.Name, v.Parent = name, parent
	return v
end
-- Road piece: 10x10 Base; exits given in Base space (y = road surface).
local function road(name, at, yaw, exits, deadEnd)
	local model = r.Instance.new("Model")
	model.Name = name
	local base = child(model, "Part", "Base")
	base.Size, base.CFrame = V(10, 1, 10), C(at) * r.CFrame.Angles(0, math.rad(yaw or 0), 0)
	model.PrimaryPart = base
	for exitName, position in exits do
		child(base, "Attachment", exitName).CFrame = C(position)
	end
	if deadEnd then
		child(base, "Attachment", "DeadEnd").CFrame = C(deadEnd)
	end
	return model
end
local N, S, E, W = V(0, 0.5, -5), V(0, 0.5, 5), V(5, 0.5, 0), V(-5, 0.5, 0)
local a = road("A", V(0, 0, 0), 0, { Exit1 = N, Exit2 = S })
local b = road("B", V(0, 0, -10), 0, { Exit1 = N, Exit2 = S })
local turn = road("Turn", V(0, 0, -20), 0, { Exit2 = S, Exit3 = E })
local dead = road("Dead", V(10, 0, -20), 0, { Exit1 = W }, V(2, 0.5, 0))
local house = r.Instance.new("Model")
child(house, "Part", "Base")
assert(Graph.isRoad(a) and Graph.isRoad(dead) and not Graph.isRoad(house), "Road detection by Exit markers")

local pieces = Graph.build({ a, b, turn, dead })
local byName = {}
for _, piece in pieces do
	byName[piece.model.Name] = piece
	for _, exit in piece.exits do
		piece[exit.name] = exit
	end
end
assert(#byName.A.Exit1.links == 1 and byName.A.Exit1.links[1] == byName.B.Exit2, "Adjacent exits link")
assert(#byName.A.Exit2.links == 0, "Open road end has no link")
assert(byName.Turn.Exit3.links[1] == byName.Dead.Exit1, "Turn joins dead end")
assert(#Graph.onward(byName.A.Exit2) == 1 and Graph.onward(byName.A.Exit2)[1] == byName.A.Exit1, "No U-turn out of the entry edge")
assert(math.abs(byName.A.laneOffset - 1.5) < 1e-6, "Default lane offset is 15% of road width")
print("PASS: exit markers, linking by position, open ends, onward edges, default lane offset")

-- Straight: drive north (-Z) on the right-hand side (+X).
local out = {}
Graph.traverse(byName.A.Exit2, byName.A.Exit1, out)
local frames = Graph.frames(out, 0.5, 0)
assert(#frames == 2 and math.abs(frames[1].Position.X - 1.5) < 1e-4 and math.abs(frames[2].Position.X - 1.5) < 1e-4)
assert(math.abs(frames[1].Position.Y - 1) < 1e-4, "Lift raises the car from the road surface")
assert(frames[1].LookVector:Dot(V(0, 0, -1)) > 0.99, "Car faces its direction of travel")
-- Turn: curve stays inside the piece and bends toward the exit edge.
out = {}
Graph.traverse(byName.Turn.Exit2, byName.Turn.Exit3, out)
assert(#out == 5, "Turn is sampled as a curve")
for _, point in out do
	assert(math.abs(point.position.X) <= 5.01 and math.abs(point.position.Z + 20) <= 5.01, "Curve left the piece")
end
-- Dead end: out to the marker, U-turn, back to the entry edge.
out = {}
Graph.traverse(byName.Dead.Exit1, nil, out)
assert((out[#out].position - byName.Dead.Exit1.position).Magnitude < 1e-4 and out[3].turning, "Dead end turnaround")
print("PASS: right-hand straight lane, facing and lift, curved turns inside the piece, dead-end U-turn")

-- A whole trip is continuous (no teleports) across pieces, turns, dead ends and open road ends.
local seed = 0
local function random(low, high)
	seed = (seed * 1103515245 + 12345) % 2147483648
	return low + seed % (high - low + 1)
end
local largest = 0
for _ = 1, 40 do
	local trip = Graph.frames(Graph.plan(pieces, random, 12), 0.5, 0)
	for i = 2, #trip do
		local step = (trip[i].Position - trip[i - 1].Position).Magnitude
		largest = math.max(largest, step)
		-- One straight piece (10 studs, plus a lane-offset correction at joints) is the longest legitimate segment.
		assert(step <= 10 + 1.5, "Trip jumped between waypoints: " .. step)
	end
	assert(Graph.length(trip) > 10)
end
assert(largest > 9.9, "Expected at least one full straight segment")
print("PASS: 40 random trips stay continuous through links, turns, dead ends and open-end turnarounds")

-- Two-lane pieces: per-lane exits get no extra offset and cars keep to the right-hand lane.
local lanes = road("Highway", V(40, 0, 0), 0, {
	Exit = V(2, 0.5, 5),
	Exit1 = V(-2, 0.5, 5),
	Exit2 = V(2, 0.5, -5),
	Exit3 = V(-2, 0.5, -5),
})
local highway = Graph.build({ lanes })[1]
local lane = {}
for _, exit in highway.exits do
	lane[exit.name] = exit
end
assert(highway.laneOffset == 0, "Lane exits are already lanes")
local north = Graph.onward(lane.Exit)
assert(#north == 1 and north[1] == lane.Exit2, "Northbound keeps the right (+X) lane")
local south = Graph.onward(lane.Exit3)
assert(#south == 1 and south[1] == lane.Exit1, "Southbound keeps its right (-X) lane")
out = {}
Graph.traverse(lane.Exit, lane.Exit2, out)
assert(#out == 2, "Straight lane is a straight line, not a curve through the centre")
lanes:SetAttribute("LaneOffset", 0.75)
assert(Graph.build({ lanes })[1].laneOffset == 0.75, "Authored LaneOffset override")
print("PASS: per-lane exits, right-hand lane choice both directions, straight lanes, LaneOffset override")

-- Rotated pieces link correctly (a road placed at 90 degrees).
local rotated = road("Rot", V(0, 0, 10), 90, { Exit1 = N, Exit2 = S }) -- runs along X after rotation
local rotatedPiece = Graph.build({ rotated })[1]
for _, exit in rotatedPiece.exits do
	assert(math.abs(exit.position.Z - 10) < 1e-4, "Rotated exits follow the Base")
end

-- Client path maths: constant speed, clamped ends, finished flag.
local descriptor = r.Instance.new("Folder")
descriptor:SetAttribute("Points", 3)
descriptor:SetAttribute("P1", C(0, 0, 0))
descriptor:SetAttribute("P2", C(10, 0, 0))
descriptor:SetAttribute("P3", C(10, 0, 30))
local path = Trip.readPath(descriptor)
assert(path and path.total == 40)
local mid, done = Trip.along(path, 4, 0, 1)
assert(not done and (mid.Position - V(10, 0, 0)).Magnitude < 1e-4, "Quarter time is a quarter of the distance")
local later = Trip.along(path, 4, 0, 3)
assert((later.Position - V(10, 0, 20)).Magnitude < 1e-4)
local final, finished = Trip.along(path, 4, 0, 9)
assert(finished and (final.Position - V(10, 0, 30)).Magnitude < 1e-4)
descriptor:SetAttribute("Points", nil)
assert(Trip.readPath(descriptor) == nil, "Straight trips keep the First/Last path")
print("PASS: rotated pieces, client constant-speed waypoint interpolation and legacy straight trips")

-- Exit attachments authored directly under the road Model move onto Base with their world position.
local Templates = load("src/server/services/BuildingTemplates.luau", {
	Instance = r.Instance,
	Vector3 = r.Vector3,
	CFrame = r.CFrame,
	Enum = r.Enum,
	warn = function() end,
})
local authored = r.Instance.new("Model")
authored.Name = "RoadStraight"
local authoredBase = child(authored, "Part", "Base")
authoredBase.Size, authoredBase.CFrame = V(10, 1, 10), C(100, 0, 100)
authored.PrimaryPart = authoredBase
local marker = child(authored, "Attachment", "Exit1")
marker.CFrame = C(100, 0.5, 95)
Templates.prepare(authored, nil)
assert(marker.Parent == authoredBase, "Exit not re-homed onto Base")
assert(((authoredBase.CFrame * marker.CFrame).Position - V(100, 0.5, 95)).Magnitude < 1e-4, "Exit moved")
local placed = authored:Clone()
placed.PrimaryPart.CFrame = C(0, 0, 0) * r.CFrame.Angles(0, math.rad(90), 0)
local moved = placed.Base.Exit1
local world = (placed.Base.CFrame * moved.CFrame).Position
assert((world - V(-5, 0.5, 0)).Magnitude < 1e-4, "Exit did not follow a placed, rotated copy: " .. tostring(world))
print("PASS: model-level Exit attachments are re-homed onto Base and follow placed/rotated copies")

-- Highway cars visiting a city through PlotCutOffs slip roads.
local world = r.Instance.new("Folder")
local plotsFolder = child(world, "Folder", "Plots")
local plot1 = child(plotsFolder, "Folder", "Plot1")
local landTile = child(child(plot1, "Folder", "Land"), "Part", "Tile1")
landTile.Size, landTile.CFrame = V(40, 1, 20), C(0, 0, 15)
local cutoffs = child(child(world, "Folder", "Map"), "Folder", "PlotCutOffs")
local cutoff = child(cutoffs, "Model", "Plot1")
for name, position in {
	EnterPlot = V(-10, 0.5, 49),
	EnterPlot1 = V(-10, 0.5, 40),
	EnterPlot2 = V(-10, 0.5, 31),
	ExitPlot2 = V(10, 0.5, 31),
	ExitPlot1 = V(10, 0.5, 40),
	ExitPlot = V(10, 0.5, 55),
} do
	child(cutoff, "Attachment", name).CFrame = C(position)
end
-- Player roads: up from EnterPlot2, across, and back down to ExitPlot2 (ends within 6 studs).
local cityRoads = {
	road("In", V(-10, 0, 25), 0, { Exit1 = N, Exit2 = S }),
	road("TurnW", V(-10, 0, 15), 0, { Exit1 = S, Exit2 = E }),
	road("Across", V(0, 0, 15), 0, { Exit1 = W, Exit2 = E }),
	road("TurnE", V(10, 0, 15), 0, { Exit1 = W, Exit2 = S }),
	road("Out", V(10, 0, 25), 0, { Exit1 = N, Exit2 = S }),
}
local cityState = { pieces = Graph.build(cityRoads) }
local warnings = 0
local visitsContext = {
	Graph = Graph,
	Config = { VisitChance = 1, ConnectDistance = 6, ConnectHeight = 6, HighwayReach = 12 },
	-- Lune returns a new handle per lookup, so match instances by == (Roblox handles are unique).
	cities = setmetatable({}, { __index = function(_, key)
		return if key == plot1 then cityState else nil
	end }),
	groundAt = function(position)
		return position.Y
	end,
	liftOf = function()
		return 0.5
	end,
}
luau.load(fs.readFile("src/server/systems/world/RoadTraffic/Visits.luau"), {
	environment = {
		Vector3 = r.Vector3,
		CFrame = r.CFrame,
		game = { GetService = function()
			return world
		end },
		warn = function()
			warnings += 1
		end,
	},
})()(visitsContext)
local routeA, routeB = {}, {}
local eastbound = { route = routeA, first = C(-100, 1, 50) * r.CFrame.Angles(0, math.rad(-90), 0), last = C(100, 1, 50) * r.CFrame.Angles(0, math.rad(-90), 0) }
local westbound = { route = routeB, first = C(100, 1, 56) * r.CFrame.Angles(0, math.rad(90), 0), last = C(-100, 1, 56) * r.CFrame.Angles(0, math.rad(90), 0) }
local trips = { eastbound, westbound }
local visit = assert(visitsContext.divert(eastbound, trips, nil), "Connected city was not visited")
assert(visit[1] == eastbound.first and visit[#visit] == westbound.last, "Visit starts on and rejoins the highway")
assert((visit[2].Position - V(-10, 1, 50)).Magnitude < 1e-3, "Turns off where EnterPlot meets the lane")
assert((visit[#visit - 1].Position - V(10, 1, 56)).Magnitude < 1e-3, "Rejoins where ExitPlot meets the other lane")
local function nearest(point)
	local bestIndex, bestDistance = nil, math.huge
	for index, frame in visit do
		local d = (frame.Position - point).Magnitude
		if d < bestDistance then
			bestIndex, bestDistance = index, d
		end
	end
	return bestIndex, bestDistance
end
local order = {}
for _, point in { V(-10, 1, 40), V(-10, 1, 31), V(-5, 1, 15), V(10, 1, 31), V(10, 1, 40) } do
	local index, distance = nearest(point)
	assert(distance < 2.1, "Visit missed a slip-road or city waypoint")
	table.insert(order, index)
end
for i = 2, #order do
	assert(order[i] > order[i - 1], "Visit waypoints out of order")
end
-- Visiting cars keep the highway's model orientation relative to their heading.
local index = nearest(V(-10, 1, 40))
assert(math.abs(visit[index].RightVector:Dot(V(0, 0, -1))) < 0.2, "Slip-road frame lost the highway orientation")
assert((visitsContext.correction * r.CFrame.new()).Position.Magnitude < 1e-6, "Correction is rotation only")
-- The other carriageway does not turn off here; a gap in the player's roads means no visit.
assert(visitsContext.divert(westbound, trips, nil) == nil, "Wrong carriageway turned off")
cityState.pieces = Graph.build({ cityRoads[1], cityRoads[2], cityRoads[3], cityRoads[4] })
assert(visitsContext.divert(eastbound, trips, nil) == nil, "Unconnected exit still visited")
cityState.pieces = {}
assert(visitsContext.divert(eastbound, trips, nil) == nil and warnings == 0)
-- Builder-facing status explains each missing link.
local plotRef = { Name = "Plot1" }
cityState.pieces = Graph.build(cityRoads)
assert(visitsContext.status(plotRef, cityState):find("connected"), visitsContext.status(plotRef, cityState))
cityState.pieces = Graph.build({ cityRoads[1], cityRoads[2], cityRoads[3], cityRoads[4] })
local message = visitsContext.status(plotRef, cityState)
assert(message:find("plot end of ExitPlot") and message:find("studs"), message)
cityState.pieces = Graph.build({ cityRoads[1], cityRoads[5] })
assert(visitsContext.status(plotRef, cityState):find("not joined"), visitsContext.status(plotRef, cityState))
cityState.pieces = {}
assert(visitsContext.status(plotRef, cityState) == "no roads built in this plot")
assert(visitsContext.status({ Name = "Plot9" }, cityState) == nil, "Plots without cutoffs report nothing")
-- The user's naming (EnterPlot1-3 / ExitPlot1-3, any numbering) orders itself by distance from the plot.
for _, attachment in cutoff:GetChildren() do
	attachment:Destroy()
end
for name, position in {
	EnterPlot3 = V(-10, 0.5, 49), -- numbering deliberately not in driving order
	EnterPlot1 = V(-10, 0.5, 40),
	EnterPlot2 = V(-10, 0.5, 31),
	ExitPlot1 = V(10, 0.5, 31),
	ExitPlot3 = V(10, 0.5, 40),
	ExitPlot2 = V(10, 0.5, 55),
} do
	child(cutoff, "Attachment", name).CFrame = C(position)
end
cityState.pieces = Graph.build(cityRoads)
visit = assert(visitsContext.divert(eastbound, trips, nil), "Numbered markers were not used")
local lastIndex = 0
for _, point in { V(-10, 1, 40), V(-10, 1, 31), V(10, 1, 31), V(10, 1, 40) } do
	local index, distance = nearest(point)
	assert(distance < 2.1 and index > lastIndex, "Numbered markers driven out of order")
	lastIndex = index
end
assert((visit[2].Position - V(-10, 1, 50)).Magnitude < 1e-3 and (visit[#visit - 1].Position - V(10, 1, 56)).Magnitude < 1e-3)
assert(visitsContext.status(plotRef, cityState):find("connected"))
print("PASS: highway car turns off at EnterPlot, EnterPlot1/2, tours connected player roads, ExitPlot2/1, rejoins at ExitPlot; carriageway and connection checks")

-- Roads have no level system; every other building keeps it.
local categories = {}
for _, name in { "Decorations", "Starter", "Population", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" } do
	categories[name] = load("src/server/config/BuildingConfig/" .. name .. ".luau", {})
end
local catalogue = luau.load(fs.readFile("src/server/config/BuildingConfig/init.luau"), {
	environment = { script = categories, require = function(module)
		return module
	end },
})()
local roads = 0
for name, definition in catalogue do
	if name:match("^Road") then
		roads += 1
		assert(definition.NoLevels, name .. " still has levels")
	else
		assert(not definition.NoLevels, name .. " lost its levels")
	end
end
assert(roads == 8, "Expected all 8 road pieces")
print("PASS: all 8 road pieces are tagged NoLevels; other buildings keep levels")

-- Car variety: same-named models and sub-folders each get a unique id the client can resolve.
local AmbientModel = load("src/shared/visuals/AmbientModel.luau", {})
local cars = r.Instance.new("Folder")
cars.Name = "CarTemplates"
local function car(parent, name)
	local model = child(parent, "Model", name)
	child(model, "Part", "Body")
	child(child(model, "Model", "Wheel"), "Part", "Tyre") -- nested part of the car, not a car
	return model
end
local red, blue = car(cars, "Car"), car(cars, "Car")
local truck = car(child(cars, "Folder", "Trucks"), "Truck")
local found = AmbientModel.templates(cars)
assert(#found == 3, "Expected 3 vehicles, got " .. #found)
local ids = {}
for _, model in found do
	local id = model:GetAttribute("TemplateId")
	assert(id and not ids[id], "Vehicle ids must be unique")
	ids[id] = true
end
assert(AmbientModel.find(cars, blue:GetAttribute("TemplateId"), "Car") == blue, "Same-named car resolved to the wrong model")
assert(AmbientModel.find(cars, truck:GetAttribute("TemplateId"), "Truck") == truck, "Sub-folder vehicle not found")
assert(AmbientModel.find(cars, nil, "Car") == red, "Old trips still resolve by name")
print("PASS: every car model is selectable (duplicate names, sub-folders, nested parts) and clients clone the chosen one")

-- Plot roads higher than the slip-road markers still connect; the car ramps up smoothly.
local rampRoads = {}
for index, roadModel in cityRoads do
	local copy = roadModel:Clone()
	copy.PrimaryPart.CFrame = copy.PrimaryPart.CFrame + V(0, 8, 0)
	rampRoads[index] = copy
end
cityState.pieces = Graph.build(rampRoads)
visitsContext.Config.ConnectHeight = 40
local ramp = assert(visitsContext.divert(eastbound, trips, nil), "Raised plot roads did not connect")
local climbed = false
for i = 2, #ramp do
	local rise = ramp[i].Position.Y - ramp[i - 1].Position.Y
	climbed = climbed or rise > 0.5
	assert(math.abs(rise) <= 8.01, "Car jumped vertically instead of ramping")
end
assert(climbed, "Car never climbed to the raised roads")
print("PASS: plot roads 8 studs above the slip road connect and cars ramp up and back down")

-- Exit attachments whose stored CFrame is still relative to a part (made inside Base, then dragged
-- under the Model) must not collapse onto the world origin.
local relative = r.Instance.new("Model")
relative.Name = "RoadStraight2"
local relativeBase = child(relative, "Part", "Base")
relativeBase.Size, relativeBase.CFrame = V(10, 1, 10), C(300, 0, -200)
relative.PrimaryPart = relativeBase
child(relative, "Attachment", "Exit1").CFrame = C(0, 0.5, -5)
child(relative, "Attachment", "Exit2").CFrame = C(0, 0.5, 5)
Templates.prepare(relative, nil)
for _, name in { "Exit1", "Exit2" } do
	local world = (relativeBase.CFrame * relativeBase[name].CFrame).Position
	assert((world - V(300, 0.5, -200)).Magnitude <= 5.1, name .. " resolved away from its road piece: " .. tostring(world))
end
-- Two placed copies end to end: one shared link, two open road ends.
local pieceA, pieceB = relative:Clone(), relative:Clone()
pieceA.PrimaryPart.CFrame = C(0, 0, 0)
pieceB.PrimaryPart.CFrame = C(0, 0, -10)
local joined = Graph.build({ pieceA, pieceB })
local open = 0
for _, piece in joined do
	for _, exit in piece.exits do
		open += if #exit.links == 0 then 1 else 0
	end
end
assert(open == 2, "Expected two open road ends, got " .. open)
print("PASS: part-relative Exit attachments resolve onto their road piece; joined roads keep open ends")

-- Pieces side by side (edges parallel, ends close) must not join; end-to-end pieces must.
local sideA = road("SideA", V(500, 0, 0), 90, { Exit1 = N, Exit2 = S }) -- runs along X
local sideB = road("SideB", V(500, 0, 2), 90, { Exit1 = N, Exit2 = S }) -- parallel, 2 studs over
local sidePieces = Graph.build({ sideA, sideB })
for _, piece in sidePieces do
	for _, exit in piece.exits do
		assert(#exit.links == 0, "Side-by-side pieces were joined at " .. exit.name)
	end
end
local lineA = road("LineA", V(600, 0, 0), 0, { Exit1 = N, Exit2 = S })
local lineB = road("LineB", V(600, 0, -10), 0, { Exit1 = N, Exit2 = S })
local open, joinedEnds = 0, 0
for _, piece in Graph.build({ lineA, lineB }) do
	for _, exit in piece.exits do
		if #exit.links == 0 then
			open += 1
		else
			joinedEnds += 1
		end
	end
end
assert(open == 2 and joinedEnds == 2, "End-to-end pieces should share one join and keep two open ends")
print("PASS: road ends join only when facing each other; side-by-side pieces stay separate")
