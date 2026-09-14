-- Evaluate only relevant service providers from the shared plot snapshot.
return function(Context)
	function Context.calculateCrimePercent(building, plot, snapshot)
		local position = Context.Snapshot.position(building)
		if not position then
			return Context.BASE_CRIME_RATE
		end
		snapshot = snapshot or Context.createSnapshot(plot)
		if not snapshot.valid then
			return Context.BASE_CRIME_RATE
		end
		local ratio = Context.Snapshot.coverage(position, snapshot.police, snapshot.indexes and snapshot.indexes.police)
		return math.floor(Context.BASE_CRIME_RATE + (Context.MAX_CRIME_RATE - Context.BASE_CRIME_RATE) * ratio)
	end
	function Context.calculateFireSafetyPercent(building, plot, snapshot)
		local position = Context.Snapshot.position(building)
		if not position then
			return Context.BASE_FIRE_SAFETY
		end
		snapshot = snapshot or Context.createSnapshot(plot)
		if not snapshot.valid then
			return Context.BASE_FIRE_SAFETY
		end
		local ratio = Context.Snapshot.coverage(position, snapshot.fire, snapshot.indexes and snapshot.indexes.fire)
		return math.floor(100 + (Context.MIN_FIRE_SAFETY - 100) * ratio)
	end
end
