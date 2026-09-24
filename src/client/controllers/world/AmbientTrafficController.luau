local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Model = require(ReplicatedStorage:WaitForChild("shared"):WaitForChild("visuals"):WaitForChild("AmbientModel"))
local Trip = require(ReplicatedStorage:WaitForChild("shared"):WaitForChild("visuals"):WaitForChild("AmbientTrip"))
local Controller = {}
local started = false
function Controller.start()
	if started then
		return
	end
	started = true
	local runtime = ReplicatedStorage:WaitForChild("Runtime", 30)
	local trips = runtime and runtime:WaitForChild("AmbientTraffic", 30)
	if not trips then
		return
	end
	local misc = Workspace:WaitForChild("Misc")
	local folder = Instance.new("Folder")
	folder.Name, folder.Parent = "AmbientVehicles", misc
	local entries = {}
	local function remove(trip)
		local entry = entries[trip]
		if entry and entry.model then
			entry.model:Destroy()
		end
		entries[trip] = nil
	end
	local function add(trip)
		if not entries[trip] then
			entries[trip] = {}
		end
	end
	trips.ChildAdded:Connect(add)
	trips.ChildRemoved:Connect(remove)
	for _, trip in trips:GetChildren() do
		add(trip)
	end
	RunService.RenderStepped:Connect(function()
		local now = Workspace:GetServerTimeNow()
		local created = 0
		for trip, entry in entries do
			if trip.Parent ~= trips then
				remove(trip)
				continue
			end
			local first, last = trip:GetAttribute("First"), trip:GetAttribute("Last")
			local duration, time = trip:GetAttribute("Duration"), trip:GetAttribute("Started")
			if entry.path == nil then
				-- Road cars follow waypoints; highway/train trips are a single straight line.
				entry.path = Trip.readPath(trip) or false
			end
			local target, finished
			if entry.path then
				target, finished = Trip.along(entry.path, duration, time, now)
			else
				target, finished = Trip.position(first, last, duration, time, now)
			end
			if not target then
				continue
			end
			if finished then
				if entry.model then
					entry.model:Destroy()
					entry.model = nil
				end
				continue
			end
			if not entry.model and created < 2 and now >= (entry.retryAt or 0) then
				entry.retryAt = now + 1
				local assets = ReplicatedStorage:FindFirstChild("Assets")
				local templates = assets and assets:FindFirstChild(trip:GetAttribute("TemplateFolder") or "")
				local template = templates
					and Model.find(templates, trip:GetAttribute("TemplateId"), trip:GetAttribute("TemplateName"))
				if template then
					local ok, model, pivot = pcall(Model.create, template, folder, target)
					if ok then
						entry.model, entry.pivot = model, pivot
					end
					created += 1
				end
			end
			if entry.model then
				entry.model:PivotTo(target * entry.pivot)
			end
		end
	end)
end
return Controller
