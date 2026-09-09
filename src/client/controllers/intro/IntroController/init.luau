-- Own the authored PlayerGui.Tutorial intro. HUD bootstrap remains the only initializer.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Scope = require(ReplicatedStorage:WaitForChild("shared"):WaitForChild("util"):WaitForChild("ConnectionScope"))
local Camera = require(script:WaitForChild("Camera"))
local Presentation = require(script:WaitForChild("Presentation"))
local services = {
	player = Players.LocalPlayer,
	Workspace = game:GetService("Workspace"),
	Lighting = game:GetService("Lighting"),
	RunService = game:GetService("RunService"),
}
local Intro = {}
local activeSession
local completed = false
local watchingGui
local function release(session, success)
	session.active = false
	session.scope:clear()
	for _, tween in session.tweens do
		tween:Cancel()
	end
	Camera.restore(session, success)
	services.player:SetAttribute("MyCityIntroActive", false)
	if session.hud.Parent then
		session.hud.Enabled = if success then true else session.hudEnabled
	end
	if session.screen.Parent then
		session.screen.Enabled = if success then false else session.screenEnabled
	end
	if activeSession == session then
		activeSession = nil
	end
end
function Intro.cleanup()
	if activeSession then
		release(activeSession, false)
	end
end
local function run(hud)
	Intro.cleanup()
	local gui = hud.Parent
	if not gui then
		return false
	end
	if watchingGui ~= gui then
		watchingGui = gui
		gui.ChildAdded:Connect(function(child)
			if completed and child.Name == "Tutorial" and child:IsA("ScreenGui") then
				child.Enabled = false
			end
		end)
	end
	local screen = gui:FindFirstChild("Tutorial") or gui:WaitForChild("Tutorial", 10)
	if not hud.Parent then
		return false
	end
	if not screen then
		warn("[Intro] Missing PlayerGui.Tutorial; cannot present loading/Play")
		return false
	end
	if completed then
		screen.Enabled = false
		hud.Enabled = true
		return true
	end
	local view = Presentation.create(screen)
	if not view then
		return false
	end
	local session = {
		active = true,
		scope = Scope.new(),
		tweens = {},
		view = view,
		screen = screen,
		hud = hud,
		hudEnabled = hud.Enabled,
		screenEnabled = screen.Enabled,
	}
	activeSession = session
	services.player:SetAttribute("MyCityIntroActive", true)
	hud.Enabled = false
	session.scope:connect(screen.Destroying, function()
		session.dismissed = true
	end)
	session.scope:connect(hud.Destroying, Intro.cleanup)
	local events = ReplicatedStorage.Events.Loading
	session.scope:connect(events.LoadingProgress.OnClientEvent, function(progress)
		if not session.dismissed then
			Presentation.progress(session, progress)
		end
	end)
	Camera.start(session, services)
	Presentation.loading(session)
	Presentation.progress(session, 0.1)
	-- Original presentation: orbit and reveal icon/Play without waiting on city restoration.
	-- Every join shows the authored map intro, including owner tutorial replays.
	if not session.dismissed then
		session.scope:connect(view.play.Activated, function()
			if view.play.Interactable then
				session.playRequested = true
				view.play.Interactable = false
			end
		end)
		Presentation.reveal(session)
		while session.active and not session.playRequested and not session.dismissed do
			task.wait(0.05)
		end
		if not session.active then
			return false
		end
		if not session.dismissed then
			Presentation.loading(session)
		end
		-- MyCityLoaded covers completion before this GUI existed or before Play was clicked.
		while session.active and services.player:GetAttribute("MyCityLoaded") ~= true do
			if services.player:GetAttribute("MyCityLoadFailed") or not hud.Parent then
				release(session, false)
				return false
			end
			task.wait(0.05)
		end
		if not session.active then
			return false
		end
		if not session.dismissed then
			Presentation.close(session)
		end
	end
	if not session.active then
		return false
	end
	completed = true
	release(session, true)
	Presentation.sound("SFX", "Ambience")
	return true
end
function Intro.run(hud)
	local ok, result = pcall(run, hud)
	if ok then
		return result
	end
	Intro.cleanup()
	warn("[Intro] Could not present intro:", result)
	-- Keep the server spawn hold and early overlay; a broken intro must not start gameplay.
	return false
end
return Intro
