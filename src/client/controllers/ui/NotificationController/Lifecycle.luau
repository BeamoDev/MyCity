return function(Context)
	local NotificationController = Context.NotificationController
	local function tutorialFlag()
		local player = Context.Players.LocalPlayer
		local data = player:FindFirstChild("Data")
		local info = data and data:FindFirstChild("PlayerInfo")
		local tutorial = info and info:FindFirstChild("Tutorial")
		return tutorial and tutorial:FindFirstChild("IsInTutorial")
	end
	function Context.notificationsSuppressed()
		local flag = tutorialFlag()
		return not flag or flag.Value or Context.Players.LocalPlayer:GetAttribute("MyCityIntroActive") == true
	end
	function Context.refreshNotificationVisibility()
		local suppressed = Context.notificationsSuppressed()
		local frame = Context.State.notificationsFrame
		if frame then
			frame.Visible = not suppressed
		end
		if suppressed then
			NotificationController.clearAll()
			Context.pending = {}
		end
	end
	function NotificationController.prepare()
		Context.connections:clear()
		NotificationController.clearAll()
		Context.State.playerGui = nil
		Context.State.notificationsFrame = nil
		Context.State.deferNotifications = true
		Context.pending = {}
		Context.connectNotificationEvents()
	end
	function NotificationController.flush()
		Context.State.deferNotifications = false
		local pending = Context.pending or {}
		Context.pending = {}
		for _, item in pending do
			NotificationController.showNotification(item.kind, item.text)
		end
	end
	function NotificationController.init(gui, deferNotifications)
		Context.State.deferNotifications = deferNotifications == true
		Context.connections:clear()
		NotificationController.clearAll()
		Context.State.playerGui = gui
		Context.State.notificationsFrame = gui:FindFirstChild("NotificationCenter")
			or gui:WaitForChild("NotificationCenter", 10)
		local frame = Context.State.notificationsFrame
		if not frame then
			warn("[Notifications] Missing HUD.NotificationCenter")
			return
		end
		local template = frame:FindFirstChild("Template") or frame:WaitForChild("Template", 10)
		if not template or not template:IsA("GuiObject") then
			warn("[Notifications] Missing NotificationCenter.Template")
			return
		end
		template.Visible = false
		Context.refreshNotificationVisibility()
		local flag = tutorialFlag()
		if flag then
			Context.connections:connect(flag:GetPropertyChangedSignal("Value"), Context.refreshNotificationVisibility)
		end
		Context.connections:connect(
			Context.Players.LocalPlayer:GetAttributeChangedSignal("MyCityIntroActive"),
			Context.refreshNotificationVisibility
		)
		Context.connections:connect(frame:GetPropertyChangedSignal("Visible"), function()
			if frame.Visible and Context.notificationsSuppressed() then
				frame.Visible = false
			end
		end)
		Context.connectNotificationEvents()
		if not deferNotifications then
			NotificationController.flush()
		end
	end
end
