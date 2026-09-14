local BuildingStealing = {}

function BuildingStealing.canStealBuilding(stealerPlayer, building)
	if not building or not building.Parent then
		return false, "Invalid building"
	end

	local BuildingSystem = require(script.Parent)
	local owner = BuildingSystem.getBuildingOwner(building)
	if not owner then
		return false, "Building has no owner"
	end

	if owner.UserId == stealerPlayer.UserId then
		return false, "Cannot steal your own building"
	end

	if building.Parent.Name == "Construction" then
		return false, "Cannot steal buildings under construction"
	end

	return true, owner
end

-- Paid transfers must pass through the durable receipt ledger and TransferService.
function BuildingStealing.stealBuilding()
	return false, "Use the purchase flow to steal a building."
end

BuildingStealing.createToolWithBuilding = require(script.Parent.Parent.Parent.Parent.services.ToolFactory).create

function BuildingStealing.init() end

return BuildingStealing
