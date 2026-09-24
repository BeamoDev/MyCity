-- Count committed buildings, never construction attempts or client requests.
return function(Context)
	local API = Context.PostTutorialQuest
	local function current(player)
		if player.Data.PlayerInfo.Tutorial.IsInTutorial.Value then
			return nil
		end
		local state = Context.playerStates[player.UserId]
		return if state and not state.completed then state else nil
	end
	function API.onConstructionStarted() end -- Completion owns this milestone.
	local function kind(state)
		local quest = Context.QUESTS[state.step]
		return quest and quest.kind
	end
	-- Re-measures a state-based quest (buildings, roads, population, cash, rebirths, land).
	function API.refresh(player)
		local state = current(player)
		if state and kind(state) ~= "collect" and kind(state) ~= "construct" then
			if Context.recalculateProgress(player) then
				Context.completeQuest(player)
			end
		end
	end
	function API.onIncomeCollected(player)
		local state = current(player)
		if state and kind(state) == "collect" then
			Context.updateProgress(player, 1)
		end
	end
	function API.onBuildingPlaced(player, model)
		local state = current(player)
		if not state then
			return
		end
		local id = model:GetAttribute("BuildingID")
		if not id then
			return
		end
		local seen = Context.placedBuildingIds[player.UserId] or {}
		Context.placedBuildingIds[player.UserId] = seen
		if seen[id] then
			return
		end
		seen[id] = true
		if kind(state) == "construct" then
			if not Context.isRoad(model) then
				Context.updateProgress(player, 1)
			end
		else
			API.refresh(player)
		end
	end
	function API.onPopulationChanged(player)
		API.refresh(player)
	end
end
