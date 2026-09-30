-- Lifecycle: focused implementation for PlotManager.
return function(Context)
	local State = Context.State
	local PlotManager = Context.PlotManager

	function PlotManager.init()
		State.CityNameSystem = require(script.Parent.Parent:WaitForChild("CityNameSystem"))
		local prepareEmptyPlot = require(script.Parent.Parent.EmptyPlotPresentation)
		for _, plot in Context.plotsFolder:GetChildren() do
			if not plot:GetAttribute("Assigned") then
				prepareEmptyPlot(plot)
			end
		end
		-- Cosmetic locked-tile scenery is filled once in shared frame-bounded work,
		-- rather than rescanning every plot synchronously on every player assignment.
		task.spawn(Context.spawnAllScenery)
	end
end
