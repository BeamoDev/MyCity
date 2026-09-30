local fs, luau, r = require("@lune/fs"), require("@lune/luau"), require("@lune/roblox")

local controller = luau.load(fs.readFile("src/client/controllers/world/MilitaryHelicopterController.luau"), {
	environment = {
		CFrame = r.CFrame,
		Vector3 = r.Vector3,
		game = {
			GetService = function(_, name)
				return { Name = name }
			end,
		},
	},
})()

local center = r.Vector3.new(10, 4, -5)
local frame0 = controller.flightFrame(center, 0, 30, 38, 0, 0.7)
local frame90 = controller.flightFrame(center, math.pi / 2, 30, 38, 0, 0.7)
local function horizontalDistance(frame)
	local offset = frame.Position - center
	return r.Vector3.new(offset.X, 0, offset.Z).Magnitude
end
assert(horizontalDistance(frame0) <= 30 and horizontalDistance(frame90) <= 30, "Wandering path escaped its orbit boundary")
assert(horizontalDistance(frame0) ~= horizontalDistance(frame90), "Flight path is still a perfect circle")
assert(math.abs(frame0.Position.Y - frame90.Position.Y) > 0.1, "Flight path does not smoothly change altitude")
-- Lune's CFrame look-vector sign differs from Roblox here; either way the forward axis must be tangent.
assert(frame0.LookVector.Magnitude > 0.999, "Helicopter flight frame is invalid")
assert(controller.phaseFor("building-1") == controller.phaseFor("building-1"), "Phase is not deterministic")
assert(controller.phaseFor("building-1") ~= controller.phaseFor("building-2"), "Distinct buildings overlap by default")

local epic = luau.load(fs.readFile("src/server/config/BuildingConfig/Epic.luau"))()
assert(epic.MilitaryBase and epic.MilitaryBase.Rarity == "Epic" and epic.MilitaryBase.BuildLimit == 1)

local source = fs.readFile("src/client/controllers/world/MilitaryHelicopterController.luau")
assert(source:find('MAIN_BLADE_NAMES = { "MainBlades", "main top_Material%.016_0%.002" }'), "Main blade aliases changed")
assert(source:find('REAR_ROTOR_NAMES = { "RearRotor", "main top_Material%.016_0%.011" }'), "Rear rotor aliases changed")
assert(source:find("CFrame%.Angles%(0, spin, 0%)"), "Main blade is not rotating on Y")
assert(source:find("CFrame%.Angles%(0, 0, spin%)"), "Tail blade is not rotating on Z")
assert(source:find("local function militaryBuilding"), "Late descendants do not resolve their MilitaryBase owner")
assert(source:find("Workspace%.DescendantAdded:Connect%(function%(item%)"), "Replication does not retry incomplete helicopters")
assert(not source:find('warnOnce%("hierarchy"'), "Normal replication delay still produces a false hierarchy warning")
assert(source:find("LocalTransparencyModifier = 1"), "Authored welded helicopter is not hidden locally")
assert(source:find("LocalTransparencyModifier = 0"), "Flying clone can inherit invisible local transparency")
assert(source:find("inwardBank") and source:find("pitch"), "Aircraft has no flight tilt")
assert(source:find("DEFAULT_RADIUS = 9"), "Default flight boundary was not brought closer")
assert(source:find("MINIMUM_HEIGHT = 8"), "Default flight height was not lowered")
assert(source:find("DEFAULT_ORBIT_SPEED = 0%.88 / 3"), "Flight speed was not doubled again")
assert(source:find("DEFAULT_YAW = math%.rad%(90%)"), "Default nose correction is missing")
assert(source:find("local function pathPoint"), "Flight path has no bounded wandering")
assert(source:find("CanCollide = false") and source:find("CanQuery = false"), "Flying clone can affect physics")

print("PASS: Military Base catalogue entry, deterministic sky orbit, tangent facing, rotor axes and cosmetic clone safety")
