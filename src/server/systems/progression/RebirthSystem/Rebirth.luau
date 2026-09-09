-- Rebirth: focused implementation for RebirthSystem.
return function(Context)
	local State = Context.State
	local RebirthSystem = Context.RebirthSystem
	local BuildingSystem = Context.BuildingSystem
	local IncomeSystem = Context.IncomeSystem
	local RebirthConfig = Context.RebirthConfig
	local rebirthSuccess = Context.rebirthSuccess
	local rebirthFailed = Context.rebirthFailed

	function RebirthSystem.performRebirth(player)
		local info = player:FindFirstChild("Data") and player.Data:FindFirstChild("PlayerInfo")
		local tutorial = info and info:FindFirstChild("Tutorial")
		if tutorial and tutorial.IsInTutorial.Value then
			rebirthFailed:FireClient(player, "Finish the tutorial before rebirthing.")
			return false
		end
		local ld = player:FindFirstChild("leaderstats")
		if not ld then
			rebirthFailed:FireClient(player, "Data not found")
			return
		end

		local rebirths = ld:FindFirstChild("Rebirths")
		if not rebirths then
			rebirthFailed:FireClient(player, "Rebirth data not found")
			return
		end

		local ok, requirements = RebirthConfig.canRebirth(player, rebirths.Value)
		if not ok then
			rebirthFailed:FireClient(player, "Need " .. tostring(requirements.population) .. " population!")
			return
		end

		RebirthSystem.prepareRebirth(player)

		rebirths.Value = rebirths.Value + 1

		-- Scale starting cash with rebirths
		local starterCash = RebirthConfig.getStartingCash(rebirths.Value)
		local cash = ld:FindFirstChild("Cash")
		if cash then
			cash.Value = math.floor(starterCash)
		end

		BuildingSystem.updatePopulation(player)
		IncomeSystem.calculateAndStackBuildingIncome(player)

		local ShopSystemModule = script.Parent.Parent.Parent:WaitForChild("economy"):WaitForChild("ShopSystem")
		if ShopSystemModule then
			local shopModule = require(ShopSystemModule)
			if shopModule.onPlayerRebirth then
				shopModule.onPlayerRebirth(player)
			end
		end

		rebirthSuccess:FireClient(player, rebirths.Value)
		RebirthSystem.updateRebirthUI(player)
	end
end
