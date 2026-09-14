-- READ ONLY. Paste into Studio's Command Bar in Edit mode for this place.
-- Does not require gameplay modules, modify instances, or access DataStores.
local required = {
	{ "ServerScriptService.server.bootstrap.Shutdown", "ModuleScript" },
	{ "ReplicatedStorage.shared.visuals.AmbientModel", "ModuleScript" },
	{ "ReplicatedStorage.shared.visuals.AmbientTrip", "ModuleScript" },
	{ "ServerScriptService.server.services.SimulationScheduler", "ModuleScript" },
	{ "ServerScriptService.server.systems.social.CityLikeRewards", "ModuleScript" },
	{ "ServerScriptService.server.systems.economy.IncomeSystem.CityCache", "ModuleScript" },
	{ "ClientRoot.controllers.world.AmbientTrafficController", "ModuleScript" },
	{ "ServerScriptService.server.systems.world.AmbientTraffic", "ModuleScript" },
	{ "ServerScriptService.server.systems.world.AmbientTraffic.Model", "ModuleScript" },
	{ "ServerScriptService.server.systems.world.AmbientTraffic.Routes", "ModuleScript" },
	{ "StarterGui.HUD.Buttons.Left.Quests", "GuiButton" },
	{ "StarterGui.HUD.Frames.Quests.Frame.Template", "GuiObject" },
	{ "StarterGui.HUD.Frames.Quests.Frame.Template.Reward", "TextLabel" },
	{ "StarterGui.HUD.Frames.Quests.Frame.Content", "ScrollingFrame" },
	{ "StarterGui.HUD.Frames.Quests.Frame.Content.Top", "Frame" },
	{ "StarterGui.HUD.Frames.Quests.Frame.Content.Bottom", "Frame" },
	{ "StarterGui.HUD.Frames.Quests.Frame.X", "GuiButton" },
	{ "ClientRoot.controllers.ui.UIController.DailyQuests", "ModuleScript" },
	{ "ClientRoot.controllers.ui.UIController.DailyQuests.View", "ModuleScript" },
	{ "ClientRoot.controllers.ui.UIController.DailyQuests.ButtonBinding", "ModuleScript" },
	{ "ClientRoot.controllers.ui.UIController.DailyQuests.QuestRow", "ModuleScript" },
	{ "ClientRoot.controllers.ui.UIController.DailyQuests.ClaimStyle", "ModuleScript" },
	{ "ServerScriptService.server.systems.progression.DailyQuests", "ModuleScript" },
	{ "ServerScriptService.server.systems.progression.DailyQuests.Board", "ModuleScript" },
	{ "ServerScriptService.server.systems.progression.DailyQuests.Runtime", "ModuleScript" },
	{ "ServerScriptService.server.config.DailyQuestCatalog", "ModuleScript" },
	{ "ServerScriptService.server.services.QuestSignals", "ModuleScript" },
	{ "ServerScriptService.server.persistence.PlayerDataModule.OwnerReset", "ModuleScript" },
	{ "ReplicatedStorage.shared.util.PlacementRange", "ModuleScript" },
	{ "ClientRoot.controllers.placement.PlacementAccess", "ModuleScript" },
	{ "ClientRoot.controllers.ui.UIController.RebirthConfirmation", "ModuleScript" },
	{ "ClientRoot.controllers.ui.UIController.RebirthRewards", "ModuleScript" },
	{ "ClientRoot.controllers.ui.UIController.ClaimAlerts", "ModuleScript" },
	{ "ServerScriptService.server.systems.world.CivilianSystem.Appearance", "ModuleScript" },
	{ "ReplicatedStorage.shared.ui.Transitions", "ModuleScript" },
	{ "ClientRoot.controllers.ui.UIController.Presentation", "ModuleScript" },
	{ "ClientRoot.controllers.ui.UIController.TravelButtons", "ModuleScript" },
	{ "StarterGui.HUD.Buttons.Up.Buy", "GuiButton" },
	{ "StarterGui.HUD.Buttons.Up.City", "GuiButton" },
	{ "StarterGui.HUD.Buttons.Up.Sell", "GuiButton" },
	{ "ClientRoot.controllers.placement.ToolsModule.Session.Motion", "ModuleScript" },
	{ "ReplicatedStorage.Assets.ConstructionTemplate", "GuiObject" },
	{ "ReplicatedStorage.Assets.ConstructionTemplate.BuildingName", "TextLabel" },
	{ "ReplicatedStorage.Assets.ConstructionTemplate.Timer", "TextLabel" },
	{ "ReplicatedStorage.Assets.ConstructionTemplate.Frame", "GuiObject" },
	{ "StarterGui.HUD.Frames.Construction.Frame.ScrollingFrame", "ScrollingFrame" },
	{ "StarterGui.HUD.Frames.Construction.Frame.ErrorFrame", "GuiObject" },
	{ "StarterGui.HUD.Frames.Settings", "GuiObject" },
	{ "ClientRoot.controllers.ui.UIController.Construction", "ModuleScript" },
	{ "ClientRoot.controllers.ui.UIController.Construction.Rows", "ModuleScript" },
	{ "ClientRoot.controllers.ui.UIController.Settings", "ModuleScript" },
	{ "ClientRoot.controllers.ui.UIController.Settings.Audio", "ModuleScript" },
	{ "ClientRoot.controllers.ui.UIController.Settings.Codes", "ModuleScript" },
	{ "ClientRoot.controllers.ui.UIController.BuilderDisplay", "ModuleScript" },
	{ "ClientRoot.controllers.placement.MobilePlacement", "ModuleScript" },
	{
		"ServerScriptService.server.systems.construction.ConstructionSystem.ConstructionTimer.PlayerView",
		"ModuleScript",
	},
	{ "Workspace.Map.Interactives.SellArea.Part.ShopPrompt", "ProximityPrompt" },
	{ "ServerScriptService.server", "Folder" },
	{ "ServerScriptService.server.Main", "Script" },
	{ "ServerScriptService.server.persistence.PlayerDataModule", "ModuleScript" },
	{ "ReplicatedStorage.Assets.Items" },
	{ "ReplicatedStorage.Assets.Items.CollectPrompt", "ProximityPrompt" },
	{ "ReplicatedStorage.Assets.Items.SkipPrompt", "ProximityPrompt" },
	{ "ReplicatedStorage.Assets.Items.BuildingInfo", "BillboardGui" },
	{ "ReplicatedStorage.Assets.Items.ConstructionInfo", "BillboardGui" },
	{ "ReplicatedStorage.Assets.Items.SpeechBubble", "BillboardGui" },
	{ "ReplicatedStorage.Assets.Items.RareVFX" },
	{ "ReplicatedStorage.Assets.Items.LegendaryVFX" },
	{ "ReplicatedStorage.shared", "Folder" },
	{ "ClientRoot.bootstrap.HudBootstrap", "ModuleScript" },
	{ "ClientRoot.controllers.intro.IntroController", "ModuleScript" },
	{ "ClientRoot.controllers.intro.IntroController.Camera", "ModuleScript" },
	{ "ClientRoot.controllers.intro.IntroController.Presentation", "ModuleScript" },
	{ "ReplicatedStorage.shared.Network", "ModuleScript" },
	{ "ReplicatedStorage.shared.UIEffects", "ModuleScript" },
	{ "ClientRoot.controllers.placement.ToolsModule", "ModuleScript" },
	{ "ReplicatedStorage.Assets.Shop.PurchaseFrame", "Frame" },
	{ "ReplicatedStorage.Assets.Shop.ItemTemplate", "Frame" },
	{ "ReplicatedStorage.Assets.TutorialBeamAnchor" },
	{ "ReplicatedStorage.Assets.BeamTemplate", "Beam" },
	{ "ReplicatedStorage.Assets.ArrowsGUI" },
	{ "ReplicatedStorage.Assets.BaseSelection" },
	{ "ReplicatedStorage.Assets.SparklesGold" },
	{ "ReplicatedStorage.Assets.SparklesBlue" },
	{ "ReplicatedStorage.Assets.SparklesPink" },
	{ "ReplicatedStorage.Assets.WeatherTemplate", "GuiObject" },
	{ "ReplicatedStorage.Assets.IncomeBoostTemp", "GuiObject" },
	{ "ReplicatedStorage.Assets.PopulationBoostTemp", "GuiObject" },
	{ "ReplicatedStorage.Assets.BuildingTemp", "GuiObject" },
	{ "ReplicatedStorage.TopbarPlus.Icon", "ModuleScript" },
	{ "ReplicatedStorage.Assets.Highlight", "Highlight" },
	{ "ServerStorage.Buildings" },
	{ "Workspace.Map.Interactives.BuyArea.Model.Prompt.ShopPrompt", "ProximityPrompt" },
	{ "ReplicatedStorage.Assets.Constructions" },
	{ "ReplicatedStorage.Assets.CarTemplates" },
	{ "ReplicatedStorage.Assets.Trains.Train", "Model" },
	{ "ReplicatedStorage.Assets.Expansion.Locked" },
	{ "ReplicatedStorage.Assets.Expansion.Expansion.ExpansionPrompt" },
	{ "ServerStorage.PlotTemplate" },
	{ "ServerStorage.Civilian", "Model" },
	{ "ServerScriptService.server.systems.world.CivilianSystem", "ModuleScript" },
	{ "Workspace.Plots" },
	{ "Workspace.Map.Enviorment.RoadSystem" },
	{ "Workspace.Map.Enviorment.TrainSystem" },
	{ "StarterGui.Tutorial", "ScreenGui" },
	{ "StarterGui.Tutorial.IntroFrame.Play", "GuiButton" },
	{ "StarterGui.Tutorial.Loading.LoadingFrame.FillBar", "GuiObject" },
	{ "Workspace.Map.SpawnCam", "BasePart" },
	{ "StarterGui.HUD", "ScreenGui" },
	{ "StarterGui.HUD.Frames" },
	{ "StarterGui.HUD.Buttons" },
	{ "StarterGui.HUD.CashDisplay" },
	{ "StarterGui.HUD.FriendBoost" },
	{ "StarterGui.HUD.NotificationCenter.Template" },
	{ "StarterGui.HUD.TutorialHandler.StageOne" },
	{ "StarterGui.HUD.TutorialHandler.StageTwo" },
	{ "StarterGui.HUD.TutorialQuests" },
	{ "StarterGui.HUD.MobilePlacement" },
	{ "SoundService.SFX" },
}

local starterScripts = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local client = starterScripts and (starterScripts:FindFirstChild("client") or starterScripts)
local issues = 0
local function resolve(path)
	local current = game
	local names = string.split(path, ".")
	if names[1] == "ClientRoot" then
		current = client
		table.remove(names, 1)
	end
	for _, name in names do
		current = current and current:FindFirstChild(name)
	end
	return current
end
for _, item in required do
	local found = resolve(item[1])
	if not found or (item[2] and not found:IsA(item[2])) then
		issues += 1
		warn("[MyCity] Missing/wrong class:", item[1], item[2] or "Instance")
	end
end

local settings = resolve("StarterGui.HUD.Frames.Settings")
if settings then
	for _, name in { "MusicToggle", "SFXToggle", "Holding", "CodeStatus", "CodeSubmit", "TextBox" } do
		if not settings:FindFirstChild(name, true) then
			issues += 1
			warn("[MyCity] Missing Settings control:", name)
		end
	end
	local holding = settings:FindFirstChild("Holding", true)
	for _, name in { "RedGradient", "GreenGradient" } do
		if not holding or not holding:FindFirstChild(name) then
			issues += 1
			warn("[MyCity] Missing Settings.Holding gradient:", name)
		end
	end
end
local buttons = resolve("StarterGui.HUD.Buttons")
local builders = buttons and buttons:FindFirstChild("Builders", true)
if not builders or not builders:FindFirstChild("Count") then
	issues += 1
	warn("[MyCity] Missing HUD.Buttons.Builders.Count")
end

local civilian = game:GetService("ServerStorage"):FindFirstChild("Civilian")
if civilian then
	local humanoid = civilian:FindFirstChildWhichIsA("Humanoid", true)
	local root = civilian:FindFirstChild("HumanoidRootPart", true)
	if not civilian.Archivable or not humanoid or not root or not root:IsA("BasePart") then
		issues += 1
		warn("[MyCity] Civilian needs Archivable enabled, a Humanoid and a HumanoidRootPart in its rig")
	end
end

-- Verify every exported source container, including init.luau parent modules.
for _, item in
	{
		{ "ClientRoot.bootstrap.HudBootstrap", "ModuleScript" },
		{ "ClientRoot.controllers.ui.CashFeedback", "ModuleScript" },
		{ "ClientRoot.controllers.placement.BuildingTools", "ModuleScript" },
		{ "ClientRoot.controllers.placement.ExpandHighlight", "ModuleScript" },
		{ "ClientRoot.controllers.placement.ToolsModule", "ModuleScript" },
		{ "ClientRoot.controllers.placement.ToolsModule.Session.Collision", "ModuleScript" },
		{ "ClientRoot.controllers.placement.ToolsModule.Session.Geometry", "ModuleScript" },
		{ "ClientRoot.controllers.placement.ToolsModule.Session.Hud", "ModuleScript" },
		{ "ClientRoot.controllers.placement.ToolsModule.Session", "ModuleScript" },
		{ "ClientRoot.controllers.placement.ToolsModule.Session.Input", "ModuleScript" },
		{ "ClientRoot.controllers.placement.ToolsModule.Session.Lifecycle", "ModuleScript" },
		{ "ClientRoot.controllers.placement.ToolsModule.Session.Placement", "ModuleScript" },
		{ "ClientRoot.controllers.placement.ToolsModule.Session.Preview", "ModuleScript" },
		{ "ClientRoot.controllers.shop.SellController.Display", "ModuleScript" },
		{ "ClientRoot.controllers.shop.SellController.Formatting", "ModuleScript" },
		{ "ClientRoot.controllers.shop.SellController", "ModuleScript" },
		{ "ClientRoot.controllers.shop.SellController.Lifecycle", "ModuleScript" },
		{ "ClientRoot.controllers.shop.SellController.PreviewCleanup", "ModuleScript" },
		{ "ClientRoot.controllers.shop.SellController.RemoteBindings", "ModuleScript" },
		{ "ClientRoot.controllers.shop.ShopController.Formatting", "ModuleScript" },
		{ "ClientRoot.controllers.shop.ShopController", "ModuleScript" },
		{ "ClientRoot.controllers.shop.ShopController.Lifecycle", "ModuleScript" },
		{ "ClientRoot.controllers.shop.ShopController.PurchasePanel", "ModuleScript" },
		{ "ClientRoot.controllers.shop.ShopController.StockDisplay", "ModuleScript" },
		{ "ClientRoot.controllers.social.ChatTags", "ModuleScript" },
		{ "ClientRoot.controllers.social.FriendsBoost", "ModuleScript" },
		{ "ClientRoot.controllers.social.LikeSystem", "ModuleScript" },
		{ "ClientRoot.controllers.systems.ResetButton", "ModuleScript" },
		{ "ClientRoot.controllers.tutorial.TutorialController.Camera", "ModuleScript" },
		{ "ClientRoot.controllers.tutorial.TutorialController.Guidance", "ModuleScript" },
		{ "ClientRoot.controllers.tutorial.TutorialController.Highlights", "ModuleScript" },
		{ "ClientRoot.controllers.tutorial.TutorialController", "ModuleScript" },
		{ "ClientRoot.controllers.tutorial.TutorialController.Lifecycle", "ModuleScript" },
		{ "ClientRoot.controllers.tutorial.TutorialController.Stages", "ModuleScript" },
		{ "ClientRoot.controllers.tutorial.TutorialController.Subtitles", "ModuleScript" },
		{ "ClientRoot.controllers.ui.NotificationController", "ModuleScript" },
		{ "ClientRoot.controllers.ui.NotificationController.Layout", "ModuleScript" },
		{ "ClientRoot.controllers.ui.NotificationController.Lifecycle", "ModuleScript" },
		{ "ClientRoot.controllers.ui.NotificationController.Queue", "ModuleScript" },
		{ "ClientRoot.controllers.ui.NotificationController.RemoteBindings", "ModuleScript" },
		{ "ClientRoot.controllers.ui.ProximityPromptController", "ModuleScript" },
		{ "ClientRoot.controllers.ui.ProximityPromptController.Lifecycle", "ModuleScript" },
		{ "ClientRoot.controllers.ui.ProximityPromptController.Progress", "ModuleScript" },
		{ "ClientRoot.controllers.ui.ProximityPromptController.Renderer", "ModuleScript" },
		{ "ClientRoot.controllers.ui.ProximityPromptController.ScreenGui", "ModuleScript" },
		{ "ClientRoot.controllers.ui.UIController.BuildingActions", "ModuleScript" },
		{ "ClientRoot.controllers.ui.UIController.Buttons", "ModuleScript" },
		{ "ClientRoot.controllers.ui.UIController.CityPrompts", "ModuleScript" },
		{ "ClientRoot.controllers.ui.UIController.DailyRewards", "ModuleScript" },
		{ "ClientRoot.controllers.ui.UIController.Displays", "ModuleScript" },
		{ "ClientRoot.controllers.ui.UIController", "ModuleScript" },
		{ "ClientRoot.controllers.ui.UIController.CashDisplay", "ModuleScript" },
		{ "ClientRoot.controllers.ui.UIController.Lifecycle", "ModuleScript" },
		{ "ClientRoot.controllers.ui.UIController.Navigation", "ModuleScript" },
		{ "ClientRoot.controllers.ui.UIController.Rebirth", "ModuleScript" },
		{ "ClientRoot.controllers.ui.UIController.RemoteBindings", "ModuleScript" },
		{ "ClientRoot.controllers.ui.UIController.remotes.BuildingInfo", "ModuleScript" },
		{ "ClientRoot.controllers.ui.UIController.remotes.CityName", "ModuleScript" },
		{ "ClientRoot.controllers.ui.UIController.remotes.Menus", "ModuleScript" },
		{ "ClientRoot.controllers.ui.UIController.remotes.PromptLabels", "ModuleScript" },
		{ "ClientRoot.controllers.ui.UIController.remotes.Quests", "ModuleScript" },
		{ "ClientRoot.controllers.ui.UIController.remotes.Weather", "ModuleScript" },
		{ "ClientRoot.Initialization", "LocalScript" },
		{ "ServerScriptService.server.bootstrap.PlayerLifecycle", "ModuleScript" },
		{ "ServerScriptService.server.bootstrap.ServerBootstrap", "ModuleScript" },
		{ "ServerScriptService.server.config.BuildingConfig.Decorations", "ModuleScript" },
		{ "ServerScriptService.server.config.BuildingConfig.Epic", "ModuleScript" },
		{ "ServerScriptService.server.config.BuildingConfig", "ModuleScript" },
		{ "ServerScriptService.server.config.BuildingConfig.Legendary", "ModuleScript" },
		{ "ServerScriptService.server.config.BuildingConfig.Mythic", "ModuleScript" },
		{ "ServerScriptService.server.config.BuildingConfig.Population", "ModuleScript" },
		{ "ServerScriptService.server.config.BuildingConfig.Rare", "ModuleScript" },
		{ "ServerScriptService.server.config.BuildingConfig.Starter", "ModuleScript" },
		{ "ServerScriptService.server.config.BuildingConfig.Uncommon", "ModuleScript" },
		{ "ServerScriptService.server.config.SpawnConfig", "ModuleScript" },
		{ "ServerScriptService.server.Main", "Script" },
		{ "ServerScriptService.server.maintenance.DeleteDatastore", "ModuleScript" },
		{ "ServerScriptService.server.persistence.FunnelAnalytics", "ModuleScript" },
		{ "ServerScriptService.server.persistence.PlayerDataModule", "ModuleScript" },
		{ "ServerScriptService.server.persistence.PlayerDataModule.DataSchema", "ModuleScript" },
		{ "ServerScriptService.server.persistence.PlayerDataModule.ProfileCodec", "ModuleScript" },
		{ "ServerScriptService.server.persistence.PlayerDataModule.SchemaMigration", "ModuleScript" },
		{ "ServerScriptService.server.persistence.PlayerDataModule.SessionStore", "ModuleScript" },
		{ "ServerScriptService.server.services.CodeSystem", "ModuleScript" },
		{ "ServerScriptService.server.services.MarketPlaceHandler.GrantActions", "ModuleScript" },
		{ "ServerScriptService.server.services.MarketPlaceHandler.GrantPlan", "ModuleScript" },
		{ "ServerScriptService.server.services.MarketPlaceHandler", "ModuleScript" },
		{ "ServerScriptService.server.services.MarketPlaceHandler.ProductConfig", "ModuleScript" },
		{ "ServerScriptService.server.services.MarketPlaceHandler.PurchaseIntents", "ModuleScript" },
		{ "ServerScriptService.server.services.MarketPlaceHandler.ReceiptLedger", "ModuleScript" },
		{ "ServerScriptService.server.services.MarketPlaceHandler.TransferService", "ModuleScript" },
		{ "ServerScriptService.server.services.MarketPlaceHandler.WebHook", "ModuleScript" },
		{ "ServerScriptService.server.services.ToolFactory", "ModuleScript" },
		{ "ServerScriptService.server.services.HeldBuildingVisual", "ModuleScript" },
		{ "ServerScriptService.server.services.ToolSerialization", "ModuleScript" },
		{ "ServerScriptService.server.services.ToolSetup", "ModuleScript" },
		{ "ServerScriptService.server.systems.building.BuildingSystem.BuildingConfig", "ModuleScript" },
		{ "ServerScriptService.server.systems.building.BuildingSystem.BuildingData", "ModuleScript" },
		{ "ServerScriptService.server.systems.building.BuildingSystem.BuildingPlacement", "ModuleScript" },
		{ "ServerScriptService.server.systems.building.BuildingSystem.BuildingPrompts", "ModuleScript" },
		{ "ServerScriptService.server.systems.building.BuildingSystem.BuildingStats.Aggregation", "ModuleScript" },
		{ "ServerScriptService.server.systems.building.BuildingSystem.BuildingStats.Happiness", "ModuleScript" },
		{ "ServerScriptService.server.systems.building.BuildingSystem.BuildingStats.Health", "ModuleScript" },
		{ "ServerScriptService.server.systems.building.BuildingSystem.BuildingStats", "ModuleScript" },
		{ "ServerScriptService.server.systems.building.BuildingSystem.BuildingStats.Penalties", "ModuleScript" },
		{ "ServerScriptService.server.systems.building.BuildingSystem.BuildingStats.Safety", "ModuleScript" },
		{ "ServerScriptService.server.systems.building.BuildingSystem.BuildingStealing", "ModuleScript" },
		{ "ServerScriptService.server.systems.building.BuildingSystem.BuildingThoughts", "ModuleScript" },
		{ "ServerScriptService.server.systems.building.BuildingSystem.BuildingThoughts.Lifecycle", "ModuleScript" },
		{ "ServerScriptService.server.systems.building.BuildingSystem.BuildingThoughts.Presentation", "ModuleScript" },
		{ "ServerScriptService.server.systems.building.BuildingSystem.BuildingThoughts.Selection", "ModuleScript" },
		{ "ServerScriptService.server.systems.building.BuildingSystem.BuildingValidation", "ModuleScript" },
		{ "ServerScriptService.server.systems.building.BuildingSystem.BuildingXP.Awards", "ModuleScript" },
		{ "ServerScriptService.server.systems.building.BuildingSystem.BuildingXP.Effects", "ModuleScript" },
		{ "ServerScriptService.server.systems.building.BuildingSystem.BuildingXP", "ModuleScript" },
		{ "ServerScriptService.server.systems.building.BuildingSystem.BuildingXP.Lifecycle", "ModuleScript" },
		{ "ServerScriptService.server.systems.building.BuildingSystem.BuildingXP.Progression", "ModuleScript" },
		{ "ServerScriptService.server.systems.building.BuildingSystem", "ModuleScript" },
		{ "ServerScriptService.server.systems.building.BuildingSystem.PlacementCommit", "ModuleScript" },
		{ "ServerScriptService.server.systems.construction.ConstructionSystem.ConstructionBuilder", "ModuleScript" },
		{
			"ServerScriptService.server.systems.construction.ConstructionSystem.ConstructionData.Coordinates",
			"ModuleScript",
		},
		{ "ServerScriptService.server.systems.construction.ConstructionSystem.ConstructionData", "ModuleScript" },
		{
			"ServerScriptService.server.systems.construction.ConstructionSystem.ConstructionData.Lifecycle",
			"ModuleScript",
		},
		{
			"ServerScriptService.server.systems.construction.ConstructionSystem.ConstructionData.Restoration",
			"ModuleScript",
		},
		{
			"ServerScriptService.server.systems.construction.ConstructionSystem.ConstructionData.Serialization",
			"ModuleScript",
		},
		{ "ServerScriptService.server.systems.construction.ConstructionSystem.ConstructionSkipping", "ModuleScript" },
		{
			"ServerScriptService.server.systems.construction.ConstructionSystem.ConstructionTimer.Completion",
			"ModuleScript",
		},
		{ "ServerScriptService.server.systems.construction.ConstructionSystem.ConstructionTimer", "ModuleScript" },
		{
			"ServerScriptService.server.systems.construction.ConstructionSystem.ConstructionTimer.Lifecycle",
			"ModuleScript",
		},
		{
			"ServerScriptService.server.systems.construction.ConstructionSystem.ConstructionTimer.Timing",
			"ModuleScript",
		},
		{
			"ServerScriptService.server.systems.construction.ConstructionSystem.ConstructionTimer.Visuals",
			"ModuleScript",
		},
		{ "ServerScriptService.server.systems.construction.ConstructionSystem.ConstructionVFX", "ModuleScript" },
		{ "ServerScriptService.server.systems.construction.ConstructionSystem", "ModuleScript" },
		{ "ServerScriptService.server.systems.economy.BuildingEconomy", "ModuleScript" },
		{ "ServerScriptService.server.systems.economy.IncomeSystem.BuildingAlerts", "ModuleScript" },
		{ "ServerScriptService.server.systems.economy.IncomeSystem.Calculation", "ModuleScript" },
		{ "ServerScriptService.server.systems.economy.IncomeSystem.Collection", "ModuleScript" },
		{ "ServerScriptService.server.systems.economy.IncomeSystem", "ModuleScript" },
		{ "ServerScriptService.server.systems.economy.IncomeSystem.Lifecycle", "ModuleScript" },
		{ "ServerScriptService.server.systems.economy.IncomeSystem.PlotDisplays", "ModuleScript" },
		{ "ServerScriptService.server.systems.economy.InventorySystem", "ModuleScript" },
		{ "ServerScriptService.server.systems.economy.SellSystem.Display", "ModuleScript" },
		{ "ServerScriptService.server.systems.economy.SellSystem", "ModuleScript" },
		{ "ServerScriptService.server.systems.economy.SellSystem.PromptBinding", "ModuleScript" },
		{ "ServerScriptService.server.systems.economy.SellSystem.Lifecycle", "ModuleScript" },
		{ "ServerScriptService.server.systems.economy.SellSystem.Sale", "ModuleScript" },
		{ "ServerScriptService.server.systems.economy.SellSystem.Valuation", "ModuleScript" },
		{ "ServerScriptService.server.systems.economy.ShopSystem", "ModuleScript" },
		{ "ServerScriptService.server.systems.economy.ShopSystem.Lifecycle", "ModuleScript" },
		{ "ServerScriptService.server.systems.economy.ShopSystem.PlayerView", "ModuleScript" },
		{ "ServerScriptService.server.systems.economy.ShopSystem.Purchases", "ModuleScript" },
		{ "ServerScriptService.server.systems.economy.ShopSystem.Refresh", "ModuleScript" },
		{ "ServerScriptService.server.systems.economy.ShopSystem.Stock", "ModuleScript" },
		{ "ServerScriptService.server.systems.progression.BadgeModule", "ModuleScript" },
		{ "ServerScriptService.server.systems.progression.DailyRewards", "ModuleScript" },
		{ "ServerScriptService.server.systems.progression.PlayerRewards", "ModuleScript" },
		{ "ServerScriptService.server.systems.progression.PostTutorialQuest", "ModuleScript" },
		{ "ServerScriptService.server.systems.progression.PostTutorialQuest.Lifecycle", "ModuleScript" },
		{ "ServerScriptService.server.systems.progression.PostTutorialQuest.Objectives", "ModuleScript" },
		{ "ServerScriptService.server.systems.progression.PostTutorialQuest.Progression", "ModuleScript" },
		{ "ServerScriptService.server.systems.progression.PostTutorialQuest.State", "ModuleScript" },
		{ "ServerScriptService.server.systems.progression.RebirthConfig", "ModuleScript" },
		{ "ServerScriptService.server.systems.progression.RebirthSystem.Display", "ModuleScript" },
		{ "ServerScriptService.server.systems.progression.RebirthSystem", "ModuleScript" },
		{ "ServerScriptService.server.systems.progression.RebirthSystem.Lifecycle", "ModuleScript" },
		{ "ServerScriptService.server.systems.progression.RebirthSystem.Rebirth", "ModuleScript" },
		{ "ServerScriptService.server.systems.progression.RebirthSystem.Reset", "ModuleScript" },
		{ "ServerScriptService.server.systems.progression.TutorialSystem", "ModuleScript" },
		{ "ServerScriptService.server.config.TutorialConfig", "ModuleScript" },
		{ "ServerScriptService.server.systems.security.RequestGuard", "ModuleScript" },
		{ "ServerScriptService.server.systems.social.CityRating", "ModuleScript" },
		{ "ServerScriptService.server.systems.social.FriendBoost", "ModuleScript" },
		{ "ServerScriptService.server.systems.world.CityNameSystem", "ModuleScript" },
		{ "ServerScriptService.server.systems.world.ExpansionSystem", "ModuleScript" },
		{ "ServerScriptService.server.systems.world.HighwayTrafficSystem", "ModuleScript" },
		{ "ServerScriptService.server.systems.world.PlotManager.Assignment", "ModuleScript" },
		{ "ServerScriptService.server.systems.world.PlotManager", "ModuleScript" },
		{ "ServerScriptService.server.systems.world.PlotManager.Lifecycle", "ModuleScript" },
		{ "ServerScriptService.server.systems.world.PlotManager.Relocation", "ModuleScript" },
		{ "ServerScriptService.server.systems.world.PlotManager.Reset", "ModuleScript" },
		{ "ServerScriptService.server.systems.world.PlotManager.Scenery", "ModuleScript" },
		{ "ServerScriptService.server.systems.world.TrainSystem", "ModuleScript" },
		{ "ServerScriptService.server.systems.world.VFX", "ModuleScript" },
		{ "ServerScriptService.server.systems.world.WeatherSystem", "ModuleScript" },
		{ "ReplicatedStorage.shared.Network", "ModuleScript" },
		{ "ReplicatedStorage.shared.UIEffects", "ModuleScript" },
		{ "ReplicatedStorage.shared.util.ConnectionScope", "ModuleScript" },
		{ "ReplicatedStorage.shared.util.NumberCounter", "ModuleScript" },
	}
do
	local found = resolve(item[1])
	if not found or found.ClassName ~= item[2] then
		issues += 1
		warn("[MyCity] Source container missing/wrong class:", item[1], item[2])
	end
end

local defaultPrompt = resolve("ReplicatedStorage.Assets.Default")
if not defaultPrompt then
	issues += 1
	warn("[MyCity] ReplicatedStorage.Assets.Default prompt template is missing")
end
local main = resolve("ServerScriptService.server.Main")
if main then
	local ok, source = pcall(function()
		return main.Source
	end)
	if ok and not source:find("bootstrap.ServerBootstrap", 1, true) then
		issues += 1
		warn("[MyCity] Main still has old source; sync src/server/Main.legacy.luau and all server modules")
	end
end

local hud = resolve("StarterGui.HUD")
if hud and hud:IsA("ScreenGui") and hud.ResetOnSpawn then
	warn("[MyCity] HUD resets on respawn; controller teardown/rebinding needs a play test")
end
local roots = { resolve("ServerScriptService.server"), resolve("ReplicatedStorage.shared"), client }
local outside, stale, unreadable = 0, 0, 0
for _, instance in game:GetDescendants() do
	if instance.Name == "ItemTemplate" or instance.Name == "PurchaseFrame" then
		print("[MyCity] Shop template candidate:", instance:GetFullName(), instance.ClassName)
	end
	if instance:IsA("Sound") and instance.SoundId:find("6525690145", 1, true) then
		print("[MyCity] Unapproved sound location:", instance:GetFullName(), instance.SoundId)
	end
	if instance:IsA("LuaSourceContainer") then
		local archive = game:GetService("ServerStorage"):FindFirstChild("MyCityMigrationArchive")
		if archive and instance:IsDescendantOf(archive) then
			continue
		end
		local mapped = false
		for _, root in pairs(roots) do
			if root and instance:IsDescendantOf(root) then
				mapped = true
			end
		end
		if not mapped then
			outside += 1
			print("[MyCity] Code outside sync roots (review/export):", instance:GetFullName())
		end
		local ok, source = pcall(function()
			return instance.Source
		end)
		if not ok then
			unreadable += 1
		elseif
			source:find("ReplicatedStorage.Client", 1, true)
			or source:find('WaitForChild("Client")', 1, true)
			or source:find("ServerScriptService.Main", 1, true)
			or source:find("ReplicatedStorage.Expansion", 1, true)
			or source:find("ReplicatedStorage.Modules.UIEffects", 1, true)
			or source:find("ReplicatedStorage.shared.UIController", 1, true)
			or source:find("ReplicatedStorage.shared.ToolsModule", 1, true)
		then
			stale += 1
			warn("[MyCity] Possible old path (includes comments):", instance:GetFullName())
		end
	end
end
print(
	string.format(
		"[MyCity] %d required-path issues; %d scripts outside roots; %d old-path candidates; %d unreadable sources",
		issues,
		outside,
		stale,
		unreadable
	)
)
print("[MyCity] Read-only hierarchy audit complete; no gameplay or saving was executed.")

print("[MyCity] Events/Functions are created by shared.Network on server startup; absence in Edit mode is expected.")

print(
	"[MyCity] Data and leaderstats are created on Players by DataSchema at runtime; PlayerDataModule needs no template folders."
)

local legacyIntro = resolve("StarterGui.Tutorial.Handler")
if legacyIntro and legacyIntro:IsA("BaseScript") and legacyIntro.Enabled then
	warn("[MyCity] Remove StarterGui.Tutorial.Handler after syncing IntroController; two intro owners will conflict.")
end
