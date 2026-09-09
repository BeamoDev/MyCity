local fs = require("@lune/fs")
local luau = require("@lune/luau")
local r = require("@lune/roblox")
local function load(name, env)
	return luau.load(
		fs.readFile("src/client/controllers/ui/NotificationController/" .. name .. ".luau"),
		{ environment = env or {} }
	)()
end
local propertySignals = {}
local function propertySignal(object, name)
	object = object:GetFullName()
	propertySignals[object] = propertySignals[object] or {}
	if not propertySignals[object][name] then
		local callbacks = {}
		propertySignals[object][name] = {
			Connect = function(_, fn)
				local entry = { fn = fn, active = true }
				table.insert(callbacks, entry)
				return {
					Disconnect = function()
						entry.active = false
					end,
				}
			end,
			Fire = function()
				for _, entry in callbacks do
					if entry.active then
						entry.fn()
					end
				end
			end,
		}
	end
	return propertySignals[object][name]
end
r.implementMethod("Instance", "GetPropertyChangedSignal", propertySignal)
r.implementMethod("Instance", "GetAttributeChangedSignal", propertySignal)
local function child(parent, class, name)
	local object = r.Instance.new(class)
	object.Name = name
	object.Parent = parent
	return object
end
local gui = child(nil, "ScreenGui", "HUD")
local frame = child(gui, "Frame", "NotificationCenter")
local aspect = child(frame, "UIAspectRatioConstraint", "UIAspectRatioConstraint")
local layout = child(frame, "UIListLayout", "UIListLayout")
local template = child(frame, "Frame", "Template")
local message = child(template, "TextLabel", "Message")
message.Text = "Authored template"
message.TextTransparency = 0.15
child(message, "UIStroke", "UIStroke")
local timers, sounds, bound = {}, 0, 0
local scope = {}
function scope:delay(_, fn)
	table.insert(timers, fn)
end
function scope:clear()
	table.clear(timers)
end
function scope:connect(event, fn)
	return event:Connect(fn)
end
local localPlayer = child(nil, "Player", "Owner")
local tutorialData = child(localPlayer, "Folder", "Data")
local playerInfo = child(tutorialData, "Folder", "PlayerInfo")
local tutorial = child(playerInfo, "Folder", "Tutorial")
local tutorialFlag = child(tutorial, "BoolValue", "IsInTutorial")
tutorialFlag.Value = false
localPlayer:SetAttribute("MyCityIntroActive", false)
local context = {
	Players = { LocalPlayer = localPlayer },
	State = {},
	NotificationController = {},
	activeNotifications = {},
	recentNotifications = {},
	connections = scope,
	MAX_NOTIFICATIONS = 3,
	NOTIFICATION_DATA = {},
	SoundService = {
		FindFirstChild = function()
			return nil
		end,
	},
	TweenService = {
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
	},
	connectNotificationEvents = function()
		bound += 1
	end,
}
local env = { TweenInfo = {
	new = function(...)
		return { ... }
	end,
}, Enum = r.Enum }
for _, name in { "Layout", "Queue", "Lifecycle" } do
	load(name, env)(context)
end
context.NotificationController.init(gui)
assert(bound == 1 and not template.Visible and frame.Visible)
local function notices()
	local found = {}
	for _, card in frame:GetChildren() do
		if card.Name == "Notice" then
			table.insert(found, card)
		end
	end
	return found
end
context.NotificationController.showNotification("BuildingStole", "Your Bank was stolen!")
assert(#notices() == 1 and notices()[1].Message.Text == "Your Bank was stolen!")
assert(math.abs(notices()[1].Message.TextTransparency - 0.15) < 0.0001, "Authored fade endpoint changed")
context.NotificationController.showNotification("BuildingStole", "Your Bank was stolen!")
assert(#notices() == 1, "Duplicate theft alert")
for i = 1, 30 do
	context.NotificationController.showNotification("Error", "Error " .. i)
end
assert(#notices() == 3, "Notification burst exceeded physical clone budget")
assert(template.Message.Text == "Authored template" and aspect.Parent == frame and layout.Parent == frame)
local pending = timers
timers = {}
for _, fn in pending do
	fn()
end
assert(#notices() == 3, "Fade-out cards should remain until their animation finishes")
for _, fn in timers do
	fn()
end
assert(#notices() == 0)
context.NotificationController.showNotification("BuildingStole", { Message = "Alex stole your Bank!" })
assert(notices()[1].Message.Text == "Alex stole your Bank!")
context.NotificationController.init(gui)
assert(
	#notices() == 0 and aspect.Parent == frame and not template.Visible,
	"Reinit leaked cards/destroyed authored layout"
)
print(
	"PASS: NotificationCenter authored Message template, preserved layout/transparency, theft messages, dedup, bounded bursts, fading cleanup and reinit"
)

local function event()
	local callbacks = {}
	return {
		OnClientEvent = {
			Connect = function(_, fn)
				table.insert(callbacks, fn)
				return { Disconnect = function() end }
			end,
		},
		fire = function(_, ...)
			for _, fn in callbacks do
				fn(...)
			end
		end,
	}
end
local function folder(names)
	local result = {}
	function result:FindFirstChild(name)
		return self[name]
	end
	function result:WaitForChild(name)
		return assert(self[name], name)
	end
	for name in names:gmatch("%S+") do
		result[name] = event()
	end
	return result
end
local notifications = folder(
	"CollectIncome ErrorEvent BuildingComplete BuildingStarted ItemBought BuildingDeleted GroupReward Purchased BrokeAhh BuilderLimitReached BuildingLevelUp BuildingCollected BuildingStole BuildAllComplete StockRefreshed RarityAnnounce PlaceSound"
)
local events = {
	Notifications = notifications,
	StealBuilding = folder("Stole Recieved"),
	Movement = folder("DeletedBuilding Unauthorized CannotPlace"),
	Teleport = folder("TeleportError"),
	UI = folder("MaxReached CodeFeeback"),
	FindFirstChild = function(self, name)
		return self[name]
	end,
}
context.ReplicatedStorage = { Events = events }
load("RemoteBindings", {
	script = { Parent = { Parent = {
		WaitForChild = function()
			return {}
		end,
	} } },
	require = function(value)
		return value
	end,
})(context)
context.connectNotificationEvents()
notifications.BuildingStole:fire("A building was stolen!")
assert(notices()[1].Message.Text == "A building was stolen!")
notifications.ErrorEvent:fire("Try another tile")
events.StealBuilding.Stole:fire({ thief = "Alex", level = 12, building = "Bank" })
assert(#notices() == 3)
local found = false
for _, card in notices() do
	if card.Message.Text == "Alex stole your Level 12 Bank!" then
		found = true
	end
end
assert(found, "Steal remote did not reach NotificationCenter")
events.UI.CodeFeeback:fire(false, "Invalid code")
found = false
for _, card in notices() do
	if card.Message.Text == "Invalid code" then
		found = true
	end
end
assert(found)
print("PASS: actual alert, error, theft and code feedback remote bindings reach the shared notification feed")

context.NotificationController.prepare()
notifications.ErrorEvent:fire("A startup error")
assert(#notices() == 0 and #context.pending > 0)
context.NotificationController.init(gui, true)
assert(#notices() == 0, "Queued notice appeared before HUD readiness")
context.NotificationController.flush()
assert(#notices() == 1 and notices()[1].Message.Text == "A startup error")
print("PASS: loading/Play messages queue until HUD handoff, then deduplicate through the same feed")

context.NotificationController.clearAll()
notifications.CollectIncome:fire(5000)
assert(#notices() == 0, "Cash collection must not add a notification")
print("PASS: income collection does not show a notification")

tutorialFlag.Value = true
propertySignal(tutorialFlag, "Value"):Fire()
assert(not frame.Visible and #notices() == 0, "Tutorial did not hide and clear the entire notification center")
frame.Visible = true
propertySignal(frame, "Visible"):Fire()
assert(not frame.Visible, "Another UI handler could reveal tutorial notifications")
notifications.ErrorEvent:fire("No tutorial errors in this feed")
notifications.BuildingComplete:fire("Bank")
assert(#notices() == 0, "A tutorial notification bypassed the queue gate")
context.NotificationController.prepare()
notifications.BuildingLevelUp:fire("Bank", 12)
assert(#context.pending == 0 and #notices() == 0, "Tutorial level-up notification was queued")
context.NotificationController.init(gui, true)
tutorialFlag.Value = false
context.refreshNotificationVisibility()
assert(frame.Visible)
context.NotificationController.flush()
assert(#notices() == 0, "Tutorial level-up appeared after tutorial ended")
context.NotificationController.init(gui)
notifications.BuildingLevelUp:fire("Bank", 13)
assert(
	#notices() == 1 and notices()[1].Message.Text == "Bank reached Level 13!",
	"Normal building level-ups were suppressed"
)
print("PASS: tutorial building-level-up notices are dropped before buffering; normal gameplay still displays them")
