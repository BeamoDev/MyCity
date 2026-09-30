-- A client-only visual clone rises while the server-owned building stays at its saved pivot.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local RarityColors = require(ReplicatedStorage.shared.ui.RarityColors)

local Controller = {}
local DURATION = 5.0
local active, pending = {}, {}
local connection, generation = nil, 0

function Controller.offsetForHeight(height)
	-- GetBoundingBox().Size.Y measures the full visible vertical span, regardless
	-- of where the model pivot sits within it. Translating by that full span puts
	-- the clone's initial top at its final bottom, without an arbitrary cap.
	return height
end

function Controller.ease(alpha)
	alpha = math.clamp(alpha, 0, 1)
	return 1 - (1 - alpha) ^ 3
end

local function cleanup(key)
	local entry = active[key]
	if not entry then return end
	active[key] = nil
	if entry.connection then entry.connection:Disconnect() end
	if entry.clone then entry.clone:Destroy() end
	for part, transparency in entry.hidden do
		if part.Parent then part.LocalTransparencyModifier = transparency end
	end
	for gui, enabled in entry.hiddenUi do
		if gui.Parent then gui.Enabled = enabled end
	end
end

local function run(plotName, buildingName, rarity, ownerId, token)
	local key = plotName .. "/" .. buildingName
	local plots = Workspace:WaitForChild("Plots", 5)
	local plot = plots and plots:WaitForChild(plotName, 5)
	local buildings = plot and plot:WaitForChild("Buildings", 5)
	local placed = buildings and buildings:WaitForChild("Placed", 5)
	local source = placed and placed:WaitForChild(buildingName, 5)
	if token ~= generation or not source or source.Parent ~= placed
		or tostring(plot:GetAttribute("CityId")) ~= tostring(ownerId) then
		pending[key] = nil
		return
	end
	local color = RarityColors[rarity]
	if not color or not source:IsA("Model") then pending[key] = nil return end
	local ok, clone = pcall(source.Clone, source)
	if not ok or not clone then pending[key] = nil return end
	clone.Name = "RarityRise_" .. buildingName
	clone:SetAttribute("BuildingType", nil)
	clone:SetAttribute("BuildingID", nil)
	local boundsOk, _, bounds = pcall(source.GetBoundingBox, source)
	if not boundsOk then clone:Destroy() pending[key] = nil return end
	local finalPivot = source:GetPivot()
	local offset = Controller.offsetForHeight(bounds.Y)
	local startPivot = finalPivot - Vector3.new(0, offset, 0)
	for _, item in clone:GetDescendants() do
		if item:IsA("BasePart") then
			item.Anchored = true
			item.CanCollide, item.CanTouch, item.CanQuery = false, false, false
			item.LocalTransparencyModifier = 0
		elseif item:IsA("BaseScript") or item:IsA("ProximityPrompt") or item:IsA("ClickDetector")
			or item:IsA("LayerCollector") or item:IsA("Sound") or item:IsA("ParticleEmitter")
			or item:IsA("Beam") or item:IsA("Trail") or item:IsA("Highlight") then
			item:Destroy()
		end
	end
	local runtimePlanes = clone:FindFirstChild("RuntimePlanes")
	if runtimePlanes then runtimePlanes:Destroy() end
	local highlight = Instance.new("Highlight")
	highlight.FillColor, highlight.OutlineColor = color, color
	highlight.FillTransparency, highlight.OutlineTransparency = 0.8, 0.35
	highlight.Parent = clone
	clone:PivotTo(startPivot)
	clone.Parent = Workspace:FindFirstChild("Misc") or Workspace
	local hidden = {}
	local hiddenUi = {}
	for _, item in source:GetDescendants() do
		if item:IsA("BasePart") then
			hidden[item] = item.LocalTransparencyModifier
			item.LocalTransparencyModifier = 1
		elseif item:IsA("ProximityPrompt") or item:IsA("LayerCollector") then
			hiddenUi[item] = item.Enabled
			item.Enabled = false
		end
	end
	local entry = { clone = clone, hidden = hidden, hiddenUi = hiddenUi }
	active[key] = entry
	pending[key] = nil
	local started = os.clock()
	entry.connection = RunService.RenderStepped:Connect(function()
		if token ~= generation or source.Parent ~= placed or not plot.Parent
			or tostring(plot:GetAttribute("CityId")) ~= tostring(ownerId) then
			cleanup(key)
			return
		end
		local alpha = math.min(1, (os.clock() - started) / DURATION)
		clone:PivotTo(startPivot:Lerp(finalPivot, Controller.ease(alpha)))
		if alpha >= 1 then
			clone:PivotTo(finalPivot)
			cleanup(key)
		end
	end)
end

function Controller.start()
	if connection then return end
	connection = ReplicatedStorage.Events.VFX.RarityRise.OnClientEvent:Connect(function(plotName, buildingName, rarity, ownerId)
		if type(plotName) ~= "string" or type(buildingName) ~= "string" or pending[plotName .. "/" .. buildingName]
			or active[plotName .. "/" .. buildingName] then return end
		local key = plotName .. "/" .. buildingName
		pending[key] = true
		task.spawn(run, plotName, buildingName, rarity, ownerId, generation)
	end)
end

function Controller.stop()
	generation += 1
	if connection then connection:Disconnect() connection = nil end
	for key in active do cleanup(key) end
	table.clear(pending)
end

return Controller
