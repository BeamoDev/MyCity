local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Guard = require(script.Parent.Parent.systems.security.RequestGuard)
local Rewards = require(script.Parent.Parent.systems.progression.PlayerRewards)
local RestoreBudget = require(script.Parent.Parent.services.RestoreBudget)
local Shutdown = require(script.Parent.Shutdown)
local Lifecycle = {}
local started = false

function Lifecycle.start(systems)
	if started or Shutdown.isClosing() then
		return
	end
	started = true
	local Data = systems.PlayerDataModule
	local loading, leaving = {}, setmetatable({}, { __mode = "k" })
	Data.setBeforeSave(systems.InventorySystem.saveInventory)
	local function load(player)
		if loading[player] or not player.Parent or player:GetAttribute("MyCityLeaving") or Shutdown.isClosing() then
			return
		end
		loading[player] = true
		player:SetAttribute("JoinTime", tick())
		player:SetAttribute("MyCityLoaded", false)
		player:SetAttribute("MyCityLoadFailed", false)
		player:SetAttribute("MyCityLoadErrorCode", nil)
		local stage = "Profile"
		local function setStage(value)
			stage = value
			player:SetAttribute("MyCityLoadStage", value)
		end
		local function checkActive()
			if not player.Parent or player:GetAttribute("MyCityLeaving") or Shutdown.isClosing() then
				error("Player load canceled", 0)
			end
		end
		local ok, err = xpcall(function()
			if not Data.loadPlayerData(player) then
				return
			end
			checkActive()
			setStage("Character")
			local character = player.Character
			local deadline = os.clock() + 30
			while not character and player.Parent and os.clock() < deadline do
				checkActive()
				task.wait(0.1)
				character = player.Character
			end
			checkActive()
			if not character or not player.Parent then
				error("Character unavailable")
			end
			setStage("CityName")
			local info = player.Data.PlayerInfo
			if not player:GetAttribute("MyCityFreshStart") then
				info.CityName.Value = systems.CityNameSystem.loadCityName(player)
			end
			checkActive()
			setStage("Plot")
			systems.PlotManager.assignPlot(player, character)
			if player.Data.PlotInfo.Plot.Value <= 0 then
				error("No plot available")
			end
			checkActive()
			ReplicatedStorage.Events.Loading.LoadingProgress:FireClient(player, 0.4)
			setStage("Buildings")
			systems.BuildingSystem.loadPlayerBuildings(player)
			checkActive()
			setStage("Constructions")
			systems.ConstructionSystem.loadPlayerConstructions(player)
			checkActive()
			setStage("CityStats")
			systems.BuildingSystem.updatePlotStats(
				workspace.Plots["Plot" .. player.Data.PlotInfo.Plot.Value],
				function()
					RestoreBudget.checkpoint(player)
				end
			)
			checkActive()
			ReplicatedStorage.Events.Loading.LoadingProgress:FireClient(player, 0.75)
			setStage("Expansion")
			systems.ExpansionSystem.updateExpansionTiles(player)
			systems.CityNameSystem.applyCityNameToPlot(
				player,
				workspace.Plots["Plot" .. player.Data.PlotInfo.Plot.Value]
			)
			checkActive()
			setStage("Income")
			systems.IncomeSystem.setupPlayerIncome(player)
			setStage("Inventory")
			if not systems.InventorySystem.loadInventory(player) then
				error("Inventory restoration failed")
			end
			checkActive()
			systems.InventorySystem.startPlayer(player)
			setStage("Progression")
			systems.RebirthSystem.initializePlayer(player)
			systems.TutorialSystem.prepareForJoin(player)
			systems.TutorialSystem.resume(player)
			checkActive()
			setStage("Quests")
			player:SetAttribute("MyCityLoaded", true)
			systems.PostTutorialQuest.initializePlayer(player)
			systems.DailyQuests.initializePlayer(player)
			ReplicatedStorage.Events.Loading.LoadingProgress:FireClient(player, 1)
			ReplicatedStorage.Events.Loading.LoadingComplete:FireClient(player)
			setStage("Ready")
			-- Optional badge work must not turn a successfully restored city into a failed join.
			task.defer(function()
				if not player.Parent or player:GetAttribute("MyCityLeaving") then
					return
				end
				local rewarded, rewardError = xpcall(function()
					Rewards.trackMillionaire(player)
					systems.BadgeSystem.AwardBadge(player, 3076578083697391)
				end, debug.traceback)
				if not rewarded then
					warn("[Lifecycle] Join badge setup failed for", player.UserId, rewardError)
				end
			end)
		end, debug.traceback)
		if not ok then
			player:SetAttribute("MyCityLoaded", false)
			player:SetAttribute("MyCityInventoryReady", false)
			local canceled = Shutdown.isClosing() or not player.Parent or player:GetAttribute("MyCityLeaving")
			if not canceled then
				player:SetAttribute("MyCityLoadFailed", true)
				player:SetAttribute("MyCityLoadErrorCode", "CITY_" .. stage)
				warn("[Lifecycle] Load failed for", player.UserId, "stage=" .. stage, err)
			end
			-- Release the original record; never save a partially restored city on cancellation.
			Data.abandon(player)
			if not canceled and player.Parent and not player:GetAttribute("MyCityLeaving") then
				player:Kick(
					"Your city could not finish loading. Please report code CITY_"
						.. stage
						.. " with your username if this repeats."
				)
			end
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

	if
		not Shutdown.bind(function()
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
	then
		return
	end

	ReplicatedStorage.Events.Loading.ClientReady.OnServerEvent:Connect(function(player)
		-- Let readiness snapshots take the guard before the yielding reward save.
		task.defer(Rewards.giveGroupReward, player)
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
end

return Lifecycle
