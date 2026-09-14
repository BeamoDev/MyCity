-- BuildingActions: focused implementation for UIController.
return function(Context)
	local State = Context.State
	local UIController = Context.UIController
	local ReplicatedStorage = Context.ReplicatedStorage
	local REQUEST_COOLDOWN = Context.REQUEST_COOLDOWN

	function Context.setupBuildingDataUI()
		if not State.BuildingDataFrame then
			return
		end

		local Buttonsframe = State.BuildingDataFrame.Frame.Buttons
		local closeButton = State.BuildingDataFrame.Frame.Header:FindFirstChild("X")
		local CollectButton = Buttonsframe:FindFirstChild("Collect")
		local DeleteButton = Buttonsframe:FindFirstChild("Delete")

		if DeleteButton then
			local label = DeleteButton:FindFirstChild("TextLabel")
			if label then
				label.Text = "Store"
			elseif DeleteButton:IsA("TextButton") then
				DeleteButton.Text = "Store"
			end
		end
		if not DeleteButton or not CollectButton then
			return
		end
		Context.connections:connect(DeleteButton.Activated, function()
			local currentTime = tick()

			if currentTime - State.lastRequestTime < REQUEST_COOLDOWN then
				return
			end

			State.lastRequestTime = currentTime

			if State.currentBuildingToCollect and State.currentBuildingToCollect.Parent then
				ReplicatedStorage.Events.Movement.Delete:FireServer(State.currentBuildingToCollect)
			end

			UIController.closeUIFrame(State.BuildingDataFrame)
			State.currentBuildingToCollect = nil
		end)

		Context.connections:connect(CollectButton.Activated, function()
			local currentTime = tick()

			if currentTime - State.lastRequestTime < REQUEST_COOLDOWN then
				return
			end

			State.lastRequestTime = currentTime

			if State.currentBuildingToCollect and State.currentBuildingToCollect.Parent then
				ReplicatedStorage.Events.Movement.CollectBuilding:FireServer(State.currentBuildingToCollect)
			end

			UIController.closeUIFrame(State.BuildingDataFrame)
			State.currentBuildingToCollect = nil
		end)

		if closeButton then
			Context.connections:connect(closeButton.Activated, function()
				UIController.closeUIFrame(State.BuildingDataFrame)
				State.currentBuildingToCollect = nil
			end)
		end
	end
end
