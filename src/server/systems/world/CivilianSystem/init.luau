-- Cosmetic city residents. No currency, population, inventory or saved state mutations.
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Config = require(script.Config)
local Geometry = require(script.Geometry)
local Rig = require(script.Rig)
local Movement = require(script.Movement)
local System = {}
local cities = {}
local started = false
local random = Random.new()
local warnedTemplate = false
local function getPlot(player)
	if player:GetAttribute("MyCityLoaded") ~= true or player:GetAttribute("MyCityLeaving") then
		return nil
	end
	local data = player:FindFirstChild("Data")
	local info = data and data:FindFirstChild("PlotInfo")
	local number = info and info:FindFirstChild("Plot")
	local plots = Workspace:FindFirstChild("Plots")
	local plot = plots and number and plots:FindFirstChild("Plot" .. number.Value)
	return if plot and tostring(plot:GetAttribute("CityId")) == tostring(player.UserId) then plot else nil
end
function System.cleanupPlayer(player)
	local city = cities[player]
	if not city then
		return
	end
	city.active = false
	cities[player] = nil
	for _, record in city.records do
		Rig.destroy(record)
	end
	if city.ownsFolder then
		city.folder:Destroy()
	end
end
local function sync()
	local players = Players:GetPlayers()
	table.sort(players, function(a, b)
		return a.UserId < b.UserId
	end)
	for player, city in cities do
		if not player.Parent or getPlot(player) ~= city.plot or not city.folder.Parent then
			System.cleanupPlayer(player)
		end
	end
	local active, counts = {}, {}
	for _, player in players do
		local plot = getPlot(player)
		if not plot then
			continue
		end
		local city = cities[player]
		if not city then
			local folder = plot:FindFirstChild("CivilianNPCs")
			local ownsFolder = folder == nil
			if not folder then
				folder = Instance.new("Folder")
				folder.Name = "CivilianNPCs"
				folder.Parent = plot
			end
			city =
				{ plot = plot, player = player, folder = folder, ownsFolder = ownsFolder, records = {}, active = true }
			cities[player] = city
		end
		city.geometry = Geometry.snapshot(plot)
		table.insert(active, city)
		table.insert(counts, Config.desired(city.geometry.count))
	end
	local budgets = Config.allocate(counts)
	-- Remove excess across ALL cities before admitting new NPCs under the global cap.
	for i, city in active do
		for index = #city.records, 1, -1 do
			if index > budgets[i] or not city.records[index].model.Parent then
				Rig.destroy(table.remove(city.records, index))
			end
		end
		city.folder:SetAttribute("TargetCount", budgets[i])
	end
	local template = ServerStorage:FindFirstChild("Civilian")
	local size = Rig.describe(template)
	if not size and not warnedTemplate then
		warnedTemplate = true
		warn("[Civilian] ServerStorage.Civilian must be an archivable Model with a Humanoid and HumanoidRootPart")
	elseif size then
		warnedTemplate = false
	end
	for i, city in active do
		-- Stagger additions: one per city per sync, without blocking player restoration.
		if size and #city.records < budgets[i] then
			local point = Geometry.target(city.geometry, size.radius, random)
			if point then
				local ok, record = pcall(Rig.create, template, city.folder, city.player.UserId, point, size)
				if ok and record then
					table.insert(city.records, record)
				elseif not city.warnedSpawn then
					city.warnedSpawn = true
					warn("[Civilian] Could not spawn:", record)
				end
			end
		end
		city.folder:SetAttribute("VisibleCount", #city.records)
	end
end
function System.init()
	if started then
		return
	end
	started = true
	Players.PlayerRemoving:Connect(System.cleanupPlayer)
	local elapsed, nextSync = 0, 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < Config.StepInterval then
			return
		end
		elapsed = 0
		local now = os.clock()
		if now >= nextSync then
			nextSync = now + Config.SyncInterval
			local ok, err = pcall(sync)
			if not ok then
				warn("[Civilian] Sync failed:", err)
			end
		end
		for player, city in cities do
			if getPlot(player) ~= city.plot then
				System.cleanupPlayer(player)
				continue
			end
			for i = #city.records, 1, -1 do
				local record = city.records[i]
				local ok, alive = pcall(Movement.step, record, city, now, random)
				if not ok or not alive then
					if not ok and not city.warnedMovement then
						city.warnedMovement = true
						warn("[Civilian] Movement failed:", alive)
					end
					Rig.destroy(record)
					table.remove(city.records, i)
				end
			end
		end
	end)
end
return System
