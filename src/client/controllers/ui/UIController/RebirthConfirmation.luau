local Rewards = require(script.Parent.RebirthRewards)
return function(Context)
	local State, UIController = Context.State, Context.UIController
	function Context.showRebirthConfirmation(data)
		local confirmationFrame = State.FramesFolder:FindFirstChild("RebirthConfirm")
		if not confirmationFrame or not data then
			return
		end
		local frame = confirmationFrame:FindFirstChild("Frame") or confirmationFrame
		local scrollingFrame = frame:FindFirstChild("ScrollingFrame")
		if not scrollingFrame then
			warn("[Rebirth] Missing RebirthConfirm.Frame.ScrollingFrame")
			return
		end
		Rewards.render(scrollingFrame, data, script.Parent, Context.formatNumber)
		if State.confirmYesConnection then
			State.confirmYesConnection:Disconnect()
			State.confirmYesConnection = nil
		end
		if State.confirmNoConnection then
			State.confirmNoConnection:Disconnect()
			State.confirmNoConnection = nil
		end

		local yesButton = frame:FindFirstChild("Yes")
		local noButton = frame:FindFirstChild("No")

		if yesButton then
			State.confirmYesConnection = Context.connections:connect(yesButton.Activated, function()
				UIController.closeUIFrame(confirmationFrame)
				State.rebirthRemotes.RequestRebirth:FireServer()

				if State.confirmYesConnection then
					State.confirmYesConnection:Disconnect()
					State.confirmYesConnection = nil
				end
				if State.confirmNoConnection then
					State.confirmNoConnection:Disconnect()
					State.confirmNoConnection = nil
				end
			end)
		end

		if noButton then
			State.confirmNoConnection = Context.connections:connect(noButton.Activated, function()
				UIController.closeUIFrame(confirmationFrame)

				if State.confirmYesConnection then
					State.confirmYesConnection:Disconnect()
					State.confirmYesConnection = nil
				end
				if State.confirmNoConnection then
					State.confirmNoConnection:Disconnect()
					State.confirmNoConnection = nil
				end
			end)
		end

		UIController.openUIFrame(confirmationFrame)
	end
end
