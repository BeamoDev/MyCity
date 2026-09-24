local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local Counter = luau.load(fs.readFile("src/shared/util/NumberCounter.luau"))()
local function signal()
	local entries = {}
	return {
		Connect = function(_, callback)
			local entry = { callback = callback, connected = true }
			table.insert(entries, entry)
			return {
				Disconnect = function()
					entry.connected = false
				end,
			}
		end,
		Fire = function(_, ...)
			for _, entry in entries do
				if entry.connected then
					entry.callback(...)
				end
			end
		end,
		Count = function()
			local count = 0
			for _, entry in entries do
				if entry.connected then
					count += 1
				end
			end
			return count
		end,
	}
end
local function node(fields)
	fields = fields or {}
	function fields:WaitForChild(name)
		return assert(self[name], name)
	end
	function fields:FindFirstChild(name)
		return self[name]
	end
	return fields
end
local created = {}
local function instance(class)
	local object = { ClassName = class, Destroying = signal(), Visible = true }
	function object:IsA(name)
		return name == self.ClassName or (name == "GuiObject" and self.ClassName == "TextLabel")
	end
	function object:Destroy()
		if self.destroyed then
			return
		end
		self.destroyed = true
		self.Destroying:Fire()
		self.Parent = nil
	end
	table.insert(created, object)
	return object
end
local clock = 0
local frames = signal()
local services = {
	RunService = { RenderStepped = frames },
	ReplicatedStorage = node({ shared = node({ util = node({ NumberCounter = Counter }) }) }),
}
local Feedback = luau.load(fs.readFile("src/client/controllers/ui/CashFeedback.luau"), {
	environment = {
		game = {
			GetService = function(_, name)
				return services[name]
			end,
		},
		require = function(module)
			return module
		end,
		Instance = { new = instance },
		Color3 = roblox.Color3,
		UDim2 = roblox.UDim2,
		Vector2 = roblox.Vector2,
		os = {
			clock = function()
				return clock
			end,
		},
	},
})()
local baseline = roblox.Color3.fromRGB(255, 240, 220)
local function label()
	local result = instance("TextLabel")
	result.Parent = {
		ClassName = "ScreenGui",
		Enabled = true,
		IsA = function(_, name)
			return name == "ScreenGui"
		end,
	}
	result.TextColor3, result.TextSize, result.FontFace, result.ZIndex = baseline, 22, "AuthoredFont", 3
	return result
end
local function format(amount)
	return "$" .. tostring(amount)
end
local display = label()
local effect = Feedback.new(display, format)
effect:SetTarget(500)
assert(display.Text == "$500" and frames.Count() == 0 and #effect.popups == 0, "initial balance must snap")
effect:SetTarget(1500)
assert(frames.Count() == 1 and effect.popups[1].label.Text == "+$1000")
clock = 0.1
frames:Fire()
local intermediate = effect.counter.Current
assert(intermediate > 500 and intermediate < 1500, "must visibly count up")
effect:SetTarget(5000)
assert(effect.counter.From == intermediate and effect.popups[2].label.Text == "+$3500", "retarget without jumping")
effect:SetTarget(100)
assert(
	effect.counter.From == intermediate and effect.popups[3].label.Text == "-$4900",
	"delta uses actual balance change"
)
local oldest = effect.popups[1].label
effect:SetTarget(50)
assert(oldest.destroyed and #effect.popups == 3 and frames.Count() == 1, "bound rapid feedback and connections")
clock = 0.2
frames:Fire()
assert(effect.counter.Current < intermediate and effect.counter.Current > 50, "must visibly count down")
clock = 2
frames:Fire()
assert(display.Text == "$50" and display.TextColor3 == baseline and frames.Count() == 0 and #effect.popups == 0)
effect:SetTarget(50)
assert(frames.Count() == 0, "identical balance stays idle")
display.Visible = false
effect:SetTarget(60)
assert(#effect.popups == 0, "hidden HUD must not spawn popups")
display.Visible = true
effect:SetTarget(70)
local popup = effect.popups[1].label
display:Destroy()
assert(popup.destroyed and effect.destroyed and frames.Count() == 0 and display.Destroying.Count() == 0)
effect:SetTarget(100)
assert(frames.Count() == 0, "destroyed effect cannot restart")

-- Exercise the real HUD binding as well: repeated initialization and replacement.
local cashChanged = signal()
local cash = {
	Value = 123,
	GetPropertyChangedSignal = function()
		return cashChanged
	end,
}
local context = {
	State = { HUD = node({ CashDisplay = label() }) },
	player = node({ leaderstats = node({ Cash = cash }) }),
	formatNumber = format,
	connections = {
		connect = function(_, event, callback)
			return event:Connect(callback)
		end,
	},
}
luau.load(fs.readFile("src/client/controllers/ui/UIController/CashDisplay.luau"), {
	environment = {
		script = { Parent = { Parent = { CashFeedback = Feedback } } },
		require = function(module)
			return module
		end,
	},
})()(context)
context.updateCashDisplay()
context.updateCashDisplay()
assert(cashChanged.Count() == 1 and context.State.HUD.CashDisplay.Text == "$123")
cash.Value = 321
cashChanged:Fire()
assert(frames.Count() == 1)
local oldEffect = context.State.cashFeedback
context.State.HUD = node({ CashDisplay = label() })
context.updateCashDisplay()
assert(oldEffect.destroyed and frames.Count() == 0 and cashChanged.Count() == 1)
assert(context.State.HUD.CashDisplay.Text == "$321")
context.cleanupCashDisplay()
context.cleanupCashDisplay()
assert(cashChanged.Count() == 0 and frames.Count() == 0 and context.State.cashFeedback == nil)
print(
	"PASS: cash initial balance, gain/spend, retargeting, popup bounds, idle frames, hidden/destroyed HUD and replacement cleanup"
)

-- Counting down to $0 must never display "-$0" (math.ceil of a small negative is -0).
do
	local fsModule, luauModule = require("@lune/fs"), require("@lune/luau")
	local counter = luauModule.load(fsModule.readFile("src/shared/util/NumberCounter.luau"))()
	local displays = {}
	luauModule.load(fsModule.readFile("src/client/controllers/ui/UIController/Displays.luau"))()(displays)
	local state = {}
	counter.SetTarget(state, 5, { Minimum = 0 }, 0)
	counter.SetTarget(state, 0, { Minimum = 0 }, 0)
	for t = 0, 1, 0.01 do
		local _, value = counter.Step(state, t)
		if value then
			assert(not displays.formatNumber(value):find("-"), "Cash showed a negative zero")
		end
	end
	assert(displays.formatNumber(-0) == "$0" and displays.formatNumber(-1500) == "-$1,500")
	print("PASS: cash counting down to $0 never shows -$0")
end
