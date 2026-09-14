-- Runtime-only folders and client render templates. Authoritative models remain server-only.
local World = {}
local started = false
local Heartbeat = game:GetService("RunService").Heartbeat
local function folder(parent, name)
	local existing = parent:FindFirstChild(name)
	if existing then
		assert(existing:IsA("Folder"), name .. " must be a Folder")
		return existing
	end
	local value = Instance.new("Folder")
	value.Name = name
	value.Parent = parent
	return value
end
function World.start(isClosing)
	if started then
		return
	end
	local sliceStart, sliceCount = os.clock(), 0
	local function checkpoint(newModel)
		if isClosing and isClosing() then
			return false
		end
		if sliceCount >= 6 or os.clock() - sliceStart >= 0.003 then
			Heartbeat:Wait()
			if isClosing and isClosing() then
				return false
			end
			sliceStart, sliceCount = os.clock(), 0
		end
		if newModel then
			sliceCount += 1
		end
		return true
	end
	local misc = folder(workspace, "Misc")
	for _, name in { "PlayerAnchors", "PlayerPreviews", "Effects" } do
		folder(misc, name)
	end
	local storage = game:GetService("ServerStorage")
	local models = assert(storage:FindFirstChild("Buildings"), "Missing ServerStorage.Buildings")
	local assets = folder(game:GetService("ReplicatedStorage"), "Assets")
	local previews = folder(assets, "BuildingPreviews")
	for _, model in models:GetChildren() do
		if model:IsA("Model") then
			if not checkpoint(true) then
				return false
			end
			local copy = assert(model:Clone(), "Building must be Archivable: " .. model.Name)
			for index, child in copy:GetDescendants() do
				if index % 64 == 0 then
					if not checkpoint(false) then
						copy:Destroy()
						return false
					end
				end
				if
					child:IsA("LuaSourceContainer")
					or child:IsA("ProximityPrompt")
					or child:IsA("LayerCollector")
					or child:IsA("Sound")
					or child:IsA("ParticleEmitter")
					or child:IsA("Trail")
					or child:IsA("Beam")
				then
					child:Destroy()
				elseif child:IsA("BasePart") then
					child.Anchored = true
					child.CanCollide = false
					child.CanTouch = false
					child.CanQuery = false
				end
			end
			local old = previews:FindFirstChild(model.Name)
			if old then
				old:Destroy()
			end
			copy.Parent = previews
		end
	end
	started = true
end
return World
