local Widgets = {}
function Widgets.make(class, parent, properties)
	local object = Instance.new(class)
	for key, value in properties do
		object[key] = value
	end
	-- Generated panels must draw above authored HUD artwork in Global ZIndex mode too.
	if object:IsA("GuiObject") and properties.ZIndex == nil and parent and parent:IsA("GuiObject") then
		object.ZIndex = parent.ZIndex + 1
	end
	object.Parent = parent
	return object
end
function Widgets.corner(parent, radius)
	Widgets.make("UICorner", parent, { CornerRadius = UDim.new(0, radius or 12) })
end
function Widgets.text(parent, text, position, size, fontSize, color)
	return Widgets.make("TextLabel", parent, {
		BackgroundTransparency = 1,
		Text = text,
		Position = position,
		Size = size,
		Font = Enum.Font.GothamBold,
		TextSize = fontSize or 18,
		TextColor3 = color or Color3.fromRGB(34, 40, 47),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
	})
end
function Widgets.number(value)
	local amount = tostring(math.floor(value))
	return amount:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end
return Widgets
