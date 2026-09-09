local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Bootstrap = {}
local started = false

function Bootstrap.start()
	if started then
		return
	end
	started = true
	require(script.Parent.SpawnGuard).start()
	print("[MyCity] Modular server bootstrap v2")
	require(ReplicatedStorage:WaitForChild("shared"):WaitForChild("Network")).start()
	ReplicatedStorage.Events.Loading.IntroFinished.OnServerEvent:Connect(require(script.Parent.SpawnGuard).release)
	require(script.Parent.WorldRuntime).start()
	local systems = {
		DailyQuests = require(script.Parent.Parent.systems.progression.DailyQuests),
		PlayerDataModule = require(script.Parent.Parent:WaitForChild("persistence"):WaitForChild("PlayerDataModule")),
		BuildingConfig = require(script.Parent.Parent:WaitForChild("config"):WaitForChild("BuildingConfig")),
		SpawnConfig = require(script.Parent.Parent:WaitForChild("config"):WaitForChild("SpawnConfig")),
		PlotManager = require(
			script.Parent.Parent:WaitForChild("systems"):WaitForChild("world"):WaitForChild("PlotManager")
		),
		ShopSystem = require(
			script.Parent.Parent:WaitForChild("systems"):WaitForChild("economy"):WaitForChild("ShopSystem")
		),
		BuildingSystem = require(
			script.Parent.Parent:WaitForChild("systems"):WaitForChild("building"):WaitForChild("BuildingSystem")
		),
		IncomeSystem = require(
			script.Parent.Parent:WaitForChild("systems"):WaitForChild("economy"):WaitForChild("IncomeSystem")
		),
		ExpansionSystem = require(
			script.Parent.Parent:WaitForChild("systems"):WaitForChild("world"):WaitForChild("ExpansionSystem")
		),
		ConstructionSystem = require(
			script.Parent.Parent:WaitForChild("systems"):WaitForChild("construction"):WaitForChild("ConstructionSystem")
		),
		MarketplaceHandler = require(script.Parent.Parent:WaitForChild("services"):WaitForChild("MarketPlaceHandler")),
		SellSystem = require(
			script.Parent.Parent:WaitForChild("systems"):WaitForChild("economy"):WaitForChild("SellSystem")
		),
		InventorySystem = require(
			script.Parent.Parent:WaitForChild("systems"):WaitForChild("economy"):WaitForChild("InventorySystem")
		),
		CodeSystem = require(script.Parent.Parent:WaitForChild("services"):WaitForChild("CodeSystem")),
		BadgeSystem = require(
			script.Parent.Parent:WaitForChild("systems"):WaitForChild("progression"):WaitForChild("BadgeModule")
		),
		CityNameSystem = require(
			script.Parent.Parent:WaitForChild("systems"):WaitForChild("world"):WaitForChild("CityNameSystem")
		),
		ToolSystem = require(script.Parent.Parent:WaitForChild("services"):WaitForChild("ToolSetup")),
		RebirthSystem = require(
			script.Parent.Parent:WaitForChild("systems"):WaitForChild("progression"):WaitForChild("RebirthSystem")
		),
		TutorialSystem = require(
			script.Parent.Parent:WaitForChild("systems"):WaitForChild("progression"):WaitForChild("TutorialSystem")
		),
		FunnelAnalytics = require(script.Parent.Parent:WaitForChild("persistence"):WaitForChild("FunnelAnalytics")),
		HighwayTrafficSystem = require(
			script.Parent.Parent:WaitForChild("systems"):WaitForChild("world"):WaitForChild("HighwayTrafficSystem")
		),
		CivilianSystem = require(script.Parent.Parent.systems.world.CivilianSystem),
		DailyRewards = require(
			script.Parent.Parent:WaitForChild("systems"):WaitForChild("progression"):WaitForChild("DailyRewards")
		),
		TrainSystem = require(
			script.Parent.Parent:WaitForChild("systems"):WaitForChild("world"):WaitForChild("TrainSystem")
		),
		PostTutorialQuest = require(
			script.Parent.Parent:WaitForChild("systems"):WaitForChild("progression"):WaitForChild("PostTutorialQuest")
		),
	}
	for _, name in
		{
			"PlayerDataModule",
			"CityNameSystem",
			"ToolSystem",
			"ShopSystem",
			"PlotManager",
			"BuildingSystem",
			"IncomeSystem",
			"ExpansionSystem",
			"ConstructionSystem",
			"MarketplaceHandler",
			"SellSystem",
			"InventorySystem",
			"CodeSystem",
			"RebirthSystem",
			"TutorialSystem",
			"FunnelAnalytics",
			"HighwayTrafficSystem",
			"CivilianSystem",
			"TrainSystem",
			"PostTutorialQuest",
			"DailyRewards",
			"DailyQuests",
		}
	do
		systems[name].init()
	end
	require(script.Parent.Parent.systems.social.CityRating).start()
	require(script.Parent.Parent.systems.social.FriendBoost).start()
	require(script.Parent.ShopPrompt).start()
	require(script.Parent.PlayerLifecycle).start(systems)
end

return Bootstrap
