-- Bind authored button badges, including controls that replicate after HUD setup.
return function(buttons, buttonName, scope)
	local visible = false
	local alerts = setmetatable({}, { __mode = "k" })
	local function bind(object)
		if object.Name == "Alerts" and object:IsA("GuiObject") then
			local button = object.Parent
			if button and button.Name == buttonName and button:IsA("GuiButton") then
				alerts[object] = true
				object.Visible = visible
			end
		end
	end
	if buttons then
		scope:connect(buttons.DescendantAdded, bind)
		for _, object in buttons:GetDescendants() do
			bind(object)
		end
	end
	return function(canClaim)
		visible = canClaim == true
		for alert in alerts do
			if alert.Parent then
				alert.Visible = visible
			end
		end
	end
end
