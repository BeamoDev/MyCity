-- Highlights: focused implementation for TutorialController.
return function(Context)
	local State = Context.State
	local player = Context.player
	local tutorialState = Context.tutorialState

	function Context.getPlayerPlot()
		local data = player:FindFirstChild("Data")
		local info = data and data:FindFirstChild("PlotInfo")
		local number = info and info:FindFirstChild("Plot")
		local plots = game.Workspace:FindFirstChild("Plots")
		return plots and number and plots:FindFirstChild("Plot" .. number.Value)
	end

	function Context.refreshPlacementHighlights()
		-- The placement session now owns highlights in every stage and normal gameplay.
		-- Remove any older tutorial-owned copies without touching the active preview.
		Context.clearTileHighlights()
	end

	-- Clear tile highlights

	function Context.clearTileHighlights()
		for _, highlight in pairs(tutorialState.tileHighlights) do
			if highlight then
				highlight:Destroy()
			end
		end
		tutorialState.tileHighlights = {}
	end
end
