local Economy = require(script.Parent.Parent.BuildingEconomy)
local Catalog = require(script.Parent.Parent.Parent.Parent.config.BuildingConfig)
local Cache = {}
local plots = setmetatable({}, { __mode = "k" })
local watchedValues = { BuildingLevel = true, HappinessPercent = true, CrimePercent = true, BuildingName = true }
local function disconnect(list)
	for _, connection in list do
		connection:Disconnect()
	end
	table.clear(list)
end
function Cache.clear(plot)
	local cache = plots[plot]
	if not cache then
		return
	end
	plots[plot] = nil
	disconnect(cache.connections)
	for _, entry in cache.entries do
		disconnect(entry.connections)
	end
end
function Cache.get(plot)
	local buildings = plot and plot:FindFirstChild("Buildings")
	local placed = buildings and buildings:FindFirstChild("Placed")
	if not placed then
		return nil
	end
	local cache = plots[plot]
	if cache and cache.placed ~= placed then
		Cache.clear(plot)
		cache = nil
	end
	if not cache then
		cache =
			{ placed = placed, entries = {}, dirty = {}, connections = {}, population = 0, listDirty = true, list = {} }
		plots[plot] = cache
		local function remove(model)
			local entry = cache.entries[model]
			if not entry then
				return
			end
			cache.population -= entry.population or 0
			disconnect(entry.connections)
			cache.entries[model], cache.dirty[model], cache.listDirty = nil, nil, true
		end
		local function add(model)
			if not model:IsA("Model") or cache.entries[model] then
				return
			end
			local entry =
				{ model = model, connections = {}, bound = setmetatable({}, { __mode = "k" }), population = 0 }
			cache.entries[model], cache.dirty[model], cache.listDirty = entry, true, true
			local function mark()
				cache.dirty[model] = true
			end
			local function bind(value)
				mark()
				if watchedValues[value.Name] and value:IsA("ValueBase") and not entry.bound[value] then
					entry.bound[value] = true
					table.insert(entry.connections, value.Changed:Connect(mark))
				end
			end
			table.insert(entry.connections, model.DescendantAdded:Connect(bind))
			table.insert(entry.connections, model.DescendantRemoving:Connect(mark))
			table.insert(entry.connections, model:GetAttributeChangedSignal("BuildingType"):Connect(mark))
			for _, value in model:GetDescendants() do
				bind(value)
			end
		end
		table.insert(cache.connections, placed.ChildAdded:Connect(add))
		table.insert(cache.connections, placed.ChildRemoved:Connect(remove))
		table.insert(
			cache.connections,
			plot.Destroying:Connect(function()
				Cache.clear(plot)
			end)
		)
		for _, model in placed:GetChildren() do
			add(model)
		end
	end
	for model in cache.dirty do
		local entry = cache.entries[model]
		if entry then
			local config = model:FindFirstChild("Config")
			local name = config and config:FindFirstChild("BuildingName")
			local kind = model:GetAttribute("BuildingType") or (name and name.Value)
			local definition = kind and Catalog[kind]
			cache.population -= entry.population or 0
			entry.population = if definition then Economy.population(definition, config) else 0
			entry.rate = if definition then Economy.income(definition, config) else 0
			entry.collected = config and config:FindFirstChild("CollectedIncome")
			cache.population += entry.population
		end
		cache.dirty[model] = nil
	end
	if cache.listDirty then
		table.clear(cache.list)
		for _, entry in cache.entries do
			table.insert(cache.list, entry)
		end
		cache.listDirty = false
	end
	return cache
end
return Cache
