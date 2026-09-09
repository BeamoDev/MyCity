# Applying the MyCity refactor in Studio

The source is now organized like the Wordie pattern: one server entry, one client entry, and feature folders with child modules. The authored models and GUI templates also need to follow the moved modules. The migration has been generated locally; it has not been run in your place.

## Edit-mode migration

1. Save a backup copy of the place. Stop Play and pause Script Sync before applying the renamed/deleted source files.
2. Paste `tools/migrate_studio.luau` into Studio's Command Bar in **Edit mode** and run it once. It preflights destination classes and child collisions, moves existing script-owned templates, and disables/archives replaced old scripts under `ServerStorage.MyCityMigrationArchive`. It adds undo waypoints. If it reports a collision, preserve both copies and reconcile the named objects before rerunning.
3. Resume Script Sync and sync the complete `src` tree, including additions and removals. A folder with `init.luau` must be a ModuleScript with children. Do not Play between migration and complete sync: newly created module containers initially have no source.
4. Verify `src/server -> ServerScriptService.server`, `src/shared -> ReplicatedStorage.shared`, and `src/client -> StarterPlayer.StarterPlayerScripts.client` (or directly StarterPlayerScripts).
5. Paste/run `tools/audit_studio.luau` in Edit mode. Resolve every required/source-path error. Review scripts listed outside the sync roots, especially authored Tool/HUD/loading scripts, and export any gameplay code still absent locally. The archive is excluded from that list.
6. Confirm only `server.Main` and client `Initialization` run automatically. Items now belongs at `ReplicatedStorage.Assets.Items`; PlayerDataModule no longer needs Data/leaderstats template folders; DataSchema creates them on each player at runtime. Keep the archived scripts disabled.
7. Start a local test with Events and Functions absent from ReplicatedStorage. Network.start creates all 80 RemoteEvents and 2 RemoteFunctions in their existing feature folders before gameplay starts. A wrong class fails clearly. Do not manually recreate the old folders.

The migration preserves authored templates. It does not create missing buildings, GUI artwork, TopbarPlus, plot models, sounds, or descendants that were never exported. The audit identifies expected objects, but scripts hidden inside those assets still need review.

## Required play checks

- New player: load, Bank tutorial, income collection, buy/place/finish Shack, quest handoff.
- Returning player: inventory, equipped tools, plot orientation (including Plot5-8), nested data, ongoing and offline-completed construction, paid flags, city name and expansion tiles.
- Multiplayer: place/move/collect/delete only owned buildings; reject foreign tools and out-of-bounds/overlapping placement; simultaneous purchases, rebirth, quest completion and leaving.
- Respawn/replace HUD: no duplicate button handlers, orphaned previews, prompts or tutorial camera callbacks; inventory restored once; desktop, touch and controller placement.
- Purchases in a dedicated test environment: repeat the same receipt, disconnect/rejoin between grant steps, failed saves, shop target selection, skips/Build All, cross-player transfers and preserved paid items after rebirth.
- Data failures: failed reads refuse entry; a second server cannot own the same new-format profile; expired/stale saves are refused. Check save budgets under realistic concurrency.
- Long session: building XP, income rates and displayed values, friend bonuses, prompt cleanup, traffic/trains and plot reuse.

## Release and rollback constraints

`Data_1` is deliberately retained. Its record now includes a session lease, recursive folder encoding and purchase/code markers. This is a data-writing change, not just a file rename.

Validate in an isolated test place/store before release. At rollout, drain/restart servers running the previous save implementation: old SetAsync writers do not recognize the new lease. Restoring only the old source is not a safe rollback after new profiles have been written; use a compatible reader/writer or a reviewed data restoration plan.

Unresolved old purchases with no saved target and steals whose owner is on another live server can remain pending. Do not force these to PurchaseGranted. See BUG_AUDIT.md for the exact limits. No live servers were restarted, data stores modified, or place published by this refactor.

## Follow-up: Default, GUI FX errors, and additional server modules

- Default now belongs at `ReplicatedStorage.Assets.Default`. The renderer reads that path. Themed prompt overrides remain under ProximityPromptController.
- Eight more server modules now use init.luau with feature children. Their Roblox ModuleScript paths stay the same; sync all new children and remove the replaced flat source files from your mapping.
- After the full sync, pause Script Sync and run `tools/repair_gui_paths.luau` in Studio's Edit-mode Command Bar. This updates the FX scripts embedded in StarterGui and Assets that still use Modules. It preserves the existing FX behavior and uses [ScriptEditorService.UpdateSourceAsync](https://create.roblox.com/docs/reference/engine/classes/ScriptEditorService#UpdateSourceAsync) to update open editor buffers too. Resume sync, then start a new Play session.
- Confirm `[MyCity] Modular server bootstrap v2` appears. The uploaded log's `[DATA SERVER]` output came from old source, so the earlier server refactor was not running in that test. The audit now flags this old code as well as missing modules.
- The denied sound ID `6525690145` does not occur in exported source. The repair tool lists authored Sound instances using it; its permission/approval issue still needs to be resolved in Roblox or by replacing that authored SoundId with an approved asset.

## Latest: no data template folders

Sync `server/persistence/PlayerDataModule/DataSchema.luau` and the updated codec/migration/loader. Do not create Data or leaderstats inside PlayerDataModule. They are generated under each Player during successful loading. Existing unused template children can remain until you remove them; the code no longer reads them.

Data_1 and saved values are retained. New fields receive code defaults, and old tutorial flag locations migrate before defaults are applied. New-player starting cash is defined as 500 in DataSchema. No live data reset or namespace change is required.

The 22:38 log confirms the new bootstrap is running. Its generic restoration kick hid the exception; updated source prints `[Data] Restore failed for` with the actual cause if any other issue remains. Missing-data quest/rebirth waits and plot-cleanup errors are fixed. After syncing, run the GUI FX repair in Edit mode and start a fresh test.

## Fix for LastUpdate restore errors

Sync the updated `server/persistence/PlayerDataModule/DataSchema.luau` and `PlayerDataModule/init.luau`, then stop/start Play. Schema 4 converts old scalar representations before loading and saving. A blank/invalid LastUpdate uses the current timestamp; a valid saved timestamp is retained as an IntValue. Data_1, player keys, saved city collections and receipt history stay in place. Do not delete your save to fix this error.

## Sell-area prompt moved into the backend

Sync SellSystem/init.luau, Lifecycle.luau and PromptBinding.luau, then delete the old Script inside Workspace.Map.Interactives.SellArea.Part.ShopPrompt. Keep ShopPrompt itself. The normal server bootstrap now connects the prompt and preserves the tutorial restriction.

## Cash label script moved into the client modules

Sync UIController/init.luau, Displays.luau, CashDisplay.luau and Lifecycle.luau. Then remove the old LocalScript (Handle) under StarterGui.HUD.CashDisplay; keep the CashDisplay label. The client bootstrap initializes its display immediately and updates it when Cash changes, with teardown when the HUD is replaced.

## Animated cash balance

Also sync the new `shared/util/NumberCounter.luau` and `client/controllers/ui/CashFeedback.luau`, plus updated UIController/CashDisplay.luau and Lifecycle.luau. The new paths are ModuleScripts; CashFeedback is beside UIController, and NumberCounter is inside ReplicatedStorage.shared.util. No asset migration is needed.

Starting balance is immediate; gains/spending animate with floating green/red amounts. The original label's formatting/layout stays authored. Keep its old LocalScript removed so it cannot overwrite the animated number. In Studio, test rapid earning/spending, a large balance, phone/tablet layouts and HUD replacement; check floating text is readable and not clipped by authored ancestors.

## Owner tutorial replay

Sync the full updated src/server and src/client trees, including new server/config/TutorialConfig.luau, PlayerLifecycle, TutorialSystem, the building/construction milestone callers, ShopSystem/Purchases, FunnelAnalytics and TutorialController children. Owner ID 1790165114 replays from welcome on each join while keeping the saved city and balance. This is enabled for MyCity; no Word Hunt files were changed. Set TutorialConfig.ReplayEveryJoin=false to disable later.

Verify two owner joins, a normal completed player's join, HUD replacement, instant/offline construction completion and touch Start buttons. Existing city contents remain, so keep room for tutorial Bank/Shack placements. Tutorial purchases still charge normal cash and newly placed buildings save normally. No data reset or namespace change is required. The client advances from replicated server stages and waits for server confirmation of completion.

## Confirmed shop template relocation

PurchaseFrame and ItemTemplate now belong directly under ReplicatedStorage.Assets.Shop, as confirmed by the user's Explorer screenshot. Sync client/controllers/shop/ShopController/Lifecycle.luau. It waits for both replicated templates before connecting shop updates. Keep the authored frames in Assets.Shop; they no longer need to be under ShopController. Studio audit checks the new paths.

## City-preserving rebirth and two leaderboard stats

Sync all updated src/server and src/client files together, then restart Play. Schema 5 moves Population from leaderstats into Data.PlayerInfo.Population while keeping saved values. The leaderboard displays Cash and Rebirths. Population still drives building unlocks, quests, income bonuses and rebirth requirements. No Data_1 reset or key change is needed. Any unexported Studio scripts reading leaderstats.Population must also use the new path.

Rebirth retains buildings, active construction, tools/inventory and land. Cash keeps its existing reset formula (15,000 after the first rebirth). The confirmation explains this. Population requirements continue growing after level 50 to prevent the retained city from granting endless rebirths at a fixed threshold. Verify a populated city's rebirth and rejoin, the two-column player list, shop/quest unlock updates, confirmation text and owner tutorial replay. As with other schema changes, deploy compatible code together and avoid older writers/readers.

## ToolBuildings removed

Sync server/services/ToolFactory.luau AND new server/services/HeldBuildingVisual.luau, then restart Play. ToolFactory no longer waits for Assets.ToolBuildings or clones Assets.Tool. It creates the Tool and metadata in code, and creates a held miniature from Assets.Buildings.<buildingName>. Keep normal building models; no replacement ToolBuildings folder is needed. The old Assets.Tool may remain unused. Saved inventory IDs, levels, XP, mutations and paid flags retain their existing serialization. Verify equip/unequip, miniature size/orientation, placement and inventory restore in Studio.

## Tutorial.Handler integrated into the client

Sync updated client/bootstrap/HudBootstrap.luau and the new client/controllers/intro/IntroController directory. IntroController is a ModuleScript with Camera and Presentation child ModuleScripts. Then delete ONLY StarterGui.Tutorial.Handler (the old LocalScript), keeping Tutorial, IntroFrame, Loading and all UI children. Stop/start Play so existing PlayerGui clones also use the new setup.

The source no longer reads ReplicatedStorage.Client.Init. HudBootstrap remains the only client-system initializer. All players see the authored Play/reveal/orbit/loading UI, including owner tutorial replays. Play appears before city readiness; completed loading cannot be missed by clicking Play late. Tutorial begins after Play and readiness. Successful intro completion explicitly returns the camera to Custom and the current Humanoid. After one completed intro it will not repeat on HUD/character replacement. Verify both flows and interruption/respawn in Studio. The audit flags a leftover enabled Handler and checks the intro's authored paths.


## Latest: intro and tutorial placement regression fixes

Sync the current client and server source together and restart Play. Keep StarterGui.Tutorial and all its authored UI children; its old Handler must remain removed. IntroController now shows the Play/map orbit/blur intro even for the owner's forced tutorial replay. It starts before data-dependent HUD setup. No new authored assets are needed: existing Workspace.Map.SpawnCam is used, and an intro-only BlurEffect is created if Lighting.Blur is absent.

CashDisplay/FriendBoost remain hidden during tutorial. Bank/Shack guidance clears on unequip/cancel, and placement now survives repeated equips and late replies. Existing cities remain intact; use an unoccupied part of owned land for the replay's new placements. Sync server BuildingValidation/BuildingPlacement/PlacementCommit and ConstructionSystem with the placement-client updates so both sides use the same Base/PrimaryPart transform contract.


## Civilian residents

Keep ServerStorage.Civilian as an archivable Model containing a rigged Humanoid and HumanoidRootPart. Sync server/bootstrap/ServerBootstrap and the full new server/systems/world/CivilianSystem directory (init plus Config/Geometry/Rig/Animations/Movement). No LocalScript, remote or saved-data migration is required.

At runtime each restored city gets a CivilianNPCs folder. Completed buildings increase its target count, up to eight per city; the server cap is 24. Actors spawn gradually on free owned land, stroll beside buildings and pause like KingdomWars villagers, using the same rig-specific walk animations. Deleting/moving buildings out of a city reduces the target; leaving/resetting/reassigning a plot removes its actors. Full/blocked plots may have fewer visible actors than their budget. TargetCount and VisibleCount attributes show both values.

Studio check: join a city with open walkways, watch idle/walk animation and grounding, place/remove buildings, and test a second player leaving/rejoining. The authored model scale/joints and actual Roblox navigation are not covered by local mocks. No change is made to the source Civilian model.


## Gameplay review fixes (2026-09-09)

Sync the full client/server source together, especially PostTutorialQuest + UIController/remotes/Quests: UpdateQuest now carries authoritative reward metadata, and AllQuestsDone(true) is a silent completed-state snapshot. No DataStore reset or asset move is needed. Restart Play to replace old handlers. The new tools/audit_commerce_studio.luau is a read-only Command Bar check of all configured product/pass metadata and all catalog building/construction templates. See GAMEPLAY_REVIEW.md for the test matrix and remaining payment/balance concerns.


## Latest user-confirmed hierarchy (2026-09-09)

Sync server, client and shared together. The latest locations supersede earlier tables:

- `ServerStorage.Buildings`: original authoritative building models (with PrimaryPart/Base/Hitbox).
- `Workspace.Plots`: existing authored plots, including PlotSpawn. Keep ServerStorage.PlotTemplate.
- `Workspace.Misc`: the server creates PlayerAnchors, PlayerPreviews and Effects subfolders; no manual creation needed.
- `ReplicatedStorage.Assets.BuildingPreviews`: generated stripped copies for local previews; do not manually move the authoritative templates back into ReplicatedStorage.
- `StarterGui.HUD.NotificationCenter.Template`: keep the authored template, text label (prefer Message), UIListLayout and UIAspectRatioConstraint. NotificationsFrame and StoleAlert are retired.
- `Workspace.Map.Interactives.BuyArea.Model.Prompt.ShopPrompt`: keep the ProximityPrompt, remove its old child Script (already done by the user). New bootstrap.ShopPrompt binds it.
- `StarterGui.Tutorial`: keep IntroFrame.Play, IntroFrame.ImageLabel and Loading.LoadingFrame.FillBar. Keep Workspace.Map.SpawnCam for the orbit. The old Tutorial.Handler remains deleted.

New bootstrap modules EarlyLoading (client), SpawnGuard, WorldRuntime and ShopPrompt (server) must sync as ModuleScripts. Initialization remains the only client auto-entry point. Network now creates Loading.IntroFinished; it releases the server spawn hold only after readiness and client intro/UI setup. The first custom UI begins as soon as the client entry point and authored Tutorial screen are available; this does not replace Roblox's earlier connection/replication loading screen.

Run read-only audit_studio.luau after syncing, then test a real join, Play, tutorial, inventory, cash purchase, placement, theft notification, respawn and leaving mid-load. Verify actual Satchel behavior and streaming/floor readiness in Studio. No nuke system/event is required; the user withdrew that work.


## Remaining UI LocalScripts (2026-09-09)

Sync all current client and server files together. The removed UI scripts now live in client controllers; do not re-add copies under HUD. Keep these authored instances:

- ReplicatedStorage.Assets.ConstructionTemplate, with BuildingName, Timer and Frame (fill bar).
- HUD.Frames.Construction.Frame.ScrollingFrame and ErrorFrame.
- HUD.Frames.Settings and its MusicToggle, SFXToggle, Holding.RedGradient/GreenGradient, CodeStatus, CodeSubmit and TextBox (existing nested Frame containers are supported).
- HUD.Buttons.Builders.Count and HUD.MobilePlacement (and its existing controls).
- SoundService.SFX, including Ambience.

UIController.Construction and UIController.Settings are ModuleScripts with their helper modules as children. BuilderDisplay and controllers.placement.MobilePlacement are ModuleScripts. The ConstructionTimer.PlayerView server module supplies restored construction snapshots; both sides use Id-based updates. Run tools/audit_studio.luau read-only after sync. Check restored/duplicate/skipped construction rows, settings toggles and redeem results, builder occupancy colors and mobile visibility during Play.


## Smooth preview and startup wait (2026-09-09)

Sync client, server and shared together, including the new ModuleScript client.controllers.placement.ToolsModule.Session.Motion. No new authored assets are needed. Restart Play to use the new server bootstrap order (Events/Functions before building preview generation). Verify dragging, repeated R/mobile Rotate, placing mid-animation, sell-frame suppression and initial loading. Missing remote replication now reports an explicit startup error after 60 seconds instead of an unbounded wait warning.


## HUD travel buttons (2026-09-09)

Sync client.controllers.ui.UIController.TravelButtons as a ModuleScript along with UIController/init and Lifecycle. Keep HUD.Buttons.Up.Buy, City, Sell and their visual children; remove only their old Handler LocalScripts. City now reads Workspace.Plots.Plot<number>.PlotSpawn; Buy/Sell retain the supplied fixed world coordinates. Test each button after Play and after respawn in Studio.


## Tutorial/quest handoff and UI transitions (2026-09-09)

Sync client, server and shared together. New ModuleScripts: ReplicatedStorage.shared.ui.Transitions and client.controllers.ui.UIController.Presentation. Keep authored HUD geometry and all templates; temporary transition UIScales/white overlay are created and cleaned by code. Owner tutorial replay now restarts the five post-tutorial quests each join, preserving city/balance/inventory. Check a full Bank/taxes/Shack tutorial, its final white fade/HUD reveal, first Collect Income quest, menu/placement enter-exit effects, rapid close/reopen and respawn in Studio.


## Rebirth content and civilians (2026-09-09)

Sync client and server, including UIController.RebirthConfirmation/RebirthRewards and CivilianSystem.Appearance. Keep HUD.Frames.RebirthConfirm.Frame.ScrollingFrame/Yes/No. Rebirth card templates under UIController are now optional because readable fallback rows are created in code. Existing civilians gain variety after respawning/restarting Play; ServerStorage.Civilian stays untouched. Cloned classic Shirt/Pants/ShirtGraphic layers are removed for solid part-colour clothing.


## Latest: UI effect rollback and placement distance

Sync client/server/shared together, including new ModuleScripts shared.util.PlacementRange and client.controllers.placement.PlacementAccess. Transitions is now a small original-popup-size helper; the Word Hunt white/stagger/scale behavior is removed. HUD visibility is immediate; TutorialQuests still tweens to (0.5,0.21) as requested. Test near/far building equip, expanded plot edges, sell-only equip, and quest reveal. Numeric hotbar bindings remain untouched per the user's cancellation.

## Satchel handoff and tool lifecycle fixes (2026-09-09)

Sync updated client bootstrap/placement modules and the complete src/client/Satchel subtree into the existing Satchel loader. Keeping Satchel directly under StarterPlayerScripts works: its child Satchel ModuleScript and Packages use relative paths. Do not add a second copy under client if the direct loader is already synced. Preserve Satchel's authored attributes/styles and nested package hierarchy. No server data/schema migration is required.

Restart Play and verify: inventory hidden through loading/Play intro, one hotbar appears at gameplay/tutorial start, slot clicks/keys toggle real building Tools, repeated switching leaves one preview, distant equips notify and return, sell-frame equips show only held models, bought/collected/restored tools appear, menu close restores the inventory, and respawn/rejoin retains saved tool metadata. Local tests pass; this Studio play test is pending.

## Daily quest board and fresh owner testing (2026-09-09)

Sync server, client and shared together, then restart Play. Network creates Events.DailyQuests.Request/Update/Claim/Result. New server ModuleScripts: config.DailyQuestCatalog, services.QuestSignals, systems.progression.DailyQuests (with Board and Runtime children), persistence.PlayerDataModule.OwnerReset. New client ModuleScript: UIController.DailyQuests (with View, QuestRow and Widgets). Preserve init.luau module nesting.

Keep HUD.Buttons.Left.Quests. The client creates HUD.Frames.DailyQuests and all six quest cards at runtime; no UI template migration is necessary. Existing post-tutorial quests and daily login rewards remain. Daily boards refresh at midnight UTC; the panel displays remaining time.

Owner 1790165114 now resets gameplay progress on EVERY JOIN because TutorialConfig.ResetProgressEveryJoin is enabled. This replaces the earlier owner replay that kept the city/balance. Other players are unaffected. Test a full owner intro/tutorial, Quests opening/closing on desktop/mobile, income/purchase/city progress, reward claim and reopen, and a non-owner rejoin preserving its board/rewards. All code/local tests pass; Studio execution is pending.

## Quest visibility and tutorial/placement presentation follow-up

Sync the updated client UIController.DailyQuests subtree, NotificationController.Lifecycle/Queue, ToolsModule.Session.Preview and TutorialController.Highlights, then restart Play. No new authored assets are needed. Verify Quests after the main tutorial while post-tutorial objectives are still active, six loading cards before its snapshot, no NotificationCenter during tutorial, green land highlights for any preview, and complete cleanup when unequipping or opening the sell frame.

## Civilian walking follow-up (2026-09-09)

Sync the complete server.systems.world.CivilianSystem module and its children, then restart Play. Keep the authored ServerStorage.Civilian model. No new assets or save migration are required. Verify civilians walk between nearby locations with brief pauses, traverse completed roads, avoid buildings/constructions and stay on owned land. Check a crowded city and a small city; blocked actors should retry or be replaced instead of remaining stationary. Local regression checks pass; Studio physics and animation playback remain pending.

## Quest panel independent ScreenGui (2026-09-09)

Sync client.controllers.ui.UIController including updated Buttons, Lifecycle, Navigation and the complete DailyQuests module. DailyQuests now includes the NEW ButtonBinding ModuleScript child alongside View, QuestRow and Widgets. Restart Play so cached modules reload. There is no authored quest panel to add: the code creates PlayerGui.MyCityDailyQuests with a DailyQuests frame and six cards. The old HUD.Frames.DailyQuests runtime location is superseded.

Quests GuiButtons anywhere under HUD.Buttons bind automatically and enable input. After the main tutorial, click Quests while post-tutorial objectives are active; the panel should open at full size, show six loading/quest rows and close with X or another menu. It follows HUD.Enabled, cleans up on HUD replacement, and remains blocked during active building placement/main tutorial. Local event/navigation tests pass; Studio verification is pending.
