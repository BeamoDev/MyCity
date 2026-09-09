-- No remotes, shared modules or world dependencies may be required before this starts.
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local Actions = game:GetService("ContextActionService")
local Early = {}
local active, started = false, false
local connections, hidden = {}, {}
local backpackEnabled = true
local function connect(signal, callback)
	table.insert(connections, signal:Connect(callback))
end
function Early.start()
	if started then
		return
	end
	started, active = true, true
	local player = Players.LocalPlayer
	player:SetAttribute("MyCityIntroActive", true)
	Actions:BindActionAtPriority("MyCityLoading", function()
		return Enum.ContextActionResult.Sink
	end, false, 10000, table.unpack(Enum.PlayerActions:GetEnumItems()))
	pcall(function()
		backpackEnabled = StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.Backpack)
	end)
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	end)
	local gui = player:WaitForChild("PlayerGui")
	local function prepare(screen)
		if not screen:IsA("ScreenGui") then
			return
		end
		if screen.Name == "Tutorial" then
			screen.Enabled = true
			local function preparePart(child)
				if child.Parent == screen and child.Name == "Loading" and child:IsA("GuiObject") then
					child.Visible = true
				end
				if child.Parent == screen and child.Name == "IntroFrame" and child:IsA("GuiObject") then
					child.Visible = false
				end
			end
			for _, child in screen:GetChildren() do
				preparePart(child)
			end
			connect(screen.ChildAdded, preparePart)
		else
			hidden[screen] = screen.Enabled
			screen.Enabled = false
			connect(screen:GetPropertyChangedSignal("Enabled"), function()
				if active and screen.Enabled then
					hidden[screen] = true
					screen.Enabled = false
				end
			end)
		end
	end
	connect(gui.ChildAdded, prepare)
	for _, screen in gui:GetChildren() do
		prepare(screen)
	end
end
function Early.finish()
	if not active then
		return
	end
	active = false
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	for screen, enabled in hidden do
		if screen.Parent then
			screen.Enabled = enabled
		end
	end
	table.clear(hidden)
	Actions:UnbindAction("MyCityLoading")
	pcall(function()
		StarterGui:SetCoreGuiEnabled(
			Enum.CoreGuiType.Backpack,
			backpackEnabled and not Players.LocalPlayer:GetAttribute("MyCitySatchelActive")
		)
	end)
	Players.LocalPlayer:SetAttribute("MyCityIntroActive", false)
end
return Early
