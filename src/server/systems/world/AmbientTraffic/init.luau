-- Server owns route occupancy and lifetimes; clients render cosmetic models from immutable trips.
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Routes = require(script.Routes)
local Traffic = {}
local running, heartbeat = {}, nil
local function retire(state, index)
	local entry = state.active[index]
	entry.model:Destroy()
	state.occupied[entry.route] = nil
	table.remove(state.active, index)
end
local function spawn(state)
	local choices = {}
	for _, route in state.routes do
		if not state.config.ExclusiveRoute or not state.occupied[route] then
			table.insert(choices, route)
		end
	end
	if #choices == 0 then
		return
	end
	local route = choices[math.random(1, #choices)]
	local offset = math.random(-state.config.LaneOffset * 10, state.config.LaneOffset * 10) / 10
	local first, last, duration = Routes.trip(route, offset, state.config.Duration, state.config.Speed)
	local template = state.templates[math.random(1, #state.templates)]
	local model = Instance.new("Folder")
	state.serial += 1
	model.Name = state.config.System .. "_" .. state.serial
	model:SetAttribute("TemplateFolder", state.config.Templates)
	model:SetAttribute("TemplateName", template.Name)
	model:SetAttribute("First", first)
	model:SetAttribute("Last", last)
	model:SetAttribute("Duration", duration)
	model:SetAttribute("Started", Workspace:GetServerTimeNow())
	model.Parent = state.folder
	table.insert(state.active, {
		model = model,
		first = first,
		last = last,
		duration = duration,
		started = state.time,
		route = route,
	})
	state.occupied[route] = true
end
local function step(state, dt)
	state.time += dt
	for index = #state.active, 1, -1 do
		local entry = state.active[index]
		local alpha = math.clamp((state.time - entry.started) / entry.duration, 0, 1)
		if not entry.model.Parent or alpha >= 1 then
			retire(state, index)
		end
	end
	if state.time >= state.nextSpawn then
		state.nextSpawn = state.time + math.random(state.config.MinInterval * 10, state.config.MaxInterval * 10) / 10
		if #state.active < state.config.Limit then
			local ok, err = pcall(spawn, state)
			if not ok then
				warn("[AmbientTraffic] Spawn failed:", err)
			end
		end
	end
end
function Traffic.new(config)
	local api, state = {}, nil
	function api.init()
		if state then
			return
		end
		local map = Workspace:FindFirstChild("Map")
		local environment = map and map:FindFirstChild("Enviorment")
		local system = environment and environment:FindFirstChild(config.System)
		local assets = ReplicatedStorage:FindFirstChild("Assets")
		local source = assets and assets:FindFirstChild(config.Templates)
		if not system or not source then
			warn("[AmbientTraffic] Missing", config.System, "or Assets." .. config.Templates)
			return
		end
		local routes = Routes.read(system:FindFirstChild("Points"), config.Routes)
		local templates = {}
		for _, template in source:GetChildren() do
			if template:IsA("Model") and (not config.Template or template.Name == config.Template) then
				table.insert(templates, template)
			end
		end
		if #routes == 0 or #templates == 0 then
			warn("[AmbientTraffic] No valid routes/templates for", config.System)
			return
		end
		local runtime = ReplicatedStorage:FindFirstChild("Runtime")
		if not runtime then
			runtime = Instance.new("Folder")
			runtime.Name, runtime.Parent = "Runtime", ReplicatedStorage
		end
		local folder = runtime:FindFirstChild("AmbientTraffic")
		if not folder then
			folder = Instance.new("Folder")
			folder.Name, folder.Parent = "AmbientTraffic", runtime
		end

		state = {
			config = config,
			serial = 0,
			folder = folder,
			templates = templates,
			routes = routes,
			active = {},
			occupied = {},
			time = 0,
			nextSpawn = 0,
		}
		running[state] = true
		if not heartbeat then
			heartbeat = RunService.Heartbeat:Connect(function(dt)
				for current in running do
					step(current, dt)
				end
			end)
		end
	end
	function api.stop()
		if not state then
			return
		end
		running[state] = nil
		for i = #state.active, 1, -1 do
			retire(state, i)
		end
		state = nil
		if not next(running) and heartbeat then
			heartbeat:Disconnect()
			heartbeat = nil
		end
	end
	return api
end
return Traffic
