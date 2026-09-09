-- PreviewCleanup: focused implementation for SellController.
return function(Context)
	local State = Context.State
	local player = Context.player

	function Context.closeAllUIs()
		local UIController = require(script.Parent.Parent.Parent:WaitForChild("ui"):WaitForChild("UIController"))
		local frames = UIController.getFrames()

		if frames.BuildInfo and frames.BuildInfo.Visible then
			UIController.closeUIFrame(frames.BuildInfo)
		end

		if frames.Sell and frames.Sell.Visible then
			UIController.closeUIFrame(frames.Sell)
		end
	end

	function Context.cleanupToolPreview()
		local HUD = State.playerGui:FindFirstChild("MobilePlacement")
		if HUD then
			HUD.Visible = false
		end

		if player.Data.PlayerInfo.Tutorial.IsInTutorial.Value == false then
			HUD.Parent.Buttons.Visible = true
			HUD.Parent.Frames.Visible = true
			HUD.Parent.CashDisplay.Visible = true
			HUD.Parent.FriendBoost.Visible = true
		end

		for _, obj in pairs(workspace:GetChildren()) do
			if obj.Name:match("^Preview_") then
				obj:Destroy()
			end
		end

		local playerData = player:FindFirstChild("Data")
		if playerData then
			local plotInfo = playerData:FindFirstChild("PlotInfo")
			if plotInfo and plotInfo:FindFirstChild("Plot") then
				local plotNumber = plotInfo.Plot.Value
				if plotNumber > 0 then
					local plot = workspace.Plots:FindFirstChild("Plot" .. plotNumber)
					if plot then
						local land = plot:FindFirstChild("Land")
						local Locked = land and land:FindFirstChild("Locked")
						if Locked then
							for _, tile in pairs(Locked:GetChildren()) do
								local selectionBox = tile:FindFirstChild("LockedTileSelectionBox")
								if selectionBox then
									selectionBox:Destroy()
								end
							end
						end
					end
				end
			end
		end
	end
end
