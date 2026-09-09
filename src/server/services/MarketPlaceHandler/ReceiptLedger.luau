local Data = require(script.Parent.Parent.Parent.persistence.PlayerDataModule)
local Guard = require(script.Parent.Parent.Parent.systems.security.RequestGuard)
local Ledger = {}

function Ledger.process(player, receipt, makePlan, applyStep)
	if not Data.isLoaded(player) then
		return false
	end
	return Guard.run(player, "Receipt:" .. receipt.PurchaseId, function()
		local record = Data.getRecord(player)
		record.Receipts = record.Receipts or {}
		local entry = record.Receipts[receipt.PurchaseId]
		if entry and entry.ProductId ~= receipt.ProductId then
			return false
		end
		if entry and entry.Complete then
			return Data.savePlayerData(player)
		end
		if not entry then
			local intent = record.PurchaseIntents and record.PurchaseIntents[tostring(receipt.ProductId)]
			if intent and intent.PurchaseId and intent.PurchaseId ~= receipt.PurchaseId then
				return false
			end
			local plan = makePlan(player, receipt.ProductId, record)
			if not plan then
				return false
			end
			entry = { ProductId = receipt.ProductId, Plan = plan, Applied = {} }
			record.Receipts[receipt.PurchaseId] = entry
			local intent = record.PurchaseIntents and record.PurchaseIntents[tostring(receipt.ProductId)]
			if intent then
				intent.PurchaseId = receipt.PurchaseId
			end
			if not Data.savePlayerData(player) then
				return false
			end
		end
		for index, step in entry.Plan do
			if not Guard.ready(player) then
				return false
			end
			local key = tostring(index)
			if not entry.Applied[key] then
				if not applyStep(player, step, receipt.PurchaseId .. ":" .. key) then
					return false
				end
				entry.Applied[key] = true
			end
			-- Reward and marker are in one profile snapshot, including inventory.
			if not Data.savePlayerData(player) then
				return false
			end
		end
		entry.Complete = true
		local intent = record.PurchaseIntents and record.PurchaseIntents[tostring(receipt.ProductId)]
		if intent and intent.PurchaseId == receipt.PurchaseId then
			record.PurchaseIntents[tostring(receipt.ProductId)] = nil
		end
		return Data.savePlayerData(player)
	end) == true
end

return Ledger
