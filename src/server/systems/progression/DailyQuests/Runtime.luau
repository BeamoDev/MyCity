-- Count committed city contents once per change and elapsed online time once per second.
local Runtime = {}
function Runtime.start(player, record)
	local session = { connections = {}, lastTick = os.time(), dirty = true, cityDirty = true }
	local function connect(signal, callback)
		table.insert(session.connections, signal:Connect(callback))
	end
	local info = player.Data.PlayerInfo
	local plots = workspace:FindFirstChild("Plots")
	local plot = plots and plots:FindFirstChild("Plot" .. player.Data.PlotInfo.Plot.Value)
	local buildings = plot and plot:FindFirstChild("Buildings")
	local placed = buildings and buildings:FindFirstChild("Placed")
	if placed then
		connect(placed.ChildAdded, function()
			session.cityDirty = true
		end)
		connect(placed.ChildRemoved, function()
			session.cityDirty = true
		end)
	end
	connect(info.Population:GetPropertyChangedSignal("Value"), function()
		session.cityDirty = true
	end)
	connect(info.Tutorial.IsInTutorial:GetPropertyChangedSignal("Value"), function()
		session.cityDirty = true
	end)
	function session:sample()
		local count, roads = 0, 0
		if placed then
			for _, model in placed:GetChildren() do
				if model:IsA("Model") then
					local name = model:GetAttribute("BuildingType") or model.Name:match("^(.+)_[^_]+$") or model.Name
					if string.find(string.lower(name), "road", 1, true) then
						roads += 1
					else
						count += 1
					end
				end
			end
		end
		record(player, "buildings", count)
		record(player, "roads", roads)
		record(player, "population", info.Population.Value)
		self.cityDirty = false
	end
	function session:step(now)
		-- Count only this day's portion when an online session crosses midnight.
		local elapsed = math.max(0, now - math.max(self.lastTick, math.floor(now / 86400) * 86400))
		self.lastTick = now
		record(player, "play", elapsed)
		if self.cityDirty then
			self:sample()
		end
	end
	function session:cleanup()
		for _, connection in self.connections do
			connection:Disconnect()
		end
		table.clear(self.connections)
	end
	return session
end
return Runtime
