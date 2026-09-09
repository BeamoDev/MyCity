local Marketplace = game:GetService("MarketplaceService")
local Data = require(script.Parent.Parent.Parent.persistence.PlayerDataModule)
local Guard = require(script.Parent.Parent.Parent.systems.security.RequestGuard)
local Intents = {}

function Intents.prompt(player, productId, details)
	if not Guard.ready(player) or not Data.isLoaded(player) then
		return false
	end
	local record = Data.getRecord(player)
	record.PurchaseIntents = record.PurchaseIntents or {}
	local key = tostring(productId)
	-- A pending paid target cannot be replaced by another prompt of the same price.
	if record.PurchaseIntents[key] then
		return false, "A previous purchase at this price is still pending. Please wait for it to finish."
	end
	record.PurchaseIntents[key] = { Details = details, Created = os.time() }
	if not Data.savePlayerData(player) or not Guard.ready(player) then
		-- No prompt was opened, so this attempt cannot have a paid receipt.
		record.PurchaseIntents[key] = nil
		return false
	end
	local intent = record.PurchaseIntents[key]
	local ok = pcall(Marketplace.PromptProductPurchase, Marketplace, player, productId)
	if not ok and record.PurchaseIntents[key] == intent and not intent.PurchaseId then
		-- The API failed to open a prompt. Retire only this attempt, never a bound receipt.
		record.PurchaseIntents[key] = nil
		Data.savePlayerData(player)
	end
	return ok, if ok then nil else "The purchase prompt could not open. Please try again."
end

function Intents.init()
	Marketplace.PromptProductPurchaseFinished:Connect(function(userId, productId, purchased)
		if purchased then
			return
		end
		local player = game:GetService("Players"):GetPlayerByUserId(userId)
		local record = player and Data.getRecord(player)
		local intent = record and record.PurchaseIntents and record.PurchaseIntents[tostring(productId)]
		if intent and not intent.PurchaseId then
			record.PurchaseIntents[tostring(productId)] = nil
			Data.savePlayerData(player)
		end
	end)
end

return Intents
