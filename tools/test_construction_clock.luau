local fs, luau, r = require("@lune/fs"), require("@lune/luau"), require("@lune/roblox")
local function node(t)
	function t:FindFirstChild(k)
		return self[k]
	end
	t.WaitForChild = t.FindFirstChild
	return t
end
local function item(class, name, parent)
	local v = r.Instance.new(class)
	v.Name, v.Parent = name, parent
	return v
end
local jobs, deferred, timers, completed = {}, {}, {}, 0
local scheduler = {
	every = function(_, callback)
		table.insert(jobs, callback)
		return function() end
	end,
}
local parses = 0
local dataApi = {
	saveConstructionData = function() end,
	loadConstructionData = function()
		parses += 1
		return { position = r.Vector3.zero, rotation = r.Vector3.zero, size = "4x4" }
	end,
}
local builder = {
	getActiveBuilders = function()
		return {}
	end,
	updateBuilderCount = function() end,
}
local server = node({
	config = node({ BuildingConfig = { Bank = { Size = "4x4", Rarity = "Common" } } }),
	services = { SimulationScheduler = scheduler },
})
local systems = { Parent = server }
local category = { Parent = systems }
local construction = node({
	Parent = category,
	ConstructionData = dataApi,
	ConstructionBuilder = builder,
	ConstructionSkipping = { addSkipBuildPrompt = function() end },
})
local scriptObject = { Parent = { Parent = construction } }
local env = {
	script = scriptObject,
	require = function(m)
		assert(m)
		return m
	end,
	Instance = r.Instance,
	Vector3 = r.Vector3,
	game = {
		GetService = function()
			return node({ Assets = node({ Items = node({}) }) })
		end,
	},
	task = {
		defer = function(fn, ...)
			table.insert(deferred, { fn, table.pack(...) })
		end,
	},
}
local plot = item("Folder", "Plot", item("Folder", "Workspace"))
local data = item("Folder", "Data")
local records = item("Folder", "CurrentConstructions", data)
local player = node({ Parent = true, UserId = 7, Data = data })
function player:GetAttribute(k)
	return self[k]
end
local context = {
	State = { activeTimers = timers, completedConstructions = {} },
	ConstructionTimer = {
		finishConstruction = function()
			completed += 1
		end,
	},
	UpdateConstructionsEvent = { FireClient = function() end },
	ownsHalfConstructionSpeedGamePass = function()
		return false
	end,
	updateConstructionBillboard = function() end,
}
luau.load(
	fs.readFile("src/server/systems/construction/ConstructionSystem/ConstructionTimer/Timing.luau"),
	{ environment = env }
)()(context)
local function start(id, remaining)
	local site = item("Model", "Bank_" .. id, plot)
	local base = item("Part", "Base", site)
	site.PrimaryPart = base
	base.Position = r.Vector3.zero
	base.CFrame = r.CFrame.identity
	site:SetAttribute("BuildingType", "Bank")
	site:SetAttribute("ConstructionID", id)
	item("StringValue", site.Name, records).Value = "saved"
	context.ConstructionTimer.startConstructionTimer(
		player,
		plot,
		site,
		{},
		10,
		remaining,
		true,
		false,
		4,
		52,
		timers,
		{},
		{},
		true
	)
	return site, jobs[#jobs]
end
local site, step = start("one", 6)
assert(step(2.25) and math.abs(timers.Bank_one.remainingTime - 3.75) < 0.001)
assert(parses == 1, "Timer reparsed immutable coordinates")
local fields = string.split(records.Bank_one.Value, ",")
assert(#fields == 12 and fields[10] == "4" and fields[11] == "52" and fields[12] == "true")
assert(step(10) == false and completed == 1 and timers.Bank_one == nil)
assert(step(10) == false and completed == 1, "Late timer completed twice")
local removed, oldStep = start("two", 5)
removed:Destroy()
assert(oldStep(1) == false and completed == 1)
local canceled, cancelStep = start("three", 5)
canceled.TimerActive.Value = false
assert(cancelStep(1) == false and completed == 1)
local leaving, leaveStep = start("four", 5)
player.MyCityLeaving = true
assert(leaveStep(1) == false and completed == 1)
player.MyCityLeaving = false
start("zero", 0)
for _, job in deferred do
	job[1](table.unpack(job[2], 1, job[2].n))
end
assert(completed == 2, "Zero-duration completion failed")
print(
	"PASS: construction elapsed time, one coordinate decode, 12 saved fields, delayed completion once, destroyed/skipped/departing cancellation and zero-time completion"
)
