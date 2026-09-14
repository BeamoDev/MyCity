local Model = {}
function Model.create(template, parent, startFrame)
	local clone = template:Clone()
	if not clone then
		return nil
	end
	local primary = clone.PrimaryPart or clone:FindFirstChild("Base") or clone:FindFirstChildWhichIsA("BasePart", true)
	if not primary or not primary:IsA("BasePart") then
		clone:Destroy()
		return nil
	end
	clone.PrimaryPart = primary
	-- Prepare before replication: physics and embedded movement scripts must not fight the route.
	for _, item in clone:GetDescendants() do
		if item:IsA("LuaSourceContainer") or item:IsA("ProximityPrompt") then
			item:Destroy()
		elseif item:IsA("BasePart") then
			item.Anchored = true
			item.CanCollide, item.CanTouch, item.CanQuery = false, false, false
		end
	end
	local pivotOffset = primary.CFrame:ToObjectSpace(clone:GetPivot())
	clone:PivotTo(startFrame * pivotOffset)
	clone:SetAttribute("MyCityAmbientVehicle", true)
	clone.Parent = parent
	return clone, pivotOffset
end
return Model
