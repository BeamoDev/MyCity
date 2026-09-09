local Transitions = require(game:GetService("ReplicatedStorage").shared.ui.Transitions)
return function(Context)
	local UI, State = Context.UIController, Context.State
	Context.Transitions = Transitions
	function UI.setGameplayUIVisible(visible)
		for _, name in { "Buttons", "CashDisplay", "FriendBoost" } do
			local node = State.HUD:FindFirstChild(name)
			if node then
				node.Visible = visible
			end
		end
		State.FramesFolder.Visible = true
	end
	function UI.finishTutorial(cleanup)
		cleanup()
		Context.player:SetAttribute("MyCityHudTransition", false)
		Context.refreshQuestUI()
		Context.ReplicatedStorage.Events.Loading.ClientReady:FireServer()
	end
	function Context.cleanupPresentation()
		Context.player:SetAttribute("MyCityHudTransition", false)
		if State.HUD then
			Transitions.cancelTree(State.HUD)
		end
	end
end
