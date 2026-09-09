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
		local distance, range = Context.Snapshot.nearest(position, snapshot.health)
		if range == 0 then
			return 50
		end
		local ratio = math.clamp((distance - range) / (range * 2), 0, 1)
		return math.floor(100 + (50 - 100) * ratio)
	end
end
