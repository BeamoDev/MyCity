local View = require(script.View)
local Row = require(script.QuestRow)
local bindButton = require(script.ButtonBinding)
local bindAlert = require(script.Parent.ClaimAlerts)
return function(Context)
	local State = Context.State
	local events = Context.ReplicatedStorage.Events.DailyQuests
	local view, snapshot, receivedAt
	local rows, pending = {}, {}
	local lastRequest = -math.huge
	local setAlert
	local function request()
		if os.clock() - lastRequest < 2 then
			return
		end
		lastRequest = os.clock()
		events.Request:FireServer()
	end
	local function render()
		if not view or not snapshot then
			return
		end
		local present = {}
		local ordered = {}
		local claimable = false
		for index, quest in snapshot.Quests do
			if index > 6 then
				break
			end
			local progress = math.clamp(quest.Progress / math.max(1, quest.Target), 0, 1)
			if not quest.Claimed and progress >= 1 and not pending[quest.Id] then
				claimable = true
			end
			table.insert(ordered, {
				quest = quest,
				index = index,
				progress = progress,
				group = if quest.Claimed then 3 elseif progress >= 1 then 1 else 2,
			})
		end
		setAlert(claimable and snapshot.ResetsAt > snapshot.ServerTime + os.clock() - receivedAt)
		table.sort(ordered, function(a, b)
			if a.group ~= b.group then
				return a.group < b.group
			end
			if a.progress ~= b.progress then
				return a.progress > b.progress
			end
			return a.index < b.index
		end)
		for index, entry in ordered do
			local quest = entry.quest
			present[quest.Id] = true
			if not rows[quest.Id] then
				rows[quest.Id] = Row.create(view.Template, view.List, function(id)
					if not snapshot or pending[id] then
						return
					end
					pending[id] = os.clock() + 6
					render()
					events.Claim:FireServer(snapshot.Day, id)
				end)
			end
			rows[quest.Id].Root.Parent = view.List
			Row.update(rows[quest.Id], quest, index + 1, Context.TweenService, pending[quest.Id] ~= nil)
		end
		for id, row in rows do
			if not present[id] then
				Row.destroy(row)
				rows[id] = nil
			end
		end
	end
	function Context.setupDailyQuests()
		setAlert = bindAlert(State.ButtonFolder, "Quests", Context.connections)
		view = View.create(State.HUD)
		if not view then
			return
		end
		State.DailyQuestFrame = view.Root
		View.updateTimer(view, nil)
		-- A real loading layout is visible even before the first server snapshot arrives.
		for index = 1, 6 do
			local row = Row.create(view.Template, view.List, function() end)
			row.Root.Name, row.Root.LayoutOrder = "Loading" .. index, index + 1
			rows[row.Root.Name] = row
		end
		Context.connections:connect(view.Close.Activated, function()
			Context.UIController.closeUIFrame(view.Root)
		end)
		Context.connections:connect(events.Update.OnClientEvent, function(data)
			if type(data) ~= "table" or type(data.Quests) ~= "table" then
				return
			end
			snapshot, receivedAt = data, os.clock()
			-- Keep pending until the claim result, a claimed snapshot, or the timeout.
			for _, quest in data.Quests do
				if quest.Claimed then
					pending[quest.Id] = nil
				end
			end
			render()
			View.updateTimer(view, math.max(0, data.ResetsAt - data.ServerTime))
		end)
		Context.connections:connect(events.Result.OnClientEvent, function(success, message)
			if not success then
				table.clear(pending)
			end
			render()
			request()
			Context.NotificationController.showNotification(if success then "ItemBought" else "CannotPlace", message)
		end)
		Context.connections:connect(Context.player:GetAttributeChangedSignal("MyCityPlacementTool"), function()
			if Context.player:GetAttribute("MyCityPlacementTool") then
				Context.UIController.closeUIFrame(view.Root)
			end
		end)
		Context.connections:spawn(function()
			while view do
				local now = os.clock()
				local changed = false
				for id, expires in pending do
					if now >= expires then
						pending[id] = nil
						changed = true
					end
				end
				if changed then
					render()
					request()
				end
				if snapshot then
					local remaining =
						math.max(0, math.ceil(snapshot.ResetsAt - (snapshot.ServerTime + now - receivedAt)))
					View.updateTimer(view, remaining)
					if remaining == 0 then
						setAlert(false)
						request()
					end
				elseif view.Root.Visible then
					View.updateTimer(view, nil)
					request()
				end
				task.wait(1)
			end
		end)
		bindButton(State.ButtonFolder, Context.connections, Context.toggleDailyQuests)
		request()
	end
	function Context.toggleDailyQuests()
		if Context.checkTutorialStatus() or Context.player:GetAttribute("MyCityPlacementTool") then
			return
		end
		if not view then
			return
		end
		State.FramesFolder.Visible = true
		if State.currentOpenFrame == view.Root and view.Root.Visible then
			Context.UIController.closeUIFrame(view.Root)
		else
			Context.UIController.openUIFrame(view.Root)
		end
		request()
	end
	function Context.cleanupDailyQuests()
		if setAlert then
			setAlert(false)
		end
		for _, row in rows do
			Row.destroy(row)
		end
		table.clear(rows)
		table.clear(pending)
		if view then
			Context.Transitions.cancel(view.Root)
			if State.currentOpenFrame == view.Root then
				Context.UIController.closeUIFrame(view.Root)
			end
			view.Root.Visible = false
			view.Template.Visible = false
		end
		view, snapshot, receivedAt = nil, nil, nil
		lastRequest = -math.huge
		State.DailyQuestFrame = nil
	end
end
