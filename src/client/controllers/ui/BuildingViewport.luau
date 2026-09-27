-- Shared client renderer for building thumbnails outside inventory/Satchel.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Renderer, entries, connection = {}, {}, nil
local elapsed, accumulator = 0, 0
local UPDATE_INTERVAL, RELEASE_DELAY, FIELD_OF_VIEW = 1 / 30, 2, 35
function Renderer.cameraDistance(size, fieldOfView)
	return math.max(size.Magnitude * 0.5, 1) / math.tan(math.rad((fieldOfView or FIELD_OF_VIEW) * 0.5)) * 1.08
end
function Renderer.lightingState()
	return Color3.fromRGB(145, 145, 155), Color3.fromRGB(255, 244, 225), Vector3.new(-1, -1, -0.65)
end
local function applyLighting(viewport)
	viewport.Ambient, viewport.LightColor, viewport.LightDirection = Renderer.lightingState()
end
local function shown(gui)
	local current = gui
	while current do
		if current:IsA("GuiObject") and not current.Visible then return false end
		if current:IsA("LayerCollector") and not current.Enabled then return false end
		current = current.Parent
	end
	return true
end
local function visible(entry)
	if not shown(entry.viewport) then return false end
	local clip = entry.clip
	if not clip then return true end
	local p, s, cp, cs = entry.viewport.AbsolutePosition, entry.viewport.AbsoluteSize, clip.AbsolutePosition, clip.AbsoluteSize
	return p.X + s.X > cp.X and p.X < cp.X + cs.X and p.Y + s.Y > cp.Y and p.Y < cp.Y + cs.Y
end
local function release(entry)
	if entry.model then entry.model:Destroy(); entry.model, entry.pivotOffset = nil, nil end
end
local function populate(entry)
	if entry.model then return true end
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local previews = assets and assets:FindFirstChild("BuildingPreviews")
	local template = previews and previews:FindFirstChild(entry.buildingName)
	if not (template and template:IsA("Model")) then return false end
	local model = template:Clone()
	model.Name = "Building"
	local hitbox = model:FindFirstChild("Hitbox")
	if hitbox then hitbox:Destroy() end
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			item.Anchored, item.CanCollide, item.CanTouch, item.CanQuery = true, false, false, false
		elseif item:IsA("LayerCollector") or item:IsA("ProximityPrompt") or item:IsA("LuaSourceContainer") then item:Destroy() end
	end
	model.Parent = entry.world
	local bounds, size = model:GetBoundingBox()
	entry.pivotOffset, entry.model = bounds:ToObjectSpace(model:GetPivot()), model
	entry.camera.CFrame = CFrame.lookAt(Vector3.new(0.85, 0.55, 1.35).Unit * Renderer.cameraDistance(size), Vector3.zero)
	return true
end
local function stopIfEmpty()
	if #entries == 0 and connection then connection:Disconnect(); connection = nil; elapsed, accumulator = 0, 0 end
end
local function update(dt)
	elapsed, accumulator = elapsed + dt, accumulator + dt
	if accumulator < UPDATE_INTERVAL then return end
	accumulator %= UPDATE_INTERVAL
	local active = {}
	for _, entry in entries do
		if entry.viewport.Parent and entry.host.Parent then
			table.insert(active, entry)
			if visible(entry) then
				entry.lastVisible = elapsed; applyLighting(entry.viewport)
				if populate(entry) then entry.model:PivotTo(CFrame.Angles(0, elapsed * entry.speed, 0) * entry.pivotOffset) end
			elseif entry.model and elapsed - entry.lastVisible >= RELEASE_DELAY then release(entry) end
		else release(entry) end
	end
	entries = active; stopIfEmpty()
end
function Renderer.detach(host)
	local active = {}
	for _, entry in entries do
		if entry.host == host then release(entry); if entry.viewport.Parent then entry.viewport:Destroy() end else table.insert(active, entry) end
	end
	entries = active; stopIfEmpty()
end
function Renderer.attach(host, buildingName, options)
	if not (host and host:IsA("GuiObject") and type(buildingName) == "string" and buildingName ~= "") then return nil end
	Renderer.detach(host)
	if host:IsA("ImageLabel") or host:IsA("ImageButton") then host.Image = "" end
	host.ClipsDescendants = true
	local viewport = Instance.new("ViewportFrame")
	viewport.Name, viewport.Size, viewport.BackgroundTransparency, viewport.BorderSizePixel = "BuildingViewport", UDim2.fromScale(1, 1), 1, 0
	viewport.ZIndex, viewport.Parent = host.ZIndex, host; applyLighting(viewport)
	local world = Instance.new("WorldModel"); world.Name, world.Parent = "PreviewWorld", viewport
	local camera = Instance.new("Camera"); camera.Name, camera.FieldOfView, camera.Parent = "PreviewCamera", FIELD_OF_VIEW, viewport
	viewport.CurrentCamera = camera
	table.insert(entries, { host = host, viewport = viewport, world = world, camera = camera, buildingName = buildingName, clip = options and options.clip, speed = math.rad((options and options.degreesPerSecond) or 18), lastVisible = elapsed })
	if not connection then connection = RunService.RenderStepped:Connect(update) end
	return viewport
end
return Renderer
