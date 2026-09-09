-- Progression: focused implementation for PostTutorialQuest.
return function(Context)
	local State = Context.State
	local events = Context.events
	local evUpdate = Context.evUpdate
	local evComplete = Context.evComplete
	local evAllDone = Context.evAllDone
	local playerStates = Context.playerStates
	local QUESTS = Context.QUESTS

	function Context.updateUI(player)
		local state = playerStates[player.UserId]
		if not state or state.completing then
			return
		end
		if state.completed then
			evAllDone:FireClient(player, true)
			return
		end
		local quest = QUESTS[state.step]
		evUpdate:FireClient(player, quest.title, state.progress, quest.required, state.step, #QUESTS, quest.reward)
	end

	-- Reward giving

	function Context.giveReward(player, reward)
		if reward.type == "cash" then
			local stats = player:FindFirstChild("leaderstats")
			local cash = stats and stats:FindFirstChild("Cash")
			if not cash then
				return false
			end
			cash.Value += reward.amount
			return true
		elseif reward.type == "building" then
			local backpack = player:FindFirstChild("Backpack")
			if not backpack then
				return false
			end
			local factory = require(script.Parent.Parent.Parent.Parent.services.ToolFactory)
			local tool = factory.create(reward.building, false, 1, 0)
			if not tool then
				return false
			end
			tool.Parent = backpack
			return true
		end
		return false
	end

	function Context.recalculateProgress(player)
		local state = playerStates[player.UserId]
		if not state or state.completed or state.completing then
			return
		end

		local quest = QUESTS[state.step]
		local oldProgress = state.progress

		-- Recalculate based on quest type
		if quest.id == "construct_buildings" then
			-- Don't recalculate constructions - they're tracked as events
			-- Keep the existing progress
		elseif quest.id == "buildings_total" then
			state.progress = math.min(quest.required, Context.countPlaced(player, { onlyRoads = false }))
		elseif quest.id == "place_roads" then
			state.progress = math.min(quest.required, Context.countPlaced(player, { onlyRoads = true }))
		elseif quest.id == "population" then
			state.progress = math.min(quest.required, Context.getPopulation(player))
		end

		if state.progress ~= oldProgress then
			Context.saveState(player)
			Context.updateUI(player)
		end

		return state.progress >= quest.required
	end

	-- Quest progression

	function Context.completeQuest(player)
		local state = playerStates[player.UserId]
		if not state or state.completed or state.completing then
			return
		end

		local quest = QUESTS[state.step]
		if not quest or state.progress < quest.required then
			return
		end
		state.completing = true

		-- reward + notify
		local ok, rewarded = pcall(Context.giveReward, player, quest.reward)
		if not ok or not rewarded then
			state.completing = false
			warn("[Quests] Reward deferred for", player.UserId, quest.id)
			return
		end

		-- mark current step as completed in the persisted counter
		state.progressionValue.Value = math.max(state.progressionValue.Value or 0, state.step)

		-- advance
		state.step += 1
		state.completing = false
		state.progress = 0
		Context.saveState(player)
		evComplete:FireClient(player, quest.title, quest.reward)

		if state.step > #QUESTS then
			state.completed = true
			Context.saveState(player) -- writes completed flag and clears progress
			evAllDone:FireClient(player)
			return
		end

		-- seed the next quest's starting progress from world state
		local newQuest = QUESTS[state.step]
		local newProgress = 0
		if newQuest.id == "buildings_total" then
			newProgress = math.min(newQuest.required, Context.countPlaced(player, { onlyRoads = false }))
		elseif newQuest.id == "place_roads" then
			newProgress = math.min(newQuest.required, Context.countPlaced(player, { onlyRoads = true }))
		elseif newQuest.id == "population" then
			newProgress = math.min(newQuest.required, Context.getPopulation(player))
		end

		state.progress = newProgress
		Context.saveState(player)
		Context.updateUI(player)

		-- instant complete if they already meet it
		if newProgress >= newQuest.required then
			task.defer(function()
				Context.completeQuest(player)
			end)
		end
	end

	function Context.updateProgress(player, amount)
		local state = playerStates[player.UserId]
		if not state or state.completed or state.completing then
			return
		end

		local quest = QUESTS[state.step]
		state.progress = math.min(quest.required, state.progress + (amount or 1))

		Context.saveState(player)
		Context.updateUI(player)

		if state.progress >= quest.required then
			Context.completeQuest(player)
		end
	end
end
