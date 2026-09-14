local Marketplace = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local Ledger = require(script.ReceiptLedger)
local Plans = require(script.GrantPlan)
local Actions = require(script.GrantActions)
local Intents = require(script.PurchaseIntents)
local Handler = {}
local started = false
local notices = setmetatable({}, { __mode = "k" })
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
		if os.clock() >= (notices[player] or 0) then
			notices[player] = os.clock() + 60
			local rep = game:GetService("ReplicatedStorage")
			local events = rep:FindFirstChild("Events")
			local notifications = events and events:FindFirstChild("Notifications")
			local event = notifications and notifications:FindFirstChild("ErrorEvent")
			if event then
				event:FireClient(
					player,
					"Your purchase is pending recovery. Please do not buy it again. If it stays pending, contact the developer with your Roblox purchase history."
				)
			end
		end
		if not ok then
			warn("[Receipts] Deferred", receipt.PurchaseId, granted)
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
end
return Handler
