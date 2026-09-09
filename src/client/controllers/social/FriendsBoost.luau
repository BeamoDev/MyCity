local player = game:GetService("Players").LocalPlayer
local FriendBoost = {}
local connections = {}
function FriendBoost.cleanup()
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
end
function FriendBoost.init(hud)
	FriendBoost.cleanup()
	local label = hud:WaitForChild("FriendBoost")
	local function update()
		local boost = player:GetAttribute("FriendBoost") or 0
		local count = player:GetAttribute("FriendCount") or 0
		label.Text = string.format("Friend Boost: %d%% (%d friends)", boost, count)
		label.Visible = boost > 0
	end
	for _, name in { "FriendBoost", "FriendCount" } do
		table.insert(connections, player:GetAttributeChangedSignal(name):Connect(update))
	end
	update()
end
return FriendBoost
