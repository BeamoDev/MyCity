local Controller = {}
local started = false
function Controller.start()
	if started then
		return
	end
	started = true
	-- Building tool behavior lives here instead of depending on an unsynced Tool.Init.
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	local player = Players.LocalPlayer
	local ToolHandler = require(script.Parent:WaitForChild("ToolsModule"))

	local observedTools = setmetatable({}, { __mode = "k" })
	local function initializeTool(tool)
		if not tool:IsA("Tool") or observedTools[tool] then
			return
		end
		observedTools[tool] = true
		local childConnection, destroyConnection
		local initializing = false
		local function disconnect()
			if childConnection then
				childConnection:Disconnect()
			end
			if destroyConnection then
				destroyConnection:Disconnect()
			end
		end
		local function tryInitialize()
			-- Slow replication must not permanently strand an otherwise valid Tool.
			if
				initializing
				or not tool.Parent
				or not tool:FindFirstChild("ToolName")
				or not tool:FindFirstChild("IsValid")
			then
				return
			end
			initializing = true
			disconnect()
			task.spawn(function()
				ToolHandler.init(tool)
			end)
		end
		childConnection = tool.ChildAdded:Connect(tryInitialize)
		destroyConnection = tool.Destroying:Connect(disconnect)
		tryInitialize()
	end

	local watchedContainers = setmetatable({}, { __mode = "k" })
	local function watchContainer(container)
		if watchedContainers[container] then
			return
		end
		watchedContainers[container] = true
		container.ChildAdded:Connect(initializeTool)
		for _, tool in ipairs(container:GetChildren()) do
			task.spawn(initializeTool, tool)
		end
	end

	player.CharacterAdded:Connect(watchContainer)
	player.ChildAdded:Connect(function(child)
		if child:IsA("Backpack") then
			watchContainer(child)
		end
	end)
	if player.Character then
		watchContainer(player.Character)
	end
	watchContainer(player:WaitForChild("Backpack"))
end
return Controller
