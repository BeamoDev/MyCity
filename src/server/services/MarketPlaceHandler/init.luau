local Marketplace = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local Ledger = require(script.ReceiptLedger)
local Plans = require(script.GrantPlan)
local Actions = require(script.GrantActions)
local Intents = require(script.PurchaseIntents)
local Handler = {}
local started = false
function Handler.init()
	if started then
		return
	end
	started = true
	Intents.init()
	Marketplace.ProcessReceipt = function(receipt)
		local player = Players:GetPlayerByUserId(receipt.PlayerId)
		if not player then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local ok, granted = pcall(Ledger.process, player, receipt, Plans.create, Actions.apply)
		if ok and granted then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		if not ok then
			warn("[Receipts] Deferred", receipt.PurchaseId, granted)
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
end
return Handler
