-- Lifecycle: focused implementation for SellController.
return function(Context)
	local State = Context.State
	local SellController = Context.SellController
	local OpenSellUIEvent = Context.OpenSellUIEvent

	function SellController.init(gui)
		State.playerGui = gui

		State.sellFrame = State.playerGui.Frames:WaitForChild("SellTool")
		State.sellMenu = State.sellFrame:WaitForChild("Frame")

		local toolItem = State.sellMenu:WaitForChild("ToolItem")
		State.equippedToolName = toolItem:WaitForChild("ItemName")
		State.equippedToolCost = toolItem:WaitForChild("Cost")
		State.equippedToolIcon = toolItem:WaitForChild("Icon")

		State.sellItemButton = State.sellMenu:WaitForChild("SellItem")

		State.constructBuildingFrame = State.sellMenu:WaitForChild("ConstructBuilding", 5)
		State.equipBuildingFrame = State.sellMenu:WaitForChild("EquipABuilding", 5)

		Context.setUIState("no_tool", nil, 0, 0, nil)
		Context.connectSellEvents()
		OpenSellUIEvent:FireServer()
	end
end
