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
		local distance, range = Context.Snapshot.nearest(position, snapshot.police)
		if range == 0 then
			return Context.MAX_CRIME_RATE
		end
		local ratio = math.clamp((distance - range) / (range * 2), 0, 1)
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
		local distance, range = Context.Snapshot.nearest(position, snapshot.fire)
		if range == 0 then
			return Context.MIN_FIRE_SAFETY
		end
		local ratio = math.clamp((distance - range) / (range * 2), 0, 1)
		return math.floor(100 + (Context.MIN_FIRE_SAFETY - 100) * ratio)
	end
end
