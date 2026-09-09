-- Scenery: focused implementation for PlotManager.
return function(Context)
	local State = Context.State
	local ReplicatedStorage = Context.ReplicatedStorage
	local plotsFolder = Context.plotsFolder

	function Context.getTileNumber(tile)
		return tonumber(tile.Name:match("Tile(%d+)"))
	end

	function Context.chooseLockedScenery()
		local SpawnConfig =
			require(script.Parent.Parent.Parent.Parent:WaitForChild("config"):WaitForChild("SpawnConfig"))
		local totalChance = 0
		for _, item in pairs(SpawnConfig) do
			totalChance += item.Chance
		end

		local randomValue = math.random(1, totalChance)
		local cumulativeChance = 0

		for name, item in pairs(SpawnConfig) do
			cumulativeChance += item.Chance
			if randomValue <= cumulativeChance then
				return name
			end
		end
	end

	function Context.spawnAllScenery()
		for _, plot in ipairs(plotsFolder:GetChildren()) do
			local locked = plot.Land:FindFirstChild("Locked")
			if locked then
				for _, tile in ipairs(locked:GetChildren()) do
					if not tile:FindFirstChild("LockedScenery") and tile:FindFirstChild("ExpansionPrompt") == nil then
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
		end
	end
end
