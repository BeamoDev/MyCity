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
	function API.onIncomeCollected(player)
		local state = current(player)
		if state and state.step == 1 then
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
		if state.step == 2 and not Context.isRoad(model) then
			Context.updateProgress(player, 1)
		elseif state.step == 3 or state.step == 4 then
			if Context.recalculateProgress(player) then
				Context.completeQuest(player)
			end
		end
	end
	function API.onPopulationChanged(player)
		local state = current(player)
		if state and state.step == 5 and Context.recalculateProgress(player) then
			Context.completeQuest(player)
		end
	end
end
