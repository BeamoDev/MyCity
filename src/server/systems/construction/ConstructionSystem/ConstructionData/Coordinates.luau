-- Coordinates: focused implementation for ConstructionData.
return function(Context)
	local State = Context.State

	function Context.getPlotRelativePosition(worldPosition, plot)
		local plotCenter = plot:FindFirstChild("Center")
		if not plotCenter then
			return worldPosition
		end

		local relativePosition = worldPosition - plotCenter.Position

		local plotNumber = tonumber(plot.Name:match("Plot(%d+)"))
		if plotNumber and plotNumber >= 5 and plotNumber <= 8 then
			relativePosition = Vector3.new(-relativePosition.X, relativePosition.Y, -relativePosition.Z)
		end

		return relativePosition
	end

	function Context.getWorldPositionFromRelative(relativePosition, plot)
		local plotCenter = plot:FindFirstChild("Center")
		if not plotCenter then
			return relativePosition
		end

		local plotNumber = tonumber(plot.Name:match("Plot(%d+)"))
		if plotNumber and plotNumber >= 5 and plotNumber <= 8 then
			relativePosition = Vector3.new(-relativePosition.X, relativePosition.Y, -relativePosition.Z)
		end

		local worldPosition = plotCenter.Position + relativePosition
		return worldPosition
	end

	function Context.getRotationForPlot(orientation, plot)
		local plotNumber = tonumber(plot.Name:match("Plot(%d+)"))
		if plotNumber and plotNumber >= 5 and plotNumber <= 8 then
			return Vector3.new(orientation.X, orientation.Y + 180, orientation.Z)
		end
		return orientation
	end

	function Context.getRotationFromPlot(orientation, plot)
		local plotNumber = tonumber(plot.Name:match("Plot(%d+)"))
		if plotNumber and plotNumber >= 5 and plotNumber <= 8 then
			return Vector3.new(orientation.X, orientation.Y - 180, orientation.Z)
		end
		return orientation
	end
end
