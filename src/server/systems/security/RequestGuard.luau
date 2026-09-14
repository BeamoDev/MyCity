local Guard = {}
local busy = setmetatable({}, { __mode = "k" })
local intervals = { DailyQuestRequest = 1, DailyRewardUpdate = 1, CityName = 2, ClientReady = 1 }
local requests = setmetatable({}, { __mode = "k" })

function Guard.ready(player)
	return player.Parent ~= nil
		and player:GetAttribute("MyCityLoaded") == true
		and player:GetAttribute("MyCityLeaving") ~= true
		and player:GetAttribute("MyCityInventoryReady") ~= false
end

function Guard.isBusy(player)
	return busy[player] == true
end

function Guard.run(player, action, callback, ...)
	if not Guard.ready(player) or busy[player] then
		return false
	end
	local times = requests[player] or {}
	requests[player] = times
	local now = os.clock()
	if now - (times[action] or -math.huge) < (intervals[action] or 0.25) then
		return false
	end
	times[action] = now
	busy[player] = true
	local results = table.pack(pcall(callback, player, ...))
	busy[player] = nil
	if not results[1] then
		warn("[RequestGuard]", action, results[2])
		return false
	end
	return table.unpack(results, 2, results.n)
end

return Guard
