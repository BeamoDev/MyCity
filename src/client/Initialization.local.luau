require(script.Parent:WaitForChild("bootstrap"):WaitForChild("EarlyLoading")).start()
-- Single client entry point; controllers own their feature behavior.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
require(ReplicatedStorage:WaitForChild("shared"):WaitForChild("Network")).wait()
local controllers = script.Parent:WaitForChild("controllers")
for _, module in
	{
		controllers:WaitForChild("placement"):WaitForChild("BuildingTools"),
		controllers.placement:WaitForChild("ExpandHighlight"),
		controllers:WaitForChild("social"):WaitForChild("ChatTags"),
		controllers:WaitForChild("systems"):WaitForChild("ResetButton"),
		controllers:WaitForChild("ui"):WaitForChild("ProximityPromptController"),
	}
do
	task.spawn(function()
		require(module).start()
	end)
end
local Init = require(script.Parent:WaitForChild("bootstrap"):WaitForChild("HudBootstrap"))
local playerGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
local function initialize(hud)
	if hud.Name == "HUD" and hud:IsA("ScreenGui") then
		Init.initialize(hud)
	end
end
playerGui.ChildAdded:Connect(initialize)
local hud = playerGui:FindFirstChild("HUD")
if hud then
	initialize(hud)
end
