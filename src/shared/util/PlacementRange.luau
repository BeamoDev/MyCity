local Range = { MaxDistance = 24 }
function Range.isNear(position, plot)
	if not position or not plot then
		return false
	end
	local land = plot:FindFirstChild("Land")
	local owned = land and land:FindFirstChild("Owned")
	if not owned then
		return false
	end
	for _, tile in owned:GetChildren() do
		if tile:IsA("BasePart") then
			local point = tile.CFrame:PointToObjectSpace(position)
			local half = tile.Size / 2
			local nearest = Vector3.new(
				math.clamp(point.X, -half.X, half.X),
				math.clamp(point.Y, -half.Y, half.Y),
				math.clamp(point.Z, -half.Z, half.Z)
			)
			if (point - nearest).Magnitude <= Range.MaxDistance then
				return true
			end
		end
	end
	return false
end
return Range
