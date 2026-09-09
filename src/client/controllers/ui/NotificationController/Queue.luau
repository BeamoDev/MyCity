return function(Context)
	local NotificationController = Context.NotificationController
	local active, recent = Context.activeNotifications, Context.recentNotifications
	local sequence = 0
	local function destroy(entry)
		for _, tween in entry.tweens do
			tween:Cancel()
		end
		for index = #active, 1, -1 do
			if active[index] == entry then
				table.remove(active, index)
			end
		end
		if entry.card then
			entry.card:Destroy()
			entry.card = nil
		end
	end
	function NotificationController.clearAll()
		for index = #active, 1, -1 do
			destroy(active[index])
		end
		table.clear(recent)
	end
	function NotificationController.showNotification(kind, text)
		if Context.notificationsSuppressed() then
			return
		end
		if Context.State.deferNotifications then
			Context.pending = Context.pending or {}
			if #Context.pending >= 20 then
				table.remove(Context.pending, 1)
			end
			table.insert(Context.pending, { kind = kind, text = text })
			return
		end
		local frame = Context.State.notificationsFrame
		local template = frame and frame:FindFirstChild("Template")
		if not template or not frame.Parent then
			return
		end
		if type(text) == "table" then
			text = text.Message or text.Text or text.Title
		end
		if text == nil then
			return
		end
		text = tostring(text):gsub("%s+", " ")
		if text == "" then
			return
		end
		local valid, length = pcall(utf8.len, text)
		if not valid then
			length = nil
		end
		if length and length > 160 then
			text = text:sub(1, utf8.offset(text, 160) - 1) .. "?"
		end
		local key, now = tostring(kind) .. ":" .. text, os.clock()
		for name, stamp in recent do
			if now - stamp > 1 then
				recent[name] = nil
			end
		end
		if recent[key] and now - recent[key] < 0.5 then
			return
		end
		recent[key] = now
		-- Count closing cards too, keeping physical clones bounded during bursts.
		while #active >= Context.MAX_NOTIFICATIONS do
			destroy(active[1])
		end
		local card = template:Clone()
		card.Name = "Notice"
		card.Visible = true
		sequence += 1
		card.LayoutOrder = -sequence
		local label = Context.messageLabel(card)
		if not label then
			card:Destroy()
			warn("[Notifications] Template needs a text label")
			return
		end
		label.RichText = false
		label.Text = text
		local data = Context.NOTIFICATION_DATA[kind]
		if data then
			label.TextColor3 = data.textColor
		end
		local entry = { card = card, records = Context.capture(card), tweens = {} }
		card.Parent = frame
		table.insert(active, entry)
		Context.fade(entry, true)
		local sfx = Context.SoundService:FindFirstChild("SFX")
		local sound = sfx and sfx:FindFirstChild(data and data.sound or "NotificationLow")
		if sound then
			sound:Play()
		end
		Context.connections:delay(if kind == "BuildingStole" then 6 else 3, function()
			if not entry.card then
				return
			end
			Context.fade(entry, false)
			Context.connections:delay(0.42, function()
				destroy(entry)
			end)
		end)
	end
end
