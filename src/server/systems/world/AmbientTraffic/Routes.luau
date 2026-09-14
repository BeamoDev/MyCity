local Routes = {}
function Routes.read(points, definitions)
	local routes = {}
	if not points then
		return routes
	end
	for _, definition in definitions do
		local first, last = points:FindFirstChild(definition[1]), points:FindFirstChild(definition[2])
		if
			first
			and last
			and first:IsA("BasePart")
			and last:IsA("BasePart")
			and (first.Position - last.Position).Magnitude > 0.01
		then
			table.insert(
				routes,
				{ first = first.CFrame, last = last.CFrame, rotation = CFrame.Angles(0, math.rad(definition[3]), 0) }
			)
		end
	end
	return routes
end
function Routes.trip(route, offset, duration, speed)
	local shift = CFrame.new(offset, 0, 0)
	local first, last = route.first * shift * route.rotation, route.last * shift * route.rotation
	return first, last, duration or (last.Position - first.Position).Magnitude / speed
end
return Routes
