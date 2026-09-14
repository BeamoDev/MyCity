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

		local data = player:FindFirstChild("Data")
		local info = data and data:FindFirstChild("PlayerInfo")
		local tutorial = info and info:FindFirstChild("Tutorial")
		local active = tutorial and tutorial:FindFirstChild("IsInTutorial")
		if active and not active.Value and not player:GetAttribute("MyCityIntroActive") then
			for _, name in { "Buttons", "Frames", "CashDisplay", "FriendBoost" } do
				local child = State.playerGui:FindFirstChild(name)
				if child and child:IsA("GuiObject") then
					child.Visible = true
				end
			end
		end

		-- The placement controller owns and destroys its exact preview instances.
		local UIController = require(script.Parent.Parent.Parent:WaitForChild("ui"):WaitForChild("UIController"))
		UIController.clearStuckEffects()

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
