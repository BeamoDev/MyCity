-- Hold characters before any data/asset dependency can yield. Released after the client Play handoff.
local Players = game:GetService("Players")
local Guard = {}
local states = {}
local started = false
local function watch(player)
	if states[player] then
		return
	end
	local state = { roots = {}, connections = {} }
	states[player] = state
	local function hold(character)
		local function bind(root)
			if root.Name ~= "HumanoidRootPart" or not root:IsA("BasePart") or states[player] ~= state then
				return
			end
			if state.roots[root] == nil then
				state.roots[root] = root.Anchored
			end
			root:SetAttribute("MyCitySpawnHeld", true)
			root.Anchored = true
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
		end
		local root = character:FindFirstChild("HumanoidRootPart")
		if root then
			bind(root)
		end
		table.insert(state.connections, character.ChildAdded:Connect(bind))
	end
	table.insert(state.connections, player.CharacterAdded:Connect(hold))
	if player.Character then
		hold(player.Character)
	end
end
function Guard.release(player)
	if player:GetAttribute("MyCityLoaded") ~= true or player:GetAttribute("MyCityLeaving") then
		return
	end
	local state = states[player]
	if not state then
		return
	end
	states[player] = nil
	for _, connection in state.connections do
		connection:Disconnect()
	end
	for root, anchored in state.roots do
		if root.Parent then
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
			root.Anchored = anchored
			root:SetAttribute("MyCitySpawnHeld", nil)
		end
	end
	player:SetAttribute("MyCityPlaying", true)
end
function Guard.start()
	if started then
		return
	end
	started = true
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(player)
		local state = states[player]
		states[player] = nil
		if state then
			for _, connection in state.connections do
				connection:Disconnect()
			end
		end
	end)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
end
return Guard
