local View = require(script.View)
local Row = require(script.QuestRow)
local bindButton = require(script.ButtonBinding)
return function(Context)
	local State = Context.State
	local events = Context.ReplicatedStorage.Events.DailyQuests
	local view, snapshot, receivedAt
	local rows, pending = {}, {}
	local lastRequest = -math.huge
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
		local present, claimed = {}, 0
		for index, quest in snapshot.Quests do
			present[quest.Id] = true
			if quest.Claimed then
				claimed += 1
			end
			if not rows[quest.Id] then
				rows[quest.Id] = Row.create(view.List, function(id)
					if not snapshot or pending[id] then
						return
					end
					pending[id] = os.clock() + 6
					render()
					events.Claim:FireServer(snapshot.Day, id)
				end)
			end
			Row.update(rows[quest.Id], quest, index, Context.TweenService, pending[quest.Id] ~= nil)
		end
		for id, row in rows do
			if not present[id] then
				Row.destroy(row)
				rows[id] = nil
			end
		end
		view.Footer.Text = string.format("%d / 6 rewards claimed / New quests every day", claimed)
	end
	function Context.setupDailyQuests()
		view = View.create(State.HUD)
		State.DailyQuestFrame = view.Root
		Context.connections:connect(State.HUD:GetPropertyChangedSignal("Enabled"), function()
			view.Screen.Enabled = State.HUD.Enabled
		end)
		-- A real loading layout is visible even before the first server snapshot arrives.
		for index = 1, 6 do
			local row = Row.create(view.List, function() end)
			row.Root.Name, row.Root.LayoutOrder = "Loading" .. index, index
			row.Title.Text = "Loading quest..."
			row.Difficulty.Text, row.Progress.Text = "", "-- / --"
			row.Reward.Text = "Reward ..."
			row.Claim.Text, row.Claim.Interactable = "Loading", false
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
		end)
		Context.connections:connect(events.Result.OnClientEvent, function(success, message)
			table.clear(pending)
			render()
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
				if view.Root.Visible and snapshot then
					local remaining =
						math.max(0, math.ceil(snapshot.ResetsAt - (snapshot.ServerTime + now - receivedAt)))
					view.Timer.Text = string.format(
						"New quests in %02d:%02d:%02d",
						math.floor(remaining / 3600),
						math.floor(remaining % 3600 / 60),
						remaining % 60
					)
					if remaining == 0 then
						request()
					end
				elseif view.Root.Visible then
					view.Timer.Text = "Loading your six quests..."
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
		if State.currentOpenFrame == view.Root and view.Root.Visible then
			Context.UIController.closeUIFrame(view.Root)
		else
			Context.UIController.openUIFrame(view.Root)
		end
		request()
	end
	function Context.cleanupDailyQuests()
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
			view.Screen:Destroy()
		end
		view, snapshot, receivedAt = nil, nil, nil
		State.DailyQuestFrame = nil
	end
end
