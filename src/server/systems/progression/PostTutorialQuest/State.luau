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

	local RARITY_RANK = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5, Mythic = 6 }

	-- Non-road buildings in the city whose rarity is at least minRarity.
	function Context.countRarity(player, minRarity)
		local plot = Context.getPlot(player)
		local placed = plot and plot:FindFirstChild("Buildings") and plot.Buildings:FindFirstChild("Placed")
		if not placed then
			return 0
		end
		local catalogue = require(script.Parent.Parent.Parent.Parent.config.BuildingConfig)
		local needed, count = RARITY_RANK[minRarity] or 1, 0
		for _, model in placed:GetChildren() do
			local definition = catalogue[model:GetAttribute("BuildingType")]
			if not Context.isRoad(model) and definition and (RARITY_RANK[definition.Rarity] or 1) >= needed then
				count += 1
			end
		end
		return count
	end

	local function stat(player, name)
		local stats = player:FindFirstChild("leaderstats")
		local value = stats and stats:FindFirstChild(name)
		return value and value.Value or 0
	end

	function Context.countLand(player)
		local plot = Context.getPlot(player)
		local owned = plot and plot:FindFirstChild("Land") and plot.Land:FindFirstChild("Owned")
		local count = 0
		for _, tile in (if owned then owned:GetChildren() else {}) do
			if tile:IsA("BasePart") then
				count += 1
			end
		end
		return count
	end

	-- Current value for quests measured from the world/player state; nil for counted (event) quests.
	function Context.measure(player, quest)
		local kind = quest.kind
		if kind == "buildings" then
			return if quest.minRarity
				then Context.countRarity(player, quest.minRarity)
				else Context.countPlaced(player, { onlyRoads = false })
		elseif kind == "roads" then
			return Context.countPlaced(player, { onlyRoads = true })
		elseif kind == "population" then
			return Context.getPopulation(player)
		elseif kind == "cash" then
			return stat(player, "Cash")
		elseif kind == "rebirths" then
			return stat(player, "Rebirths")
		elseif kind == "land" then
			return Context.countLand(player)
		end
		return nil
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

		-- Completion is derived from the chain length, so players who finished an earlier, shorter
		-- chain continue with newly added quests.
		local finished = (questProgValue.Value or 0) >= #QUESTS
		completedValue.Value = finished
		playerStates[player.UserId] = {
			step = math.clamp((questProgValue.Value or 0) + 1, 1, #QUESTS),
			progress = progressValue.Value or 0,
			completed = finished,

			progressValue = progressValue,
			completedValue = completedValue,
			progressionValue = questProgValue,
		}

	end

	-- UI update
end
