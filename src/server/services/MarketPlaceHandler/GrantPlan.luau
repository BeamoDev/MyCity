local Products = require(script.Parent.ProductConfig)
local Plans = {}

function Plans.create(player, productId, record)
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
	local intent = record.PurchaseIntents and record.PurchaseIntents[tostring(productId)]
	if not intent then
		return nil
	end
	local details = intent.Details
	if Products.Shop[productId] and details.Kind == "Building" then
		return { details }
	end
	if Products.Skip[productId] and details.Kind == "Skip" then
		return { details }
	end
	if productId == Products.Steal and details.Kind == "Steal" then
		return { details }
	end
	return nil
end

return Plans
