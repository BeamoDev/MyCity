-- Lifecycle: focused implementation for ConstructionTimer.
return function(Context)
	local State = Context.State
	local ConstructionTimer = Context.ConstructionTimer

	function ConstructionTimer.init(activeTimersRef, completedConstructionsRef)
		State.activeTimers = activeTimersRef
		State.completedConstructions = completedConstructionsRef
	end
end
