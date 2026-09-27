local fs, luau, r = require("@lune/fs"), require("@lune/luau"), require("@lune/roblox")

local emptyService = {}
local system = luau.load(fs.readFile("src/server/systems/world/AirportSystem.luau"), {
	environment = {
		CFrame = r.CFrame,
		Vector3 = r.Vector3,
		game = { GetService = function() return emptyService end },
	},
})()

local travel = r.Vector3.new(0, 0, -1)
local frame = system.routeFrame(r.Vector3.zero, travel, 180, -90)
assert(frame.Position:FuzzyEq(r.Vector3.zero, 0.0001), "Orientation correction moved the route position")
assert(system.speedFor("A1_TouchdownPoint") > system.speedFor("A1_TaxiPoint1"), "Landing does not decelerate into taxi")
assert(system.speedFor("D1_DeparturePoint") > system.speedFor("D1_TakeoffStart"), "Departure does not accelerate")
assert(system.speedFor("A1_TouchdownPoint") == 2 and system.speedFor("A1_TaxiPoint1") == 0.2, "Airport is not real-time paced")
assert(system.minimumDuration("A1_TouchdownPoint") == 6, "Short landing legs can still finish too quickly")
assert(system.minimumDuration("A1_TaxiPoint1") == 4, "Short taxi legs can still finish too quickly")
assert(system.motionProfile("A1_TouchdownPoint", 0.5) > 0.49 and system.motionProfile("A1_TouchdownPoint", 0.5) < 0.51, "Approach easing changed")
assert(system.motionProfile("A1_BrakingPoint", 0.5) > 0.8, "Braking does not gradually decelerate")
assert(system.flarePitch("A1_TouchdownPoint", 0.5) == 0, "Flare begins too early")
assert(math.abs(system.flarePitch("A1_TouchdownPoint", 1) - 7) < 0.001, "Touchdown does not reach full flare")
assert(system.flarePitch("A1_BrakingPoint", 1) == 0, "Plane does not settle after flare")

local source = fs.readFile("src/server/systems/world/AirportSystem.luau")
local bootstrap = fs.readFile("src/server/bootstrap/ServerBootstrap.luau")
assert(source:find("DEFAULT_YAW = 180"), "Additional 90-degree-right correction is missing")
assert(source:find("DEFAULT_PITCH = %-90"), "90-degree-down pitch correction is missing")
assert(source:find("ROUTE_Y_OFFSET = %-0%.2"), "Airport route is not lowered by 0.2 studs")
assert(source:find("local function horizontalDirection"), "Ground route headings are not flattened")
assert(source:find("outgoing or entry%.lastDirection"), "Overlapping departure points do not use route heading fallback")
assert(not source:find("plane:GetPivot%(%)%.LookVector"), "Corrected model LookVector can still cause a 90-degree pitch jump")
assert(source:find("plane:PivotTo"), "Airport traffic does not move the full aircraft Model")
assert(source:find("RuntimePlanes"), "Airport runtime plane ownership is missing")
assert(source:find('current%.Parent%.Name == "Placed"'), "Airport construction sites are not excluded")
assert(source:find("item%.Disabled = true"), "Legacy model-local airport controller is not disabled")
assert(not source:find("BindableEvent"), "Airport scheduling still uses the old BindableEvent chain")
assert(not source:find("TweenService"), "Airport movement still depends on PrimaryPart tweens")
assert(bootstrap:find("AirportSystem = require") and bootstrap:find('"AirportSystem"'), "AirportSystem is not server-bootstrapped")

print("PASS: real-time airport cycle, whole-model motion and right/down orientation correction")
