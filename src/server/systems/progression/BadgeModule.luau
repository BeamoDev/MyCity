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

task.spawn(function()
	while true do
		task.wait(300)
		for uid in pairs(awardedCache) do
			if not Players:GetPlayerByUserId(uid) then
				awardedCache[uid] = nil
			end
		end
	end
end)

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

	if userHasBadge(uid, badgeId) then
		awardedCache[uid][badgeId] = true
		return true
	end

	local ok, granted = pcall(function()
		return BadgeService:AwardBadge(uid, badgeId)
	end)

	if ok and granted then
		awardedCache[uid][badgeId] = true
		return true
	end

	return false
end

return BadgeModule
