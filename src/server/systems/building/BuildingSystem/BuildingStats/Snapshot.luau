-- Short-lived snapshot: no persistent cache to become stale after moving/deleting a building.
local Snapshot = {}
local categories = {
	Hospital = "health",
	Clinic = "health",
	PoliceStation = "police",
	SheriffOffice = "police",
	FireStation = "fire",
	FireShed = "fire",
}
function Snapshot.position(building)
	local part = building.PrimaryPart or building:FindFirstChild("Hitbox")
	return part and part.Position
end
function Snapshot.create(plot, catalog, ranges)
	local buildings = plot and plot:FindFirstChild("Buildings")
	local placed = buildings and buildings:FindFirstChild("Placed")
	local result = {
		buildings = placed and placed:GetChildren() or {},
		health = {},
		police = {},
		fire = {},
		decorations = {},
		valid = placed ~= nil,
	}
	for _, building in result.buildings do
		local kind = building:GetAttribute("BuildingType")
		local category = categories[kind]
		local config = catalog[kind]
		if category or (config and config.IsDecoration) then
			local position = Snapshot.position(building)
			if position then
				local entry = { position = position, range = ranges[kind] }
				if category then
					table.insert(result[category], entry)
				end
				if config and config.IsDecoration then
					table.insert(result.decorations, entry)
				end
			end
		end
	end
	result.indexes = {}
	for _, category in { "health", "police", "fire", "decorations" } do
		result.indexes[category] = Snapshot.index(result[category])
	end
	return result
end
-- Spatial buckets bound service/decor queries to their effective neighbourhood.
local CELL_SIZE = 30
function Snapshot.index(entries)
	local index = { cells = {}, maxRange = 0 }
	for _, entry in entries do
		local x, z = math.floor(entry.position.X / CELL_SIZE), math.floor(entry.position.Z / CELL_SIZE)
		local key = x .. ":" .. z
		index.cells[key] = index.cells[key] or {}
		table.insert(index.cells[key], entry)
		index.maxRange = math.max(index.maxRange, entry.range or 0)
	end
	return index
end
local function visit(index, position, radius, callback)
	for x = math.floor((position.X - radius) / CELL_SIZE), math.floor((position.X + radius) / CELL_SIZE) do
		for z = math.floor((position.Z - radius) / CELL_SIZE), math.floor((position.Z + radius) / CELL_SIZE) do
			for _, entry in index.cells[x .. ":" .. z] or {} do
				if callback(entry) then
					return
				end
			end
		end
	end
end
function Snapshot.coverage(position, providers, index)
	local ratio = 1
	local function consider(provider)
		local range = provider.range or 0
		if range > 0 then
			local distance = (position - provider.position).Magnitude
			ratio = math.min(ratio, math.clamp((distance - range) / (range * 2), 0, 1))
		end
		return ratio == 0
	end
	if index and #providers > 8 then
		visit(index, position, index.maxRange * 3, consider)
	else
		for _, provider in providers do
			if consider(provider) then
				break
			end
		end
	end
	return ratio
end
function Snapshot.decorationBoost(snapshot, position, range, boost)
	local total = 0
	local function consider(entry)
		local distance = (position - entry.position).Magnitude
		if distance <= range then
			total += boost * (1 - distance / range)
		end
		return total >= 40
	end
	if snapshot.indexes and #snapshot.decorations > 8 then
		visit(snapshot.indexes.decorations, position, range, consider)
	else
		for _, entry in snapshot.decorations do
			if consider(entry) then
				break
			end
		end
	end
	return math.min(total, 40)
end
return Snapshot
