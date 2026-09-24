local Products = require(script.Parent.ProductConfig)
local Plans = {}

-- Returns the grant steps for a Details table saved when the prompt opened, if it matches the product.
local function fromDetails(productId, details)
	if type(details) ~= "table" then
		return nil
	end
	if Products.Shop[productId] and details.Kind == "Building" then
		return { details }
	end
	if Products.Skip[productId] and details.Kind == "Skip" then
		return { details }
	end
	if productId == Products.Steal and details.Kind == "Steal" then
		local step = table.clone(details)
		-- Starts the grace period after which a blocked transfer delivers the saved snapshot.
		step.Created = step.Created or os.time()
		return { step }
	end
	return nil
end

-- Nothing records what was chosen (e.g. receipts from before intents were archived).
-- Grant equal value instead of leaving a paid receipt pending forever.
local function compensation(player, productId)
	if Products.Shop[productId] then
		local name = require(script.Parent.Parent.Parent.systems.economy.ShopSystem).compensationBuilding(productId)
		return name and { { Kind = "Building", Name = name, Compensation = true } }
	end
	if Products.Skip[productId] then
		local folder = player.Data.CurrentConstructions
		for _, entry in folder:GetChildren() do
			if entry:IsA("StringValue") then
				return { { Kind = "Skip", Identifier = entry.Name, Compensation = true } }
			end
		end
	end
	return nil
end

-- Returns plan, consume. The ledger calls consume() when it records the receipt, binding the source.
function Plans.create(player, productId, record, purchaseId)
	local product = Products.Rewards[productId]
	if product then
		local plan = {}
		if product.rewards.cash then
			table.insert(plan, { Kind = "Cash", Amount = product.rewards.cash })
		end
		for _, name in product.rewards.buildings or {} do
			table.insert(plan, { Kind = "Building", Name = name })
		end
		return plan
	end
	if productId == Products.Refresh then
		return { { Kind = "Refresh" } }
	end
	if productId == Products.BuildAll then
		local plan = {}
		local folder = player.Data.CurrentConstructions
		for _, entry in folder:GetChildren() do
			if entry:IsA("StringValue") then
				table.insert(plan, { Kind = "Skip", Identifier = entry.Name })
			end
		end
		return plan
	end
	local key = tostring(productId)
	-- 1. The prompt currently open for this product, unless another receipt already owns it.
	local intent = record.PurchaseIntents and record.PurchaseIntents[key]
	if intent and (not intent.PurchaseId or intent.PurchaseId == purchaseId) then
		local plan = fromDetails(productId, intent.Details)
		if plan then
			return plan, function()
				intent.PurchaseId = purchaseId
			end
		end
	end
	-- 2. The oldest archived choice (a prompt replaced before its receipt arrived).
	local archive = record.IntentArchive and record.IntentArchive[key]
	for index, archived in archive or {} do
		local plan = fromDetails(productId, archived.Details)
		if plan then
			return plan, function()
				table.remove(archive, index)
			end
		end
	end
	-- 3. Equal-value compensation.
	return compensation(player, productId)
end

return Plans
