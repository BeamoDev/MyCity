return function(Context)
	function Context.setupBuilderDisplay()
		local builders = Context.State.ButtonFolder:FindFirstChild("Builders", true)
		local count = builders and builders:FindFirstChild("Count")
		if not count then
			warn("[Builders UI] Missing HUD.Buttons.Builders.Count")
			return
		end
		Context.connections:connect(
			Context.ReplicatedStorage.Events.UI.UpdateBuilderUI.OnClientEvent,
			function(current, maximum)
				if type(current) ~= "number" or type(maximum) ~= "number" then
					return
				end
				count.Text = string.format("%d/%d", current, maximum)
				count.TextColor3 = if current == 0
					then Color3.fromRGB(47, 255, 47)
					elseif current < maximum then Color3.fromRGB(255, 255, 0)
					else Color3.fromRGB(255, 47, 47)
			end
		)
	end
end
