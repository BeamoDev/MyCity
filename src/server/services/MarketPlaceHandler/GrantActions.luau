local Factory = require(script.Parent.Parent.ToolFactory)
local Serialization = require(script.Parent.Parent.ToolSerialization)
local Construction = require(script.Parent.Parent.Parent.systems.construction.ConstructionSystem)
local Shop = require(script.Parent.Parent.Parent.systems.economy.ShopSystem)
local Transfers = require(script.Parent.TransferService)
local Actions = {}

function Actions.apply(player, step, transactionId)
	if step.Kind == "Cash" then
		local cash = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Cash")
		if not cash then
			return false
		end
		cash.Value += step.Amount
		return true
	elseif step.Kind == "Building" then
		local backpack = player:FindFirstChild("Backpack")
		if not backpack then
			return false
		end
		local tool = Factory.create(step.Name, false, 1, 0)
		if not tool then
			return false
		end
		tool:SetAttribute("RobuxBuilding", true)
		tool.Parent = backpack
		return true
	elseif step.Kind == "Skip" then
		-- Already finished naturally or in a previous durable receipt step.
		if not player.Data.CurrentConstructions:FindFirstChild(step.Identifier) then
			return true
		end
		return Construction.skipConstruction(player, step.Identifier) == true
	elseif step.Kind == "Refresh" then
		Shop.resetPlayerShop(player)
		return true
	elseif step.Kind == "Steal" then
		if step.OwnerId == player.UserId or not player:FindFirstChild("Backpack") then
			return false
		end
		local descriptor, outcome = Transfers.take(step, transactionId)
		if not descriptor and outcome == "missing" and type(step.Snapshot) == "table" then
			-- Only confirmed absence permits compensation; service/lease errors keep retrying.
			descriptor = table.clone(step.Snapshot)
		end
		if not descriptor or not require(script.Parent.Parent.Parent.systems.security.RequestGuard).ready(player) then
			return false
		end
		local tool = Serialization.decode(descriptor)
		if not tool then
			return false
		end
		tool.Parent = player.Backpack
		return true
	end
	return false
end

return Actions
