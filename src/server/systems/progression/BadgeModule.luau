local BadgeModule = {}
local BadgeService = game:GetService("BadgeService")
local Players = game:GetService("Players")

local awardedCache = {}

local function userHasBadge(userId, badgeId)
	local ok, has = pcall(function()
		return BadgeService:UserHasBadgeAsync(userId, badgeId)
	end)
	return ok and has
end

Players.PlayerRemoving:Connect(function(player)
	awardedCache[player.UserId] = nil
end)

local pending = {}

function BadgeModule.AwardBadge(player, badgeId)
	if not player or typeof(badgeId) ~= "number" or not player.Parent then
		return false
	end

	local uid = player.UserId

	if not awardedCache[uid] then
		awardedCache[uid] = {}
	end

	if awardedCache[uid][badgeId] then
		return true
	end

	local key = uid .. ":" .. badgeId
	if pending[key] then
		return false
	end
	pending[key] = true
	local granted = false
	for attempt = 1, 3 do
		if not player.Parent then
			break
		end
		if userHasBadge(uid, badgeId) then
			granted = true
			break
		end
		local ok, result = pcall(BadgeService.AwardBadge, BadgeService, uid, badgeId)
		if ok and result then
			granted = true
			break
		end
		if attempt < 3 then
			task.wait(attempt * 2)
		end
	end
	pending[key] = nil
	if granted and player.Parent then
		awardedCache[uid] = awardedCache[uid] or {}
		awardedCache[uid][badgeId] = true
		return true
	end

	return false
end

return BadgeModule
