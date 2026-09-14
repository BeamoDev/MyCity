-- Rebirth reward cards use authored Assets templates only.
local Rewards = {}
local GENERATED = "MyCityRebirthReward"
function Rewards.render(scroll, data, templates)
	for _, child in scroll:GetChildren() do
		if child:GetAttribute(GENERATED) then
			child:Destroy()
		end
	end
	local layout = scroll:FindFirstChildOfClass("UIListLayout")
	if layout then
		layout.SortOrder = Enum.SortOrder.LayoutOrder
	end
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.fromScale(0, 0)
	scroll.CanvasPosition = Vector2.zero
	local function boost(key, title, templateName, order)
		local current = (data.multipliers and data.multipliers[key]) or 1
		local nextValue = (data.nextMultipliers and data.nextMultipliers[key]) or current
		local template = templateName and templates:FindFirstChild(templateName)
		if
			template
			and template:IsA("GuiObject")
			and template:FindFirstChild("Now", true)
			and template:FindFirstChild("Next", true)
		then
			local row = template:Clone()
			row.Name = title .. "Boost"
			row.LayoutOrder = order
			row.Visible = true
			row:SetAttribute(GENERATED, true)
			row:FindFirstChild("Now", true).Text = string.format("x %.2f", current)
			row:FindFirstChild("Next", true).Text = string.format("x %.2f", nextValue)
			row.Parent = scroll
		end
	end
	boost("income", "Income", "IncomeBoostTemp", 1)
	boost("population", "Population", "PopulationBoostTemp", 2)
	boost("xp", "Building XP", "XPBoostTemp", 3)
	local unlocks = data.unlockedBuildings or {}
	do
		local template = templates:FindFirstChild("BuildingTemp")
		for index, building in unlocks do
			if template and template:IsA("GuiObject") and template:FindFirstChild("BuildingName", true) then
				local row = template:Clone()
				row.Name = "Building_" .. index
				row.Visible = true
				row.LayoutOrder = 4 + index
				row:SetAttribute(GENERATED, true)
				row:FindFirstChild("BuildingName", true).Text = building.name
				local icon = row:FindFirstChild("BuildingIcon", true)
				if icon then
					icon.Image = "rbxassetid://" .. tostring(building.imageId or 0)
				end
				row.Parent = scroll
			end
		end
	end
end
return Rewards
