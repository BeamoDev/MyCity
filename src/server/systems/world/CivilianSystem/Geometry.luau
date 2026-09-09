local Geometry = {}
function Geometry.snapshot(plot)
	local land, buildings = plot:FindFirstChild("Land"), plot:FindFirstChild("Buildings")
	local owned = land and land:FindFirstChild("Owned")
	local result = { tiles = {}, obstacles = {}, buildings = {}, walkways = {}, count = 0 }
	if owned then
		for _, tile in owned:GetChildren() do
			if tile:IsA("BasePart") then
				table.insert(result.tiles, tile)
			end
		end
	end
	if buildings then
		for _, name in { "Placed", "Construction" } do
			local folder = buildings:FindFirstChild(name)
			if folder then
				for _, model in folder:GetChildren() do
					if not model:IsA("Model") then
						continue
					end
					local base = model:FindFirstChild("Base") or model:FindFirstChild("Hitbox")
					if name == "Placed" then
						result.count += 1
					end
					if base and base:IsA("BasePart") then
						local buildingType = model:GetAttribute("BuildingType") or model.Name
						if name == "Placed" and buildingType:match("^Road") then
							table.insert(result.walkways, base)
							continue
						end
						table.insert(result.obstacles, base)
						if name == "Placed" then
							table.insert(result.buildings, base)
						end
					end
				end
			end
		end
	end
	return result
end
local function groundAt(geometry, point)
	for _, tile in geometry.tiles do
		if not tile.Parent then
			continue
		end
		local localPoint = tile.CFrame:PointToObjectSpace(point)
		if math.abs(localPoint.X) <= tile.Size.X / 2 + 0.01 and math.abs(localPoint.Z) <= tile.Size.Z / 2 + 0.01 then
			local ground = tile.CFrame:PointToWorldSpace(Vector3.new(localPoint.X, tile.Size.Y / 2, localPoint.Z))
			for _, road in geometry.walkways or {} do
				if road.Parent then
					local p = road.CFrame:PointToObjectSpace(point)
					if math.abs(p.X) <= road.Size.X / 2 and math.abs(p.Z) <= road.Size.Z / 2 then
						local top = road.CFrame:PointToWorldSpace(Vector3.new(p.X, road.Size.Y / 2, p.Z))
						if top.Y >= ground.Y and top.Y - ground.Y <= 0.3 then
							ground = top
						end
					end
				end
			end
			return ground
		end
	end
	return nil
end
function Geometry.ground(geometry, point, radius)
	local ground = groundAt(geometry, point)
	if not ground then
		return nil
	end
	for _, offset in
		{
			Vector3.new(radius, 0, radius),
			Vector3.new(-radius, 0, radius),
			Vector3.new(radius, 0, -radius),
			Vector3.new(-radius, 0, -radius),
		}
	do
		local edge = groundAt(geometry, point + offset)
		if not edge or math.abs(edge.Y - ground.Y) > 0.3 then
			return nil
		end
	end
	for _, base in geometry.obstacles do
		if not base.Parent then
			continue
		end
		local p = base.CFrame:PointToObjectSpace(ground)
		if math.abs(p.X) < base.Size.X / 2 + radius and math.abs(p.Z) < base.Size.Z / 2 + radius then
			return nil
		end
	end
	return ground
end
function Geometry.segment(geometry, start, finish, radius)
	local distance = (finish - start).Magnitude
	local steps = math.max(1, math.ceil(distance / 0.75))
	if steps > 256 then
		return false
	end
	for i = 0, steps do
		if not Geometry.ground(geometry, start:Lerp(finish, i / steps), radius) then
			return false
		end
	end
	return true
end
function Geometry.wander(geometry, origin, radius, random)
	-- Prefer a reachable local walk before asking navmesh for a route across the city.
	local firstAngle = random:NextNumber(0, math.pi * 2)
	for _, distance in { 7, 4, 2 } do
		for direction = 0, 7 do
			local angle = firstAngle + direction * math.pi / 4
			local point = origin + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
			local ground = Geometry.ground(geometry, point, radius)
			if ground and Geometry.segment(geometry, origin, ground, radius) then
				return ground
			end
		end
	end
	return nil
end
function Geometry.target(geometry, radius, random)
	-- Visit the outside of buildings, then fall back to a free patch of land.
	for attempt = 1, 36 do
		local position
		if attempt <= 12 and #geometry.buildings > 0 then
			local base = geometry.buildings[random:NextInteger(1, #geometry.buildings)]
			local side = random:NextInteger(1, 4)
			local x = (side <= 2) and (base.Size.X / 2 + radius + 0.5) * (side == 1 and 1 or -1) or 0
			local z = (side > 2) and (base.Size.Z / 2 + radius + 0.5) * (side == 3 and 1 or -1) or 0
			position = base.CFrame:PointToWorldSpace(Vector3.new(x, 0, z))
		elseif #geometry.tiles > 0 then
			local tile = geometry.tiles[random:NextInteger(1, #geometry.tiles)]
			position = tile.CFrame:PointToWorldSpace(
				Vector3.new(random:NextNumber(-0.5, 0.5) * tile.Size.X, 0, random:NextNumber(-0.5, 0.5) * tile.Size.Z)
			)
		else
			return nil
		end
		local ground = Geometry.ground(geometry, position, radius)
		if ground then
			return ground
		end
	end
	return nil
end
return Geometry
