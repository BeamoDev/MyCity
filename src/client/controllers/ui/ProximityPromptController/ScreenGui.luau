-- ScreenGui: focused implementation for Controller.
return function(Context)
	local State = Context.State
	local PlayerGui = Context.PlayerGui

	function Context.getScreenGui()
		local screenGui = PlayerGui:FindFirstChild("ProximityPrompts")
		if screenGui == nil then
			screenGui = Instance.new("ScreenGui")
			screenGui.Name = "ProximityPrompts"
			screenGui.ResetOnSpawn = false
			screenGui.Parent = PlayerGui
		end
		return screenGui
	end
end
