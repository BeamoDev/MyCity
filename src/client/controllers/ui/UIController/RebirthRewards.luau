-- Confirmation content is always readable, even without optional authored cards.
local Rewards = {}
local GENERATED = "MyCityRebirthReward"
local function textRow(parent, name, text, order, height)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, -16, 0, height or 44)
	label.TextWrapped = true
	label.TextScaled = false
	label.TextSize = 18
	label.Font = Enum.Font.GothamMedium
	label.TextColor3 = Color3.fromRGB(35, 45, 40)
	label.TextStrokeTransparency = 1
	label.Text = text
	label.LayoutOrder = order
	label:SetAttribute(GENERATED, true)
	label.Parent = parent
	return label
end
function Rewards.render(scroll, data, templates, formatCash)
	for _, child in scroll:GetChildren() do
		if child:GetAttribute(GENERATED) or child.Name == "RebirthSummary" then
			child:Destroy()
		end
	end
	local layout = scroll:FindFirstChildOfClass("UIListLayout")
	if not layout then
		layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, 8)
		layout.Parent = scroll
	end
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.fromScale(0, 0)
	scroll.CanvasPosition = Vector2.zero
	textRow(
		scroll,
		"RebirthSummary",
		"Keep your city, buildings, land and inventory.\nCash resets to " .. formatCash(data.startingCash or 0) .. ".",
		0,
		70
	)
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
		else
			textRow(scroll, key .. "Boost", string.format("%s: x%.2f ? x%.2f", title, current, nextValue), order)
		end
	end
	boost("income", "Income", "IncomeBoostTemp", 1)
	boost("population", "Population", "PopulationBoostTemp", 2)
	boost("xp", "Building XP", nil, 3)
	local unlocks = data.unlockedBuildings or {}
	if #unlocks == 0 then
		textRow(
			scroll,
			"NoBuildingUnlock",
			"No new building types at this rebirth. You still gain all three boosts.",
			4,
			60
		)
	else
		textRow(scroll, "ShopUnlocks", "New buildings available to buy in the shop:", 4)
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
			else
				textRow(scroll, "Building_" .. index, building.name, 4 + index)
			end
		end
	end
end
return Rewards
