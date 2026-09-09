local Players = game:GetService("Players")
local FriendBoost = {}
function FriendBoost.start()
	task.spawn(function()
		while true do
			local roster = Players:GetPlayers()
			for _, player in roster do
				local count = 0
				for _, other in roster do
					if player ~= other then
						local ok, friends = pcall(player.IsFriendsWith, player, other.UserId)
						if ok and friends and other.Parent == Players then
							count += 1
						end
					end
				end
				if player.Parent == Players then
					player:SetAttribute("FriendCount", count)
					player:SetAttribute("FriendBoost", math.min(count * 10, 20) + (if count > 2 then 5 else 0))
				end
			end
			task.wait(30)
		end
	end)
end
return FriendBoost
