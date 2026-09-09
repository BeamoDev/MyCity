-- RemoteBindings: focused implementation for UIController.
return function(Context)
	local State = Context.State
	local UIController = Context.UIController
	local TweenService = Context.TweenService
	local ReplicatedStorage = Context.ReplicatedStorage
	local ProximityPromptService = Context.ProximityPromptService
	local Icon = Context.Icon
	local player = Context.player
	local questEvents = Context.questEvents

	function Context.connectMenus()
		Context.connections:connect(
			ReplicatedStorage.Events.UI:WaitForChild("ToggleOverheadUI").OnClientEvent,
			function(overheadBillboard)
				overheadBillboard.Enabled = true
				overheadBillboard.ImageLabel.ImageTransparency = 0
			end
		)

		Context.connections:connect(ReplicatedStorage.Events.UI:WaitForChild("OpenItemShop").OnClientEvent, function()
			-- Block during tutorial
			if Context.checkTutorialStatus() then
				return
			end
			UIController.openUIFrame(State.ItemShopFrame)
		end)

		Context.connections:connect(ReplicatedStorage.Events.Sell:WaitForChild("OpenUI").OnClientEvent, function()
			-- Block during tutorial
			if Context.checkTutorialStatus() then
				return
			end
			State.SellFrame.Parent.Visible = true
			UIController.openUIFrame(State.SellFrame)
		end)
	end
end
