local Config = require(script.Parent.Parent.Parent.config.TutorialConfig)
local Reset = {}
function Reset.apply(player, record)
	if not Config.ResetProgressEveryJoin or player.UserId ~= Config.OwnerUserId then
		return record
	end
	-- Preserve transaction history/lease. Reset only gameplay, before any city restoration.
	local fresh = table.clone(record)
	fresh.PlayerData, fresh.LeaderBoardData, fresh.DailyQuests = nil, nil, nil
	fresh.CodeRedemptions = {}
	fresh.NewProfile, fresh.FolderEncoding = true, 2
	player:SetAttribute("MyCityFreshStart", true)
	return fresh
end
return Reset
