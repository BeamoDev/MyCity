local function getWebhookUrl()
	local secrets = game:GetService("ServerStorage"):FindFirstChild("MyCitySecrets")
	local url = secrets and secrets:FindFirstChild("PurchaseWebhook")
	return url and url.Value or ""
end
local players = game:GetService("Players")
local https = game:GetService("HttpService")

local PurchaseChannel = getWebhookUrl()

local function getPlayerHeadshotUrl(Player)
	local success, result = pcall(function()
		return https:JSONDecode(
			https:GetAsync(
				"https://thumbnails.roproxy.com/v1/users/avatar-headshot?userIds="
					.. Player.UserId
					.. "&size=150x150&format=Png"
			)
		)
	end)

	if success and result and result.data and result.data[1] and result.data[1].imageUrl then
		return result.data[1].imageUrl
	else
		return "https://t3.rbxcdn.com/9fc30fe577bf95e045c9a3d4abaca05d"
	end
end

local module = {}

function module.FireWebhook(plr, report, color)
	local headshotUrl = getPlayerHeadshotUrl(plr)

	local AEST_Time = os.date("!%Y-%m-%d %H:%M:%S", os.time() + 10 * 60 * 60)

	local data = {
		["content"] = "",
		["embeds"] = {
			{
				["author"] = {
					["name"] = "Purchase By " .. players:GetNameFromUserIdAsync(plr.UserId),
					["icon_url"] = headshotUrl, -- Player's profile picture
				},
				["description"] = "```" .. report .. "```",
				["color"] = color, -- Embed Line Color
				["fields"] = {
					{
						["name"] = "Account Age",
						["value"] = plr.AccountAge .. " days old",
						["inline"] = true,
					},
					{
						["name"] = "Account ID",
						["value"] = plr.UserId,
						["inline"] = true,
					},
					{
						["name"] = "Time of Purchase (AEST)",
						["value"] = AEST_Time,
						["inline"] = true,
					},
				},
				["footer"] = {
					["text"] = "Purchase System", -- Footer Text
					["icon_url"] = "https://cdn.discordapp.com/attachments/1249313018593017906/1290138475323985940/v2.png?ex=66fb5e96&is=66fa0d16&hm=e99060a4ce37f201ced99a7c47048826092f71484ad071c91a5ea99aeef69de0&", -- Footer Icon
				},
			},
		},
		["attachments"] = {},
	}

	local newdata = https:JSONEncode(data)

	https:PostAsync(PurchaseChannel, newdata)
end

return module
