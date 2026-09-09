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

	function Context.connectCityName()
		Context.connections:connect(
			ReplicatedStorage.Events.CitySign.RequestCityNameEdit.OnClientEvent,
			function(currentName)
				-- Block during tutorial
				if Context.checkTutorialStatus() then
					return
				end

				if State.CityNameFrame then
					local textBox = State.CityNameFrame.Frame:FindFirstChild("TextBox")
					if textBox then
						textBox.Text = currentName or ""
					end
					UIController.openUIFrame(State.CityNameFrame)
					if textBox then
						textBox:CaptureFocus()
					end
				end
			end
		)

		Context.connections:connect(
			ReplicatedStorage.Events.CitySign.UpdateCityName.OnClientEvent,
			function(success, filteredName)
				if success and State.currentEditingPlot then
					local citySign = State.currentEditingPlot.UI:FindFirstChild("CitySign")
					if citySign and citySign:FindFirstChild("Body") and citySign.Body:FindFirstChild("SurfaceGui") then
						citySign.Body.SurfaceGui.Frame.CityName.Text = filteredName
					end
				end
			end
		)

		Context.connections:connect(ReplicatedStorage.Events.Notifications.PlaceSound.OnClientEvent, function()
			game.SoundService.SFX.PlaceSound:Play()
		end)
	end
end
