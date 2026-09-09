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
	return result
end
function Snapshot.nearest(position, providers)
	local nearestSquared, range = math.huge, 0
	for _, provider in providers do
		local delta = position - provider.position
		local squared = delta:Dot(delta)
		if squared < nearestSquared then
			nearestSquared, range = squared, provider.range
		end
	end
	return math.sqrt(nearestSquared), range
end
return Snapshot
