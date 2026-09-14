local fs, luau, r = require("@lune/fs"), require("@lune/luau"), require("@lune/roblox")
local function signal()
	local callbacks = {}
	return {
		Connect = function(_, fn)
			local entry = { fn = fn, active = true }
			table.insert(callbacks, entry)
			return {
				Disconnect = function()
					entry.active = false
				end,
			}
		end,
		Fire = function(_, ...)
			for _, entry in callbacks do
				if entry.active then
					entry.fn(...)
				end
			end
		end,
	}
end
local all = {}
local function instance(class)
	local object = {
		ClassName = class,
		Activated = signal(),
		DescendantAdded = signal(),
		attributes = {},
		Position = r.UDim2.new(),
		Size = r.UDim2.fromScale(1, 1),
		BackgroundColor3 = r.Color3.new(1, 1, 1),
	}
	table.insert(all, object)
	function object:IsA(class)
		return self.ClassName == class
			or (class == "GuiButton" and self.ClassName == "TextButton")
			or (
				class == "GuiObject"
				and (
					self.ClassName == "Frame"
					or self.ClassName == "TextLabel"
					or self.ClassName == "TextButton"
					or self.ClassName == "ScrollingFrame"
				)
			)
	end
	function object:GetChildren()
		local children = {}
		for _, child in all do
			if child.Parent == self then
				table.insert(children, child)
			end
		end
		return children
	end
	function object:FindFirstChild(name, recursive)
		for _, child in (if recursive then self:GetDescendants() else self:GetChildren()) do
			if child.Name == name then
				return child
			end
		end
	end
	function object:FindFirstChildOfClass(className)
		for _, child in self:GetChildren() do
			if child.ClassName == className then
				return child
			end
		end
	end
	function object:Clone()
		local clone = instance(self.ClassName)
		for key, value in self do
			if type(value) ~= "function" and type(value) ~= "table" and key ~= "Parent" then
				clone[key] = value
			end
		end
		clone.attributes = table.clone(self.attributes)
		for _, child in self:GetChildren() do
			local copy = child:Clone()
			copy.Parent = clone
		end
		return clone
	end
	function object:GetDescendants()
		local descendants = {}
		local function visit(parent)
			for _, child in parent:GetChildren() do
				table.insert(descendants, child)
				visit(child)
			end
		end
		visit(self)
		return descendants
	end
	function object:GetPropertyChangedSignal(name)
		return self:GetAttributeChangedSignal("property:" .. name)
	end
	function object:SetAttribute(name, value)
		self.attributes[name] = value
	end
	function object:GetAttribute(name)
		return self.attributes[name]
	end
	function object:GetAttributeChangedSignal(name)
		self.signals = self.signals or {}
		self.signals[name] = self.signals[name] or signal()
		return self.signals[name]
	end
	function object:Destroy()
		for _, child in self:GetChildren() do
			child:Destroy()
		end
		self.Parent = nil
		self.destroyed = true
	end
	return object
end
local shared = {
	Instance = { new = instance },
	Enum = r.Enum,
	UDim = r.UDim,
	UDim2 = r.UDim2,
	Vector2 = r.Vector2,
	Color3 = r.Color3,
	ColorSequence = r.ColorSequence,
	ColorSequenceKeypoint = r.ColorSequenceKeypoint,
	TweenInfo = {
		new = function()
			return {}
		end,
	},
	require = function(m)
		return m
	end,
}
local function load(path, env)
	return luau.load(fs.readFile(path), { environment = env or shared })()
end
local prefix = "src/client/controllers/ui/UIController/DailyQuests/"
local Style = load(prefix .. "ClaimStyle.luau")
shared.script = { Parent = { ClaimStyle = Style } }
local View = load(prefix .. "View.luau")
local Row = load(prefix .. "QuestRow.luau")
local bindButton = load(prefix .. "ButtonBinding.luau")
local function remote()
	return {
		OnClientEvent = signal(),
		calls = {},
		FireServer = function(self, ...)
			table.insert(self.calls, table.pack(...))
		end,
	}
end
local bindAlert = load("src/client/controllers/ui/UIController/ClaimAlerts.luau")
local events = { Request = remote(), Update = remote(), Claim = remote(), Result = remote() }
local gui = instance("PlayerGui")
local hud = instance("ScreenGui")
hud.Parent, hud.Enabled, hud.DisplayOrder = gui, true, 5
local frames = instance("Frame")
frames.Name, frames.Parent, frames.Visible, frames.Size = "Frames", hud, false, r.UDim2.fromScale(1, 1)
local function add(class, name, parent)
	local obj = instance(class)
	obj.Name, obj.Parent = name, parent
	return obj
end
local authored = add("Frame", "Quests", frames)
local panel = add("Frame", "Frame", authored)
local header = add("Frame", "Header", panel)
local headerText = add("TextLabel", "TextLabel", add("Frame", "Pattern", header))
local content = add("ScrollingFrame", "Content", panel)
local listLayout = add("UIListLayout", "UIListLayout", content)
local top, bottom = add("Frame", "Top", content), add("Frame", "Bottom", content)
top.Size, bottom.Size = r.UDim2.fromOffset(10, 12), r.UDim2.fromOffset(10, 24)
local template = add("Frame", "Template", panel)
local track = add("Frame", "Progress", template)
add("Frame", "Fill", track)
local templateClaim = add("TextButton", "Claim", template)
add("UIGradient", "UIGradient", templateClaim).Color = r.ColorSequence.new(r.Color3.new(1, 1, 1))
add("UIStroke", "UIStroke", templateClaim)
add("TextLabel", "TextLabel", templateClaim).Text = "Claim"
add("TextLabel", "Title", template).Text = "Original title"
add("TextLabel", "Reward", template).Text = "Original reward"
add("TextLabel", "Difficulty", template)
add("TextLabel", "Difficulty", template).Position = r.UDim2.fromScale(0, 0.8)
add("TextLabel", "Progress", template)
local close = add("TextButton", "X", panel)
local legacy = add("ScreenGui", "MyCityDailyQuests", gui)
legacy:SetAttribute("MyCityGenerated", true)
local buttons = instance("Frame")
buttons.Parent = hud
local questsButton = instance("TextButton")
questsButton.Name, questsButton.Parent = "Quests", buttons
questsButton.Active, questsButton.Interactable = false, false
local questAlert = add("Frame", "Alerts", questsButton)
questAlert.Visible = true
local player = instance("Player")
local isTutorial = false
local notices = {}
local context = {
	State = { FramesFolder = frames, HUD = hud, ButtonFolder = buttons },
	player = player,
	ReplicatedStorage = { Events = { DailyQuests = events } },
	checkTutorialStatus = function()
		return isTutorial
	end,
	NotificationController = {
		showNotification = function(_, message)
			table.insert(notices, message)
		end,
	},
	connections = {
		connect = function(_, event, fn)
			return event:Connect(fn)
		end,
		spawn = function() end,
		delay = function() end,
	},
	TweenService = {
		Create = function(_, object, _, goals)
			return {
				Play = function()
					for key, value in goals do
						object[key] = value
					end
				end,
				Cancel = function() end,
			}
		end,
	},
	UIController = {
		openUIFrame = function(frame)
			frame.Visible = true
			frame.Size = r.UDim2.fromScale(1, 1)
		end,
		closeUIFrame = function(frame)
			frame.Visible = false
		end,
	},
}
context.Camera = { FieldOfView = 70 }
context.DEFAULT_CAMERA_FIELD_OF_VIEW, context.ZOOMED_FOV, context.MAX_BLUR = 70, 60, 24
context.blurEffect = { Size = 0 }
context.Transitions = {
	cancel = function() end,
	panel = function(frame, visible)
		frame.Visible = visible
	end,
	immediate = function(frame, visible)
		frame.Visible = visible
	end,
}
local navEnv = table.clone(shared)
navEnv.game = { SoundService = { SFX = { Swoosh = { Play = function() end } } } }
load("src/client/controllers/ui/UIController/Navigation.luau", navEnv)(context)
context.checkTutorialStatus = function()
	return isTutorial
end
local questClock, questWorker = 0, nil
context.connections.spawn = function(_, fn)
	questWorker = coroutine.create(fn)
end
local env = table.clone(shared)
env.os = {
	clock = function()
		return questClock
	end,
}
env.script = { View = View, QuestRow = Row, ButtonBinding = bindButton, Parent = { ClaimAlerts = bindAlert } }
env.task = { wait = coroutine.yield }
load(prefix .. "init.luau", env)(context)
context.setupDailyQuests()
assert(not questAlert.Visible, "Quest badge visible before eligibility snapshot")
local root = context.State.DailyQuestFrame
assert(root and not root.Visible and #events.Request.calls == 1)
assert(root == authored and root.Parent == frames and legacy.destroyed)
assert(not template.Visible and not gui:FindFirstChild("MyCityDailyQuests"))
assert(top.LayoutOrder == 1 and bottom.LayoutOrder == 100 and listLayout.SortOrder == r.Enum.SortOrder.LayoutOrder)
assert(questsButton.Active and questsButton.Interactable, "Quests button input remained disabled")
context.State.questUI = { Visible = true } -- Existing post-tutorial objectives never block daily quests.
frames.Visible = false
root.Visible, root.Size = true, r.UDim2.fromScale(0, 0)
questsButton.Activated:Fire()
assert(root.Visible and root.Size == r.UDim2.fromScale(1, 1))
assert(frames.Visible, "Authored quest container stayed hidden")
questsButton.Activated:Fire()
assert(not root.Visible, "Second button activation did not close quests")
questsButton.Activated:Fire()
assert(root.Visible, "Button did not reopen quests")
context.UIController.clearStuckEffects()
assert(not root.Visible, "Menu cleanup left the independent quest layer open")
local replacement = instance("TextButton")
replacement.Name, replacement.Parent = "Quests", buttons
buttons.DescendantAdded:Fire(replacement)
buttons.DescendantAdded:Fire(replacement)
replacement.Activated:Fire()
assert(root.Visible, "Late Quests button was unbound or bound twice")
local loadingCount = 0
for _, object in all do
	if object.ClassName == "Frame" and object.Parent == content and object:GetAttribute("MyCityQuestRow") then
		loadingCount += 1
		assert(object.LayoutOrder >= 2 and object.LayoutOrder <= 7)
	end
end
assert(loadingCount == 6, "No placeholder cards appeared before the server snapshot")
assert(not template.Visible and template:FindFirstChild("Title").Text == "Original title")
local catalog = load("src/server/config/DailyQuestCatalog.luau")
local quests = {}
for i = 1, 6 do
	local q = catalog.List[i]
	table.insert(quests, {
		Id = q.Id,
		Title = q.Title,
		Difficulty = q.Difficulty,
		Metric = q.Metric,
		Target = q.Target,
		Reward = q.Reward,
		Progress = if i == 1 then q.Target else 0,
		Claimed = false,
	})
end
local snapshot = { Day = 100, ResetsAt = 101 * 86400, ServerTime = 100 * 86400, Quests = quests }
events.Update.OnClientEvent:Fire(snapshot)
assert(questAlert.Visible, "Earned unclaimed quest did not show badge")
local lateAlert = add("Frame", "Alerts", replacement)
buttons.DescendantAdded:Fire(lateAlert)
assert(lateAlert.Visible, "Late badge did not inherit eligibility")
local cards = {}
for _, object in all do
	if object.ClassName == "Frame" and object.Parent == content and object:GetAttribute("MyCityQuestRow") then
		table.insert(cards, object)
	end
end
assert(#cards == 6, "Daily board did not render six cards")
local first = cards[1]
assert(first:FindFirstChild("Title").Text == quests[1].Title)
assert(first:FindFirstChild("Reward").Text:sub(1, 2) == "+$")
local claim
for _, child in first:GetChildren() do
	if child.ClassName == "TextButton" then
		claim = child
	end
end
local claimText = claim:FindFirstChild("TextLabel")
assert(claim.Text == "" and claimText.Text == "Claim" and claim.Interactable)
assert(claim:FindFirstChild("UIStroke").Color == r.Color3.fromRGB(31, 106, 40))
local green = claim:FindFirstChild("UIGradient").Color.Keypoints
local function closeColor(a, b)
	return math.abs(a.R - b.R) < 0.00001 and math.abs(a.G - b.G) < 0.00001 and math.abs(a.B - b.B) < 0.00001
end
assert(
	closeColor(green[1].Value, r.Color3.fromRGB(68, 255, 11))
		and closeColor(green[#green].Value, r.Color3.fromRGB(174, 255, 69))
)
for i, card in cards do
	assert(card.LayoutOrder == i + 1 and card.Visible)
end
assert(headerText.Text == "Daily Quests (24H 00M)")
View.updateTimer({ Timer = headerText }, 19 * 3600 + 20 * 60)
assert(headerText.Text == "Daily Quests (19H 20M)")
local secondClaim = cards[2]:FindFirstChild("Claim")
assert(not secondClaim.Interactable and secondClaim:FindFirstChild("TextLabel").Text == "Locked")
secondClaim.Activated:Fire()
assert(#events.Claim.calls == 0)
claim.Activated:Fire()
assert(not questAlert.Visible and not lateAlert.Visible, "Pending quest still advertised as claimable")
assert(claimText.Text == "Claiming..." and not claim.Interactable)
assert(claim:FindFirstChild("UIStroke").Color == r.Color3.fromRGB(80, 80, 80))
assert(#events.Claim.calls == 1 and events.Claim.calls[1][1] == 100 and events.Claim.calls[1][2] == quests[1].Id)
claim.Activated:Fire()
assert(#events.Claim.calls == 1, "Pending claim submitted twice")
-- A rejected claim unlocks an earned reward again with the exact authored green style.
events.Result.OnClientEvent:Fire(false, "Try again")
assert(questAlert.Visible, "Failed claim did not restore badge")
assert(claim.Interactable and claimText.Text == "Claim")
assert(claim:FindFirstChild("UIStroke").Color == r.Color3.fromRGB(31, 106, 40))
assert(closeColor(claim:FindFirstChild("UIGradient").Color.Keypoints[2].Value, r.Color3.fromRGB(174, 255, 69)))
table.clear(notices)

quests[1].Claimed = true
events.Update.OnClientEvent:Fire(snapshot)
events.Result.OnClientEvent:Fire(true, "Quest complete!")
assert(not questAlert.Visible, "Claimed quest still advertised")
assert(claimText.Text == "Claimed" and not claim.Interactable and notices[1] == "Quest complete!")
-- Claimed cards sink; claimable comes first, then normalized progress (not raw counts).
assert(first.LayoutOrder == 7, "Claimed quest did not move below all unfinished quests")
quests[2].Progress, quests[2].Target = 8, 10
quests[3].Progress, quests[3].Target = 50, 100
quests[4].Progress, quests[4].Target, quests[4].Claimed = 10, 10, true
quests[5].Progress, quests[5].Target = 3, 4
quests[6].Progress, quests[6].Target = 5, 5
events.Update.OnClientEvent:Fire(snapshot)
local expectedOrders = { 6, 3, 5, 7, 4, 2 }
for i, card in cards do
	assert(card.LayoutOrder == expectedOrders[i], "Wrong quest priority for card " .. i)
	assert(card.LayoutOrder >= 2 and card.LayoutOrder <= 7)
	assert(snapshot.Quests[i].Id == quests[i].Id, "UI sorting changed the server snapshot order")
end
-- Equal percentages keep the original board order, avoiding reshuffles on each update.
quests[2].Progress = 7.5
events.Update.OnClientEvent:Fire(snapshot)
assert(cards[2].LayoutOrder == 3 and cards[5].LayoutOrder == 4)
assert(top.LayoutOrder == 1 and bottom.LayoutOrder == 100)
-- Expired boards must lose their badge and refresh even while closed.
context.UIController.closeUIFrame(root)
local requestCount = #events.Request.calls
questClock = 86400
assert(coroutine.resume(questWorker))
assert(not questAlert.Visible and #events.Request.calls == requestCount + 1)
-- Replacing a day removes only the generated cards and disconnects old claim controls.
for i = 1, 6 do
	local q = catalog.List[i + 6]
	quests[i] = {
		Id = q.Id,
		Title = q.Title,
		Difficulty = q.Difficulty,
		Metric = q.Metric,
		Target = q.Target,
		Reward = q.Reward,
		Progress = 0,
		Claimed = false,
	}
end
snapshot.Day = 101
events.Update.OnClientEvent:Fire(snapshot)
assert(not questAlert.Visible, "Fresh board retained claim badge")
assert(first.destroyed)
claim.Activated:Fire()
assert(#events.Claim.calls == 1)
context.UIController.closeUIFrame(root)
isTutorial = true
context.toggleDailyQuests()
assert(not root.Visible)
isTutorial = false
player:SetAttribute("MyCityPlacementTool", "Bank")
context.toggleDailyQuests()
assert(not root.Visible)
context.cleanupDailyQuests()
coroutine.close(questWorker)
assert(not root.destroyed and not root.Visible and context.State.DailyQuestFrame == nil)
assert(template.Parent == panel and not template.Visible and top.Parent == content and bottom.Parent == content)
assert(top.Size == r.UDim2.fromOffset(10, 12) and bottom.Size == r.UDim2.fromOffset(10, 24))
for _, child in content:GetChildren() do
	assert(not child:GetAttribute("MyCityQuestRow"))
end
print(
	"PASS: authored quest template cloning, 2-7 sorted layout with preserved spacers, countdown title, exact green/grey claims, snapshots/claims/day rollover and authored UI preservation"
)

-- Exercise the actual daily-reward binding while its authored panel stays closed.
local dailyEvents = { UpdateUI = remote(), RequestUpdate = remote(), ClaimReward = remote() }
local dailyButton = add("TextButton", "DailyReward", buttons)
local dailyAlert = add("Frame", "Alerts", dailyButton)
dailyAlert.Visible = true
local dailyFrame = add("Frame", "DailyReward", frames)
dailyFrame.Visible = false
local dailyContent = add("Frame", "Content", add("Frame", "Frame", dailyFrame))
local day = add("Frame", "Day1", dailyContent)
local claimSection = add("Frame", "Claim", day)
local claimButton = add("TextButton", "ClaimButton", claimSection)
local claimedSection = add("Frame", "Claimed", day)
local timerSection = add("Frame", "Timer", day)
local timeLabel = add("TextLabel", "Time", timerSection)
local now, workers = 0, {}
local dailyEnv = table.clone(shared)
dailyEnv.script = { Parent = { ClaimAlerts = bindAlert } }
dailyEnv.os = {
	clock = function()
		return now
	end,
}
dailyEnv.task = { wait = coroutine.yield, cancel = coroutine.close }
local dailyContext = {
	State = { DailyRewardFrame = dailyFrame, ButtonFolder = buttons },
	ReplicatedStorage = { Events = { DailyRewards = dailyEvents } },
	connections = {
		connect = context.connections.connect,
		spawn = function(_, fn)
			local thread = coroutine.create(fn)
			table.insert(workers, thread)
			assert(coroutine.resume(thread))
			return thread
		end,
	},
}
load("src/client/controllers/ui/UIController/DailyRewards.luau", dailyEnv)(dailyContext)
dailyContext.setupDailyRewardUI()
assert(not dailyAlert.Visible)
local dailySnapshot = { currentDay = 1, canClaim = false, timeUntilNext = 2, claimedDays = {} }
dailyEvents.UpdateUI.OnClientEvent:Fire(dailySnapshot)
assert(not dailyAlert.Visible and timerSection.Visible and timeLabel.Text == "00:00:02")
-- Closing the popup cannot cancel the availability refresh at the deadline.
dailyFrame:GetPropertyChangedSignal("Visible"):Fire()
now = 2
for _, worker in workers do
	if coroutine.status(worker) == "suspended" then
		assert(coroutine.resume(worker))
	end
end
assert(#dailyEvents.RequestUpdate.calls == 1, "Closed panel missed eligibility refresh or sent duplicate requests")
assert(not dailyAlert.Visible, "Badge advertised availability without server confirmation")
dailySnapshot.canClaim = true
dailyEvents.UpdateUI.OnClientEvent:Fire(dailySnapshot)
assert(dailyAlert.Visible and claimSection.Visible and not timerSection.Visible and not dailyFrame.Visible)
local lateDailyButton = add("TextButton", "DailyReward", buttons)
local lateDailyAlert = add("Frame", "Alerts", lateDailyButton)
buttons.DescendantAdded:Fire(lateDailyAlert)
assert(lateDailyAlert.Visible)
dailyEvents.UpdateUI.OnClientEvent:Fire(dailySnapshot)
claimButton.Activated:Fire()
assert(#dailyEvents.ClaimReward.calls == 1, "Repeated snapshots duplicated claim handlers")
-- A rejected claim retains eligibility; a committed claim clears both badges.
dailyEvents.UpdateUI.OnClientEvent:Fire(dailySnapshot)
assert(dailyAlert.Visible)
dailySnapshot.canClaim, dailySnapshot.timeUntilNext, dailySnapshot.claimedDays[1] = false, 86400, true
dailyEvents.UpdateUI.OnClientEvent:Fire(dailySnapshot)
assert(not dailyAlert.Visible and not lateDailyAlert.Visible and claimedSection.Visible and not claimSection.Visible)
for _, worker in workers do
	if coroutine.status(worker) == "suspended" then
		coroutine.close(worker)
	end
end
print(
	"PASS: daily reward badges follow authoritative claims, late controls and closed-panel deadlines without duplicate claim bindings"
)
