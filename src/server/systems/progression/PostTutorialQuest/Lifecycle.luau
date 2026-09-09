-- PlayerLifecycle starts quests only after data and the owned plot are restored.
return function(Context)
	local PostTutorialQuest = Context.PostTutorialQuest
	local playerStates = Context.playerStates
	local placedBuildingIds = Context.placedBuildingIds
	local initialized = setmetatable({}, { __mode = "k" })
	local connections = {}
	function PostTutorialQuest.initializePlayer(player)
		if initialized[player] or not player:FindFirstChild("Data") or not player:FindFirstChild("leaderstats") then
			return
		end
		initialized[player] = true
		Context.loadState(player)
		local tutorial = player.Data.PlayerInfo.Tutorial.IsInTutorial
		local active = false
		connections[player] = {}
		local function activate()
			if active or tutorial.Value or not player.Parent or player:GetAttribute("MyCityLeaving") then
				return
			end
			active = true
			table.insert(
				connections[player],
				player.Data.PlayerInfo.Population:GetPropertyChangedSignal("Value"):Connect(function()
					PostTutorialQuest.onPopulationChanged(player)
				end)
			)
			local plot = Context.getPlot(player)
			local buildings = plot and plot:FindFirstChild("Buildings")
			local placed = buildings and buildings:FindFirstChild("Placed")
			if placed then
				table.insert(
					connections[player],
					placed.ChildRemoved:Connect(function()
						if player.Parent and not player:GetAttribute("MyCityLeaving") then
							Context.recalculateProgress(player)
						end
					end)
				)
			end
			local complete = Context.recalculateProgress(player)
			Context.updateUI(player)
			if complete then
				Context.completeQuest(player)
			end
		end
		table.insert(connections[player], tutorial:GetPropertyChangedSignal("Value"):Connect(activate))
		activate()
	end
	function PostTutorialQuest.syncPlayer(player)
		PostTutorialQuest.initializePlayer(player)
		if not player.Data.PlayerInfo.Tutorial.IsInTutorial.Value and Context.recalculateProgress(player) then
			Context.completeQuest(player)
		end
		Context.updateUI(player)
	end
	function PostTutorialQuest.init()
		Context.Players.PlayerRemoving:Connect(function(player)
			for _, connection in connections[player] or {} do
				connection:Disconnect()
			end
			connections[player] = nil
			initialized[player] = nil
			playerStates[player.UserId] = nil
			placedBuildingIds[player.UserId] = nil
		end)
	end
end
