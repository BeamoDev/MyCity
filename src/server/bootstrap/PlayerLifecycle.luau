local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Guard = require(script.Parent.Parent.systems.security.RequestGuard)
local Rewards = require(script.Parent.Parent.systems.progression.PlayerRewards)
local RestoreBudget = require(script.Parent.Parent.services.RestoreBudget)
local Lifecycle = {}

function Lifecycle.start(systems)
	local Data = systems.PlayerDataModule
	local loading, leaving = {}, setmetatable({}, { __mode = "k" })
	Data.setBeforeSave(systems.InventorySystem.saveInventory)
	local function load(player)
		if loading[player] then
			return
		end
		loading[player] = true
		player:SetAttribute("JoinTime", tick())
		player:SetAttribute("MyCityLoaded", false)
		local ok, err = pcall(function()
			if not Data.loadPlayerData(player) then
				return
			end
			local character = player.Character
			local deadline = os.clock() + 30
			while not character and player.Parent and os.clock() < deadline do
				task.wait(0.1)
				character = player.Character
			end
			if not character or not player.Parent then
				error("Character unavailable")
			end
			local info = player.Data.PlayerInfo
			if not player:GetAttribute("MyCityFreshStart") then
				info.CityName.Value = systems.CityNameSystem.loadCityName(player)
			end
			systems.PlotManager.assignPlot(player, character)
			if player.Data.PlotInfo.Plot.Value <= 0 then
				error("No plot available")
			end
			ReplicatedStorage.Events.Loading.LoadingProgress:FireClient(player, 0.4)
			systems.BuildingSystem.loadPlayerBuildings(player)
			systems.ConstructionSystem.loadPlayerConstructions(player)
			systems.BuildingSystem.updatePlotStats(
				workspace.Plots["Plot" .. player.Data.PlotInfo.Plot.Value],
				function()
					RestoreBudget.checkpoint(player)
				end
			)
			ReplicatedStorage.Events.Loading.LoadingProgress:FireClient(player, 0.75)
			systems.ExpansionSystem.updateExpansionTiles(player)
			systems.CityNameSystem.applyCityNameToPlot(
				player,
				workspace.Plots["Plot" .. player.Data.PlotInfo.Plot.Value]
			)
			systems.IncomeSystem.setupPlayerIncome(player)
			if not systems.InventorySystem.loadInventory(player) then
				error("Inventory restoration failed")
			end
			systems.InventorySystem.startPlayer(player)
			systems.RebirthSystem.initializePlayer(player)
			systems.TutorialSystem.prepareForJoin(player)
			systems.TutorialSystem.resume(player)
			if not player.Parent or player:GetAttribute("MyCityLeaving") then
				return
			end
			player:SetAttribute("MyCityLoaded", true)
			systems.PostTutorialQuest.initializePlayer(player)
			systems.DailyQuests.initializePlayer(player)
			ReplicatedStorage.Events.Loading.LoadingProgress:FireClient(player, 1)
			ReplicatedStorage.Events.Loading.LoadingComplete:FireClient(player)
			Rewards.trackMillionaire(player)
			task.spawn(Rewards.giveGroupReward, player)
			systems.BadgeSystem.AwardBadge(player, 3076578083697391)
		end)
		if not ok then
			player:SetAttribute("MyCityLoadFailed", true)
			warn("[Lifecycle] Load failed for", player.UserId, err)
			-- A partial world/inventory restore must never be saved as the real profile.
			Data.abandon(player)
			player:Kick("Your city could not finish loading. Please rejoin.")
		end
		loading[player] = nil
	end

	local function leave(player)
		if leaving[player] then
			while leaving[player] == "saving" do
				task.wait()
			end
			return
		end
		leaving[player] = "saving"
		player:SetAttribute("MyCityLeaving", true)
		while loading[player] or Guard.isBusy(player) do
			task.wait()
		end
		if Data.isLoaded(player) then
			local ok, err = pcall(systems.IncomeSystem.collectPendingIncome, player)
			if not ok then
				warn("[Lifecycle] Income settlement failed", player.UserId, err)
			end
			systems.InventorySystem.saveInventory(player)
			local stamp = player.Data.PlayerInfo:FindFirstChild("LastUpdate")
			if stamp then
				stamp.Value = if stamp:IsA("StringValue") then tostring(os.time()) else os.time()
			end
			Data.savePlayerData(player, true)
		end
		for _, cleanup in
			{
				systems.ConstructionSystem.clearPlayerConstructions,
				systems.IncomeSystem.cleanupPlayer,
				systems.PlotManager.resetPlot,
				systems.InventorySystem.cleanup,
				Rewards.cleanup,
				Data.forget,
			}
		do
			local ok, err = pcall(cleanup, player)
			if not ok then
				warn("[Lifecycle] Cleanup failed", player.UserId, err)
			end
		end
		leaving[player] = "done"
	end

	ReplicatedStorage.Events.Loading.ClientReady.OnServerEvent:Connect(function(player)
		Guard.run(player, "ClientReady", function()
			systems.RebirthSystem.updateRebirthUI(player)
			systems.DailyRewards.updatePlayerUI(player)
			systems.PostTutorialQuest.syncPlayer(player)
			systems.DailyQuests.syncPlayer(player)
			systems.ShopSystem.syncPlayer(player)
			systems.ConstructionSystem.syncPlayer(player)
		end)
	end)
	Players.PlayerAdded:Connect(function(player)
		task.spawn(load, player)
	end)
	Players.PlayerRemoving:Connect(leave)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end
	game:BindToClose(function()
		local pending = 0
		for _, player in Players:GetPlayers() do
			pending += 1
			task.spawn(function()
				local ok, err = pcall(leave, player)
				if not ok then
					warn("[Lifecycle] Shutdown save failed", player.UserId, err)
				end
				pending -= 1
			end)
		end
		while pending > 0 do
			task.wait()
		end
	end)
end

return Lifecycle
