local Rows = {}
function Rows.formatTime(seconds)
	seconds = math.max(0, math.ceil(seconds))
	local days = math.floor(seconds / 86400)
	local hours = math.floor(seconds / 3600) % 24
	local minutes = math.floor(seconds / 60) % 60
	local result = if days > 0 then string.format("%dd ", days) else ""
	if hours > 0 or days > 0 then
		result ..= string.format("%02dh ", hours)
	end
	if minutes > 0 or hours > 0 or days > 0 then
		result ..= string.format("%02dm ", minutes)
	end
	return result .. string.format("%02ds", seconds % 60)
end
function Rows.new(template, container, tweenService)
	local rows = {}
	local api = {}
	function api.remove(id)
		local row = rows[id]
		if not row then
			return
		end
		if row.tween then
			row.tween:Cancel()
		end
		row.frame:Destroy()
		rows[id] = nil
	end
	function api.clear()
		for id in rows do
			api.remove(id)
		end
	end
	function api.upsert(data, now)
		if type(data) ~= "table" or type(data.Id) ~= "string" or type(data.Name) ~= "string" then
			return
		end
		local duration = data.Duration
		if type(duration) ~= "number" or duration ~= duration or math.abs(duration) == math.huge then
			return
		end
		local row = rows[data.Id]
		if not row then
			local frame = template:Clone()
			frame.Name = data.Id
			frame.Visible = true
			frame.Parent = container
			row = { frame = frame }
			rows[data.Id] = row
		end
		row.frame.BuildingName.Text = data.Name
		row.remaining = math.max(0, duration)
		row.receivedAt = now
		local total = data.TotalDuration
		row.total = if type(total) == "number"
				and total == total
				and total < math.huge
			then math.max(total, duration, 0)
			else math.max(duration, 0)
	end
	function api.render(now)
		local sorted = {}
		for id, row in rows do
			local remaining = math.max(0, row.remaining - (now - row.receivedAt))
			row.frame.Timer.Text = Rows.formatTime(remaining)
			local progress = if row.total > 0 then math.clamp(1 - remaining / row.total, 0.03, 1) else 1
			if row.progress ~= progress then
				if row.tween then
					row.tween:Cancel()
				end
				row.tween = tweenService:Create(
					row.frame.Frame,
					TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
					{ Size = UDim2.new(progress, 0, 1, 0) }
				)
				row.tween:Play()
				row.progress = progress
			end
			table.insert(sorted, { id = id, row = row, remaining = remaining })
		end
		table.sort(sorted, function(a, b)
			if a.remaining == b.remaining then
				return a.id < b.id
			end
			return a.remaining < b.remaining
		end)
		for index, item in sorted do
			item.row.frame.LayoutOrder = index
		end
		-- Only server removal confirms completion, including skipped/slow constructions.
		return #sorted
	end
	return api
end
return Rows
