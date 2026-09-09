-- RemoteBindings: focused implementation for NotificationController.
return function(Context)
	local State = Context.State
	local NotificationController = Context.NotificationController
	local TweenService = Context.TweenService
	local ReplicatedStorage = Context.ReplicatedStorage
	local RunService = Context.RunService

	function Context.connectNotificationEvents()
		local function message(name, kind, fallback)
			local event = ReplicatedStorage.Events.Notifications:FindFirstChild(name)
			if event then
				Context.connections:connect(event.OnClientEvent, function(text)
					NotificationController.showNotification(kind, text or fallback)
				end)
			end
		end
		message("ErrorEvent", "CannotPlace", "Something went wrong. Please try again.")
		message("BuildingStole", "BuildingStole", "A building was stolen!")
		message("StockRefreshed", "PurchaseSuccessful", "Shop stock refreshed!")
		message("BuildAllComplete", "BuildingComplete", "All buildings completed!")
		message("RarityAnnounce", "LevelUp", "A rare building was discovered!")
		local code = ReplicatedStorage.Events.UI:FindFirstChild("CodeFeeback")
		if code then
			Context.connections:connect(code.OnClientEvent, function(success, text)
				NotificationController.showNotification(if success then "PurchaseSuccessful" else "CannotPlace", text)
			end)
		end

		local StealEvents = ReplicatedStorage.Events:FindFirstChild("StealBuilding")
		local stolenEvent = StealEvents:FindFirstChild("Stole")
		local receivedEvent = StealEvents:FindFirstChild("Recieved")

		Context.connections:connect(
			ReplicatedStorage.Events.Notifications:WaitForChild("BuildingComplete").OnClientEvent,
			function(buildingName)
				NotificationController.showNotification("BuildingComplete", buildingName .. " Complete!")
			end
		)

		Context.connections:connect(stolenEvent.OnClientEvent, function(data)
			NotificationController.showNotification(
				"BuildingStole",
				string.format("%s stole your Level %d %s!", data.thief, data.level, data.building)
			)
		end)

		Context.connections:connect(receivedEvent.OnClientEvent, function(data)
			NotificationController.showNotification(
				"PurchaseSuccessful",
				string.format("Stole Level %d %s from %s!", data.level, data.building, data.owner)
			)
		end)

		Context.connections:connect(
			ReplicatedStorage.Events.Notifications:WaitForChild("BuildingStarted").OnClientEvent,
			function(buildingName)
				NotificationController.showNotification("BuildingStarted", buildingName .. " Started Construction")
			end
		)

		Context.connections:connect(
			ReplicatedStorage.Events.Notifications:WaitForChild("ItemBought").OnClientEvent,
			function(itemName)
				NotificationController.showNotification("ItemBought", itemName .. " Bought!")
			end
		)

		Context.connections:connect(
			ReplicatedStorage.Events.Notifications:WaitForChild("BuildingDeleted").OnClientEvent,
			function(itemName)
				NotificationController.showNotification("BuildingDeleted", "Deleted " .. itemName)
			end
		)

		Context.connections:connect(ReplicatedStorage.Events.Movement.DeletedBuilding.OnClientEvent, function()
			NotificationController.showNotification("BuildingDeleted", "Building Deleted")
		end)

		Context.connections:connect(ReplicatedStorage.Events.Movement.Unauthorized.OnClientEvent, function()
			NotificationController.showNotification("NotYourPlot", "Not Your Plot!")
		end)

		Context.connections:connect(ReplicatedStorage.Events.Teleport.TeleportError.OnClientEvent, function(message)
			NotificationController.showNotification("TeleportError", message)
		end)

		Context.connections:connect(ReplicatedStorage.Events.Notifications.Purchased.OnClientEvent, function()
			NotificationController.showNotification("PurchaseSuccessful", "Purchase Successful!")
		end)

		Context.connections:connect(
			ReplicatedStorage.Events.Notifications:WaitForChild("GroupReward").OnClientEvent,
			function()
				NotificationController.showNotification("GroupReward", "Group: Free Police Station!")
			end
		)

		Context.connections:connect(ReplicatedStorage.Events.Notifications.BrokeAhh.OnClientEvent, function()
			if not State.playerGui then
				NotificationController.showNotification("NotEnoughCash", "Not Enough Cash!")
				return
			end
			local UIController = require(script.Parent.Parent:WaitForChild("UIController"))
			local frames = UIController.getFrames()
			UIController.openUIFrame(frames.Shop)

			local sf = frames.Shop.Frame.ScrollingFrame
			sf.ScrollingDirection = Enum.ScrollingDirection.Y
			sf.ScrollingEnabled = true

			Context.connections:spawn(function()
				local deadline = time() + 2
				while sf.AbsoluteSize.Y == 0 and time() < deadline do
					RunService.RenderStepped:Wait()
				end

				local layout = sf:FindFirstChildOfClass("UIListLayout") or sf:FindFirstChildOfClass("UIGridLayout")
				if layout then
					sf.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y)
				end

				TweenService:Create(sf, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					CanvasPosition = Vector2.new(0, 560),
				}):Play()
			end)

			NotificationController.showNotification("NotEnoughCash", "Not Enough Cash!")
		end)

		Context.connections:connect(ReplicatedStorage.Events.UI.MaxReached.OnClientEvent, function()
			NotificationController.showNotification("MaxBuilt", "Max Buildings Reached!")
		end)

		Context.connections:connect(ReplicatedStorage.Events.Movement.CannotPlace.OnClientEvent, function()
			NotificationController.showNotification("CannotPlace", "Cannot Place Here!")
		end)

		Context.connections:connect(ReplicatedStorage.Events.Notifications.BuilderLimitReached.OnClientEvent, function()
			if not State.playerGui then
				NotificationController.showNotification("BuildingLimitReached", "Builder Limit Reached!")
				return
			end
			local UIController = require(script.Parent.Parent:WaitForChild("UIController"))
			local frames = UIController.getFrames()
			UIController.openUIFrame(frames.Shop)

			local sf = frames.Shop.Frame.ScrollingFrame
			sf.ScrollingDirection = Enum.ScrollingDirection.Y
			sf.ScrollingEnabled = true

			Context.connections:spawn(function()
				local deadline = time() + 2
				while sf.AbsoluteSize.Y == 0 and time() < deadline do
					RunService.RenderStepped:Wait()
				end

				local layout = sf:FindFirstChildOfClass("UIListLayout") or sf:FindFirstChildOfClass("UIGridLayout")
				if layout then
					sf.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y)
				end

				TweenService:Create(sf, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					CanvasPosition = Vector2.new(0, 1120),
				}):Play()
			end)

			NotificationController.showNotification("BuildingLimitReached", "Builder Limit Reached!")
		end)

		if ReplicatedStorage.Events.Notifications:FindFirstChild("BuildingLevelUp") then
			Context.connections:connect(
				ReplicatedStorage.Events.Notifications.BuildingLevelUp.OnClientEvent,
				function(buildingType, level)
					local data = Context.Players.LocalPlayer:FindFirstChild("Data")
					local info = data and data:FindFirstChild("PlayerInfo")
					local tutorial = info and info:FindFirstChild("Tutorial")
					local active = tutorial and tutorial:FindFirstChild("IsInTutorial")
					-- Drop these at receipt, before any intro/HUD notification buffering.
					if not active or active.Value then
						return
					end
					NotificationController.showNotification(
						"LevelUp",
						string.format("%s reached Level %d!", buildingType, level)
					)
				end
			)
		end
	end
end
