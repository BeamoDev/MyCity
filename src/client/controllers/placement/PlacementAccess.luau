local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Range = require(ReplicatedStorage.shared.util.PlacementRange)
local Notifications = require(script.Parent.Parent.ui.NotificationController)
local Access = {}
local lastNotice = -math.huge
function Access.check(player, plot, tool)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root and Range.isNear(root.Position, plot) then
		return true
	end
	local backpack = player:FindFirstChild("Backpack")
	if tool and backpack and tool.Parent == player.Character then
		tool.Parent = backpack
	end
	if os.clock() - lastNotice >= 1 then
		lastNotice = os.clock()
		Notifications.showNotification(
			"CannotPlace",
			"Too far from your plot to place a building. Return to your city."
		)
	end
	return false
end
return Access
