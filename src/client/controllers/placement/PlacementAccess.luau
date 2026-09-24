local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Range = require(ReplicatedStorage.shared.util.PlacementRange)
local Rules = require(ReplicatedStorage.shared.util.PlacementRules)
local Notifications = require(script.Parent.Parent.ui.NotificationController)
local Access = {}
local lastNotice = -math.huge
local lastFailure = -math.huge
-- Explains why a placement was refused, using the server's reason when it sent one.
function Access.notifyFailure(reason)
	-- The server already showed its own builder-limit notice.
	if reason == "BuilderLimit" or os.clock() - lastFailure < 1 then
		return
	end
	lastFailure = os.clock()
	Notifications.showNotification("CannotPlace", Rules.Messages[reason] or "Cannot place here. Try another spot.")
end
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
