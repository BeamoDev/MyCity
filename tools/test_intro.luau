local fs = require("@lune/fs")
local luau = require("@lune/luau")
local r = require("@lune/roblox")
local function signal()
	local list = {}
	return {
		Connect = function(_, fn)
			local entry = { fn = fn, on = true }
			table.insert(list, entry)
			return {
				Disconnect = function()
					entry.on = false
				end,
			}
		end,
		Fire = function(_, ...)
			for _, entry in list do
				if entry.on then
					entry.fn(...)
				end
			end
		end,
		Count = function()
			local n = 0
			for _, entry in list do
				if entry.on then
					n += 1
				end
			end
			return n
		end,
	}
end
local function node(t)
	function t:FindFirstChild(name)
		return self[name]
	end
	function t:WaitForChild(name)
		return assert(self[name], name)
	end
	return t
end
local function scenario(
	readyAtStart,
	tutorialAtStart,
	tutorialAtLoad,
	cancel,
	lateWorld,
	missingBlur,
	initialScriptable
)
	local ready = readyAtStart
	local status = { Value = tutorialAtStart }
	local play = { Interactable = false, Activated = signal() }
	local screen = node({ Enabled = true, Destroying = signal() })
	local gui = node({ Tutorial = screen, ChildAdded = signal() })
	screen.Parent = gui
	local hud = { Parent = gui, Enabled = true, Destroying = signal() }
	local progress = signal()
	local render = signal()
	local camera = {
		CameraType = if initialScriptable then "Scriptable" else "Custom",
		CameraSubject = "OldSubject",
		CFrame = r.CFrame.new(8, 9, 10),
	}
	local original = camera.CFrame
	local root = { Parent = true, Anchored = false }
	local blur = {
		Parent = true,
		Size = 3,
		IsA = function(_, kind)
			return kind == "BlurEffect"
		end,
	}
	local blurDestroyed = false
	function blur:Destroy()
		blurDestroyed = true
		self.Parent = nil
	end
	local target = {
		Parent = true,
		Position = r.Vector3.zero,
		CFrame = r.CFrame.identity,
		IsA = function(_, kind)
			return kind == "BasePart"
		end,
	}
	local player = node({
		Character = node({ HumanoidRootPart = root, Humanoid = "CurrentHumanoid" }),
		Data = node({ PlayerInfo = node({ Tutorial = node({ IsInTutorial = status }) }) }),
		GetAttribute = function(_, name)
			return name == "MyCityLoaded" and ready
		end,
		SetAttribute = function() end,
	})
	local Scope = {
		new = function()
			local scope = { entries = {} }
			function scope:connect(event, fn)
				local c = event:Connect(fn)
				table.insert(self.entries, c)
				return c
			end
			function scope:clear()
				for _, c in self.entries do
					c:Disconnect()
				end
			end
			return scope
		end,
	}
	local calls = { reveal = 0, close = 0, progress = 0 }
	local presentation = {
		create = function()
			return { play = play }
		end,
		loading = function() end,
		progress = function()
			calls.progress += 1
		end,
		reveal = function()
			calls.reveal += 1
			play.Interactable = true
		end,
		close = function()
			calls.close += 1
		end,
		sound = function() end,
	}
	local cameraModule = luau.load(fs.readFile("src/client/controllers/intro/IntroController/Camera.luau"), {
		environment = {
			Instance = {
				new = function()
					return blur
				end,
			},
			CFrame = r.CFrame,
			Vector3 = r.Vector3,
			Enum = { CameraType = { Scriptable = "Scriptable", Custom = "Custom" } },
		},
	})()
	local replicated = node({
		shared = node({ util = node({ ConnectionScope = Scope }) }),
		Events = { Loading = { LoadingProgress = { OnClientEvent = progress } } },
	})
	local services = {
		Players = { LocalPlayer = player },
		ReplicatedStorage = replicated,
		Workspace = node({ Map = node({ SpawnCam = target }), CurrentCamera = camera }),
		Lighting = node({ Blur = blur }),
		RunService = { RenderStepped = render },
	}
	local originalMap, originalCharacter = services.Workspace.Map, player.Character
	if lateWorld then
		services.Workspace.Map, services.Workspace.CurrentCamera, player.Character = nil, nil, nil
	end
	if missingBlur then
		services.Lighting.Blur = nil
	end
	local intro = luau.load(fs.readFile("src/client/controllers/intro/IntroController/init.luau"), {
		environment = {
			game = {
				GetService = function(_, name)
					return assert(services[name], name)
				end,
			},
			script = node({
				Camera = cameraModule,
				Presentation = presentation,
				Parent = { Parent = { Parent = { bootstrap = { EarlyLoading = { releaseCamera = function() end } } } } },
			}),
			require = function(module)
				return module
			end,
			task = { wait = coroutine.yield },
			warn = function(...)
				error("Unexpected intro warning")
			end,
		},
	})()
	local result
	local thread = coroutine.create(function()
		result = intro.run(hud)
	end)
	assert(coroutine.resume(thread))
	if lateWorld then
		services.Workspace.Map, services.Workspace.CurrentCamera, player.Character =
			originalMap, camera, originalCharacter
		render:Fire(1 / 60)
	end
	assert(not hud.Enabled and calls.reveal == 1 and root.Anchored and blur.Size == 12)
	assert(camera.CameraType == "Scriptable", "Original orbit not active while Play is visible")
	local beforeOrbit = camera.CFrame
	render:Fire(1 / 30)
	assert(camera.CFrame ~= beforeOrbit, "Camera remained fixed at the camera part")
	if cancel then
		intro.cleanup()
		assert(coroutine.resume(thread))
	else
		play.Activated:Fire()
		play.Activated:Fire()
		assert(coroutine.resume(thread))
		if not readyAtStart then
			assert(coroutine.status(thread) == "suspended" and result == nil, "Play bypassed server readiness")
			progress:Fire(0.4)
			status.Value, ready = tutorialAtLoad, true
			assert(coroutine.resume(thread))
		end
	end
	assert(coroutine.status(thread) == "dead")
	assert(result == not cancel)
	assert(not root.Anchored)
	if cancel then
		assert(
			camera.CameraType == (if initialScriptable then "Scriptable" else "Custom") and camera.CFrame == original
		)
	else
		assert(
			camera.CameraType == "Custom" and camera.CameraSubject == "CurrentHumanoid",
			"Play did not return camera to current character"
		)
		assert(camera.CFrame ~= original, "Play restored the stale intro camera transform")
	end
	assert(if missingBlur then blurDestroyed else blur.Size == (if cancel then 3 else 0))
	assert(render.Count() == 0 and progress.Count() == 0 and play.Activated.Count() == 0)
	if not cancel then
		assert(hud.Enabled and not screen.Enabled and calls.close == 1)
		local prior = calls.reveal
		assert(intro.run(hud) and calls.reveal == prior, "Respawn must not replay the intro")
		local replacement = {
			Name = "Tutorial",
			Enabled = true,
			IsA = function(_, kind)
				return kind == "ScreenGui"
			end,
		}
		gui.ChildAdded:Fire(replacement)
		assert(not replacement.Enabled)
	end
end
scenario(true, false, false, false) -- load already finished before Play
scenario(false, false, true, false) -- owner/tutorial status arrives late
scenario(false, false, false, false)
scenario(true, true, true, false)
scenario(true, false, false, false, false, false, true) -- initially Scriptable camera must return to character
scenario(true, false, false, true) -- interrupted HUD/session
scenario(false, false, true, false, true, false) -- character/camera/map arrive after intro starts
scenario(false, false, true, false, true, true) -- no authored BlurEffect
scenario(false, false, true, true, true, true) -- cancellation removes the owned effect
print(
	"PASS: original orbit/icon/Play before readiness, delayed loading catch-up, single Play handoff, owner tutorial intro, intro cancellation, camera/root/blur restoration and replacement GUI"
)
