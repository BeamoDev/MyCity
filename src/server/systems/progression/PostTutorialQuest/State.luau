-- State: focused implementation for PostTutorialQuest.
return function(Context)
	local State = Context.State
	local Workspace = Context.Workspace
	local playerStates = Context.playerStates
	local QUESTS = Context.QUESTS

	function Context.ensureValue(parent, class, name, default)
		local v = parent:FindFirstChild(name)
		if not v then
			v = Instance.new(class)
			v.Name = name
			v.Parent = parent
			if default ~= nil then
				v.Value = default
			end
		end
		return v
	end

	function Context.getPlot(player)
		local pv = player:FindFirstChild("Data")
			and player.Data:FindFirstChild("PlotInfo")
			and player.Data.PlotInfo:FindFirstChild("Plot")
		if not pv or pv.Value == 0 then
			return nil
		end
		return Workspace.Plots:FindFirstChild("Plot" .. pv.Value)
	end

	function Context.isRoad(model)
		local kind = model:GetAttribute("BuildingType")
		return type(kind) == "string" and string.find(string.lower(kind), "road", 1, true) ~= nil
	end

	function Context.countPlaced(player, opts)
		opts = opts or {}
		local plot = Context.getPlot(player)
		if not plot then
			return 0
		end

		local placed = plot:FindFirstChild("Buildings") and plot.Buildings:FindFirstChild("Placed")
		if not placed then
			return 0
		end

		local count = 0
		for _, m in ipairs(placed:GetChildren()) do
			if opts.onlyRoads then
				if Context.isRoad(m) then
					count = count + 1
				end
			else
				-- Count ALL non-road buildings for the placement quest
				if not Context.isRoad(m) then
					count = count + 1
				end
			end
		end
		return count
	end

	function Context.getPopulation(player)
		local ls = player:FindFirstChild("leaderstats")
		if not ls then
			return 0
		end
		local p = player:FindFirstChild("Data") and player.Data.PlayerInfo:FindFirstChild("Population")
		return p and p.Value or 0
	end

	-- Save/Load functions

	function Context.saveState(player)
		local state = playerStates[player.UserId]
		if not state then
			return
		end

		state.progressValue.Value = state.progress
		state.completedValue.Value = state.completed
		-- keep QuestProgression as "highest completed step"
		-- (do not set here unless we actually complete a step)
	end

	function Context.loadState(player)
		local pi = player:WaitForChild("Data"):WaitForChild("PlayerInfo")
		local questsFolder = pi:WaitForChild("Quests")

		local progressValue = questsFolder:WaitForChild("PostTutorialQuestProgress")
		local completedValue = questsFolder:WaitForChild("PostTutorialQuestComplete")
		local questProgValue = questsFolder:WaitForChild("QuestProgression")

		playerStates[player.UserId] = {
			step = math.clamp((questProgValue.Value or 0) + 1, 1, #QUESTS),
			progress = progressValue.Value or 0,
			completed = completedValue.Value or false,

			progressValue = progressValue,
			completedValue = completedValue,
			progressionValue = questProgValue,
		}

		if questProgValue.Value >= #QUESTS then
			playerStates[player.UserId].completed = true
			completedValue.Value = true
		end
	end

	-- UI update
end
