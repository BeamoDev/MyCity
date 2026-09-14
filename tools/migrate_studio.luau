-- Run ONCE in Studio Command Bar in EDIT mode, with Script Sync paused.
-- Moves existing templates with their modules. Resume source sync before Play.
-- Old replaced scripts are disabled and archived; no gameplay/DataStore calls.
assert(not game:GetService("RunService"):IsRunning(), "Stop Play before migrating")
local moves = {
	{
		{ "server", "Main", "BuildingSystem", "BuildingConfig" },
		{ "server", "systems", "building", "BuildingSystem", "BuildingConfig" },
	},
	{
		{ "server", "Main", "BuildingSystem", "BuildingData" },
		{ "server", "systems", "building", "BuildingSystem", "BuildingData" },
	},
	{
		{ "server", "Main", "BuildingSystem", "BuildingPlacement" },
		{ "server", "systems", "building", "BuildingSystem", "BuildingPlacement" },
	},
	{
		{ "server", "Main", "BuildingSystem", "BuildingPrompts" },
		{ "server", "systems", "building", "BuildingSystem", "BuildingPrompts" },
	},
	{
		{ "server", "Main", "BuildingSystem", "BuildingStats" },
		{ "server", "systems", "building", "BuildingSystem", "BuildingStats" },
	},
	{
		{ "server", "Main", "BuildingSystem", "BuildingStealing" },
		{ "server", "systems", "building", "BuildingSystem", "BuildingStealing" },
	},
	{
		{ "server", "Main", "BuildingSystem", "BuildingThoughts" },
		{ "server", "systems", "building", "BuildingSystem", "BuildingThoughts" },
	},
	{
		{ "server", "Main", "BuildingSystem", "BuildingXP" },
		{ "server", "systems", "building", "BuildingSystem", "BuildingXP" },
	},
	{
		{ "server", "Main", "ConstructionSystem", "ConstructionBuilder" },
		{ "server", "systems", "construction", "ConstructionSystem", "ConstructionBuilder" },
	},
	{
		{ "server", "Main", "ConstructionSystem", "ConstructionData" },
		{ "server", "systems", "construction", "ConstructionSystem", "ConstructionData" },
	},
	{
		{ "server", "Main", "ConstructionSystem", "ConstructionSkipping" },
		{ "server", "systems", "construction", "ConstructionSystem", "ConstructionSkipping" },
	},
	{
		{ "server", "Main", "ConstructionSystem", "ConstructionTimer" },
		{ "server", "systems", "construction", "ConstructionSystem", "ConstructionTimer" },
	},
	{
		{ "server", "Main", "ConstructionSystem", "ConstructionVFX" },
		{ "server", "systems", "construction", "ConstructionSystem", "ConstructionVFX" },
	},
	{
		{ "server", "Main", "MarketPlaceHandler", "WebHook" },
		{ "server", "services", "MarketPlaceHandler", "WebHook" },
	},
	{ { "server", "Main", "BadgeModule" }, { "server", "systems", "progression", "BadgeModule" } },
	{ { "server", "Main", "BuildingConfig" }, { "server", "config", "BuildingConfig" } },
	{ { "server", "Main", "CityNameSystem" }, { "server", "systems", "world", "CityNameSystem" } },
	{ { "server", "Main", "CodeSystem" }, { "server", "services", "CodeSystem" } },
	{ { "server", "Main", "DailyRewards" }, { "server", "systems", "progression", "DailyRewards" } },
	{ { "server", "Main", "DeleteDatastore" }, { "server", "maintenance", "DeleteDatastore" } },
	{ { "server", "Main", "ExpansionSystem" }, { "server", "systems", "world", "ExpansionSystem" } },
	{ { "server", "Main", "FunnelAnalytics" }, { "server", "persistence", "FunnelAnalytics" } },
	{ { "server", "Main", "HighwayTrafficSystem" }, { "server", "systems", "world", "HighwayTrafficSystem" } },
	{ { "server", "Main", "IncomeSystem" }, { "server", "systems", "economy", "IncomeSystem" } },
	{ { "server", "Main", "InventorySystem" }, { "server", "systems", "economy", "InventorySystem" } },
	{ { "server", "Main", "PlotManager" }, { "server", "systems", "world", "PlotManager" } },
	{ { "server", "Main", "PostTutorialQuest" }, { "server", "systems", "progression", "PostTutorialQuest" } },
	{ { "server", "Main", "RebirthConfig" }, { "server", "systems", "progression", "RebirthConfig" } },
	{ { "server", "Main", "RebirthSystem" }, { "server", "systems", "progression", "RebirthSystem" } },
	{ { "server", "Main", "SellSystem" }, { "server", "systems", "economy", "SellSystem" } },
	{ { "server", "Main", "ShopSystem" }, { "server", "systems", "economy", "ShopSystem" } },
	{ { "server", "Main", "SpawnConfig" }, { "server", "config", "SpawnConfig" } },
	{ { "server", "Main", "ToolSetup" }, { "server", "services", "ToolSetup" } },
	{ { "server", "Main", "TrainSystem" }, { "server", "systems", "world", "TrainSystem" } },
	{ { "server", "Main", "TutorialSystem" }, { "server", "systems", "progression", "TutorialSystem" } },
	{ { "server", "Main", "VFX" }, { "server", "systems", "world", "VFX" } },
	{ { "server", "Main", "WeatherSystem" }, { "server", "systems", "world", "WeatherSystem" } },
	{ { "server", "Main", "BuildingSystem" }, { "server", "systems", "building", "BuildingSystem" } },
	{ { "server", "Main", "ConstructionSystem" }, { "server", "systems", "construction", "ConstructionSystem" } },
	{ { "server", "Main", "MarketPlaceHandler" }, { "server", "services", "MarketPlaceHandler" } },
	{ { "server", "Main", "PlayerDataModule" }, { "server", "persistence", "PlayerDataModule" } },
	{ { "server", "CityRating" }, { "server", "systems", "social", "CityRating" } },
	{ { "server", "FriendBoost" }, { "server", "systems", "social", "FriendBoost" } },
	{ { "shared", "Init" }, { "client", "bootstrap", "HudBootstrap" } },
	{ { "shared", "UIController" }, { "client", "controllers", "ui", "UIController" } },
	{ { "shared", "NotificationController" }, { "client", "controllers", "ui", "NotificationController" } },
	{ { "shared", "ShopController" }, { "client", "controllers", "shop", "ShopController" } },
	{ { "shared", "SellController" }, { "client", "controllers", "shop", "SellController" } },
	{ { "shared", "TutorialController" }, { "client", "controllers", "tutorial", "TutorialController" } },
	{ { "shared", "ToolsModule" }, { "client", "controllers", "placement", "ToolsModule" } },
	{ { "shared", "FriendsBoost" }, { "client", "controllers", "social", "FriendsBoost" } },
	{ { "shared", "LikeSystem" }, { "client", "controllers", "social", "LikeSystem" } },
	{ { "client", "BuildingTools" }, { "client", "controllers", "placement", "BuildingTools" } },
	{ { "client", "ChatTags" }, { "client", "controllers", "social", "ChatTags" } },
	{ { "client", "ExpandHighlight" }, { "client", "controllers", "placement", "ExpandHighlight" } },
	{ { "client", "Functions" }, { "client", "controllers", "systems", "ResetButton" } },
	{ { "client", "ProximityPromptScript" }, { "client", "controllers", "ui", "ProximityPromptController" } },
}
local classes = {
	["server.bootstrap.Shutdown"] = "ModuleScript",
	["shared.visuals.AmbientModel"] = "ModuleScript",
	["shared.visuals.AmbientTrip"] = "ModuleScript",
	["server.services.SimulationScheduler"] = "ModuleScript",
	["server.systems.social.CityLikeRewards"] = "ModuleScript",
	["server.systems.economy.IncomeSystem.CityCache"] = "ModuleScript",
	["client.controllers.world.AmbientTrafficController"] = "ModuleScript",
	["client.bootstrap.EarlyLoading"] = "ModuleScript",
	["client.bootstrap.HudBootstrap"] = "ModuleScript",
	["client.controllers.intro.IntroController.Camera"] = "ModuleScript",
	["client.controllers.intro.IntroController"] = "ModuleScript",
	["client.controllers.intro.IntroController.Presentation"] = "ModuleScript",
	["client.controllers.placement.BuildingTools"] = "ModuleScript",
	["client.controllers.placement.ExpandHighlight"] = "ModuleScript",
	["client.controllers.placement.MobilePlacement"] = "ModuleScript",
	["client.controllers.placement.PlacementAccess"] = "ModuleScript",
	["client.controllers.placement.ToolsModule"] = "ModuleScript",
	["client.controllers.placement.ToolsModule.Session.Collision"] = "ModuleScript",
	["client.controllers.placement.ToolsModule.Session.Geometry"] = "ModuleScript",
	["client.controllers.placement.ToolsModule.Session.Hud"] = "ModuleScript",
	["client.controllers.placement.ToolsModule.Session"] = "ModuleScript",
	["client.controllers.placement.ToolsModule.Session.Input"] = "ModuleScript",
	["client.controllers.placement.ToolsModule.Session.Lifecycle"] = "ModuleScript",
	["client.controllers.placement.ToolsModule.Session.Motion"] = "ModuleScript",
	["client.controllers.placement.ToolsModule.Session.Placement"] = "ModuleScript",
	["client.controllers.placement.ToolsModule.Session.Preview"] = "ModuleScript",
	["client.controllers.shop.SellController.Display"] = "ModuleScript",
	["client.controllers.shop.SellController.Formatting"] = "ModuleScript",
	["client.controllers.shop.SellController"] = "ModuleScript",
	["client.controllers.shop.SellController.Lifecycle"] = "ModuleScript",
	["client.controllers.shop.SellController.PreviewCleanup"] = "ModuleScript",
	["client.controllers.shop.SellController.RemoteBindings"] = "ModuleScript",
	["client.controllers.shop.ShopController.Formatting"] = "ModuleScript",
	["client.controllers.shop.ShopController"] = "ModuleScript",
	["client.controllers.shop.ShopController.Lifecycle"] = "ModuleScript",
	["client.controllers.shop.ShopController.PurchasePanel"] = "ModuleScript",
	["client.controllers.shop.ShopController.StockDisplay"] = "ModuleScript",
	["client.controllers.social.ChatTags"] = "ModuleScript",
	["client.controllers.social.FriendsBoost"] = "ModuleScript",
	["client.controllers.social.LikeSystem"] = "ModuleScript",
	["client.controllers.systems.ResetButton"] = "ModuleScript",
	["client.controllers.tutorial.TutorialController.Camera"] = "ModuleScript",
	["client.controllers.tutorial.TutorialController.Guidance"] = "ModuleScript",
	["client.controllers.tutorial.TutorialController.Highlights"] = "ModuleScript",
	["client.controllers.tutorial.TutorialController"] = "ModuleScript",
	["client.controllers.tutorial.TutorialController.Lifecycle"] = "ModuleScript",
	["client.controllers.tutorial.TutorialController.Stages"] = "ModuleScript",
	["client.controllers.tutorial.TutorialController.Subtitles"] = "ModuleScript",
	["client.controllers.ui.CashFeedback"] = "ModuleScript",
	["client.controllers.ui.NotificationController"] = "ModuleScript",
	["client.controllers.ui.NotificationController.Layout"] = "ModuleScript",
	["client.controllers.ui.NotificationController.Lifecycle"] = "ModuleScript",
	["client.controllers.ui.NotificationController.Queue"] = "ModuleScript",
	["client.controllers.ui.NotificationController.RemoteBindings"] = "ModuleScript",
	["client.controllers.ui.ProximityPromptController"] = "ModuleScript",
	["client.controllers.ui.ProximityPromptController.Lifecycle"] = "ModuleScript",
	["client.controllers.ui.ProximityPromptController.Progress"] = "ModuleScript",
	["client.controllers.ui.ProximityPromptController.Renderer"] = "ModuleScript",
	["client.controllers.ui.ProximityPromptController.ScreenGui"] = "ModuleScript",
	["client.controllers.ui.UIController.BuilderDisplay"] = "ModuleScript",
	["client.controllers.ui.UIController.BuildingActions"] = "ModuleScript",
	["client.controllers.ui.UIController.Buttons"] = "ModuleScript",
	["client.controllers.ui.UIController.CashDisplay"] = "ModuleScript",
	["client.controllers.ui.UIController.CityPrompts"] = "ModuleScript",
	["client.controllers.ui.UIController.Construction"] = "ModuleScript",
	["client.controllers.ui.UIController.Construction.Rows"] = "ModuleScript",
	["client.controllers.ui.UIController.DailyQuests"] = "ModuleScript",
	["client.controllers.ui.UIController.DailyQuests.ButtonBinding"] = "ModuleScript",
	["client.controllers.ui.UIController.DailyQuests.QuestRow"] = "ModuleScript",
	["client.controllers.ui.UIController.DailyQuests.View"] = "ModuleScript",
	["client.controllers.ui.UIController.DailyQuests.ClaimStyle"] = "ModuleScript",
	["client.controllers.ui.UIController.DailyRewards"] = "ModuleScript",
	["client.controllers.ui.UIController.Displays"] = "ModuleScript",
	["client.controllers.ui.UIController"] = "ModuleScript",
	["client.controllers.ui.UIController.Lifecycle"] = "ModuleScript",
	["client.controllers.ui.UIController.Navigation"] = "ModuleScript",
	["client.controllers.ui.UIController.Presentation"] = "ModuleScript",
	["client.controllers.ui.UIController.Rebirth"] = "ModuleScript",
	["client.controllers.ui.UIController.RebirthConfirmation"] = "ModuleScript",
	["client.controllers.ui.UIController.RebirthRewards"] = "ModuleScript",
	["client.controllers.ui.UIController.ClaimAlerts"] = "ModuleScript",
	["client.controllers.ui.UIController.RemoteBindings"] = "ModuleScript",
	["client.controllers.ui.UIController.remotes.BuildingInfo"] = "ModuleScript",
	["client.controllers.ui.UIController.remotes.CityName"] = "ModuleScript",
	["client.controllers.ui.UIController.remotes.Menus"] = "ModuleScript",
	["client.controllers.ui.UIController.remotes.PromptLabels"] = "ModuleScript",
	["client.controllers.ui.UIController.remotes.Quests"] = "ModuleScript",
	["client.controllers.ui.UIController.remotes.Weather"] = "ModuleScript",
	["client.controllers.ui.UIController.Settings.Audio"] = "ModuleScript",
	["client.controllers.ui.UIController.Settings.Codes"] = "ModuleScript",
	["client.controllers.ui.UIController.Settings"] = "ModuleScript",
	["client.controllers.ui.UIController.TravelButtons"] = "ModuleScript",
	["client.Initialization"] = "LocalScript",
	["client.Satchel"] = "LocalScript",
	["client.Satchel.Satchel"] = "ModuleScript",
	["client.Satchel.Satchel.Packages._Index.legitatx_topbarplus@3.0.5.topbarplus.Attribute"] = "ModuleScript",
	["client.Satchel.Satchel.Packages._Index.legitatx_topbarplus@3.0.5.topbarplus.Elements.Caption"] = "ModuleScript",
	["client.Satchel.Satchel.Packages._Index.legitatx_topbarplus@3.0.5.topbarplus.Elements.Container"] = "ModuleScript",
	["client.Satchel.Satchel.Packages._Index.legitatx_topbarplus@3.0.5.topbarplus.Elements.Dropdown"] = "ModuleScript",
	["client.Satchel.Satchel.Packages._Index.legitatx_topbarplus@3.0.5.topbarplus.Elements.Indicator"] = "ModuleScript",
	["client.Satchel.Satchel.Packages._Index.legitatx_topbarplus@3.0.5.topbarplus.Elements.Menu"] = "ModuleScript",
	["client.Satchel.Satchel.Packages._Index.legitatx_topbarplus@3.0.5.topbarplus.Elements.Notice"] = "ModuleScript",
	["client.Satchel.Satchel.Packages._Index.legitatx_topbarplus@3.0.5.topbarplus.Elements.Selection"] = "ModuleScript",
	["client.Satchel.Satchel.Packages._Index.legitatx_topbarplus@3.0.5.topbarplus.Elements.Widget"] = "ModuleScript",
	["client.Satchel.Satchel.Packages._Index.legitatx_topbarplus@3.0.5.topbarplus.Features.Gamepad"] = "ModuleScript",
	["client.Satchel.Satchel.Packages._Index.legitatx_topbarplus@3.0.5.topbarplus.Features.Overflow"] = "ModuleScript",
	["client.Satchel.Satchel.Packages._Index.legitatx_topbarplus@3.0.5.topbarplus.Features.Themes.Classic"] = "ModuleScript",
	["client.Satchel.Satchel.Packages._Index.legitatx_topbarplus@3.0.5.topbarplus.Features.Themes.Default"] = "ModuleScript",
	["client.Satchel.Satchel.Packages._Index.legitatx_topbarplus@3.0.5.topbarplus.Features.Themes"] = "ModuleScript",
	["client.Satchel.Satchel.Packages._Index.legitatx_topbarplus@3.0.5.topbarplus"] = "ModuleScript",
	["client.Satchel.Satchel.Packages._Index.legitatx_topbarplus@3.0.5.topbarplus.Packages.GoodSignal"] = "ModuleScript",
	["client.Satchel.Satchel.Packages._Index.legitatx_topbarplus@3.0.5.topbarplus.Packages.Janitor"] = "ModuleScript",
	["client.Satchel.Satchel.Packages._Index.legitatx_topbarplus@3.0.5.topbarplus.Reference"] = "ModuleScript",
	["client.Satchel.Satchel.Packages._Index.legitatx_topbarplus@3.0.5.topbarplus.Utility"] = "ModuleScript",
	["client.Satchel.Satchel.Packages._Index.legitatx_topbarplus@3.0.5.topbarplus.VERSION"] = "ModuleScript",
	["client.Satchel.Satchel.Packages.topbarplus"] = "ModuleScript",
	["server.bootstrap.PlayerLifecycle"] = "ModuleScript",
	["server.bootstrap.ServerBootstrap"] = "ModuleScript",
	["server.bootstrap.ShopPrompt"] = "ModuleScript",
	["server.bootstrap.SpawnGuard"] = "ModuleScript",
	["server.bootstrap.WorldRuntime"] = "ModuleScript",
	["server.config.BuildingConfig.Decorations"] = "ModuleScript",
	["server.config.BuildingConfig.Epic"] = "ModuleScript",
	["server.config.BuildingConfig"] = "ModuleScript",
	["server.config.BuildingConfig.Legendary"] = "ModuleScript",
	["server.config.BuildingConfig.Mythic"] = "ModuleScript",
	["server.config.BuildingConfig.Population"] = "ModuleScript",
	["server.config.BuildingConfig.Rare"] = "ModuleScript",
	["server.config.BuildingConfig.Starter"] = "ModuleScript",
	["server.config.BuildingConfig.Uncommon"] = "ModuleScript",
	["server.config.DailyQuestCatalog"] = "ModuleScript",
	["server.config.SpawnConfig"] = "ModuleScript",
	["server.config.TutorialConfig"] = "ModuleScript",
	["server.Main"] = "Script",
	["server.maintenance.DeleteDatastore"] = "ModuleScript",
	["server.persistence.FunnelAnalytics"] = "ModuleScript",
	["server.persistence.PlayerDataModule.DataSchema"] = "ModuleScript",
	["server.persistence.PlayerDataModule"] = "ModuleScript",
	["server.persistence.PlayerDataModule.OwnerReset"] = "ModuleScript",
	["server.persistence.PlayerDataModule.ProfileCodec"] = "ModuleScript",
	["server.persistence.PlayerDataModule.SchemaMigration"] = "ModuleScript",
	["server.persistence.PlayerDataModule.SessionStore"] = "ModuleScript",
	["server.services.CodeSystem"] = "ModuleScript",
	["server.services.GamePassOwnership"] = "ModuleScript",
	["server.services.HeldBuildingVisual"] = "ModuleScript",
	["server.services.MarketPlaceHandler.GrantActions"] = "ModuleScript",
	["server.services.MarketPlaceHandler.GrantPlan"] = "ModuleScript",
	["server.services.MarketPlaceHandler"] = "ModuleScript",
	["server.services.MarketPlaceHandler.ProductConfig"] = "ModuleScript",
	["server.services.MarketPlaceHandler.PurchaseIntents"] = "ModuleScript",
	["server.services.MarketPlaceHandler.ReceiptLedger"] = "ModuleScript",
	["server.services.MarketPlaceHandler.TransferService"] = "ModuleScript",
	["server.services.MarketPlaceHandler.WebHook"] = "ModuleScript",
	["server.services.QuestSignals"] = "ModuleScript",
	["server.services.RestoreBudget"] = "ModuleScript",
	["server.services.ToolFactory"] = "ModuleScript",
	["server.services.ToolSerialization"] = "ModuleScript",
	["server.services.ToolSetup"] = "ModuleScript",
	["server.systems.building.BuildingSystem.BuildingConfig"] = "ModuleScript",
	["server.systems.building.BuildingSystem.BuildingData"] = "ModuleScript",
	["server.systems.building.BuildingSystem.BuildingPlacement"] = "ModuleScript",
	["server.systems.building.BuildingSystem.BuildingPrompts"] = "ModuleScript",
	["server.systems.building.BuildingSystem.BuildingStats.Aggregation"] = "ModuleScript",
	["server.systems.building.BuildingSystem.BuildingStats.Happiness"] = "ModuleScript",
	["server.systems.building.BuildingSystem.BuildingStats.Health"] = "ModuleScript",
	["server.systems.building.BuildingSystem.BuildingStats"] = "ModuleScript",
	["server.systems.building.BuildingSystem.BuildingStats.Penalties"] = "ModuleScript",
	["server.systems.building.BuildingSystem.BuildingStats.Safety"] = "ModuleScript",
	["server.systems.building.BuildingSystem.BuildingStats.Snapshot"] = "ModuleScript",
	["server.systems.building.BuildingSystem.BuildingStealing"] = "ModuleScript",
	["server.systems.building.BuildingSystem.BuildingThoughts"] = "ModuleScript",
	["server.systems.building.BuildingSystem.BuildingThoughts.Lifecycle"] = "ModuleScript",
	["server.systems.building.BuildingSystem.BuildingThoughts.Presentation"] = "ModuleScript",
	["server.systems.building.BuildingSystem.BuildingThoughts.Selection"] = "ModuleScript",
	["server.systems.building.BuildingSystem.BuildingValidation"] = "ModuleScript",
	["server.systems.building.BuildingSystem.BuildingXP.Awards"] = "ModuleScript",
	["server.systems.building.BuildingSystem.BuildingXP.Effects"] = "ModuleScript",
	["server.systems.building.BuildingSystem.BuildingXP"] = "ModuleScript",
	["server.systems.building.BuildingSystem.BuildingXP.Lifecycle"] = "ModuleScript",
	["server.systems.building.BuildingSystem.BuildingXP.Progression"] = "ModuleScript",
	["server.systems.building.BuildingSystem"] = "ModuleScript",
	["server.systems.building.BuildingSystem.PlacementCommit"] = "ModuleScript",
	["server.systems.construction.ConstructionSystem.ConstructionBuilder"] = "ModuleScript",
	["server.systems.construction.ConstructionSystem.ConstructionData.Coordinates"] = "ModuleScript",
	["server.systems.construction.ConstructionSystem.ConstructionData"] = "ModuleScript",
	["server.systems.construction.ConstructionSystem.ConstructionData.Lifecycle"] = "ModuleScript",
	["server.systems.construction.ConstructionSystem.ConstructionData.Restoration"] = "ModuleScript",
	["server.systems.construction.ConstructionSystem.ConstructionData.Serialization"] = "ModuleScript",
	["server.systems.construction.ConstructionSystem.ConstructionSkipping"] = "ModuleScript",
	["server.systems.construction.ConstructionSystem.ConstructionTimer.Completion"] = "ModuleScript",
	["server.systems.construction.ConstructionSystem.ConstructionTimer"] = "ModuleScript",
	["server.systems.construction.ConstructionSystem.ConstructionTimer.Lifecycle"] = "ModuleScript",
	["server.systems.construction.ConstructionSystem.ConstructionTimer.PlayerView"] = "ModuleScript",
	["server.systems.construction.ConstructionSystem.ConstructionTimer.Timing"] = "ModuleScript",
	["server.systems.construction.ConstructionSystem.ConstructionTimer.Visuals"] = "ModuleScript",
	["server.systems.construction.ConstructionSystem.ConstructionVFX"] = "ModuleScript",
	["server.systems.construction.ConstructionSystem"] = "ModuleScript",
	["server.systems.economy.BuildingEconomy"] = "ModuleScript",
	["server.systems.economy.IncomeSystem.BuildingAlerts"] = "ModuleScript",
	["server.systems.economy.IncomeSystem.Calculation"] = "ModuleScript",
	["server.systems.economy.IncomeSystem.Collection"] = "ModuleScript",
	["server.systems.economy.IncomeSystem"] = "ModuleScript",
	["server.systems.economy.IncomeSystem.Lifecycle"] = "ModuleScript",
	["server.systems.economy.IncomeSystem.PlotDisplays"] = "ModuleScript",
	["server.systems.economy.InventorySystem"] = "ModuleScript",
	["server.systems.economy.SellSystem.Display"] = "ModuleScript",
	["server.systems.economy.SellSystem"] = "ModuleScript",
	["server.systems.economy.SellSystem.Lifecycle"] = "ModuleScript",
	["server.systems.economy.SellSystem.PromptBinding"] = "ModuleScript",
	["server.systems.economy.SellSystem.Sale"] = "ModuleScript",
	["server.systems.economy.SellSystem.Valuation"] = "ModuleScript",
	["server.systems.economy.ShopSystem"] = "ModuleScript",
	["server.systems.economy.ShopSystem.Lifecycle"] = "ModuleScript",
	["server.systems.economy.ShopSystem.PlayerView"] = "ModuleScript",
	["server.systems.economy.ShopSystem.Purchases"] = "ModuleScript",
	["server.systems.economy.ShopSystem.Refresh"] = "ModuleScript",
	["server.systems.economy.ShopSystem.Stock"] = "ModuleScript",
	["server.systems.progression.BadgeModule"] = "ModuleScript",
	["server.systems.progression.DailyQuests.Board"] = "ModuleScript",
	["server.systems.progression.DailyQuests"] = "ModuleScript",
	["server.systems.progression.DailyQuests.Runtime"] = "ModuleScript",
	["server.systems.progression.DailyRewards"] = "ModuleScript",
	["server.systems.progression.PlayerRewards"] = "ModuleScript",
	["server.systems.progression.PostTutorialQuest"] = "ModuleScript",
	["server.systems.progression.PostTutorialQuest.Lifecycle"] = "ModuleScript",
	["server.systems.progression.PostTutorialQuest.Objectives"] = "ModuleScript",
	["server.systems.progression.PostTutorialQuest.Progression"] = "ModuleScript",
	["server.systems.progression.PostTutorialQuest.State"] = "ModuleScript",
	["server.systems.progression.RebirthConfig"] = "ModuleScript",
	["server.systems.progression.RebirthSystem.Display"] = "ModuleScript",
	["server.systems.progression.RebirthSystem"] = "ModuleScript",
	["server.systems.progression.RebirthSystem.Lifecycle"] = "ModuleScript",
	["server.systems.progression.RebirthSystem.Rebirth"] = "ModuleScript",
	["server.systems.progression.RebirthSystem.Reset"] = "ModuleScript",
	["server.systems.progression.TutorialSystem"] = "ModuleScript",
	["server.systems.security.RequestGuard"] = "ModuleScript",
	["server.systems.social.CityRating"] = "ModuleScript",
	["server.systems.social.FriendBoost"] = "ModuleScript",
	["server.systems.world.CityNameSystem"] = "ModuleScript",
	["server.systems.world.CivilianSystem.Animations"] = "ModuleScript",
	["server.systems.world.CivilianSystem.Appearance"] = "ModuleScript",
	["server.systems.world.CivilianSystem.Config"] = "ModuleScript",
	["server.systems.world.CivilianSystem.Geometry"] = "ModuleScript",
	["server.systems.world.CivilianSystem"] = "ModuleScript",
	["server.systems.world.CivilianSystem.Movement"] = "ModuleScript",
	["server.systems.world.CivilianSystem.Rig"] = "ModuleScript",
	["server.systems.world.ExpansionSystem"] = "ModuleScript",
	["server.systems.world.HighwayTrafficSystem"] = "ModuleScript",
	["server.systems.world.PlotManager.Assignment"] = "ModuleScript",
	["server.systems.world.PlotManager"] = "ModuleScript",
	["server.systems.world.PlotManager.Lifecycle"] = "ModuleScript",
	["server.systems.world.PlotManager.Relocation"] = "ModuleScript",
	["server.systems.world.PlotManager.Reset"] = "ModuleScript",
	["server.systems.world.PlotManager.Scenery"] = "ModuleScript",
	["server.systems.world.TrainSystem"] = "ModuleScript",
	["server.systems.world.AmbientTraffic"] = "ModuleScript",
	["server.systems.world.AmbientTraffic.Model"] = "ModuleScript",
	["server.systems.world.AmbientTraffic.Routes"] = "ModuleScript",
	["server.systems.world.VFX"] = "ModuleScript",
	["server.systems.world.WeatherSystem"] = "ModuleScript",
	["shared.Network"] = "ModuleScript",
	["shared.ui.Transitions"] = "ModuleScript",
	["shared.UIEffects"] = "ModuleScript",
	["shared.util.ConnectionScope"] = "ModuleScript",
	["shared.util.NumberCounter"] = "ModuleScript",
	["shared.util.PlacementRange"] = "ModuleScript",
}
local starter = game:GetService("StarterPlayer").StarterPlayerScripts
local roots = {
	server = game:GetService("ServerScriptService"):FindFirstChild("server"),
	client = starter:FindFirstChild("client") or starter,
	shared = game:GetService("ReplicatedStorage"):FindFirstChild("shared"),
}
assert(roots.server and roots.shared, "Expected server and shared Script Sync roots")
local function resolve(path, create, stopBeforeLeaf)
	local current = roots[path[1]]
	local prefix = path[1]
	local last = #path - (stopBeforeLeaf and 1 or 0)
	for index = 2, last do
		local name = path[index]
		prefix ..= "." .. name
		local child = current:FindFirstChild(name)
		if not child and create then
			child = Instance.new(classes[prefix] or "Folder")
			child.Name = name
			child.Parent = current
		end
		if not child then
			return nil
		end
		current = child
	end
	return current
end

-- Preflight destination classes, including parent ModuleScripts, before mutation.
for path, expected in classes do
	local names = string.split(path, ".")
	local current = roots[names[1]]
	local prefix = names[1]
	for index = 2, #names do
		prefix ..= "." .. names[index]
		current = current and current:FindFirstChild(names[index])
		if not current then
			break
		end
		local kind = classes[prefix] or "Folder"
		assert(current.ClassName == kind, "Wrong destination class: " .. current:GetFullName() .. "; expected " .. kind)
	end
end

-- Preflight authored child collisions before moving anything.
for _, move in moves do
	local old, target = resolve(move[1]), resolve(move[2])
	if old and target and old ~= target then
		for _, child in old:GetChildren() do
			if target:FindFirstChild(child.Name) then
				error(
					"Template collision; preserve and reconcile both copies: "
						.. target:GetFullName()
						.. "."
						.. child.Name
				)
			end
		end
	end
end

game:GetService("ChangeHistoryService"):SetWaypoint("Before MyCity folder migration")
local storage = game:GetService("ServerStorage")
local archive = storage:FindFirstChild("MyCityMigrationArchive") or Instance.new("Folder")
archive.Name = "MyCityMigrationArchive"
archive.Parent = storage
local count = 0
for _, move in moves do
	local old = resolve(move[1])
	if not old then
		continue
	end
	local parent = resolve(move[2], true, true)
	local name = move[2][#move[2]]
	local target = parent:FindFirstChild(name)
	local expected = classes[table.concat(move[2], ".")]
	if old == target then
		continue
	end
	if not target and old.ClassName == expected then
		old.Name = name
		old.Parent = parent
	else
		if not target then
			target = Instance.new(expected)
			target.Name = name
			target.Parent = parent
		end
		assert(target.ClassName == expected, "Wrong destination class: " .. target:GetFullName())
		for _, child in old:GetChildren() do
			assert(not target:FindFirstChild(child.Name), "Conflicting child: " .. child.Name)
			child.Parent = target
		end
		if old:IsA("BaseScript") then
			old.Enabled = false
		end
		old.Name = table.concat(move[1], "_")
		old.Parent = archive
	end
	count += 1
end
game:GetService("ChangeHistoryService"):SetWaypoint("After MyCity folder migration")
print("[MyCity] Moved", count, "source containers. Resume Script Sync and sync all src files before Play.")
print("[MyCity] Items belongs under ReplicatedStorage.Assets.Items. Archived scripts are disabled in ServerStorage.")
