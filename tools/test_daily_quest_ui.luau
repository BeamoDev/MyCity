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
	local object = { ClassName = class, Activated = signal(), DescendantAdded = signal(), attributes = {} }
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
	function object:FindFirstChild(name)
		for _, child in self:GetChildren() do
			if child.Name == name then
				return child
			end
		end
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
local W = load(prefix .. "Widgets.luau")
shared.script = { Parent = { Widgets = W } }
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
local events = { Request = remote(), Update = remote(), Claim = remote(), Result = remote() }
local gui = instance("PlayerGui")
local hud = instance("ScreenGui")
hud.Parent, hud.Enabled, hud.DisplayOrder = gui, true, 5
local frames = instance("Frame")
frames.Parent, frames.Visible, frames.Size = hud, false, r.UDim2.fromScale(0, 0)
local buttons = instance("Frame")
buttons.Parent = hud
local questsButton = instance("TextButton")
questsButton.Name, questsButton.Parent = "Quests", buttons
questsButton.Active, questsButton.Interactable = false, false
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
local env = table.clone(shared)
env.script = { View = View, QuestRow = Row, ButtonBinding = bindButton }
env.task = { wait = function() end }
load(prefix .. "init.luau", env)(context)
context.setupDailyQuests()
local root = context.State.DailyQuestFrame
assert(root and not root.Visible and #events.Request.calls == 1)
local screen = root.Parent
assert(screen.Parent == gui and screen.DisplayOrder > hud.DisplayOrder and screen.Enabled)
assert(questsButton.Active and questsButton.Interactable, "Quests button input remained disabled")
context.State.questUI = { Visible = true } -- Existing post-tutorial objectives never block daily quests.
frames.Visible = false
root.Visible, root.Size = true, r.UDim2.fromScale(0, 0)
questsButton.Activated:Fire()
assert(root.Visible and root.Size == r.UDim2.fromScale(1, 1))
assert(not frames.Visible and frames.Size == r.UDim2.fromScale(0, 0), "Opening quests changed the authored container")
questsButton.Activated:Fire()
assert(not root.Visible, "Second button activation did not close quests")
questsButton.Activated:Fire()
assert(root.Visible, "Button did not reopen quests")
hud.Enabled = false
hud:GetPropertyChangedSignal("Enabled"):Fire()
assert(not screen.Enabled, "Generated quests ignored HUD visibility")
hud.Enabled = true
hud:GetPropertyChangedSignal("Enabled"):Fire()
assert(screen.Enabled)
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
	if object.ClassName == "Frame" and object.Parent and object.Parent.Name == "Quests" then
		loadingCount += 1
	end
end
assert(loadingCount == 6, "No placeholder cards appeared before the server snapshot")
assert(root.ZIndex == 100 and root:FindFirstChild("Panel").ZIndex > root.ZIndex)
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
local cards = {}
for _, object in all do
	if object.ClassName == "Frame" and object.Parent and object.Parent.Name == "Quests" then
		table.insert(cards, object)
	end
end
assert(#cards == 6, "Daily board did not render six cards")
local first = cards[1]
local claim
for _, child in first:GetChildren() do
	if child.ClassName == "TextButton" then
		claim = child
	end
end
assert(claim.Text == "Claim" and claim.Interactable)
claim.Activated:Fire()
assert(#events.Claim.calls == 1 and events.Claim.calls[1][1] == 100 and events.Claim.calls[1][2] == quests[1].Id)
claim.Activated:Fire()
assert(#events.Claim.calls == 1, "Pending claim submitted twice")
quests[1].Claimed = true
events.Update.OnClientEvent:Fire(snapshot)
events.Result.OnClientEvent:Fire(true, "Quest complete!")
assert(claim.Text == "Claimed" and not claim.Interactable and notices[1] == "Quest complete!")
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
assert(root.destroyed and screen.destroyed and context.State.DailyQuestFrame == nil)
print(
	"PASS: generated six-card quest UI, server snapshot progress/rewards, guarded claim controls, day replacement, tutorial/placement restrictions and cleanup"
)
