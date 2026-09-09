-- Bind independently of other authored menu controls, including late/replaced buttons.
return function(buttons, scope, toggle)
	local bound = {}
	local function bind(button)
		if button.Name ~= "Quests" or not button:IsA("GuiButton") or bound[button] then
			return
		end
		bound[button] = true
		button.Active = true
		button.Interactable = true
		scope:connect(button.Activated, toggle)
	end
	scope:connect(buttons.DescendantAdded, bind)
	for _, button in buttons:GetDescendants() do
		bind(button)
	end
	if not next(bound) then
		warn("[DailyQuests] No GuiButton named Quests under HUD.Buttons; waiting for it to be added")
	end
end
