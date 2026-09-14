local Players = game:GetService("Players")
local FriendBoost = {}
local started = false
local pairsCache = {}
local refreshing, refreshAgain = false, false
local function refresh()
	if refreshing then
		refreshAgain = true
		return
	end
	refreshing = true
	local ok, err = pcall(function()
		local roster, counts = Players:GetPlayers(), {}
		for _, player in roster do
			counts[player] = 0
		end
		for i, player in roster do
			for j = i + 1, #roster do
				local other = roster[j]
				local a, b = math.min(player.UserId, other.UserId), math.max(player.UserId, other.UserId)
				local key = a .. ":" .. b
				local entry = pairsCache[key]
				if not entry or os.clock() >= entry.expires then
					local checked, friends = pcall(player.IsFriendsWith, player, other.UserId)
					if checked then
						entry = { a = a, b = b, friends = friends, expires = os.clock() + 120 }
						pairsCache[key] = entry
					elseif entry then
						entry.expires = os.clock() + 10
					else
						entry = { a = a, b = b, friends = false, expires = os.clock() + 10 }
						pairsCache[key] = entry
					end
				end
				if entry and entry.friends and player.Parent == Players and other.Parent == Players then
					counts[player] += 1
					counts[other] += 1
				end
			end
		end
		local present = {}
		for _, player in Players:GetPlayers() do
			if player.Parent == Players then
				present[player.UserId] = true
			end
		end
		for key, entry in pairsCache do
			if not present[entry.a] or not present[entry.b] then
				pairsCache[key] = nil
			end
		end
		for player, count in counts do
			if player.Parent == Players then
				player:SetAttribute("FriendCount", count)
				player:SetAttribute("FriendBoost", math.min(count * 10, 20) + (if count > 2 then 5 else 0))
			end
		end
	end)
	refreshing = false
	if refreshAgain then
		refreshAgain = false
		task.defer(refresh)
	end
	if not ok then
		warn("[Friends] Refresh failed:", err)
	end
end
function FriendBoost.start()
	if started then
		return
	end
	started = true
	Players.PlayerAdded:Connect(function()
		task.defer(refresh)
	end)
	Players.PlayerRemoving:Connect(function(player)
		for key, entry in pairsCache do
			if entry.a == player.UserId or entry.b == player.UserId then
				pairsCache[key] = nil
			end
		end
		task.defer(refresh)
	end)
	task.spawn(function()
		while true do
			refresh()
			task.wait(30)
		end
	end)
end
return FriendBoost
