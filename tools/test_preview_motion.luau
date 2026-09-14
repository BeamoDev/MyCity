local fs = require("@lune/fs")
local luau = require("@lune/luau")
local r = require("@lune/roblox")
local function load(path, env)
	return luau.load(fs.readFile(path), { environment = env or {} })()
end
local function scenario()
	local base = { Position = r.Vector3.zero, CFrame = r.CFrame.identity }
	local writes = 0
	local preview = {
		FindFirstChild = function(_, name)
			if name == "Base" then
				return base
			end
		end,
	}
	function preview:SetPrimaryPartCFrame(cf)
		writes += 1
		base.CFrame = cf
		base.Position = cf.Position
	end
	local state = { previewBuilding = preview, targetPosition = r.Vector3.zero, rotationAngle = 0 }
	local context = {
		state = state,
		SoundService = {
			FindFirstChild = function()
				return nil
			end,
		},
		updateBuildingVisuals = function() end,
		snapToGrid = function(position)
			return position
		end,
	}
	load("src/client/controllers/placement/ToolsModule/Session/Motion.luau", { CFrame = r.CFrame })(context)
	load("src/client/controllers/placement/ToolsModule/Session/Input.luau")(context)
	return context, state, base, function()
		return writes
	end
end
local c, state, base, writes = scenario()
c.smoothMoveToTarget(0)
state.targetPosition = r.Vector3.new(8, 1.25, 4)
c.rotatePreview()
assert(
	base.Position == r.Vector3.zero and state.rotationAngle == 90,
	"Rotate jumped preview or snapped an intermediate destination"
)
c.smoothMoveToTarget(0.05)
assert(base.Position.X > 0 and base.Position.X < 8)
assert(state.motion.angle > 0 and state.motion.angle < 90)
local expected = r.CFrame.new(8, 1.25, 4) * r.CFrame.Angles(0, math.rad(90), 0)
assert(c.getTargetCFrame() == expected and base.CFrame ~= expected, "Placement target follows visual interpolation")
local priorAngle = state.motion.angle
c.rotatePreview()
assert(state.motion.angle == priorAngle and state.rotationAngle == 180)
c.smoothMoveToTarget(0.05)
assert(state.motion.angle > priorAngle and state.motion.angle < 180, "Rapid rotation snapped or reversed")
c.smoothMoveToTarget(1)
assert((base.Position - state.targetPosition).Magnitude < 0.0001 and math.abs(state.motion.angle - 180) < 0.0001)
local atRest = writes()
c.smoothMoveToTarget(1)
assert(writes() == atRest, "Stationary preview wrote another model transform")
c.rotatePreview()
c.rotatePreview()
assert(state.rotationAngle == 0 and state.motionTargetAngle == 360)
c.smoothMoveToTarget(0.09)
assert(state.motion.angle > 180 and state.motion.angle < 360, "Rotation wrap reversed direction")
state.targetPosition = r.Vector3.new(-3, 1.25, 8)
local beforeRetarget = base.Position
c.smoothMoveToTarget(0.01)
assert(
	base.Position ~= state.targetPosition
		and (base.Position - beforeRetarget).Magnitude < (state.targetPosition - beforeRetarget).Magnitude
)

local function atRate(rate)
	local ctx, s = scenario()
	ctx.smoothMoveToTarget(0)
	s.targetPosition = r.Vector3.new(10, 1.25, 7)
	ctx.rotatePreview()
	for _ = 1, rate / 10 do
		ctx.smoothMoveToTarget(1 / rate)
	end
	return s.motion.position, s.motion.angle
end
local p30, a30 = atRate(30)
local p120, a120 = atRate(120)
assert((p30 - p120).Magnitude < 0.0001 and math.abs(a30 - a120) < 0.0001, "Tween speed depends on frame rate")

-- Exercise bootstrap's real order and stop at the expensive/yielding world preparation.
local order = {}
local function mockModule(name, method)
	return {
		[method] = function()
			table.insert(order, name)
		end,
	}
end
local spawn = mockModule("spawn", "start")
spawn.release = function() end
local network = mockModule("network", "start")
local storage = {
	shared = { Network = network },
	Events = {
		Loading = {
			IntroFinished = {
				OnServerEvent = {
					Connect = function()
						table.insert(order, "release binding")
					end,
				},
			},
		},
	},
}
function storage:WaitForChild(name)
	return self[name]
end
function storage.shared:WaitForChild(name)
	return self[name]
end
local bootstrap = load("src/server/bootstrap/ServerBootstrap.luau", {
	game = {
		GetService = function()
			return storage
		end,
	},
	script = {
		Parent = {
			Shutdown = {
				start = function()
					table.insert(order, "shutdown")
					return true
				end,
				isClosing = function()
					return false
				end,
			},
			SpawnGuard = spawn,
			WorldRuntime = {
				start = function()
					table.insert(order, "world")
					error("stop after world")
				end,
			},
		},
	},
	require = function(module)
		return module
	end,
	print = function() end,
})
local ok, err = pcall(bootstrap.start)
assert(not ok and string.find(err, "stop after world", 1, true))
assert(
	table.concat(order, ",") == "shutdown,spawn,network,release binding,world",
	"Remote creation still waits for preview assets"
)
print(
	"PASS: move/rotation easing, rapid retarget/wrap, exact placement targets, frame-rate independence, stationary transform reuse and network-before-assets bootstrap"
)
