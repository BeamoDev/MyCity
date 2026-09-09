-- Authored HUD.Buttons.Up shortcuts; no scripts are needed under the buttons.
return function(Context)
	local player = Context.player
	local destinations = {
		Buy = CFrame.new(-152.191, 5.194, -13.936) * CFrame.Angles(0, math.rad(90), 0),
		Sell = CFrame.new(-152.191, 5.194, 11.564) * CFrame.Angles(0, math.rad(90), 0),
	}
	local function cityDestination()
		-- Resolve on each click: plots can change after loading or reassignment.
		local data = player:FindFirstChild("Data")
		local info = data and data:FindFirstChild("PlotInfo")
		local number = info and info:FindFirstChild("Plot")
		local plots = Context.Workspace:FindFirstChild("Plots")
		local plot = number and plots and plots:FindFirstChild("Plot" .. tostring(number.Value))
		local spawn = plot and plot:FindFirstChild("PlotSpawn")
		return if spawn and spawn:IsA("BasePart") then spawn.CFrame else nil
	end
	function Context.setupTravelButtons()
		local up = Context.State.ButtonFolder:FindFirstChild("Up")
		if not up then
			warn("[Travel] Missing HUD.Buttons.Up")
			return
		end
		for _, name in { "Buy", "City", "Sell" } do
			local button = up:FindFirstChild(name)
			if not button or not button:IsA("GuiButton") then
				warn("[Travel] Missing HUD.Buttons.Up." .. name)
				continue
			end
			Context.connections:connect(button.Activated, function()
				if player:GetAttribute("MyCityIntroActive") or player:GetAttribute("MyCityLoaded") ~= true then
					return
				end
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if not root or not root:IsA("BasePart") or root.Anchored then
					return
				end
				local target = if name == "City" then cityDestination() else destinations[name]
				if not target then
					return
				end
				root.CFrame = target
				root.AssemblyLinearVelocity = Vector3.zero
				root.AssemblyAngularVelocity = Vector3.zero
			end)
		end
	end
end
