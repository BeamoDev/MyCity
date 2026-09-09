-- Lifecycle: focused implementation for PlotManager.
return function(Context)
	local State = Context.State
	local PlotManager = Context.PlotManager

	function PlotManager.init()
		State.CityNameSystem = require(script.Parent.Parent:WaitForChild("CityNameSystem"))
	end
end
