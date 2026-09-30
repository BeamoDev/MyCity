-- Display: focused implementation for SellController.
return function(Context)
	local State = Context.State
	local TweenService = Context.TweenService

	function Context.setUIState(state, tool, sellPrice, imageId, statusText)
		State.currentUIState = state
		State.currentTool = tool

		State.constructBuildingFrame.Visible = false
		State.equipBuildingFrame.Visible = false
		State.sellItemButton.Visible = false

		if tool then
			State.equippedToolName.Text = tool.Name
			State.equippedToolIcon.Image = "rbxassetid://" .. (imageId or 0)

			local toolLevel = tool:FindFirstChild("BuildingLevel")
			if toolLevel then
				State.equippedToolName.Text = tool.Name .. " (Lv." .. toolLevel.Value .. ")"
			end
		else
			State.equippedToolName.Text = "No Tool Equipped"
			State.equippedToolIcon.Image = "rbxasset://textures/ui/GuiImagePlaceholder.png"
		end

		if state == "no_tool" then
			State.equipBuildingFrame.Visible = true
			State.equippedToolCost.Text = "Equip a building tool"
			State.equippedToolCost.TextColor3 = Color3.new(0.8, 0.8, 0.8)
			State.canSell = false
		elseif state == "must_build" then
			State.constructBuildingFrame.Visible = true
			State.equippedToolCost.Text = statusText or "Must Build to Sell"
			State.equippedToolCost.TextColor3 = Color3.new(1, 0.5, 0.5)
			State.canSell = false
		elseif state == "can_sell" then
			State.sellItemButton.Visible = true
			State.sellItemButton.BackgroundColor3 = Color3.new(0.3, 0.9, 0.3)
			State.sellItemButton.Text = "SELL"
			State.sellItemButton.TextColor3 = Color3.new(1, 1, 1)
			State.sellItemButton.Active = true
			State.sellItemButton.AutoButtonColor = true

			State.equippedToolCost.Text = Context.formatPrice(sellPrice)
			State.equippedToolCost.TextColor3 = Color3.new(0.3, 1, 0.3)

			State.canSell = true

			local highlight = State.equippedToolIcon.Parent:FindFirstChild("Highlight")
			if not highlight then
				highlight = Instance.new("UIStroke")
				highlight.Name = "Highlight"
				highlight.Color = Color3.new(0.3, 1, 0.3)
				highlight.Thickness = 2
				highlight.Transparency = 0.5
				highlight.Parent = State.equippedToolIcon.Parent

				local pulseTween = TweenService:Create(
					highlight,
					TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
					{ Transparency = 0.8 }
				)
				pulseTween:Play()
			end
		else
			State.sellItemButton.Visible = true
			State.sellItemButton.BackgroundColor3 = Color3.new(0.7, 0.7, 0.7)
			State.sellItemButton.Text = "SELL"
			State.sellItemButton.TextColor3 = Color3.new(0.9, 0.9, 0.9)
			State.sellItemButton.Active = false
			State.sellItemButton.AutoButtonColor = false

			State.equippedToolCost.Text = "$0"
			State.equippedToolCost.TextColor3 = Color3.new(0.8, 0.8, 0.8)
			State.canSell = false
		end

		if state ~= "can_sell" then
			local highlight = State.equippedToolIcon.Parent:FindFirstChild("Highlight")
			if highlight then
				highlight:Destroy()
			end
		end
	end

	function Context.updateToolUI(tool, sellPrice, imageId, isValid, statusText)
		if not tool then
			Context.setUIState("no_tool", nil, 0, 0, nil)
		elseif not isValid then
			if statusText and (statusText:find("Must place") or statusText:find("Must build")) then
				Context.setUIState("must_build", tool, sellPrice, imageId, statusText)
			else
				Context.setUIState("none", tool, sellPrice, imageId, statusText)
			end
		else
			Context.setUIState("can_sell", tool, sellPrice, imageId, statusText)
		end
	end
end
