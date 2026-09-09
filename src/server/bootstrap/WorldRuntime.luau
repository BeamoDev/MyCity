-- Runtime-only folders and client render templates. Authoritative models remain server-only.
local World = {}
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
function World.start()
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
			local copy = assert(model:Clone(), "Building must be Archivable: " .. model.Name)
			for _, child in copy:GetDescendants() do
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
			task.wait() -- One template per frame, once per server; never blocks early loading presentation.
		end
	end
end
return World
