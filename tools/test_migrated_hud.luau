local fs = require("@lune/fs")
local luau = require("@lune/luau")
local r = require("@lune/roblox")
local function load(path, env)
	return luau.load(fs.readFile(path), { environment = env or {} })()
end
local function signal()
	local callbacks = {}
	return {
		Connect = function(_, fn)
			local c = { active = true }
			function c:Disconnect()
				self.active = false
			end
			table.insert(callbacks, { fn, c })
			return c
		end,
		Fire = function(_, ...)
			for _, pair in callbacks do
				if pair[2].active then
					pair[1](...)
				end
			end
		end,
	}
end
local function scope()
	local s = { connections = {}, delayed = {} }
	function s:connect(event, fn)
		table.insert(self.connections, event:Connect(fn))
	end
	function s:delay(_, fn)
		table.insert(self.delayed, fn)
	end
	function s:clear()
		for _, c in self.connections do
			c:Disconnect()
		end
		self.delayed = {}
	end
	return s
end
local function node(t)
	t = t or {}
	function t:FindFirstChild(name)
		return self[name]
	end
	function t:WaitForChild(name)
		return assert(self[name], name)
	end
	return t
end
local tweenService = {
	Create = function(_, object, _, goal)
		return {
			Play = function()
				for key, value in goal do
					object[key] = value
				end
			end,
			Cancel = function() end,
		}
	end,
}
local env = {
	UDim2 = r.UDim2,
	Color3 = r.Color3,
	TweenInfo = { new = function() end },
	Enum = { EasingStyle = { Sine = 1, Quad = 2 }, EasingDirection = { Out = 1 } },
}
local function instance(kind, name, parent)
	local o = r.Instance.new(kind)
	o.Name = name
	o.Parent = parent
	return o
end
local template = instance("Frame", "ConstructionTemplate")
instance("TextLabel", "BuildingName", template)
instance("TextLabel", "Timer", template)
instance("Frame", "Frame", template)
local container = instance("ScrollingFrame", "ScrollingFrame")
local layout = instance("UIListLayout", "UIListLayout", container)
local Rows = load("src/client/controllers/ui/UIController/Construction/Rows.luau", env)
local rows = Rows.new(template, container, tweenService)
rows.upsert({ Id = "Bank_a", Name = "Bank", Duration = 30, TotalDuration = 60 }, 0)
rows.upsert({ Id = "Bank_b", Name = "Bank", Duration = 10, TotalDuration = 60 }, 0)
assert(rows.render(4) == 2)
assert(container.Bank_b.LayoutOrder == 1 and container.Bank_a.LayoutOrder == 2)
assert(container.Bank_a.Timer.Text == "26s")
assert(math.abs(container.Bank_a.Frame.Size.X.Scale - (1 - 26 / 60)) < 0.0001)
rows.upsert({ Id = "Bank_a", Name = "Bank", Duration = 25, TotalDuration = 60 }, 5)
assert(rows.render(5) == 2, "Duplicate event created duplicate row")
rows.remove("Bank_b")
assert(rows.render(100) == 1, "Client countdown falsely confirmed construction completion")
assert(container.Bank_a.Timer.Text == "00s")
rows.clear()
assert(#container:GetChildren() == 1 and layout.Parent == container, "Cleanup deleted authored layout")
assert(Rows.formatTime(90061) == "1d 01h 01m 01s")

local api, sent = {}, nil
local function timer(owner, active)
	return {
		constructionSite = {
			Parent = true,
			GetAttribute = function()
				return owner
			end,
		},
		timerActive = { Value = active },
		displayName = "Bank",
		remainingTime = 12,
		totalTime = 20,
	}
end
load("src/server/systems/construction/ConstructionSystem/ConstructionTimer/PlayerView.luau")({
	ConstructionTimer = api,
	State = { activeTimers = { own = timer(1, true), other = timer(2, true), completed = timer(1, false) } },
	UpdateConstructionsEvent = {
		FireClient = function(_, player, action, items)
			assert(player.UserId == 1 and action == "snapshot")
			sent = items
		end,
	},
})
api.syncPlayer({ UserId = 1 })
assert(
	#sent == 1 and sent[1].Id == "own" and sent[1].Duration == 12 and sent[1].TotalDuration == 20,
	"Snapshot leaked another player's construction or missed restored duration"
)

local status = { Text = "Enter a code", TextColor3 = r.Color3.new(1, 1, 1) }
local submit, textbox = { Activated = signal() }, { Text = "", FocusLost = signal() }
local event = { OnClientEvent = signal(), sent = {} }
function event:FireServer(code)
	table.insert(self.sent, code)
end
local s = scope()
load("src/client/controllers/ui/UIController/Settings/Codes.luau", env).bind(
	node({ CodeStatus = status, CodeSubmit = submit, TextBox = textbox }),
	s,
	event,
	node()
)
submit.Activated:Fire()
assert(status.Text == "Please enter a code!" and #event.sent == 0)
textbox.Text = " WEL COME "
submit.Activated:Fire()
submit.Activated:Fire()
assert(#event.sent == 1 and event.sent[1] == "WELCOME")
event.OnClientEvent:Fire(true, "Redeemed!")
assert(textbox.Text == "" and status.Text == "Redeemed!" and status.TextColor3 == r.Color3.fromRGB(92, 255, 67))
s.delayed[1]()
assert(status.Text == "Redeemed!", "Older reset replaced newer result")
textbox.Text = "RELEASE"
textbox.FocusLost:Fire(true)
assert(#event.sent == 2)
s.delayed[#s.delayed]()
assert(status.Text == "No response. Please try again.")
submit.Activated:Fire()
assert(#event.sent == 3, "Timeout permanently locked code submission")
s:clear()
submit.Activated:Fire()
assert(#event.sent == 3)

local function button()
	return node({ Activated = signal(), TextLabel = node({ Text = "" }) })
end
local musicButton, sfxButton = button(), button()
local function sound(name, volume)
	return {
		Name = name,
		Volume = volume,
		Parent = true,
		IsA = function(_, kind)
			return kind == "Sound"
		end,
	}
end
local music, effect, silent = sound("Ambience", 0.6), sound("Click", 0.4), sound("Silent", 0)
local sounds = { music, effect, silent }
local folder = {
	DescendantAdded = signal(),
	GetDescendants = function()
		return sounds
	end,
}
local audioRoot = node({ MusicToggle = musicButton, SFXToggle = sfxButton, Holding = node() })
local Audio = load("src/client/controllers/ui/UIController/Settings/Audio.luau", env)
local audioScope = scope()
local stopAudio = Audio.bind(audioRoot, audioScope, node({ SFX = folder }), tweenService)
sfxButton.Activated:Fire()
assert(effect.Volume == 0 and music.Volume == 0.6 and sfxButton.TextLabel.Text == "Off")
local late = sound("Click", 0.8)
table.insert(sounds, late)
folder.DescendantAdded:Fire(late)
assert(late.Volume == 0)
sfxButton.Activated:Fire()
assert(
	effect.Volume == 0.4 and late.Volume == 0.8 and silent.Volume == 0,
	"Volume restore confused equal sound names or unmuted authored silence"
)
musicButton.Activated:Fire()
assert(music.Volume == 0 and effect.Volume == 0.4)
audioScope:clear()
stopAudio()
local replacement = scope()
Audio.bind(audioRoot, replacement, node({ SFX = folder }), tweenService)
assert(music.Volume == 0 and musicButton.TextLabel.Text == "Off", "HUD replacement lost audio preference")
replacement:clear()

local cleanupEvent, builderEvent = signal(), signal()
local mobile = { Visible = true }
local mobileScope = scope()
load("src/client/controllers/placement/MobilePlacement.luau").bind(
	node({ MobilePlacement = mobile }),
	mobileScope,
	{ OnClientEvent = cleanupEvent }
)
assert(not mobile.Visible)
mobile.Visible = true
cleanupEvent:Fire()
assert(not mobile.Visible)
mobileScope:clear()
mobile.Visible = true
cleanupEvent:Fire()
assert(mobile.Visible)
local count = {}
local builderScope = scope()
local context = {
	State = { ButtonFolder = node({ Builders = node({ Count = count }) }) },
	connections = builderScope,
	ReplicatedStorage = { Events = { UI = { UpdateBuilderUI = { OnClientEvent = builderEvent } } } },
}
load("src/client/controllers/ui/UIController/BuilderDisplay.luau", env)(context)
context.setupBuilderDisplay()
for _, current in { 0, 1, 7 } do
	builderEvent:Fire(current, 7)
	assert(count.Text == tostring(current) .. "/7")
	local expected = if current == 0
		then r.Color3.fromRGB(47, 255, 47)
		elseif current < 7 then r.Color3.fromRGB(255, 255, 0)
		else r.Color3.fromRGB(255, 47, 47)
	assert(count.TextColor3 == expected)
end
builderScope:clear()
print(
	"PASS: construction IDs/ordering/progress/snapshots, code submission/timeout/stale results, audio mute/late sounds/replacement, builder colors and mobile cleanup"
)
