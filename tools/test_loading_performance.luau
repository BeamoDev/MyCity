local fs = require("@lune/fs")
local luau = require("@lune/luau")
local r = require("@lune/roblox")
local function load(path, env)
	return luau.load(fs.readFile(path), { environment = env or {} })()
end
local function node(values)
	local obj = values or {}
	function obj:FindFirstChild(name)
		if rawget(self, name) then
			return rawget(self, name)
		end
		for _, child in self.children or {} do
			if child.Name == name then
				return child
			end
		end
	end
	function obj:WaitForChild(name)
		return assert(self:FindFirstChild(name), name)
	end
	function obj:GetChildren()
		return self.children or {}
	end
	function obj:GetAttribute(key)
		return self[key]
	end
	function obj:SetAttribute(key, value)
		self[key] = value
	end
	function obj:IsA(class)
		return self.ClassName == class
	end
	return obj
end
local function module(path)
	return setmetatable({ path = path }, {
		__index = function(self, key)
			if key == "Parent" then
				return module(self.path:match("^(.*)/[^/]+$"))
			end
			if key == "WaitForChild" then
				return function(_, name)
					return module(self.path .. "/" .. name)
				end
			end
			return module(self.path .. "/" .. key)
		end,
	})
end
-- Shared budget counts work from multiple players, and enforces time as well as object limits.
local now, frames, reset = 0, 0, nil
local heartbeat = {
	Connect = function(_, fn)
		reset = fn
	end,
	Wait = function()
		frames += 1
		now += 1 / 60
		reset()
	end,
}
local budget = load("src/server/services/RestoreBudget.luau", {
	game = {
		GetService = function()
			return { Heartbeat = heartbeat }
		end,
	},
	os = {
		clock = function()
			return now
		end,
	},
})
local player, other = node({ Parent = true }), node({ Parent = true })
for i = 1, 600 do
	budget.checkpoint(if i % 2 == 0 then player else other)
end
assert(frames == 99, "Simultaneous joins bypassed shared object budget")
reset()
budget.checkpoint(player)
now += 0.004
budget.checkpoint(player)
assert(frames == 100, "Slow work did not yield")
player.MyCityLeaving = true
assert(not pcall(budget.checkpoint, player), "Departure must stop restoration")
player.MyCityLeaving = nil
print("PASS: shared restoration budget across 600 operations, time budget and departure cancellation")

-- Real BuildingData restores all saved metadata, prepares before publishing and performs no city income scans.
local entries, created = {}, {}
local placed = node({ Name = "Placed" })
local plot =
	node({ Name = "Plot6", Buildings = node({ Placed = placed }), Center = { Position = r.Vector3.new(50, 0, 20) } })
local plots = node({ Plot6 = plot })
local template = node({ PrimaryPart = true })
function template:Clone()
	local clone = node({})
	function clone:SetPrimaryPartCFrame(cf)
		self.cf = cf
	end
	table.insert(created, clone)
	return clone
end
local models = node({ Bank = template })
local rep = { Assets = node({}) }
local services =
	{ Workspace = node({ Plots = plots }), ReplicatedStorage = rep, ServerStorage = node({ Buildings = models }) }
local data = node({ CurrentBuildings = node({ children = entries }), PlotInfo = node({ Plot = { Value = 6 } }) })
player.Data = data
for i = 1, 100 do
	entries[i] = node({ Name = "Bank_" .. i, ClassName = "StringValue", Value = "2,1.25,4,0,180,0,100,20,2500,true" })
end
local checkpoints, incomeScans = 0, 0
local deps = {
	["server/services/RestoreBudget"] = {
		checkpoint = function(p)
			budget.checkpoint(p)
			checkpoints += 1
		end,
	},
	["server/config/BuildingConfig"] = { Bank = {} },
	["server/systems/building/BuildingSystem/BuildingConfig"] = {
		setupBuildingConfig = function(b, kind, level, xp)
			assert(b.Parent == nil)
			b.Config = { level = level, xp = xp }
			assert(kind == "Bank")
		end,
	},
	["server/systems/building/BuildingSystem/BuildingPrompts"] = {
		addBuildingPrompts = function(b)
			assert(b.Parent == nil and b.Config, "Replicated incomplete building")
		end,
	},
	["server/systems/building/BuildingSystem/BuildingXP"] = {
		startBuildingXPLoop = function(b)
			assert(b.Parent == placed and b.BuildingID and b.Config)
		end,
	},
	["server/systems/world/WeatherSystem"] = { updateNewBuilding = function() end },
	["server/systems/economy/IncomeSystem"] = {
		calculateAndStackBuildingIncome = function()
			incomeScans += 1
		end,
	},
}
local buildingData = load("src/server/systems/building/BuildingSystem/BuildingData.luau", {
	script = module("server/systems/building/BuildingSystem/BuildingData"),
	game = {
		GetService = function(_, name)
			return assert(services[name], name)
		end,
	},
	require = function(token)
		return assert(deps[token.path], token.path)
	end,
	Vector3 = r.Vector3,
	CFrame = r.CFrame,
	task = {
		wait = function()
			error("Fixed restoration delay")
		end,
	},
})
buildingData.loadPlayerBuildings(player)
assert(#created == 100 and checkpoints == 100 and incomeScans == 0)
for i, building in created do
	assert(building.BuildingID == tostring(i) and building.BuildingType == "Bank" and building.RobuxBuilding)
	assert(building.Config.level == 20 and building.Config.xp == 2500)
	assert((building.cf.Position - r.Vector3.new(48, 1.25, 16)).Magnitude < 0.001)
	assert(entries[i].Value == "2,1.25,4,0,180,0,100,20,2500,true", "Rewrote valid saved data")
end
models.Bank = nil
assert(not pcall(buildingData.loadPlayerBuildings, player), "Missing authored model must fail safely")
models.Bank = template
player.MyCityLeaving = true
local before = #created
assert(not pcall(buildingData.loadPlayerBuildings, player) and #created == before)
print(
	"PASS: 100 restored buildings preserve mirrored placement/IDs/paid status/XP; zero per-building income scans; missing asset and departure stop safely"
)

-- Real construction restoration preserves active timers and converts offline completions once.
player.MyCityLeaving = nil
local constructionEntries = {}
for i = 1, 10 do
	local entry = node({
		Name = "Bank_site" .. i,
		ClassName = "StringValue",
		Value = (if i <= 5 then "30" else "300") .. ",2,1.25,4,0,180,0,4x4,100,12,200,true",
	})
	function entry:Destroy()
		self.destroyed = true
	end
	constructionEntries[i] = entry
end
player.Data.CurrentConstructions = node({ children = constructionEntries })
plot.Buildings.Construction = node({ Name = "Construction" })
rep.Assets.Constructions = node({ ["4x4"] = template })
local started, saved, builderUpdates, milestones = 0, 0, 0, 0
local base = "server/systems/building/BuildingSystem/"
deps["server/systems/building/BuildingSystem"] = {
	setupBuildingConfig = deps[base .. "BuildingConfig"].setupBuildingConfig,
	addBuildingPrompts = deps[base .. "BuildingPrompts"].addBuildingPrompts,
	startBuildingXPLoop = deps[base .. "BuildingXP"].startBuildingXPLoop,
	saveBuildingData = function(p, id, kind, cf, assigned, level, xp, paid)
		saved += 1
		assert(id == "site" .. saved and kind == "Bank" and assigned == plot)
		assert(level == 12 and xp == 200 and paid and cf.Position.X == 48)
	end,
}
deps["server/systems/construction/ConstructionSystem/ConstructionTimer"] = {
	startConstructionTimer = function(
		p,
		assigned,
		site,
		final,
		total,
		remaining,
		restoring,
		tutorial,
		level,
		xp,
		_,
		_,
		_,
		paid
	)
		started += 1
		assert(remaining == 200 and restoring and not tutorial and paid and level == 12 and xp == 200)
		assert(site.Parent == plot.Buildings.Construction and site.ConstructionID == "site" .. (started + 5))
	end,
}
deps["server/systems/construction/ConstructionSystem/ConstructionBuilder"] = {
	updateBuilderCount = function()
		builderUpdates += 1
	end,
}
deps["server/systems/progression/TutorialSystem"] = {
	handleConstructionComplete = function()
		milestones += 1
	end,
}
local constructionContext = { State = {}, ConstructionData = {}, ReplicatedStorage = rep, plotsFolder = plots }
local constructionPath = "src/server/systems/construction/ConstructionSystem/ConstructionData/"
local constructionEnv = {
	game = {
		GetService = function(_, name)
			return assert(services[name], name)
		end,
	},
	Vector3 = r.Vector3,
	CFrame = r.CFrame,
	os = {
		time = function()
			return 200
		end,
	},
	script = module("server/systems/construction/ConstructionSystem/ConstructionData/Restoration"),
	require = function(token)
		return assert(deps[token.path], token.path)
	end,
	task = {
		wait = function()
			error("Fixed construction restoration delay")
		end,
	},
}
load(constructionPath .. "Serialization.luau", constructionEnv)(constructionContext)
load(constructionPath .. "Coordinates.luau", constructionEnv)(constructionContext)
load(constructionPath .. "Restoration.luau", constructionEnv)(constructionContext)
local beforeConstructionCheckpoints = checkpoints
constructionContext.ConstructionData.loadPlayerConstructions(player)
assert(
	saved == 5
		and started == 5
		and milestones == 5
		and builderUpdates == 1
		and checkpoints == beforeConstructionCheckpoints + 10
		and incomeScans == 0
)
for i, entry in constructionEntries do
	assert((entry.destroyed == true) == (i <= 5))
end
print(
	"PASS: active/offline-completed construction restore preserves IDs/paid status/XP/timing; one builder finalization, no income rescans or fixed delay"
)

-- Compare actual optimized stat modules with the strongest effective coverage formulas.
local statsPath = "src/server/systems/building/BuildingSystem/BuildingStats/"
local snapshotModule = load(statsPath .. "Snapshot.luau")
local ranges = { Clinic = 20, Hospital = 30, SheriffOffice = 20, PoliceStation = 30, FireShed = 20, FireStation = 30 }
local catalog = { Tree = { IsDecoration = true } }
local buildings, scans = {}, 0
local statsPlot = node({ Buildings = node({ Placed = node({}) }) })
function statsPlot.Buildings.Placed:GetChildren()
	scans += 1
	return buildings
end
local function value(n)
	return { Value = n }
end
for i = 1, 1000 do
	local kinds = { "Clinic", "Hospital", "SheriffOffice", "PoliceStation", "FireShed", "FireStation", "Tree" }
	local kind = if i <= #kinds then kinds[i] else "Bank"
	buildings[i] = node({
		Parent = true,
		BuildingType = kind,
		PrimaryPart = { Position = r.Vector3.new((i * 7) % 100, 0, (i * 13) % 100) },
		Config = node({
			BuildingLevel = value(i % 20 + 1),
			BuildingXP = value(0),
			Health = value(100),
			CrimePercent = value(0),
			FireSafetyPercent = value(0),
			HealthPercent = value(0),
			HappinessPercent = value(0),
		}),
	})
end
local ctx = {
	State = {},
	BuildingStats = {},
	BUILDING_RANGES = ranges,
	Snapshot = snapshotModule,
	BASE_CRIME_RATE = 0,
	MAX_CRIME_RATE = 85,
	BASE_HAPPINESS = 75,
	BASE_FIRE_SAFETY = 80,
	MIN_FIRE_SAFETY = 20,
	DECORATION_HAPPINESS_RANGE = 30,
	DECORATION_HAPPINESS_BOOST = 15,
	createSnapshot = function(p)
		return snapshotModule.create(p, catalog, ranges)
	end,
}
for _, name in { "Health", "Safety", "Happiness", "Aggregation" } do
	load(statsPath .. name .. ".luau")(ctx)
end
local function expected(position, a, b, inside, outside)
	local ratio = 1
	for _, building in buildings do
		if building.BuildingType == a or building.BuildingType == b then
			local distance = (position - building.PrimaryPart.Position).Magnitude
			local radius = ranges[building.BuildingType]
			ratio = math.min(ratio, math.clamp((distance - radius) / (radius * 2), 0, 1))
		end
	end
	return math.floor(inside + (outside - inside) * ratio)
end
local statCheckpoints = 0
ctx.BuildingStats.updatePlotStats(statsPlot, function()
	statCheckpoints += 1
end)
assert(scans == 1 and statCheckpoints == 1000, "Repeated city snapshots")
for _, building in buildings do
	local p, c = building.PrimaryPart.Position, building.Config
	local crime = expected(p, "PoliceStation", "SheriffOffice", 0, 85)
	local fire = expected(p, "FireStation", "FireShed", 100, 20)
	local health = expected(p, "Hospital", "Clinic", 100, 50)
	assert(c.CrimePercent.Value == crime and c.FireSafetyPercent.Value == fire and c.HealthPercent.Value == health)
	local happy = 75 - crime * 0.5
	happy += if fire >= 80 then (fire - 80) * 0.2 elseif fire < 60 then -(60 - fire) * 0.3 else 0
	happy += if health >= 80 then (health - 80) * 0.25 elseif health < 60 then -(60 - health) * 0.25 else 0
	happy += c.BuildingLevel.Value * 0.3
	local distance = (p - buildings[7].PrimaryPart.Position).Magnitude
	if distance <= 30 then
		happy += 15 * (1 - distance / 30)
	end
	assert(c.HappinessPercent.Value == math.floor(math.clamp(happy, 0, 100)))
end
local target, unaffected = buildings[100], buildings[101].Config.HappinessPercent.Value
buildings[100].Config.BuildingLevel.Value += 10
ctx.BuildingStats.updateBuildingStats(target, statsPlot)
assert(scans == 2 and buildings[101].Config.HappinessPercent.Value == unaffected)
buildings[1].PrimaryPart.Position = r.Vector3.new(999, 0, 999)
ctx.BuildingStats.updatePlotStats(statsPlot)
assert(
	buildings[100].Config.HealthPercent.Value
		== expected(buildings[100].PrimaryPart.Position, "Clinic", "Hospital", 100, 50)
)
buildings = {}
ctx.BuildingStats.updatePlotStats(statsPlot)
ctx.BuildingStats.updatePlotStats(nil)
print(
	"PASS: 1,000-building stats match strongest coverage formulas with one city enumeration; level-only update, moved providers and empty/missing plots"
)
