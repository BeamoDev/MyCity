local fs = require("@lune/fs")
local luau = require("@lune/luau")
local r = require("@lune/roblox")
local function node(fields)
	fields = fields or {}
	function fields:FindFirstChild(name)
		return self[name]
	end
	return fields
end
local function signal()
	local entries = {}
	return {
		Connect = function(_, fn)
			local entry = { fn = fn, connected = true }
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
					entry.fn(...)
				end
			end
		end,
	}
end
local function value(v)
	local event = signal()
	return {
		Value = v,
		GetPropertyChangedSignal = function()
			return event
		end,
		changed = event,
	}
end
local function remote()
	return {
		calls = 0,
		OnClientEvent = signal(),
		FireServer = function(self)
			self.calls += 1
		end,
	}
end
local queue = {}
local scope = { threads = {} }
function scope:connect(event, callback)
	return event:Connect(callback)
end
function scope:defer(fn)
	local thread = coroutine.create(fn)
	self.threads[thread] = true
	table.insert(queue, thread)
	return thread
end
scope.spawn = scope.defer
local function drain()
	local pending = queue
	queue = {}
	for _, thread in pending do
		if coroutine.status(thread) == "suspended" then
			assert(coroutine.resume(thread))
		end
	end
end
local fakeTask = { wait = coroutine.yield, cancel = coroutine.close }
local events = { GiveBank = remote(), ToolEquipped = remote(), DisplayPlace = remote(), ShopOpened = remote() }
local finished = remote()
local stage, active = value(0), value(true)
local first, second = { Frame = { Start = { Activated = signal() } } }, { Frame = { Start = { Activated = signal() } } }
local uiStatus = false
local state = {
	TutorialStageOne = first,
	TutorialStageTwo = second,
	serverTutorial = { ServerStage = stage, IsInTutorial = active },
	playerGui = { TutorialHandler = {} },
	ButtonFolder = {},
	FramesFolder = node({ TutorialItemShop = {} }),
	UIController = {
		finishTutorial = function(callback)
			callback()
		end,
		closeUIFrame = function(frame)
			frame.Visible = false
		end,
		openUIFrame = function(frame)
			frame.Visible = true
		end,
		updateTutorialStatus = function(v)
			uiStatus = v
		end,
	},
}
local context = {
	State = state,
	tutorialState = { connections = {} },
	TutorialController = {},
	connections = scope,
	ReplicatedStorage = { Events = { Tutorial = events, TutorialFinished = finished } },
	updateTutorialText = function(text)
		state.lastText = text
	end,
	cleanupCameraOrbit = function() end,
	cleanupBeam = function() end,
	cleanupIncomeHover = function() end,
	clearTileHighlights = function() end,
	createTileHighlights = function() end,
	refreshPlacementHighlights = function() end,
	player = {
		GetAttributeChangedSignal = function()
			return signal()
		end,
	},
	setupOrbitCamera = function() end,
	getPlayerPlot = function()
		return nil
	end,
	showcaseShopItems = function()
		coroutine.yield()
		error("Stale shop presentation survived")
	end,
}
function context.cleanupTutorial()
	context.cancelStagePresentation()
	context.tutorialState.isActive = false
	state.ButtonFolder.Visible = true
end
luau.load(
	fs.readFile("src/client/controllers/tutorial/TutorialController/Stages.luau"),
	{ environment = { task = fakeTask } }
)()(context)
context.connectTutorialEvents()
context.TutorialController.startTutorial()
drain()
assert(first.Visible and uiStatus and state.FramesFolder.Visible)
first.Frame.Start.Activated:Fire()
assert(events.GiveBank.calls == 1 and stage.Value == 0, "Client must not grant its own stage")
local function advance(v)
	stage.Value = v
	stage.changed:Fire()
	drain()
end
advance(2)
advance(3)
second.Frame.Start.Activated:Fire() -- absent streamed plot is safe
assert(context.tutorialState.currentStage == 4)
advance(4)
local oldShop = context.tutorialState.stageThread
assert(coroutine.status(oldShop) == "suspended")
advance(5)
assert(coroutine.status(oldShop) == "dead" and state.lastText == "Place your new Shack!")
advance(7) -- direct jump / instant completion also works
local finalThread = context.tutorialState.stageThread
assert(coroutine.resume(finalThread))
assert(finished.calls == 0, "Completion subtitle was skipped")
assert(coroutine.resume(finalThread))
assert(finished.calls == 1 and context.tutorialState.isActive and uiStatus)
assert(coroutine.resume(finalThread))
assert(finished.calls == 2, "Busy server can retry completion")
active.Value = false
active.changed:Fire()
assert(not context.tutorialState.isActive and not uiStatus and coroutine.status(finalThread) == "dead")

-- Exercise actual camera ownership: late zoom cancellation, exact restoration,
-- and safe cleanup without an active orbit.
queue = {}
local rendered = signal()
local camera =
	{ CameraType = "OriginalType", CameraSubject = "OriginalSubject", FieldOfView = 81, CFrame = r.CFrame.new(4, 5, 6) }
local originalCFrame = camera.CFrame
local characterRoot = { Anchored = true, Parent = true }
local zooms = 0
local plot = node({
	Buildings = node({
		Construction = {
			GetChildren = function()
				return {
					node({
						Base = { Position = r.Vector3.zero },
						GetAttribute = function(_, key)
							return if key == "BuildingType" then "Bank" else "target"
						end,
					}),
				}
			end,
		},
	}),
})
local cameraContext = {
	State = {},
	tutorialState = {},
	TutorialController = {},
	connections = scope,
	player = {
		Character = node({ HumanoidRootPart = characterRoot }),
		GetAttribute = function()
			return "target"
		end,
	},
	getPlayerPlot = function()
		return plot
	end,
	RunService = { RenderStepped = rendered },
	TweenService = {
		Create = function()
			zooms += 1
			return { Play = function() end, Cancel = function() end }
		end,
	},
}
luau.load(fs.readFile("src/client/controllers/tutorial/TutorialController/Camera.luau"), {
	environment = {
		game = { Workspace = { CurrentCamera = camera } },
		Enum = { CameraType = { Scriptable = "Scriptable" } },
		Vector3 = r.Vector3,
		CFrame = r.CFrame,
		task = fakeTask,
	},
})()(cameraContext)
cameraContext.cleanupCameraOrbit()
assert(camera.FieldOfView == 81 and characterRoot.Anchored)
cameraContext.setupOrbitCamera("Bank", true)
local zoomThread = queue[1]
drain()
assert(camera.CameraType == "Scriptable" and camera.FieldOfView == 55)
cameraContext.cleanupCameraOrbit()
assert(camera.CameraType == "OriginalType" and camera.CameraSubject == "OriginalSubject")
assert(camera.FieldOfView == 81 and camera.CFrame == originalCFrame and characterRoot.Anchored)
assert(zooms == 0 and coroutine.status(zoomThread) == "dead", "Zoom must not start after cleanup")
plot = nil
cameraContext.setupOrbitCamera("Bank", true)
assert(camera.FieldOfView == 81)
-- Old subtitle animation completions cannot overwrite the current instruction.
local tweens = {}
local message = node({ Text = "Original" })
local subtitleContext = {
	State = { TutorialFrame = node({ StatusMessage = message }) },
	connections = scope,
	TweenService = {
		Create = function()
			local tween = { Completed = signal(), Play = function() end }
			function tween:Cancel()
				self.Completed:Fire("Cancelled")
			end
			table.insert(tweens, tween)
			return tween
		end,
	},
}
luau.load(fs.readFile("src/client/controllers/tutorial/TutorialController/Subtitles.luau"), {
	environment = {
		game = {
			GetService = function()
				return node()
			end,
		},
		TweenInfo = {
			new = function()
				return {}
			end,
		},
		Enum = { EasingStyle = { Quad = "Quad" }, EasingDirection = { Out = "Out" } },
		UDim2 = r.UDim2,
		Vector2 = r.Vector2,
	},
})()(subtitleContext)
subtitleContext.updateTutorialText("Old instruction")
local oldMove = tweens[2]
subtitleContext.updateTutorialText("Current instruction")
oldMove.Completed:Fire()
assert(message.Text == "Original")
tweens[4].Completed:Fire()
assert(message.Text == "Current instruction")
subtitleContext.clearSubtitleTweens()
oldMove.Completed:Fire()
assert(message.Text == "Current instruction")

print(
	"PASS: replicated tutorial catch-up, canceled stale stage, touch activation, missing plot, completion retry/ack, camera ownership and canceled zoom"
)
