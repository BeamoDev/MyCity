local Players = game:GetService("Players")
local Data = require(script.Parent.Parent.Parent.persistence.PlayerDataModule)
local Store = require(script.Parent.Parent.Parent.persistence.PlayerDataModule.SessionStore)
local Guard = require(script.Parent.Parent.Parent.systems.security.RequestGuard)
local Transfer = {}

function Transfer.descriptor(value, identifier, construction)
	local parts = string.split(value, ",")
	return {
		Name = identifier:match("^([^_]+)_"),
		IsValid = true,
		BuildingLevel = tonumber(parts[if construction then 10 else 8]) or 1,
		BuildingXP = tonumber(parts[if construction then 11 else 9]) or 0,
		RobuxBuilding = parts[if construction then 12 else 10] == "true",
	}
end

function Transfer.take(details, transferId)
	local owner = Players:GetPlayerByUserId(details.OwnerId)
	if not owner then
		return Store.transferOffline(
			details.OwnerId,
			details.Identifier,
			details.Construction,
			transferId,
			Transfer.descriptor
		)
	end
	if not Data.isLoaded(owner) then
		return nil
	end
	return Guard.run(owner, "Transfer", function()
		local record = Data.getRecord(owner)
		record.Transfers = record.Transfers or {}
		local descriptor = record.Transfers[transferId]
		if not descriptor then
			local folder = if details.Construction then owner.Data.CurrentConstructions else owner.Data.CurrentBuildings
			local tracker = folder:FindFirstChild(details.Identifier)
			if not tracker or not tracker:IsA("StringValue") then
				return nil
			end
			descriptor = Transfer.descriptor(tracker.Value, details.Identifier, details.Construction)
			local plot = workspace.Plots:FindFirstChild("Plot" .. owner.Data.PlotInfo.Plot.Value)
			local models = plot
				and (if details.Construction then plot.Buildings.Construction else plot.Buildings.Placed)
			local model = models and models:FindFirstChild(details.Identifier)
			if not model then
				return nil
			end
			tracker:Destroy()
			model:Destroy()
			record.Transfers[transferId] = descriptor
			task.defer(function()
				if not owner.Parent then
					return
				end
				require(script.Parent.Parent.Parent.systems.construction.ConstructionSystem.ConstructionBuilder).updateBuilderCount(
					owner
				)
				require(script.Parent.Parent.Parent.systems.building.BuildingSystem).updatePopulation(owner)
			end)
		end
		if not Data.savePlayerData(owner) then
			return nil
		end
		return descriptor
	end)
end

return Transfer
