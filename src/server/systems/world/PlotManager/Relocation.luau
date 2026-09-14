-- Retired: restoration already maps the complete saved transform to the assigned plot.
-- The legacy in-place relocation truncated saved construction metadata.
return function(Context)
	local PlotManager = Context.PlotManager
	function PlotManager.offsetBuildingsAndConstructions()
		return false, "Plot relocation is only supported through city restoration."
	end
end
