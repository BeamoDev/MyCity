-- Assignment: focused implementation for PlotManager.
return function(Context)
	local State = Context.State
	local PlotManager = Context.PlotManager
	local ReplicatedStorage = Context.ReplicatedStorage
	local plotsFolder = Context.plotsFolder

	function PlotManager.assignPlot(player, character)
		local plotData = player:WaitForChild("Data"):WaitForChild("PlotInfo"):WaitForChild("Plot")
		plotData.Value = 0

		local availablePlots = {}
		for _, plotCandidate in ipairs(plotsFolder:GetChildren()) do
			if
				plotCandidate.Name:match("^Plot%d+$")
				and plotCandidate:FindFirstChild("Land")
				and plotCandidate:FindFirstChild("Buildings")
				and plotCandidate:FindFirstChild("PlotSpawn")
				and not plotCandidate:GetAttribute("Assigned")
			then
				table.insert(availablePlots, plotCandidate)
			end
		end

		if #availablePlots == 0 then
			return
		end

		local plot = availablePlots[math.random(1, #availablePlots)]
		local plotNumber = tonumber(plot.Name:match("Plot(%d+)"))
		plotData.Value = plotNumber

		local lastPlot = player.Data:FindFirstChild("PlayerInfo") and player.Data.PlayerInfo:FindFirstChild("LastPlot")
		if lastPlot then
			lastPlot.Value = plotNumber
		end

		plot:SetAttribute("Assigned", true)
		plot:SetAttribute("CityId", player.UserId)

		local ownedTilesFolder = player:WaitForChild("Data"):WaitForChild("OwnedTiles")
		local Owned = plot.Land:FindFirstChild("Owned")
		local Locked = plot.Land:FindFirstChild("Locked")

		if Owned and Locked then
			for _, tile in ipairs(Owned:GetChildren()) do
				local tileNumber = Context.getTileNumber(tile)
				if tileNumber then
					if not ownedTilesFolder:FindFirstChild("Tile" .. tileNumber) then
						local tileValue = Instance.new("IntValue")
						tileValue.Name = "Tile" .. tileNumber
						tileValue.Value = tileNumber
						tileValue.Parent = ownedTilesFolder
					end
				end
			end

			for _, tile in ipairs(Locked:GetChildren()) do
				local tileNumber = Context.getTileNumber(tile)
				if tileNumber and ownedTilesFolder:FindFirstChild("Tile" .. tileNumber) then
					for _, child in ipairs(tile:GetChildren()) do
						if child.Name == "LockedScenery" or child.Name == "ExpansionPrompt" then
							child:Destroy()
						end
					end

					tile.Parent = Owned
					tile.Color = Color3.fromRGB(52, 142, 64)
					tile.Size = Vector3.new(5, 0.2, 5)
				end
			end
		end

		local playerSign = plot.UI:FindFirstChild("CitySign")
		if playerSign and playerSign:FindFirstChild("Body") and playerSign.Body:FindFirstChild("SurfaceGui") then
			local savedCityName = nil
			if State.CityNameSystem then
				savedCityName = State.CityNameSystem.getCityName(player)
			end

			if savedCityName and savedCityName ~= "" then
				playerSign.Body.SurfaceGui.Frame.CityName.Text = savedCityName
			else
				playerSign.Body.SurfaceGui.Frame.CityName.Text = player.Name .. "'s City!"
			end
		end

		local playerUserId = player.UserId
		plot.UI.Overhead.Mugshot.ImageLabel.Image = "https://www.roblox.com/headshot-thumbnail/image?userId="
			.. playerUserId
			.. "&width=420&height=420&format=png"

		local overheadBillboard = plot.UI.Overhead.Mugshot
		overheadBillboard.Enabled = false
		ReplicatedStorage:WaitForChild("Events").UI
			:WaitForChild("ToggleOverheadUI")
			:FireClient(player, overheadBillboard)

		local root = character:WaitForChild("HumanoidRootPart", 10)
		assert(
			root and player.Parent and player.Character == character and not player:GetAttribute("MyCityLeaving"),
			"Character unavailable or player departing"
		)
		root.CFrame = plot:FindFirstChild("PlotSpawn").CFrame

		Context.spawnAllScenery()
	end
end
