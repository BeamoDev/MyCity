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
-- Every vehicle model in a template folder (sub-folders included; a model nested inside another
-- model is part of that vehicle). The server stamps each with a unique TemplateId attribute so
-- clients clone exactly the chosen model even when several share a Name.
function Model.templates(folder, onlyName)
	local found = {}
	for _, item in folder:GetDescendants() do
		if item:IsA("Model") and (not onlyName or item.Name == onlyName) then
			local nested = false
			local parent = item.Parent
			while parent and parent ~= folder do
				if parent:IsA("Model") then
					nested = true
					break
				end
				parent = parent.Parent
			end
			if not nested and item:FindFirstChildWhichIsA("BasePart", true) then
				table.insert(found, item)
			end
		end
	end
	for index, template in found do
		if template:GetAttribute("TemplateId") == nil then
			template:SetAttribute("TemplateId", folder.Name .. "#" .. index .. "#" .. template.Name)
		end
	end
	return found
end

-- Client lookup: by TemplateId when the trip has one, else by name (older trips).
function Model.find(folder, id, name)
	if id then
		for _, item in folder:GetDescendants() do
			if item:IsA("Model") and item:GetAttribute("TemplateId") == id then
				return item
			end
		end
	end
	return if name then folder:FindFirstChild(name, true) else nil
end

return Model
