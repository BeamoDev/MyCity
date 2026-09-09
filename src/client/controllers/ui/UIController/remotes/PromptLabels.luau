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

	function Context.connectPromptLabels()
		Context.connections:connect(ProximityPromptService.PromptShown, function(prompt, inputType)
			local ownerUserId = prompt:GetAttribute("OwnerUserId")
			if ownerUserId and prompt.Parent then
				local promptVal = prompt.Parent:FindFirstChild("PromptVal")

				if ownerUserId ~= player.UserId then
					if promptVal and promptVal.Value == "Construction" then
						prompt.ActionText = "Steal"
					else
						prompt.ActionText = "Steal"
					end
				else
					if promptVal and promptVal.Value == "Construction" then
						prompt.ActionText = "Skip"
					else
						prompt.ActionText = "Info"
					end
				end
			end
		end)

		Context.connections:connect(ProximityPromptService.PromptHidden, function(prompt, inputType)
			local ownerUserId = prompt:GetAttribute("OwnerUserId")
			if ownerUserId and prompt.Parent then
				local promptVal = prompt.Parent:FindFirstChild("PromptVal")

				if promptVal and promptVal.Value == "Construction" then
					prompt.ActionText = "Skip"
				else
					prompt.ActionText = "Info"
				end
			end
		end)

		-- Monitor tutorial status changes
		Context.connections:spawn(function()
			local data = player:WaitForChild("Data")
			local playerInfo = data:WaitForChild("PlayerInfo")
			local tutorialValue = playerInfo.Tutorial:WaitForChild("IsInTutorial")

			-- Set initial status
			State.isInTutorial = tutorialValue.Value

			-- Listen for changes
			Context.connections:connect(tutorialValue:GetPropertyChangedSignal("Value"), function()
				State.isInTutorial = tutorialValue.Value
			end)
		end)
	end
end
