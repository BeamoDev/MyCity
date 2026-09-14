-- Evaluate only relevant service providers from the shared plot snapshot.
return function(Context)
	function Context.calculateHealthPercent(building, plot, snapshot)
		local position = Context.Snapshot.position(building)
		if not position then
			return 50
		end
		snapshot = snapshot or Context.createSnapshot(plot)
		if not snapshot.valid then
			return 50
		end
		local ratio = Context.Snapshot.coverage(position, snapshot.health, snapshot.indexes and snapshot.indexes.health)
		return math.floor(100 + (50 - 100) * ratio)
	end
end
