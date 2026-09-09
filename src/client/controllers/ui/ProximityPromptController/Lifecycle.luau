-- Lifecycle: focused implementation for Controller.
return function(Context)
	local State = Context.State
	local Controller = Context.Controller
	local ProximityPromptService = Context.ProximityPromptService

	function Controller.start()
		if State.started then
			return
		end
		State.started = true
		ProximityPromptService.PromptShown:Connect(function(prompt, inputType)
			if prompt.Style == Enum.ProximityPromptStyle.Default then
				return
			end

			local gui = Context.getScreenGui()

			local cleanupFunction = Context.createPrompt(prompt, inputType, gui)

			local hidden, destroying
			local function close()
				if hidden then
					hidden:Disconnect()
				end
				if destroying then
					destroying:Disconnect()
				end
				cleanupFunction()
			end
			hidden = prompt.PromptHidden:Connect(close)
			destroying = prompt.Destroying:Connect(close)
		end)
	end
end
