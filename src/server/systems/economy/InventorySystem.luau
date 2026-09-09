local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local Serialization = require(script.Parent.Parent.Parent.services.ToolSerialization)
local Inventory = {}
local restored = {}
local monitored = {}
local queued = {}

local function toolsFor(player)
	local result = {}
	for _, container in { player:FindFirstChild("Backpack"), player.Character } do
		if container then
			for _, tool in container:GetChildren() do
				if tool:IsA("Tool") and tool:FindFirstChild("ToolName") then
					table.insert(result, tool)
				end
			end
		end
	end
	return result
end

function Inventory.saveInventory(player)
	if not restored[player] or not player:FindFirstChild("Data") then
		return
	end
	local folder = player.Data:FindFirstChild("Inventory")
	if not folder then
		return
	end
	local entries = {}
	local seen = {}
	for _, tool in toolsFor(player) do
		local data = Serialization.encode(tool)
		if data and not (data.ToolId and seen[data.ToolId]) then
			data.ToolId = data.ToolId or HttpService:GenerateGUID(false)
			seen[data.ToolId] = true
			tool:SetAttribute("ToolId", data.ToolId)
			local value = Instance.new("StringValue")
			value.Name = "Tool_" .. data.ToolId
			value.Value = HttpService:JSONEncode(data)
			table.insert(entries, value)
		end
	end
	folder:ClearAllChildren()
	for _, entry in entries do
		entry.Parent = folder
	end
end

function Inventory.queueSave(player)
	if queued[player] or not restored[player] then
		return
	end
	queued[player] = true
	task.defer(function()
		queued[player] = nil
		Inventory.saveInventory(player)
	end)
end

function Inventory.loadInventory(player)
	if restored[player] then
		return true
	end
	local backpack = player:WaitForChild("Backpack", 10)
	local data = player:FindFirstChild("Data")
	local inventory = data and data:FindFirstChild("Inventory")
	if not backpack or not inventory then
		return false
	end
	local existing = {}
	for _, tool in toolsFor(player) do
		local id = tool:GetAttribute("ToolId")
		if id then
			existing[id] = true
		end
	end
	local prepared = {}
	for _, entry in inventory:GetChildren() do
		if entry:IsA("StringValue") then
			local ok, descriptor = pcall(HttpService.JSONDecode, HttpService, entry.Value)
			if not ok then
				return false
			end
			if type(descriptor) ~= "table" then
				return false
			end
			if not descriptor.ToolId or not existing[descriptor.ToolId] then
				local tool = Serialization.decode(descriptor)
				if not tool then
					return false
				end
				table.insert(prepared, tool)
				if descriptor.ToolId then
					existing[descriptor.ToolId] = true
				end
			end
		end
	end
	for _, tool in prepared do
		tool.Parent = backpack
	end
	restored[player] = true
	player:SetAttribute("MyCityInventoryReady", true)
	return true
end

function Inventory.startPlayer(player)
	if monitored[player] then
		return
	end
	local connections = {}
	monitored[player] = connections
	local watched = setmetatable({}, { __mode = "k" })
	local function watch(container)
		if watched[container] then
			return
		end
		watched[container] = true
		table.insert(
			connections,
			container.ChildAdded:Connect(function(child)
				if child:IsA("Tool") then
					Inventory.queueSave(player)
				end
			end)
		)
		table.insert(
			connections,
			container.ChildRemoved:Connect(function(child)
				if child:IsA("Tool") then
					Inventory.queueSave(player)
				end
			end)
		)
	end
	watch(player:WaitForChild("Backpack"))
	if player.Character then
		watch(player.Character)
	end
	table.insert(
		connections,
		player.CharacterRemoving:Connect(function()
			player:SetAttribute("MyCityInventoryReady", false)
			Inventory.saveInventory(player)
			restored[player] = nil
		end)
	)
	table.insert(
		connections,
		player.CharacterAdded:Connect(function(character)
			task.defer(function()
				if player:GetAttribute("MyCityLeaving") then
					return
				end
				if not Inventory.loadInventory(player) then
					player:SetAttribute("MyCityLeaving", true)
					player:Kick("Your inventory could not be restored. Please rejoin.")
					return
				end
				watch(character)
				watch(player:WaitForChild("Backpack"))
			end)
		end)
	)
end

function Inventory.cleanup(player)
	for _, connection in monitored[player] or {} do
		connection:Disconnect()
	end
	monitored[player], restored[player], queued[player] = nil, nil, nil
end

function Inventory.init() end
return Inventory
