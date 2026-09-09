-- Serialization: focused implementation for ConstructionData.
return function(Context)
	local State = Context.State
	local ConstructionData = Context.ConstructionData
	local HttpService = Context.HttpService

	function ConstructionData.generateUniqueID()
		return HttpService:GenerateGUID(false):sub(1, 12) .. "_" .. tostring(os.time())
	end

	function ConstructionData.saveConstructionData(
		player,
		constructionID,
		buildingType,
		timeLeft,
		position,
		rotation,
		size,
		plot,
		level,
		xp,
		isRobuxBuilding
	)
		local currentConstructions = player:FindFirstChild("Data")
			and player.Data:FindFirstChild("CurrentConstructions")
		if not currentConstructions then
			return
		end

		local adjustedPos = Context.getPlotRelativePosition(position, plot)
		local adjustedRotation = Context.getRotationForPlot(rotation, plot)

		-- Add Robux flag to save data (as 12th parameter)
		local saveData = string.format(
			"%.0f,%.2f,%.2f,%.2f,%.1f,%.1f,%.1f,%s,%d,%d,%d,%s",
			timeLeft,
			adjustedPos.X,
			adjustedPos.Y,
			adjustedPos.Z,
			adjustedRotation.X,
			adjustedRotation.Y,
			adjustedRotation.Z,
			size,
			os.time(),
			level or 1,
			xp or 0,
			isRobuxBuilding and "true" or "false" -- Add Robux flag
		)

		local dataEntry = Instance.new("StringValue")
		dataEntry.Name = buildingType .. "_" .. constructionID
		dataEntry.Value = saveData
		dataEntry.Parent = currentConstructions
	end

	function ConstructionData.loadConstructionData(dataString)
		local parts = string.split(dataString, ",")

		return {
			timeLeft = tonumber(parts[1]) or 0,
			position = Vector3.new(tonumber(parts[2]) or 0, tonumber(parts[3]) or 1.25, tonumber(parts[4]) or 0),
			rotation = Vector3.new(tonumber(parts[5]) or 0, tonumber(parts[6]) or 0, tonumber(parts[7]) or 0),
			size = parts[8] or "4x4",
			lastUpdated = tonumber(parts[9]) or os.time(),
			level = tonumber(parts[10]) or 1,
			xp = tonumber(parts[11]) or 0,
			isRobuxBuilding = parts[12] == "true", -- Parse Robux flag
		}
	end
end
