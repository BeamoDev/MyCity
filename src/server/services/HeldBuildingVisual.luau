-- Match KingdomWars' held miniature, using MyCity's normal building assets.
local Visual = {}
local MAX_SIZE = 1.7
local OFFSET = CFrame.new(0, 0.65, 0) * CFrame.Angles(0, math.rad(180), 0)

local function prepare(template, buildingName)
	local model = template:Clone()
	model.Name = "HeldBuildingVisual"
	-- Remove behavior before the clone enters a replicated container.
	for _, item in model:GetDescendants() do
		if
			item:IsA("LuaSourceContainer")
			or item:IsA("ProximityPrompt")
			or item:IsA("BillboardGui")
			or item:IsA("SurfaceGui")
			or item:IsA("Highlight")
			or item:IsA("Sound")
			or item:IsA("Constraint")
			or item:IsA("JointInstance")
		then
			item:Destroy()
		end
	end
	local parts = {}
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			table.insert(parts, item)
		end
	end
	if #parts == 0 then
		model:Destroy()
		return
	end
	local _, size = model:GetBoundingBox()
	local largest = math.max(size.X, size.Y, size.Z)
	if largest <= 0 or largest == math.huge or largest ~= largest then
		model:Destroy()
		return
	end
	local scaled = pcall(function()
		model:ScaleTo(model:GetScale() * MAX_SIZE / largest)
	end)
	if not scaled then
		model:Destroy()
		warn("[ToolFactory] Could not scale held model: " .. buildingName)
		return
	end
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.4, 0.4, 0.4)
	handle.Transparency = 1
	handle.Anchored = false
	handle.CanCollide, handle.CanQuery, handle.CanTouch = false, false, false
	handle.Massless = true
	local primary = model.PrimaryPart or model:FindFirstChild("Base") or model:FindFirstChild("Hitbox")
	if primary and primary:IsA("BasePart") then
		model:PivotTo((handle.CFrame * OFFSET) * primary.CFrame:Inverse() * model:GetPivot())
	else
		model:PivotTo(handle.CFrame * OFFSET)
	end
	for _, part in parts do
		part.Anchored = false
		part.CanCollide, part.CanQuery, part.CanTouch = false, false, false
		part.Massless = true
		local weld = Instance.new("WeldConstraint")
		weld.Name = "HeldBuildingWeld"
		weld.Part0, weld.Part1, weld.Parent = handle, part, part
	end
	local container = Instance.new("Folder")
	handle.Parent, model.Parent = container, container
	return container
end
local cache = {}
local serial = 0
function Visual.attach(tool, buildingName)
	local buildings = game:GetService("ServerStorage"):FindFirstChild("Buildings")
	local template = buildings and buildings:FindFirstChild(buildingName)
	if not template or not template:IsA("Model") then
		warn("[ToolFactory] Missing held model: ServerStorage.Buildings." .. buildingName)
		return
	end
	serial += 1
	local entry = cache[buildingName]
	if entry and entry.source ~= template then
		entry.model:Destroy()
		cache[buildingName], entry = nil, nil
	end
	if not entry then
		local model = prepare(template, buildingName)
		if not model then
			return
		end
		entry = { source = template, model = model }
		cache[buildingName] = entry
	end
	entry.used = serial
	local clone = entry.model:Clone()
	for _, child in clone:GetChildren() do
		child.Parent = tool
	end
	clone:Destroy()
	tool.RequiresHandle = true
	tool.Grip = CFrame.Angles(0, math.rad(90), 0)
	tool:SetAttribute("HeldBuildingType", buildingName)
	local count, oldestName, oldest = 0, nil, math.huge
	for name, value in cache do
		count += 1
		if value.used < oldest then
			oldest, oldestName = value.used, name
		end
	end
	if count > 32 then
		cache[oldestName].model:Destroy()
		cache[oldestName] = nil
	end
end
return Visual
