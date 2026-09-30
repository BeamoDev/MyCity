-- Scenery: focused implementation for PlotManager.
local RestoreBudget = require(script.Parent.Parent.Parent.Parent.services.RestoreBudget)
return function(Context)
	local State = Context.State
	local ReplicatedStorage = Context.ReplicatedStorage
	local plotsFolder = Context.plotsFolder
	local sceneryChoices, totalChance

	function Context.getTileNumber(tile)
		return tonumber(tile.Name:match("Tile(%d+)"))
	end

	function Context.chooseLockedScenery()
		if not sceneryChoices then
			local spawnConfig =
				require(script.Parent.Parent.Parent.Parent:WaitForChild("config"):WaitForChild("SpawnConfig"))
			sceneryChoices, totalChance = {}, 0
			for name, item in spawnConfig do
				totalChance += item.Chance
				table.insert(sceneryChoices, { name = name, chance = item.Chance })
			end
			table.sort(sceneryChoices, function(a, b) return a.name < b.name end)
		end

		local randomValue = math.random(1, totalChance)
		local cumulativeChance = 0
		for _, item in sceneryChoices do
			cumulativeChance += item.chance
			if randomValue <= cumulativeChance then
				return item.name
			end
		end
	end

	function Context.spawnSceneryForPlot(plot)
		local locked = plot:FindFirstChild("Land") and plot.Land:FindFirstChild("Locked")
		if not locked then return end
		for _, tile in locked:GetChildren() do
			RestoreBudget.checkpoint()
			if plot.Parent ~= plotsFolder then return end
			if not tile:FindFirstChild("LockedScenery") and not tile:FindFirstChild("ExpansionPrompt") then
				local chosenItem = Context.chooseLockedScenery()
				local scenery = ReplicatedStorage.Assets.Expansion.Locked:FindFirstChild(chosenItem)
				if scenery then
					local clonedScenery = scenery:Clone()
					clonedScenery.Name = "LockedScenery"
					clonedScenery.CFrame = tile.CFrame + Vector3.new(0, 2, 0)
					clonedScenery.Parent = tile
				end
			end
		end
	end

	function Context.spawnAllScenery()
		for _, plot in plotsFolder:GetChildren() do
			Context.spawnSceneryForPlot(plot)
		end
	end
end
