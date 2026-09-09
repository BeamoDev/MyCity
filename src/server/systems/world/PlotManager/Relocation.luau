-- Relocation: focused implementation for PlotManager.
return function(Context)
	local State = Context.State
	local PlotManager = Context.PlotManager
	local plotsFolder = Context.plotsFolder

	function PlotManager.offsetBuildingsAndConstructions(player, newSlotNumber)
		local data = player:WaitForChild("Data")
		local plotData = data:WaitForChild("PlotInfo"):FindFirstChild("Plot")
		local lastPlotData = data:FindFirstChild("PlayerInfo") and data.PlayerInfo:FindFirstChild("LastPlot")

		if not plotData or not lastPlotData then
			return
		end

		local plotNumber = plotData.Value
		local lastSlotNumber = lastPlotData.Value
		local plot = plotsFolder:FindFirstChild("Plot" .. plotNumber)

		if not plot then
			return
		end

		if not lastSlotNumber or lastSlotNumber == 0 then
			return
		end

		local lastPlot = plotsFolder:FindFirstChild("Plot" .. lastSlotNumber)

		if not lastPlot then
			return
		end

		local function findClosestPlot(position)
			local closestPlot = nil
			local closestDistance = math.huge

			for _, plotFolder in ipairs(plotsFolder:GetChildren()) do
				if plotFolder:IsA("Folder") and plotFolder:FindFirstChild("Center") then
					local distance = (plotFolder.Center.Position - position).Magnitude
					if distance < closestDistance then
						closestDistance = distance
						closestPlot = plotFolder
					end
				end
			end

			return closestPlot, closestDistance
		end

		local function offsetModel(model)
			if not (model:IsA("Model") and model.PrimaryPart) then
				return
			end

			local closestPlot, distance = findClosestPlot(model.PrimaryPart.Position)
			if closestPlot and closestPlot ~= plot then
				local relativeCFrame = closestPlot.Center.CFrame:toObjectSpace(model.PrimaryPart.CFrame)
				local correctedCFrame = plot.Center.CFrame:toWorldSpace(relativeCFrame)
				model:SetPrimaryPartCFrame(correctedCFrame)
			else
				local relativeCFrame = lastPlot.Center.CFrame:toObjectSpace(model.PrimaryPart.CFrame)
				local newCFrame = plot.Center.CFrame:toWorldSpace(relativeCFrame)
				model:SetPrimaryPartCFrame(newCFrame)
			end

			local newCFrame = model.PrimaryPart.CFrame
			local xRot, yRot, zRot = newCFrame:ToOrientation()
			xRot, yRot, zRot = math.deg(xRot), math.deg(yRot), math.deg(zRot)

			local name = model.Config.BuildingName.Value
			local buildingEntry = data.CurrentBuildings:FindFirstChild(name)
			if buildingEntry then
				buildingEntry.Value = string.format(
					"%s,%s,%s,%s,%s,%s",
					newCFrame.Position.X,
					newCFrame.Position.Y,
					newCFrame.Position.Z,
					xRot,
					yRot,
					zRot
				)
			end
		end

		local function offsetFolder(folder)
			if not folder then
				return
			end

			for _, model in ipairs(folder:GetChildren()) do
				offsetModel(model)
			end
		end

		offsetFolder(plot.Buildings:FindFirstChild("Placed"))
		offsetFolder(plot.Buildings:FindFirstChild("Construction"))

		lastSlotNumber = newSlotNumber
	end
end
