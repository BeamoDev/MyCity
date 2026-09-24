local fs, luau, r = require("@lune/fs"), require("@lune/luau"), require("@lune/roblox")
local function child(parent, class, name)
	local v = r.Instance.new(class)
	v.Name = name
	v.Parent = parent
	return v
end
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
local function run(input)
	local hud = child(nil, "ScreenGui", "HUD")
	local frames, buttons = child(hud, "Folder", "Frames"), child(hud, "Folder", "Buttons")
	local shop = child(frames, "Frame", "Shop")
	local quests = child(frames, "Frame", "Quests")
	local authored = child(quests, "UIScale", "UIScale")
	authored.Scale = 0.8
	local left, right, up = child(buttons, "Frame", "Left"), child(buttons, "Frame", "Right"), child(buttons, "Frame", "Up")
	local other = child(buttons, "Frame", "Bottom")
	local added = signal()
	local Context = {
		State = { FramesFolder = { GetChildren = function()
			return frames:GetChildren()
		end, ChildAdded = added }, ButtonFolder = buttons },
		connections = { connect = function(_, s, fn)
			s:Connect(fn)
		end },
	}
	luau.load(fs.readFile("src/client/controllers/ui/UIController/MobileScale.luau"), {
		environment = {
			game = { GetService = function()
				return input
			end },
			Instance = r.Instance,
		},
	})()(Context)
	Context.setupMobileScale()
	return Context, { shop = shop, quests = quests, authored = authored, left = left, right = right, up = up, other = other, frames = frames, added = added }
end
local function scaleOf(gui)
	local s = gui:FindFirstChildOfClass("UIScale")
	return s and s.Scale
end
local function near(a, b)
	return a and math.abs(a - b) < 1e-4
end

local _, desktop = run({ TouchEnabled = true, KeyboardEnabled = true })
assert(not scaleOf(desktop.shop) and not scaleOf(desktop.left) and near(scaleOf(desktop.quests), 0.8), "Keyboard devices unchanged")

local Context, m = run({ TouchEnabled = true, KeyboardEnabled = false })
assert(near(scaleOf(m.shop), 1.15), "Popup frames 15% larger")
assert(near(m.authored.Scale, 0.92) and #m.quests:GetChildren() == 1, "Authored UIScale multiplied, not duplicated")
assert(near(scaleOf(m.left), 1.1) and near(scaleOf(m.right), 1.1) and near(scaleOf(m.up), 1.1), "Button groups 10% larger")
assert(not scaleOf(m.other), "Other button groups untouched")
local late = child(m.frames, "Frame", "Late")
m.added:Fire(late)
assert(near(scaleOf(late), 1.15), "Late popups scaled")
Context.setupMobileScale()
assert(near(scaleOf(m.shop), 1.15) and near(m.authored.Scale, 0.92), "Reapplying never compounds")
print("PASS: touch-only 15% popups, 10% Left/Right/Up buttons, authored UIScale kept, late frames, idempotent, desktop unchanged")
