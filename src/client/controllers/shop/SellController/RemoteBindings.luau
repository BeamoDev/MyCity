-- RemoteBindings: focused implementation for SellController.
return function(Context)
	local State = Context.State
	local ReplicatedStorage = Context.ReplicatedStorage
	local TweenService = Context.TweenService
	local SoundService = Context.SoundService
	local player = Context.player
	local SellEvents = Context.SellEvents
	local SellItemEvent = Context.SellItemEvent
	local OpenSellUIEvent = Context.OpenSellUIEvent
	local UpdateUIEvent = Context.UpdateUIEvent
	local CleanupPreviewEvent = Context.CleanupPreviewEvent

	function Context.connectSellEvents()
		Context.connections:connect(State.sellItemButton.MouseButton1Click, function()
			if not State.canSell then
				if SoundService:FindFirstChild("SFX") and SoundService.SFX:FindFirstChild("Error") then
					SoundService.SFX.Error:Play()
				end

				local originalPos = State.sellItemButton.Position
				for i = 1, 3 do
					State.sellItemButton.Position = originalPos + UDim2.new(0.01, 0, 0, 0)
					task.wait(0.05)
					State.sellItemButton.Position = originalPos - UDim2.new(0.01, 0, 0, 0)
					task.wait(0.05)
				end
				State.sellItemButton.Position = originalPos

				return
			end

			local tool = player.Character and player.Character:FindFirstChildWhichIsA("Tool")
			if tool then
				Context.cleanupToolPreview()
				SellItemEvent:FireServer(tool.Name)
				Context.closeAllUIs()
			else
				if SoundService:FindFirstChild("SFX") and SoundService.SFX:FindFirstChild("Error") then
					SoundService.SFX.Error:Play()
				end
			end
		end)

		Context.connections:connect(UpdateUIEvent.OnClientEvent, function(tool, sellPrice, imageId, isValid, statusText)
			Context.updateToolUI(tool, sellPrice, imageId, isValid, statusText)
		end)

		Context.connections:connect(CleanupPreviewEvent.OnClientEvent, function()
			Context.cleanupToolPreview()
		end)

		if SellEvents:FindFirstChild("CantSellBank") then
			Context.connections:connect(SellEvents.CantSellBank.OnClientEvent, function()
				Context.showNotification("CannotSellBank", "Error", "Cannot sell this item!")
			end)
		end

		Context.connections:connect(SellEvents.MustBuildBuilding.OnClientEvent, function()
			Context.showNotification("BuildIt", "Error", "Must place building first!")
		end)

		if SellEvents:FindFirstChild("SoldWithProfit") then
			Context.connections:connect(
				SellEvents.SoldWithProfit.OnClientEvent,
				function(amount, buildingType, profit, level)
					local message = string.format(
						"Sold Lv.%d %s for %s (Profit: +%s)!",
						level or 1,
						buildingType,
						Context.formatPrice(amount),
						Context.formatPrice(profit)
					)
					Context.showNotification("IncomeCollected", "CaChing", message)
					Context.setUIState("no_tool", nil, 0, 0, nil)

					if State.sellFrame then
						local flash = Instance.new("Frame")
						flash.Size = UDim2.new(1, 0, 1, 0)
						flash.Position = UDim2.new(0, 0, 0, 0)
						flash.BackgroundColor3 = Color3.new(0.3, 1, 0.3)
						flash.BackgroundTransparency = 0.8
						flash.Parent = State.sellFrame

						local profitPopup = Instance.new("TextLabel")
						profitPopup.Size = UDim2.new(0.6, 0, 0.2, 0)
						profitPopup.Position = UDim2.new(0.2, 0, 0.4, 0)
						profitPopup.BackgroundTransparency = 1
						profitPopup.Text = "+$" .. tostring(profit)
						profitPopup.TextScaled = true
						profitPopup.Font = Enum.Font.SourceSansBold
						profitPopup.TextColor3 = Color3.new(0.3, 1, 0.3)
						profitPopup.TextStrokeTransparency = 0
						profitPopup.TextStrokeColor3 = Color3.new(0, 0, 0)
						profitPopup.Parent = State.sellFrame

						local popupTween = TweenService:Create(
							profitPopup,
							TweenInfo.new(1, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
							{
								Position = UDim2.new(0.2, 0, 0.2, 0),
								TextTransparency = 1,
							}
						)

						local flashTween = TweenService:Create(
							flash,
							TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
							{ BackgroundTransparency = 1 }
						)

						popupTween:Play()
						flashTween:Play()

						Context.connections:connect(flashTween.Completed, function()
							flash:Destroy()
							profitPopup:Destroy()
						end)
					end
				end
			)
		end

		Context.connections:connect(SellEvents.Sold.OnClientEvent, function(amount, buildingType)
			local message = buildingType and string.format("Sold %s for %s!", buildingType, Context.formatPrice(amount))
				or string.format("Sold for %s!", Context.formatPrice(amount))

			Context.showNotification("IncomeCollected", "CaChing", message)
			Context.setUIState("no_tool", nil, 0, 0, nil)

			if State.sellFrame then
				local flash = Instance.new("Frame")
				flash.Size = UDim2.new(1, 0, 1, 0)
				flash.Position = UDim2.new(0, 0, 0, 0)
				flash.BackgroundColor3 = Color3.new(0.3, 1, 0.3)
				flash.BackgroundTransparency = 0.8
				flash.Parent = State.sellFrame

				local flashTween = TweenService:Create(
					flash,
					TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ BackgroundTransparency = 1 }
				)
				flashTween:Play()
				Context.connections:connect(flashTween.Completed, function()
					flash:Destroy()
				end)
			end
		end)

		if SellEvents:FindFirstChild("ErrorEvent") then
			Context.connections:connect(SellEvents.ErrorEvent.OnClientEvent, function(errorMessage)
				Context.showNotification("Error", "Error", errorMessage or "Failed to sell item")
			end)
		end

		if ReplicatedStorage.Events.Notifications:FindFirstChild("BuildingCollected") then
			Context.connections:connect(
				ReplicatedStorage.Events.Notifications.BuildingCollected.OnClientEvent,
				function(notificationText)
					Context.showNotification("IncomeCollected", "CaChing", notificationText)
				end
			)
		end

		local function setupCharacterConnections(character)
			Context.connections:connect(character.ChildAdded, function(child)
				if child:IsA("Tool") then
					task.wait(0.1)
					OpenSellUIEvent:FireServer()
				end
			end)

			Context.connections:connect(character.ChildRemoved, function(child)
				if child:IsA("Tool") then
					task.wait(0.1)
					OpenSellUIEvent:FireServer()
				end
			end)
		end

		local character = player.Character or player.CharacterAdded:Wait()
		setupCharacterConnections(character)

		Context.connections:connect(player.CharacterAdded, function(newCharacter)
			character = newCharacter
			setupCharacterConnections(character)
		end)
	end
end
