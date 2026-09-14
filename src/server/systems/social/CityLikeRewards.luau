local Data = require(script.Parent.Parent.Parent.persistence.PlayerDataModule)
local Guard = require(script.Parent.Parent.security.RequestGuard)
local Rewards = {}
function Rewards.settle(player, sequence)
	if type(sequence) ~= "number" or sequence ~= sequence or sequence < 0 or sequence >= math.huge then
		return false
	end
	sequence = math.floor(sequence)
	local record = Data.getRecord(player)
	if not record or sequence <= (record.CityLikeRewardSequence or 0) then
		return false
	end
	return Guard.run(player, "CityLikeReward", function()
		local cash = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Cash")
		if not cash then
			return false
		end
		local previous = record.CityLikeRewardSequence or 0
		if sequence <= previous then
			return false
		end
		cash.Value += (sequence - previous) * 50
		record.CityLikeRewardSequence = sequence
		-- Marker and cash share the same save. Failed writes retain both for autosave retry.
		return Data.savePlayerData(player)
	end)
end
return Rewards
