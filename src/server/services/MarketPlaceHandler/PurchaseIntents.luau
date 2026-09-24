local Marketplace = game:GetService("MarketplaceService")
local Data = require(script.Parent.Parent.Parent.persistence.PlayerDataModule)
local Guard = require(script.Parent.Parent.Parent.systems.security.RequestGuard)
local Intents = {}
local ARCHIVE_LIMIT = 20
local ARCHIVE_DAYS = 30

function Intents.archive(record, key, intent)
	record.IntentArchive = record.IntentArchive or {}
	local list = record.IntentArchive[key] or {}
	record.IntentArchive[key] = list
	table.insert(list, { Details = intent.Details, Created = intent.Created or os.time() })
	local cutoff = os.time() - ARCHIVE_DAYS * 86400
	for index = #list, 1, -1 do
		if (list[index].Created or 0) < cutoff then
			table.remove(list, index)
		end
	end
	while #list > ARCHIVE_LIMIT do
		table.remove(list, 1)
	end
end

function Intents.prompt(player, productId, details)
	if not Guard.ready(player) or not Data.isLoaded(player) then
		return false
	end
	if details.Kind == "Steal" then
		local owner = game:GetService("Players"):GetPlayerByUserId(details.OwnerId)
		local folder = owner
			and owner:FindFirstChild("Data")
			and owner.Data:FindFirstChild(if details.Construction then "CurrentConstructions" else "CurrentBuildings")
		local entry = folder and folder:FindFirstChild(details.Identifier)
		if not entry or not entry:IsA("StringValue") then
			return false, "That building is no longer available."
		end
		details = table.clone(details)
		details.Snapshot =
			require(script.Parent.TransferService).descriptor(entry.Value, details.Identifier, details.Construction)
	end
	local record = Data.getRecord(player)
	record.PurchaseIntents = record.PurchaseIntents or {}
	local key = tostring(productId)
	-- Never block a new purchase. A bound intent's plan already lives in its receipt entry; an
	-- unbound one is archived so a late receipt for it still grants the target the player chose.
	local previous = record.PurchaseIntents[key]
	if previous then
		if not previous.PurchaseId then
			Intents.archive(record, key, previous)
		end
		record.PurchaseIntents[key] = nil
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

-- World prompts do not have a shop response listener, so report their failures centrally.
function Intents.open(player, productId, details)
	local ok, message = Intents.prompt(player, productId, details)
	if not ok and message then
		game:GetService("ReplicatedStorage").Events.Notifications.ErrorEvent:FireClient(player, message)
	end
	return ok, message
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
