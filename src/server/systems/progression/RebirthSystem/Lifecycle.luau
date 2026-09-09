-- Lifecycle: focused implementation for RebirthSystem.
return function(Context)
	local State = Context.State
	local RebirthSystem = Context.RebirthSystem
	local initialized = Context.initialized
	local Guard = Context.Guard
	local Players = Context.Players
	local requestRebirth = Context.requestRebirth

	function RebirthSystem.initializePlayer(player)
		if initialized[player] then
			return
		end
		local data = player:FindFirstChild("Data")
		local leaderstats = player:FindFirstChild("leaderstats")
		if not data or not leaderstats then
			return
		end
		initialized[player] = true

		local leaderRebirths = Context.getOrCreateLeaderRebirths(leaderstats)

		data.PlayerInfo.Population:GetPropertyChangedSignal("Value"):Connect(function()
			RebirthSystem.updateRebirthUI(player)
		end)

		leaderRebirths:GetPropertyChangedSignal("Value"):Connect(function()
			RebirthSystem.updateRebirthUI(player)
		end)

		RebirthSystem.updateRebirthUI(player)
	end

	function RebirthSystem.init()
		requestRebirth.OnServerEvent:Connect(function(player)
			Guard.run(player, "Rebirth", RebirthSystem.performRebirth)
		end)

		-- PlayerLifecycle initializes this only after a successful restoration.
	end
end
