-- Preserve the authored card and layout, as in KingdomWars NotificationFeed.
return function(Context)
	function Context.messageLabel(root)
		if root:IsA("TextLabel") or root:IsA("TextButton") then
			return root
		end
		local named = root:FindFirstChild("Message", true)
		if named and named:IsA("TextLabel") then
			return named
		end
		return root:FindFirstChildWhichIsA("TextLabel", true)
	end
	function Context.capture(card)
		local records = {}
		local descendants = card:GetDescendants()
		table.insert(descendants, card)
		for _, object in descendants do
			local values = {}
			if object:IsA("GuiObject") then
				values.BackgroundTransparency = object.BackgroundTransparency
			end
			if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
				values.TextTransparency = object.TextTransparency
				values.TextStrokeTransparency = object.TextStrokeTransparency
			elseif object:IsA("ImageLabel") or object:IsA("ImageButton") then
				values.ImageTransparency = object.ImageTransparency
			elseif object:IsA("UIStroke") then
				values.Transparency = object.Transparency
			end
			if next(values) then
				table.insert(records, { object = object, values = values })
				for property in values do
					object[property] = 1
				end
			end
		end
		return records
	end
	function Context.fade(entry, showing)
		for _, tween in entry.tweens do
			tween:Cancel()
		end
		table.clear(entry.tweens)
		local info = TweenInfo.new(
			if showing then 0.36 else 0.4,
			Enum.EasingStyle.Quad,
			if showing then Enum.EasingDirection.Out else Enum.EasingDirection.In
		)
		for _, record in entry.records do
			if record.object.Parent then
				local goals = {}
				for property, value in record.values do
					goals[property] = if showing then value else 1
				end
				local tween = Context.TweenService:Create(record.object, info, goals)
				table.insert(entry.tweens, tween)
				tween:Play()
			end
		end
	end
end
