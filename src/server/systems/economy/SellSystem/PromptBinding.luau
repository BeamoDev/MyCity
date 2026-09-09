-- The authored prompt stays in the map; its behavior belongs to SellSystem.
return function(Context)
	function Context.bindWorldPrompt()
		local map = game:GetService("Workspace"):FindFirstChild("Map")
		local interactives = map and map:FindFirstChild("Interactives")
		local area = interactives and interactives:FindFirstChild("SellArea")
		local part = area and area:FindFirstChild("Part")
		local prompt = part and part:FindFirstChild("ShopPrompt")
		if not prompt or not prompt:IsA("ProximityPrompt") then
			warn("[SellSystem] Missing ProximityPrompt: Workspace.Map.Interactives.SellArea.Part.ShopPrompt")
			return
		end

		prompt.Triggered:Connect(function(player)
			if not Context.Guard.ready(player) then
				return
			end
			local data = player:FindFirstChild("Data")
			local info = data and data:FindFirstChild("PlayerInfo")
			local tutorial = info and info:FindFirstChild("Tutorial")
			local isInTutorial = tutorial and tutorial:FindFirstChild("IsInTutorial")
			if not isInTutorial or isInTutorial.Value then
				return
			end
			Context.OpenSellUIEvent:FireClient(player)
		end)
	end
end
