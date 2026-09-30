-- Reset: focused implementation for PlotManager.
return function(Context)
	local State = Context.State
	local PlotManager = Context.PlotManager
	local Workspace = Context.Workspace
	local ReplicatedStorage = Context.ReplicatedStorage
	local plotsFolder = Context.plotsFolder
	local prepareEmptyPlot = require(script.Parent.Parent.EmptyPlotPresentation)

	function PlotManager.resetPlot(player)
		local data = player:FindFirstChild("Data")
		local info = data and data:FindFirstChild("PlotInfo")
		local plotData = info and info:FindFirstChild("Plot")
		if not plotData then
			return
		end

		local plotNumber = plotData.Value
		if plotNumber == 0 then
			return
		end

		local plot = plotsFolder:FindFirstChild("Plot" .. plotNumber)
		if not plot or tostring(plot:GetAttribute("CityId")) ~= tostring(player.UserId) then
			return
		end

		local lastPlot = player.Data.PlayerInfo:FindFirstChild("LastPlot")
		if lastPlot then
			lastPlot.Value = plotNumber
		end

		plot:SetAttribute("Assigned", false)
		plot:SetAttribute("CityId", "Empty")

		local playerSign = plot.UI:FindFirstChild("CitySign")
		if playerSign and playerSign:FindFirstChild("Body") and playerSign.Body:FindFirstChild("SurfaceGui") then
			playerSign.Body.SurfaceGui.Frame.CityName.Text = "Nothing"
			local popLabel = playerSign.Body.SurfaceGui.Frame:FindFirstChild("Population")
			if popLabel then
				popLabel.Text = "Population: 0"
			end
		end

		local overhead = plot:FindFirstChild("UI") and plot.UI:FindFirstChild("Overhead")
		local mugshot = overhead and overhead:FindFirstChild("Mugshot")
		if mugshot then
			mugshot.ImageLabel.Image = ""
			mugshot.Enabled = false
		end

		local collectButton = plot:FindFirstChild("UI")
			and plot.UI:FindFirstChild("CollectIncome")
			and plot.UI.CollectIncome:FindFirstChild("Button")
		if collectButton then
			local surfaceGui = collectButton:FindFirstChild("ButtonInfo")
			if surfaceGui then
				local incomeLabel = surfaceGui:FindFirstChild("IncomeAvailable")
				if incomeLabel then
					incomeLabel.Text = "$0"
				end
			end
		end

		local newplot = game.ServerStorage["PlotTemplate"]:FindFirstChild(plot.Name):Clone()
		prepareEmptyPlot(newplot)

		plot:Destroy()
		wait()
		newplot.Parent = game.Workspace.Plots

		task.spawn(Context.spawnSceneryForPlot, newplot)

		plotData.Value = 0
	end
end
