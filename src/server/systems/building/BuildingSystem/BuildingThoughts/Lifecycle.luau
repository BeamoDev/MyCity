-- Lifecycle: focused implementation for BuildingThoughts.
return function(Context)
	local State = Context.State
	local BuildingThoughts = Context.BuildingThoughts
	local CHECK_INTERVAL = Context.CHECK_INTERVAL

	function BuildingThoughts.init()
		-- Main loop
		task.spawn(function()
			while true do
				task.wait(CHECK_INTERVAL)
				Context.selectRandomBuildings()

				-- Clean up any orphaned thoughts
				for building, data in pairs(State.activeThoughts) do
					if not building or not building.Parent or tick() > data.endTime then
						if data.bubble and data.bubble.Parent then
							data.bubble:Destroy()
						end
						if data.statsConnection then
							data.statsConnection:Disconnect()
						end
						State.activeThoughts[building] = nil
					end
				end
			end
		end)
	end

	function BuildingThoughts.cleanup()
		-- Clean up all active thoughts
		for building, data in pairs(State.activeThoughts) do
			if data.bubble and data.bubble.Parent then
				data.bubble:Destroy()
			end
			if data.statsConnection then
				data.statsConnection:Disconnect()
			end
		end
		State.activeThoughts = {}
	end
end
