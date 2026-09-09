local CodeSystem = {}
local Data = require(script.Parent.Parent.persistence.PlayerDataModule)
local Guard = require(script.Parent.Parent.systems.security.RequestGuard)

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RedeemedCodesStore = DataStoreService:GetDataStore("Codes")

local CodeFeedback = ReplicatedStorage.Events.UI:WaitForChild("CodeFeeback")

local CODES = {
	["RELEASE"] = 10000,
	["WELCOME"] = 5000,
	["NEWPLAYER"] = 2500,

	--["UPD1"] = 25000,
	--["1KLIKES"] = 10000,

	["NEWBUILDINGS"] = 15000,
	["UPD2"] = 25000,

	-- special
	["WentySwirl"] = 25000,
	["VfEsvQwY"] = 2500000,
}

-- Build a case-insensitive map once
local CODES_UPPER = {}
for k, v in pairs(CODES) do
	CODES_UPPER[string.upper(k)] = v
end

local function grantCash(player, amount)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		return false
	end
	local cash = leaderstats:FindFirstChild("Cash")
	if not cash then
		return false
	end
	cash.Value = cash.Value + amount
	return true
end

local function formatNumber(num)
	if num >= 1000000 then
		return string.format("%.1fM", num / 1000000)
	elseif num >= 1000 then
		return string.format("%.1fK", num / 1000)
	else
		return tostring(num)
	end
end

function CodeSystem.redeemCode(player, inputCode)
	if type(inputCode) ~= "string" or #inputCode > 100 then
		return false, "Invalid code!"
	end
	local upper = string.upper(inputCode:match("^%s*(.-)%s*$"))
	local amount = CODES_UPPER[upper]
	if not amount then
		return false, "Invalid code!"
	end
	local record = Data.getRecord(player)
	if not record then
		return false, "Your city is still loading."
	end
	record.CodeRedemptions = record.CodeRedemptions or {}
	if record.CodeRedemptions[upper] then
		return false, "You've already redeemed this code!"
	end
	-- Honor pre-migration redemptions; new rewards and markers use one profile save.
	local ok, legacy = true, false
	if not player:GetAttribute("MyCityFreshStart") then
		ok, legacy =
			pcall(RedeemedCodesStore.GetAsync, RedeemedCodesStore, string.format("%d_%s", player.UserId, upper))
	end
	if not ok then
		return false, "Error checking code. Please try again."
	end
	if not Guard.ready(player) then
		return false, "Your city is not ready. Please try again."
	end
	if legacy then
		return false, "You've already redeemed this code!"
	end
	if not grantCash(player, amount) then
		return false, "Your cash is not ready."
	end
	record.CodeRedemptions[upper] = { RedeemedAt = os.time(), Amount = amount }
	if not Data.savePlayerData(player) then
		return false, "Reward added; saving will retry. Please stay connected."
	end
	return true, ("Code redeemed! +$%s"):format(formatNumber(amount))
end

function CodeSystem.init()
	CodeFeedback.OnServerEvent:Connect(function(player, code)
		local success, message = Guard.run(player, "RedeemCode", CodeSystem.redeemCode, code)
		CodeFeedback:FireClient(player, success, message)
	end)
end

return CodeSystem
