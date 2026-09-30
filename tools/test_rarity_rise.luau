local fs, luau, r = require("@lune/fs"), require("@lune/luau"), require("@lune/roblox")
local source = fs.readFile("src/client/controllers/world/RarityRiseController.luau")
local completion = fs.readFile("src/server/systems/construction/ConstructionSystem/ConstructionTimer/Completion.luau")
local restoration = fs.readFile("src/server/systems/construction/ConstructionSystem/ConstructionData/Restoration.luau")
assert(completion:find("if playedSpecialVFX then", 1, true))
assert(completion:find("RarityRise:FireAllClients", 1, true))
assert(not restoration:find("RarityRise", 1, true), "Historical restored buildings must not rise")
assert(source:find("local finalPivot = source:GetPivot()", 1, true))
assert(source:find("local DURATION = 5.0", 1, true))
assert(source:find("clone:PivotTo(finalPivot)", 1, true))
assert(source:find("item.CanCollide, item.CanTouch, item.CanQuery = false", 1, true))

local now, listener, frame, cloneCount, lastClone = 0, nil, nil, 0, nil
local function node(values)
	values = values or {}
	function values:WaitForChild(name) return self[name] end
	function values:FindFirstChild(name) return self[name] end
	return values
end
local function object(class)
	local value = { Parent = true, LocalTransparencyModifier = 0, Enabled = true }
	function value:IsA(name) return name == class end
	return value
end
local finalPivot = r.CFrame.new(10, 25, 5) * r.CFrame.Angles(0, math.rad(90), 0)
local sourcePart, sourcePrompt = object("BasePart"), object("ProximityPrompt")
local sourceModel = node({ Name = "Tower_1", PrimaryPart = sourcePart })
function sourceModel:IsA(class) return class == "Model" end
function sourceModel:GetDescendants() return { sourcePart, sourcePrompt } end
function sourceModel:GetBoundingBox() return finalPivot, r.Vector3.new(5, 20, 5) end
function sourceModel:GetPivot() return finalPivot end
function sourceModel:Clone()
	cloneCount += 1
	local clonePart = object("BasePart")
	local clone = node({ part = clonePart })
	function clone:GetDescendants() return { clonePart } end
	function clone:SetAttribute() end
	function clone:PivotTo(cf) self.pivot = cf end
	function clone:Destroy() self.destroyed = true end
	lastClone = clone
	return clone
end
local placed = node({ Tower_1 = sourceModel })
sourceModel.Parent = placed
local plot = node({ Buildings = node({ Placed = placed }), Parent = true })
function plot:GetAttribute(name) return if name == "CityId" then self.cityId else nil end
plot.cityId = 55
local plots = node({ Plot1 = plot })
local workspace = node({ Plots = plots })
local remote = { OnClientEvent = { Connect = function(_, fn)
	listener = fn
	return { Disconnect = function() listener = nil end }
end } }
local replicated = { shared = { ui = { RarityColors = {} } }, Events = { VFX = { RarityRise = remote } } }
local heartbeat = { Connect = function(_, fn)
	frame = fn
	return { Disconnect = function() frame = nil end }
end }
local services = { ReplicatedStorage = replicated, RunService = { RenderStepped = heartbeat }, Workspace = workspace }
local controller = luau.load(source, { environment = {
	game = { GetService = function(_, name) return services[name] end },
	require = function() return { Epic = { R = 1, G = 0, B = 1 } } end,
	Workspace = workspace,
	Vector3 = r.Vector3,
	Instance = { new = function() return {} end },
	os = { clock = function() return now end },
	task = { spawn = function(callback, ...) callback(...) end },
} })()
assert(controller.offsetForHeight(2) == 2 and controller.offsetForHeight(100) == 100)
assert(controller.offsetForHeight(20) == 20)
assert(controller.ease(0) == 0 and controller.ease(1) == 1)
controller.start()
listener("Plot1", "Tower_1", "Epic", 55)
assert(cloneCount == 1 and sourcePart.LocalTransparencyModifier == 1 and not sourcePrompt.Enabled)
assert(lastClone.pivot.Position.Y == finalPivot.Position.Y - 20)
listener("Plot1", "Tower_1", "Epic", 55)
assert(cloneCount == 1, "Duplicate rise started while active")
now = 4.9
frame()
assert(frame and sourcePart.LocalTransparencyModifier == 1, "Rise ended before five seconds")
now = 5.0
frame()
assert(lastClone.destroyed and (lastClone.pivot.Position - finalPivot.Position).Magnitude < 0.0001)
assert((lastClone.pivot.LookVector - finalPivot.LookVector).Magnitude < 0.0001)
assert(sourcePart.LocalTransparencyModifier == 0 and sourcePrompt.Enabled and not frame)
-- A second event canceled by plot reassignment must restore local presentation.
listener("Plot1", "Tower_1", "Epic", 55)
assert(sourcePart.LocalTransparencyModifier == 1)
plot.cityId = 66
frame()
assert(sourcePart.LocalTransparencyModifier == 0 and sourcePrompt.Enabled and not frame)
controller.stop()
print("PASS: rarity rise bounds/easing, duplicate guard, exact-pivot path, prompt safety and reassignment cancellation")
