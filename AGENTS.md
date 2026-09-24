# MyCity project handoff

## Road cars, purchase recovery, rarity labels, income alerts (2026-09-23)

Road traffic: new server.systems.world.RoadTraffic (init + Graph), initialized after TrainSystem. Road pieces are Placed models containing Attachments whose names contain "Exit" (Exit, Exit1..4, InsideLaneExit, OuterLaneExit, ...) and optionally "DeadEnd". BuildingTemplates re-homes attachments that are not inside a part (the user's markers sit directly under the road Model) onto Base, preserving world position, so they follow placed/rotated copies. Exits of different pieces within 2.5 studs link. Each exit's edge is its Base-axis-snapped normal; cars never leave by their entry edge, curve through the corner of the two lane lines on turns, U-turn at DeadEnd markers and at open road ends. Edges with several exits are per-lane: cars take the right-hand lane for their direction, and those pieces get no extra offset; single-exit edges get a right-hand offset of 15% of the Base's narrow side (model attribute LaneOffset overrides). Cars: Assets.CarTemplates, 8 studs/s, one per 3 road pieces, max 6 per city / 30 total, trips of up to 12 pieces, replanned when a road is placed or removed. Trips are published to Runtime.AmbientTraffic with Points + P1..Pn CFrames (lifted so the model's bottom sits on the raycast road surface); AmbientTrafficController follows them at constant speed via AmbientTrip.readPath/along, and highway/train First/Last trips are unchanged. Templates not modelled facing -Z need a RoadYaw attribute (degrees) on the car model or the CarTemplates folder. All eight road configs already existed (RoadStraight2/Turn2/Intersection2 are the "Highway" variants).

Highway visits (2026-09-23, same day): RoadTraffic/Visits. The first Workspace.Map descendant named PlotCutOffs holds Plot<N> models (matched to Workspace.Plots.Plot<N>) with Attachments EnterPlot, EnterPlot1, EnterPlot2, ExitPlot2, ExitPlot1, ExitPlot. HighwayTrafficSystem passes a Divert hook to AmbientTraffic; on each highway spawn, with VisitChance 0.35, a car may visit a city if EnterPlot lies on its own carriageway (the nearest route line, within HighwayReach 12) and the player's roads have open (unlinked) ends within ConnectDistance 6 of EnterPlot2 and ExitPlot2. Path: highway start -> projection of EnterPlot on its lane -> EnterPlot -> EnterPlot1 -> EnterPlot2 -> city tour (BFS via a random piece, right-hand lanes) -> ExitPlot2 -> ExitPlot1 -> ExitPlot -> projection on the nearest carriageway -> that route's end. Visit frames reuse the highway's authored car orientation (heading-to-model correction), and city-only cars adopt the same correction unless RoadYaw is set. Visiting trips are highway trips (highway Speed/Limit), not tracked per city, so a road removed mid-visit is not replanned. The user's message was cut off after "and also now"; that part is unknown.

Follow-up (user saw no visiting cars after linking roads; cause not observable without Studio): thresholds relaxed to VisitChance 0.5, ConnectDistance 10, ConnectHeight 40 (was 6; user: plot roads sit higher than the slip-road markers, cars ramp between waypoint heights), HighwayReach 20. Visits.status/report print "[RoadTraffic] Plot<N> highway link: ..." to server Output whenever a city's roads change (and once when the first highway car reveals lane positions), naming the failing check: missing marker, marker too far from highway lanes, nearest open road end distance to EnterPlot2/ExitPlot2, or ends not joined. Empty plots stay quiet. Use that line to diagnose further reports.

Owner tutorial (2026-09-23): TutorialConfig.ReplayEveryJoin=false, new SkipTutorial=true: TutorialSystem.prepareForJoin marks the owner's tutorial finished (ServerStage 7, IsInTutorial false) every join; ResetProgressEveryJoin is still true (owner starts from a fresh $500 profile each join, now without the tutorial). Owner tutorial analytics are always suppressed.

Car variety: AmbientModel.templates(folder) collects every top-level vehicle model in a template folder (sub-folders searched, nested models treated as parts) and stamps a unique TemplateId attribute; highway, train and road trips publish TemplateId and clients resolve with AmbientModel.find (falls back to TemplateName). Previously clients looked templates up by Name, so same-named car models always rendered as the first one.

Slip-road markers are name-agnostic: every Attachment in a cutoff starting with "EnterPlot" (user uses EnterPlot1-3) or "ExitPlot" (ExitPlot1-3) is used, ordered by horizontal distance from the plot Land centre (entry: farthest to nearest; exit: nearest to farthest). Numbering does not matter. The plot ends must meet player roads; the highway ends must be within HighwayReach of a lane.

Attachment space (user report: connected roads showed "no open road end"): attachments not inside a part may store a world CFrame or one still relative to the part they were made in. BuildingTemplates (road Exit markers) and Graph.worldPosition (PlotCutOffs markers) evaluate both readings and keep the one horizontally nearer the piece/model. Suspected cause of the report: part-relative exits collapsing near the world origin and all linking to each other; unconfirmed in Studio. The no-open-end message now reports piece/end/open counts and the nearest open end.

Road joins now also require facing edges (normal dot < -0.7), so side-by-side pieces or corner lane markers cannot join; ConnectDistance raised to 20 (user road was 12 studs from the marker because the marker sits outside buildable land). When a plot reports "0 open", Visits prints every road end (name, position, facing, joins) for diagnosis.

Car speeds (user: 3x slower): highway Speed 5/3 (also visiting cars), city RoadTraffic Speed 8/3 studs/s. Trains unchanged.

Visit diagnostics: Visits.evaluate is the single decision used by both spawning and status. Server Output: "[RoadTraffic] Started: N car models", "Using <path> (N plot cutoffs)" plus missing attachments, "N highway lanes found", "PlotN highway link: <state>" on road changes, "PlotN not visited: <reason>" (throttled 20 s; skips empty plots and the other carriageway), and "A <car> is driving into PlotN" per visit.

Quest chain (2026-09-23): PostTutorialQuest definitions moved to PostTutorialQuest/QuestList (35 quests; APPEND-ONLY, since saved QuestProgression is an index). The original five stay first, unchanged. Kinds: collect/construct (event-counted) and buildings (optional minRarity)/roads/population/cash/rebirths/land (measured via Context.measure; Lifecycle listens to Cash, Rebirths and Land.Owned). PostTutorialQuestComplete is now derived (QuestProgression >= #QUESTS) on load, so players who finished the old five continue at quest 6. UpdateQuest/QuestComplete send reward.label (DisplayName); the client uses MansionIcon for any non-Apartments building reward and formats cash with commas. test_gameplay_audit completes all 35 through real triggers. Construction rise heights now scale 2/3/4/5/6 studs for 2x2..6x6 (4x4 was 2).

WorldRuntime prepares templates and builds previews ONLY for ServerStorage.Buildings models that have a BuildingConfig entry; other models there (the user's PlotScenary1/2) are left untouched and no longer warned about. The audit still warns about config entries with no model. BuildingData Buttons.Delete text is authored: no code sets it (the old "Store" rename was removed).

Roads have no levels: BuildingConfig/init tags every Road* entry NoLevels. The XP loop does not start for them, BuildingPrompts destroys the BuildingInfo Container.BuildingLevel label and ProgressBar on road billboards, and pickup notices omit the level. Saved level/XP values on existing roads are left untouched (hidden, unused).

Purchases (user asked to fix stuck purchases; this supersedes the earlier "keep ambiguous price-tier receipts pending" decision): a new prompt is never refused. An unbound old intent moves to record.IntentArchive[productId] (Details kept, 20 per product, 30 days); a bound one is dropped because its plan lives in its receipt entry. GrantPlan resolves open intent (unbound or bound to this receipt) -> oldest archived choice -> compensation (ShopSystem.compensationBuilding: the most expensive catalogue building in that Robux tier; Skip products skip an active construction). The ledger binds the chosen source via consume() in the same save as the entry. PendingReceipts no longer blocks prompts; legacy pending receipts resolve on Roblox's next retry. Steal steps carry Created; a transfer blocked for 600 s (owner busy/other server) delivers the saved snapshot once. Unknown products still never invent rewards.

Rarity colours: shared.ui.RarityColors (Common grey, Uncommon green, Rare blue, Epic purple, Legendary orange, Mythic pink) is used by both the building info label and the construction billboard (Common construction labels were yellow; now grey like the info label). Income alerts show green / yellow (crime > 30) / red (crime > 50), and generated IncomeAlerts use ExtentsOffsetWorldSpace (0,1,0) so they float above the roof unless authored otherwise.

Validation: new test_road_traffic, updated purchase_intents/purchase_recovery/receipts/gameplay_audit; all 44 suites, 272 source / 48 tooling compile and path/helper audits pass. Not verified in Studio: attachment positions on the real road models, car orientation/lift, road surface raycast, alert placement.

## Placement rules unified (2026-09-23, player report)

Report: buildings flush against an owned-land edge/corner were refused. Cause in source: the server used GetPartBoundsInBox and rejected ANY descendant of Land.Locked, including the ExpansionPrompt sign and LockedScenery that ExpansionSystem parents inside locked tiles adjacent to owned land and that overhang onto owned land; the client preview checked only direct Locked children, so it showed green. Neighbours' Hitboxes (now generated to the full art bounds) could also block. Separately, client failure feedback fired Movement.CannotPlace:FireServer() with no server listener, so players never saw why.

shared/util/PlacementRules is now the single rule set for client preview and server validation: every footprint sample (edges inset 0.05) must be on an Owned tile, and the candidate Base must not overlap another Placed/Construction model's Base footprint (2D separating-axis test; touching/float noise within 0.05 allowed). No physics queries; Hitboxes, decorations, signs and scenery never block. The server additionally keeps range and Base-height checks. Validation.placement/isValidPlacement/placeBuilding and PlaceBlock return false plus reason (OutsideLand, Overlap, Height, TooFar, BuilderLimit). The client shows Rules.Messages via PlacementAccess.notifyFailure (throttled; BuilderLimit silent because the server already notifies). No remotes/save changes. Sync shared.util.PlacementRules with the server BuildingSystem and client placement modules. test_security covers the corner/scenery regression, flush and float-noise neighbours, Hitbox overhang, construction overlap and reasons; not reproduced in Studio.

## Code-completed building templates (2026-09-23)

Authoring a building is now: a Model in ServerStorage.Buildings, named exactly as its BuildingConfig key, whose PrimaryPart is Base, plus the visual parts. Nothing else is authored. New services.BuildingTemplates.prepare runs once per template from WorldRuntime.start (before preview cloning and before any system init/restore), mutating the ServerStorage template in place:
- Hitbox: invisible Part sized to the bounding box of all parts in Base's frame (CanCollide/CanTouch/CanQuery false, Massless). Prompts, BuildingInfo, thoughts, XP and preview tint still use it by name.
- Every child of ReplicatedStorage.Assets.Hitbox (PlaceVFX, VFX) is cloned into Hitbox, keeping authored attachment positions.
- ReplicatedStorage.Assets.IncomeAlert (must be a BillboardGui) is cloned to the model root, Enabled=false, Adornee=Hitbox; clones remap Adornee to their own Hitbox.
- Base is anchored; every other part (including Hitbox) gets a WeldConstraint `MyCityWeld` to Base and is unanchored, so the construction completion PrimaryPart rise tweens move the whole building.
- Config is still created at runtime by setupBuildingConfig; no Build folder is needed.
Legacy templates with an authored Hitbox/IncomeAlert are reused (missing VFX is added); existing direct Base WeldConstraints are not duplicated. A PrimaryPart not named Base is renamed Base. A model without Base/PrimaryPart warns once and is left unplaceable. Prepared models carry attribute MyCityTemplatePrepared. No save/schema change.

Current authored layout (user, 2026-09-23): Model { Build (Folder of parts), Base }. Parts are gathered by descendant search, so the Build folder needs no special handling; Hitbox spans Base to the top of the tallest part. BuildingTemplates.audit (after preview generation) warns once per: config entry without model, model without config entry, Size without Assets.Constructions model, and Base footprint differing >1 stud from the Size site's Base. New config entries (no ImageId yet; icons blank until added): CoffeeShop (Population/Common, 2x2, pop req 175), BookStore (Uncommon, 2x2, 700), SolarTower (Rare, 3x3, 14000), ElectricTower (Epic, 3x3, 38000). Sizes are guesses; trust the audit warning.

Mobile: UIController.MobileScale runs from init on TouchEnabled-without-keyboard devices. Each HUD.Frames child gets UIScale x1.15, HUD.Buttons Left/Right/Up/Top x1.1. An authored UIScale is multiplied (original kept in attribute MyCityBaseScale), never duplicated; late Frames children are scaled. test_mobile_scale covers it. Studio overflow on small phones is unverified.

Validation: test_join_hierarchy now executes the real module through WorldRuntime (rotated bounds, VFX/alert cloning, welds, clone Adornee remap, idempotence, legacy reuse, missing Base). All 41 test scripts, 267 source / 46 tooling compilation and path/helper audits pass. Not verified in Studio: IncomeAlert/VFX placement relative to the generated Hitbox centre, CollectPrompt line-of-sight inside large buildings, and physics of welded unanchored MeshParts. Sync services.BuildingTemplates with bootstrap.WorldRuntime.

## Epic stock availability (2026-09-20)

All Epic buildings, including Shopping Mall and other names in LIMITED_BUILDINGS, now use the regular Epic stock rule: 65% positive-stock chance, 2–6 copies. After three consecutive zero-stock generations for a building, the next generation guarantees 2–6. Positive availability resets that building's streak, regardless of purchase. Other rarities, unlocks, costs and the five-minute timer are unchanged.

DataSchema adds the empty dynamic Data.ShopEpicMisses folder; per-building IntValues save through the existing Data_1/profile codec, with schema 5 retained. Existing saves gain the folder without replacing gameplay data. Normal save/rejoin retains streaks; the explicit owner fresh-profile reset still resets them. Initial join stock and explicit shop resets count as generations; repeated snapshots/stat/rebirth sync do not. No offline restocks accrue. Stock generation waits for MyCityLoaded and refuses departure, so early join/timer callbacks cannot overwrite restored counters. Sync the entire ShopSystem ModuleScript with its children and PlayerDataModule.DataSchema together, then start fresh servers.

Validation: new test_shop_stock executes actual shop modules/config plus schema/codec for every Epic, exact miss threshold, per-player/per-building isolation, normal stock reset, snapshot stability, unchanged unlocks/non-Epic stock, loading/departure and save/rejoin. It and ten relevant regression suites pass; all 266 source / 46 tooling files compile and path/helper audits pass. No Studio or live storage verification was performed. See docs/BUG_AUDIT.md for the Play procedure.

Updated 2026-09-14. Root: `Active Games/MyCity`, the standalone city-building game.
This is not the historical KingdomWars campaign checkout named MyCity.

## Repeated join refusal recovery (2026-09-14)

The user supplied a player complaint about repeatedly being told the city failed to load and to rejoin; no username or server traceback is available. Source confirms a recovery gap: profile acquisition previously tried three times with only six seconds of waits while an old lease lasts 180 seconds. This can reproduce repeated quick-rejoin refusals, but is not proof of the reported player's exact cause.

PlayerDataModule now polls a contested lease every five seconds for up to a 190-second acquisition window, allowing a previous server to release or a crashed server's lease to expire. Five consecutive service errors stop retries with backoff; departure stops retry waits within 0.25 seconds. External DataStore calls can still exceed the local deadline. Active foreign leases are never force-released, and failed reads never become default cities.

SessionStore.release atomically removes only the calling session's lock from the current stored record. Failed/canceled loads use this method with three release attempts instead of writing an in-memory snapshot. This preserves saved city/receipt data even if owner reset or partial restoration changed the working record; a newer server's lock is untouched. Normal successful departure still saves gameplay and releases through the existing save path.

PlayerLifecycle records MyCityLoadStage and logs the failing stage plus traceback. Terminal errors expose MyCityLoadErrorCode: LOAD_SESSION, LOAD_SERVICE, LOAD_RESTORE, or CITY_<stage>. A failed city load revokes both MyCityLoaded and MyCityInventoryReady before abandonment. Optional join badge work runs separately and cannot fail a restored city. Persistent restoration failures request a report code instead of endlessly promising that another rejoin will fix them.

Validation: all 40 local suites pass, including new test_load_recovery using the real loader/SessionStore with simulated storage and clocks; test_shutdown also covers building/quest failures and optional badge failure. Source/tool compilation and path/helper checks pass. No live DataStore or Studio reproduction was performed. Sync PlayerDataModule (including SessionStore) and bootstrap.PlayerLifecycle together, then start fresh servers. Existing data namespace/envelope/schema and authored assets are unchanged. See docs/BUG_AUDIT.md for the verification procedure.

## Startup/shutdown race fix (2026-09-10)

The supplied Studio log showed PlayerLifecycle registering BindToClose after yielding bootstrap work, when Play was already stopping. New `server/bootstrap/Shutdown.luau` registers once before SpawnGuard, network/assets or system initialization. It marks closure/departure immediately and accepts the lifecycle save callback before any player load starts. A bootstrap resumed during closure returns; preview preparation cancels between work slices. An already-closing Script Sync session refuses startup safely.

PlayerLifecycle is idempotent, rejects queued departing/closing joins, checks cancellation after yielding load stages and abandons partial restorations without a late kick or partial save. A DataStore acquisition returning after departure releases the original record before creating player data. Spawn holds reject late departing-character events, and plot relocation verifies the current character/departure status after its bounded root wait. Normal loaded players retain the shared PlayerRemoving/BindToClose save path.

The separate Studio message `Character cannot be changed as Player ... is being removed` had no source traceback. Exported source contains no LoadCharacter call or direct Player.Character assignment; these guards fix late gameplay work, but an engine or unexported-script origin cannot be confirmed from that message alone. Do not claim that message reproduced or resolved in Studio without a fresh Play/Stop test.

Validation: 39 local test suites pass; all 266 source and 44 tool files compile; path/helper audits pass. New test_shutdown executes early registration, already-closing refusal, stop-during-bootstrap, cancellation while data is loading, queued join refusal and one normal shutdown save. Data-schema tests execute a departure during successful profile acquisition and verify unchanged-record release. Studio stop-during-load remains unverified.

Sync the new ModuleScript `ServerScriptService.server.bootstrap.Shutdown` with the updated server tree, then start a fresh Play session. The read-only audit and migration module-class table include it.

## Latest state: full hardening pass (2026-09-10)

Read `docs/SYSTEM_HARDENING.md` first for the complete per-system change ledger and remaining integration limits. This section supersedes historical notes below. The tree currently has 266 source files. No Git or Studio connection was available.

- User approved Store instead of permanent Delete, smoother rebirth requirements, equivalent-item compensation for confirmed missing paid-steal targets, and keeping ambiguous old price-tier purchases pending with recovery feedback.
- Required new modules: server.services.SimulationScheduler; server.systems.economy.IncomeSystem.CityCache; server.systems.social.CityLikeRewards; client.controllers.world.AmbientTrafficController; shared.visuals.AmbientModel and AmbientTrip. Sync all three roots and restart Play together.
- Server ambient traffic creates immutable Folder descriptors in ReplicatedStorage.Runtime.AmbientTraffic. Clients clone sanitized Assets models into Workspace.Misc.AmbientVehicles and animate them with synchronized timestamps. Do not restore server per-frame model motion alongside this renderer.
- XP and construction use SimulationScheduler (six dispatches/3 ms per frame, elapsed-time callbacks, no callback self-overlap). Income rates/population cache invalidates on city/value changes. Service coverage chooses best effective coverage with spatial buckets for large lists. Held visual cache is capped at 32 templates; source replacement invalidates it, in-place live asset edits require restarting Play.
- Data_1, original envelopes and schema 5 remain. Autosaves are staggered; failed saves retry and queued saves have a bounded busy wait. Completed receipt plans are compacted without deleting receipt IDs. PendingReceipts blocks ambiguous product reuse. Confirmed absence enables saved-descriptor steal compensation; active foreign leases/service errors remain pending.
- CityRatings.rewardSequence counts new non-self likes; Data_1.CityLikeRewardSequence saves alongside owner cash. Retain this metadata across owner gameplay resets and rollbacks. Historical likes are not retrospectively rewarded. Permanent receipt/transfer/voter history still needs a safe archival design at extreme volume.
- Delete now returns a prepared tool and the authored button says Store. Rebirths 1?10 require 100/300/650/1200/2000/3200/5000/7500/11000/16000 population; level 50 remains 142000, later levels grow 15%. Existing city preservation/cash reset and template-only reward UI remain.
- The unused direct-steal and in-place plot-relocation APIs now refuse mutation. Use the receipt transfer path and normal city restoration.
- Daily quest progress coalesces to five seconds, completion/rollover refresh promptly, and the claimed snapshot precedes result feedback. Daily rewards save immediately. No cash-collection/construction-start/tutorial notifications were added. No Word Hunt UI transitions or inventory rewrite was added.
- Validation: 38 source/mock test suites plus compilation/path/helper audits. Studio asset approval, real storage/receipts, camera/input feel and measured loading/FPS remain unverified. See the report for each system's evidence; do not call this 100/100 or zero-lag production verification.

## Working rules

- Script Sync is the source mapping; there is no Rojo project, place export, or Git repository here.
- Preserve authored models, GUI templates, names, and all unrelated synced changes.
- Read the current tree before editing. The current 2026-09-09 tree has 254 source files, including the newly synced Satchel package; enumerate the current tree as sync can add files.
- `docs/MIGRATION.md` explains the required Studio asset migration. It has not been executed in Studio.
- No code-only check establishes published, multiplayer, DataStore, purchase, or device behavior.
- Keep this handoff and `docs/BUG_AUDIT.md` current when behavior changes.
- Do not run maintenance deletion or publish/commit/push as part of routine code work.

## Runtime mapping and authored objects

| Local source | Roblox location |
| --- | --- |
| `src/server` | `ServerScriptService.server` |
| `src/client` | `StarterPlayer.StarterPlayerScripts.client`, or StarterPlayerScripts itself |
| `src/shared` | `ReplicatedStorage.shared` |

Ordinary `.luau` files are ModuleScripts; `init.luau` makes its directory the ModuleScript, with the other files as children. `.local.luau` is a LocalScript and `.legacy.luau` a Script. Preserve the parent-module structure when syncing.

The city gameplay entry points are `server/Main.legacy.luau` and `client/Initialization.local.luau`. The separately synced inventory also has `client/Satchel/init.local.luau`; it was left untouched after the user withdrew hotbar work. Former independent city scripts are modules called by the city entry points. Maintenance is an unrequired module.

Exact authored names include `shared`, `server`, `MarketPlaceHandler`, `Enviorment`, `HamburgerResturaunt`, `StealBuilding.Recieved`, and `CodeFeeback`. Do not silently correct them.

- Highlight: `ReplicatedStorage.Assets.Highlight`.
- Expansion: `ReplicatedStorage.Assets.Expansion.Locked` and `.Expansion.ExpansionPrompt`.
- Shared effects: `ReplicatedStorage.shared.UIEffects`.
- `ReplicatedStorage.Assets.Items` contains the templates, with building/construction billboards, prompts, SpeechBubble and rarity effects.
- PlayerDataModule needs no authored data templates. DataSchema creates player Data/leaderstats and supplies missing nested defaults in code.
- Client controller templates move with their owning modules unless explicitly relocated. Default is `ReplicatedStorage.Assets.Default`; ProximityPromptController retains only themed overrides; shop PurchaseFrame/ItemTemplate are in `ReplicatedStorage.Assets.Shop`; TutorialController keeps beam/anchor templates; UIController keeps its GUI templates.
- `ReplicatedStorage.TopbarPlus.Icon`, Assets models/tools, StarterGui.HUD, Workspace.Map and ServerStorage.PlotTemplate remain authored Studio dependencies.
- ToolFactory creates Tools and marker values in code; Assets.Tool/Tool.Init and ToolBuildings are retired dependencies. HeldBuildingVisual clones ServerStorage.Buildings models for the held miniature. BuildingTools initializes behavior centrally. Other scripts hidden inside Studio assets still require inspection/export.

## Folder structure and ownership

```text
src/
  server/
    Main.legacy.luau
    bootstrap/                 # ServerBootstrap, PlayerLifecycle
    config/BuildingConfig/     # Catalogue assembled from category modules
    persistence/
      PlayerDataModule/        # DataSchema, ProfileCodec, SchemaMigration, SessionStore
      FunnelAnalytics.luau
    services/
      MarketPlaceHandler/     # ProductConfig, intents, plans, ledger, actions, transfers
      ToolFactory.luau
      ToolSerialization.luau
      ToolSetup.luau
      CodeSystem.luau
    systems/
      building/BuildingSystem/ # Validation, placement commit, data, XP, stats, prompts
      construction/ConstructionSystem/
        ConstructionTimer/    # Timing, Completion, Visuals, Lifecycle
      economy/                 # Inventory, shop, selling, BuildingEconomy, IncomeSystem/
      progression/             # Tutorial, quests, rebirth, daily/group rewards, badges
      world/                   # Plots, expansion, city names, traffic, trains, weather, VFX
      social/                  # CityRating, FriendBoost
      security/                # RequestGuard
    maintenance/               # DeleteDatastore; never automatic
  client/
    Initialization.local.luau
    bootstrap/HudBootstrap.luau
    controllers/
      ui/                      # UIController/, NotificationController/, ProximityPromptController/
      shop/                    # ShopController/, SellController/
      tutorial/TutorialController/
      placement/               # BuildingTools, ExpandHighlight, ToolsModule/Session/
      social/                  # ChatTags, FriendsBoost, LikeSystem
      systems/                 # ResetButton
  shared/
    Network.luau
    UIEffects.luau
    util/                     # ConnectionScope, NumberCounter
```

Feature `init.luau` modules assemble focused child modules using an explicit Context. Stable dependencies live on Context, shared mutable state on Context.State. Private cross-module functions use Context; public methods stay on the returned API. Do not copy mutable scalar values into locals and expect reassignment to update shared state.

## Startup and teardown

ServerBootstrap installs SpawnGuard, creates the network and binds IntroFinished before the yielding WorldRuntime preview preparation, then requires gameplay systems, initializes the systems, starts social services, then installs PlayerLifecycle. Weather's autonomous cycle remains disabled as in the previous source; building weather updates still exist.

PlayerLifecycle acquires/restores data, waits for a character, assigns a plot, restores buildings/constructions/expansion/city name, restores inventory, initializes rebirth/tutorial recovery, then sets `MyCityLoaded=true`. Client listeners bind before requesting ClientReady snapshots for shop, quests, daily rewards and rebirth. Early/missed loading events are covered by replicated readiness attributes.

Departure sets `MyCityLeaving`, waits for load and in-flight guarded mutations, settles income, snapshots inventory, saves/releases the profile, then clears world/controller state. BindToClose uses the same departure path. A partial restoration abandons the original acquired record instead of saving a partial city.

HudBootstrap owns HUD replacement. It cancels unfinished initialization, calls controller cleanup and ConnectionScope.clear, then binds the replacement. ConnectionScope tracks signal callbacks and spawned/deferred/delayed work. Long-lived placement/social controllers are started once by Initialization.

## Persistence and transaction rules

- Preserve `Data_1` and the existing JSON envelope (`PlayerData`, `LeaderBoardData`, `LastSaved`). Recursive folders use `FolderEncoding=2`; the codec reads legacy folder keys.
- SessionStore uses UpdateAsync with a 180-second lease in the SAME profile record. Autosave runs every 45 seconds. Saves check the session ID atomically; stale sessions are stopped.
- Do not start new servers alongside old SetAsync writers indefinitely. See the release procedure: old servers cannot honor the new lease.
- Missing/corrupt data and service failures must not become default profiles. Only a missing record is a new profile. Missing authored building templates cause restoration to fail safely.
- Inventory must be restored before taking a snapshot. Unique ToolId identifies each tool; serialization preserves level, XP, mutation, validity and paid status. MyCityInventoryReady gates remote mutations during respawn restoration.
- Requests that mutate inventory/currency/buildings use RequestGuard. Validate ownership, current plot, argument types and spatial bounds on the server.
- ReceiptLedger persists PurchaseId, plan, applied steps and completion in the player profile. A reward and its applied marker are saved together. Never acknowledge a receipt until completion saves.
- PurchaseIntents persist an immutable target before prompting. Do not replace an unresolved intent with another target. Unknown or unavailable targets remain pending; see documented limitations.
- Cross-player steals persist removal and a transfer marker in the owner's profile before granting the buyer. Do not restore the owner's item when retrying a completed transfer.
- New code-redemption markers and cash save together in Data_1; the old `Codes` store remains a read-only source for prior redemptions. `CityNames` and `CityRatings` remain their existing separate stores.
- There is no global tool factory. Use ToolFactory/ToolSerialization.

## Gameplay invariants

- BuildingValidation checks owned tools/models, finite upright quarter-turn placement, footprint on owned land, height, and overlap. Authored grid phase and all special model sizes need Studio checks.
- PlacementCommit prepares instant buildings before committing their saved record and consuming the tool. Construction placement rolls back the site/tracker/builder reservation on setup failure.
- Construction tracks all 12 CSV fields, including paid status. Completed constructions use their construction ID as the placed building ID. Builder/timer tables are canonical across new/restored/skipped construction.
- BuildingEconomy supplies the income/population formulas shared by payout and displays. Only the timer adds elapsed income; recalculation does not mint a tick. Friend boost comes from server friendship checks.
- Tutorial stages: 0 welcome, 1 Bank tool, 2 Bank started, 3 Bank completed, 4 income collected, 5 Shack purchased, 6 Shack started, 7 Shack completed. Only stage 7 can finish. Resume uses persisted stages or existing legacy city/tool evidence.
- Quest completion guards reentry and advances without a presentation delay. Daily streak calculations use the previous claim timestamp. Rebirth preserves all inventory/buildings/constructions and land; only cash resets to the existing rebirth starting amount.

## Validation and tools

`tools/check_paths.py` checks literal local requires. TopbarPlus.Icon is Studio-only; the Initialization controller loop and Rebirth's ShopSystem require are dynamic and reviewed manually.

Run the actual Lune binary if the Rokit shim fails:
`C:/Users/636922/.rokit/tool-storage/lune-org/lune/0.10.2/lune.exe`.

Run `validate_source.luau`, then `test_network.luau`, `test_startup.luau`, `test_persistence.luau`, `test_receipts.luau`, `test_security.luau`, `test_cleanup.luau`, and `test_progression.luau` using `lune run tools/<file>`.

These compile/execute source against local mocks; they do not contact Roblox or live DataStores. `audit_studio.luau` checks actual authored paths read-only in Studio. `migrate_studio.luau` performs the edit-mode migration described in docs/MIGRATION.md.

`refactor_layout.py`, `split_modules.py`, and `scope_connections.py` record one-time transformations and must not be rerun on the already-refactored tree. `build_studio_migration.py` can regenerate the migration from `docs/layout-migration.json`. The local pre-refactor backup is `.local-backups/before-deep-refactor.zip`; it includes old sensitive configuration and must not be published.

## Follow-up after Studio error log

The follow-up splits eight additional server modules into 34 child modules: ShopSystem (Stock/PlayerView/Refresh/Purchases/Lifecycle), BuildingXP (Effects/Progression/Awards/Lifecycle), BuildingThoughts (Selection/Presentation/Lifecycle), BuildingStats (Health/Safety/Happiness/Aggregation/Penalties), PlotManager (Scenery/Assignment/Reset/Relocation/Lifecycle), ConstructionData (Coordinates/Serialization/Restoration/Lifecycle), RebirthSystem (Display/Reset/Rebirth/Lifecycle), and SellSystem (Valuation/Display/Sale/Lifecycle). All retain the same public ModuleScript instance paths via init.luau.

The Studio log exposed bare helper calls missed after concatenation (`..`) and varargs (`...`) by the original extraction helper. All five occurrences were fixed, and `tools/check_module_dependencies.py` prevents recurrence. Run it alongside check_paths.py. `test_refactor_regressions.luau` executes the actual Shop lifecycle and Rebirth display callbacks plus the GUI repair transform. The shop timer uses Heartbeat deltaTime directly.

The log's old `[DATA SERVER]` messages are absent from the current source and indicate an outdated running server copy. Bootstrap now prints `[MyCity] Modular server bootstrap v2`. Resync the entire server tree before interpreting further play results. The eight failing GUI FX scripts are outside this export: `tools/repair_gui_paths.luau` patches legacy Modules paths inside FX scripts under StarterGui/Assets using ScriptEditorService in Edit mode. It does not create a Modules compatibility folder. The repair is not executed locally because Studio is not connected.

## Code-defined data schema (latest user instruction)

The user explicitly retired authored PlayerDataModule.Data/leaderstats templates. DataSchema.CreateDefault and Reconcile now define the runtime folders/values in code, following WordSearch's code-owned schema approach while retaining MyCity's existing Data_1 envelope and instance-facing gameplay APIs. Schema version is 5. New profiles start with Cash=500, Population=0, Rebirths=0; existing values are preserved. Inventory/buildings/constructions/owned tiles are dynamic collections and are never replaced with defaults. Plot assignment seeds the authored starter land.

ProfileCodec.restore only decodes saved data or creates empty folders for an explicit NewProfile record. SchemaMigration moves old tutorial flags before DataSchema supplies defaults. Missing or corrupt saved envelopes still refuse loading. Restoration errors now include a traceback and mark MyCityLoadFailed. The original record is released unchanged on a restoration failure.

PlayerLifecycle initializes Rebirth and PostTutorialQuest after restoration instead of those modules independently waiting for Player.Data/leaderstats on PlayerAdded. Quest defaults are code-defined. Plot reset tolerates missing Data and verifies the plot's current CityId before resetting it.

Run tools/test_data_schema.luau for actual codec/schema/migration/loader tests: no templates, old saved values, missing nested defaults, same-envelope round trip, clear safe failures and no-data progression/cleanup. The user's latest log confirms bootstrap v2 is running; the previous stale-server diagnosis no longer applies to that new log. GUI FX scripts are still outside the export and require the supplied Edit-mode repair.

## Legacy scalar normalization (schema 4)

The LastUpdate restore rejection came from strict Instance-class compatibility in schema 3. Following the current WordSearch DataService/DataSchema pattern, MyCity now calls DataSchema.Normalize on a detached stored table before Codec.restore and before JSON serialization in savePlayerData. Schema reconciliation also converts legacy runtime values to canonical classes. MyCity keeps Data_1, its existing keys/envelope, and its guarded UpdateAsync/session store; WordSearch's unrelated namespace/profile fields are not copied.

Known numeric fields accept finite numeric strings, floor integers, and clamp to zero. Invalid scalar values use the field's code default; an invalid LastUpdate becomes the current timestamp, while valid numeric timestamps (including zero) are preserved. Bool values migrate from true/false and 1/0 encodings. Saved cash/items/buildings and receipt/transfer metadata remain intact; dynamic collections are not replaced by defaults. Malformed whole folders and future schema versions still fail safely. Acquired records remain unchanged if restoration fails.

The expanded test_data_schema.luau executes actual PlayerDataModule load/save/rejoin methods against mocked storage with a legacy blank LastUpdate, plus multiple old field classes. It verifies canonical saved types and preservation of cash, tools, tutorial state and receipts. This is not a live DataStore or Studio test.

## Sell-area world prompt

SellSystem/PromptBinding.luau owns Workspace.Map.Interactives.SellArea.Part.ShopPrompt. SellSystem.init binds it once through the existing server bootstrap. It opens Events.Sell.OpenUI only for loaded players outside the tutorial. Keep the authored ProximityPrompt; remove its old child Script after syncing the backend binding to avoid duplicate handlers.

## HUD cash label

UIController/CashDisplay.luau owns HUD.CashDisplay. It displays leaderstats.Cash immediately, formats dollar amounts with commas, and uses the controller connection scope for updates and teardown. UIController already had this behavior; it was extracted from Displays rather than registering a second handler. After syncing, remove the old LocalScript inside the authored CashDisplay label, keeping the label.

CashFeedback.luau now animates subsequent balance changes using shared/util/NumberCounter, adapted from current KingdomWars. Initial balance snaps; later updates count up/down with green/red floating deltas and temporary tint. Popups are capped at three; the frame connection exists only during animation. cleanupCashDisplay destroys effects and disconnects the source before HUD replacement. No authored effect templates or new remotes are needed. Run tools/test_cash_feedback.luau for the actual effect/binding mock-runtime checks; visual clipping/readability still require Studio.

## Current optimization and feedback review

See docs/OPTIMIZATION_AND_FEEDBACK.md for current source findings and the supplied 28-comment historical feedback analysis. Income uses a fixed one-second accrual despite scheduler delay; service coverage chooses the nearest provider even when a farther higher-tier provider covers the building. These are documented findings, not fixes implemented by the cash-effects change. Other priorities include paid-intent recovery, quadratic plot-stat scans, repeated builder updates, server-driven ambient traffic, mobile editing and destructive rebirth UX. Historical complaints do not prove current live defects; profiling and release checks remain outstanding.

## Owner tutorial replay and recovery

Owner replay is configured in server/config/TutorialConfig.luau: OwnerUserId=1790165114, verified against current WordSearch (Word Hunt) GameConfig.Tutorial.ReplayUserId; ReplayEveryJoin=true in MyCity only. PlayerLifecycle calls prepareForJoin after world/inventory restoration and before readiness/quest activation. Only tutorial flags reset, once per join; city, inventory, cash, rebirths and quests are retained as requested. Ordinary tutorial income/purchases still affect cash. Existing Bank tools are reused; replay needs space for Bank/Shack placements. Owner replay skips legacy-city stage inference. New placement IDs identify replay targets so unrelated old construction completions cannot skip stages. Owner tutorial analytics are suppressed.

Client presentation follows replicated ServerStage/IsInTutorial instead of delayed milestone remotes. Stage transitions cancel previous presentation work, subtitle tweens and camera zoom work. Start buttons use Activated; completion stays active until the server acknowledges and retries while busy. Orbit cleanup restores captured camera/root state instead of forcing an unowned camera/root change. The required stage-4 cash Shack purchase is permitted even when random stock is zero, charges the normal price and cannot make stock negative. Run test_progression.luau and test_tutorial_client.luau alongside startup/cleanup/source checks. Authored tutorial/shop templates and actual mobile/camera behavior still require Studio verification.

## City-preserving rebirth and leaderboard schema 5

The user requested that rebirth retain the city and explicitly kept the existing cash reset. RebirthSystem/Reset now only cancels placement previews; it never deletes models, constructions, tools, saved city entries or owned land. Rebirth increments Rebirths, resets Cash to floor(10000 * (1 + newRebirths * 0.5)), recalculates population/income, and refreshes shop/UI. Confirmation adds an explicit preservation/cash-reset summary. Early population requirements stay unchanged; beyond rebirth 50, requirements grow 15% per level instead of plateauing forever with a retained city.

leaderstats now contains Cash and Rebirths only. Population is still needed for income, shop unlocks, quests and rebirth eligibility; its canonical location is player.Data.PlayerInfo.Population. DataSchema v5 moves legacy leaderstats.Population there before defaults, normalizes it and removes the old leaderboard entry. New saves keep it in PlayerData.PlayerInfo with the existing Data_1 namespace/envelope. All exported readers/listeners use the new path. Sync the full source tree together; hidden Studio scripts may need the same path update. Do not reset saves or roll back to a schema-4-only reader.

Validated with test_rebirth_preservation, test_data_schema, persistence, startup, progression and refactor regression suites, module paths/dependencies and compilation of 187 source files. Studio/device/live DataStore validation remains outstanding.

## Generated tools and held building visuals

The user deleted Assets.ToolBuildings and requested KingdomWars-style tools. ToolFactory now creates Tool/ToolName/IsValid/BuildingLevel/BuildingXP/Mutation in code, with unique ToolIds and nondroppable tools. HeldBuildingVisual clones the normal Assets.Buildings model, strips scripts/prompts/UI/sounds/old joints, scales its longest axis to 1.7 studs and welds each unanchored, noncolliding, massless part to an invisible Handle, matching the current KingdomWars held-building approach. Original models stay unchanged. A missing/unscalable cosmetic model leaves an equippable handle-free tool; actual placement still requires its normal authored model. No Assets.Tool or ToolBuildings template is required. ToolSerialization retains existing identity, level, XP, mutation, collected/paid flags. Test tool creation/metadata with tools/test_tool_factory.luau; hand orientation, physical scale and equip/placement still need Studio checks.

## Tutorial screen intro moved into client modules

The user supplied the full former StarterGui.Tutorial.Handler. Its intro flow is now client/controllers/intro/IntroController (init, Camera, Presentation), called only by HudBootstrap before data-dependent UI initialization and ClientReady/tutorial activation. The obsolete ReplicatedStorage.Client.Init lookup is gone. Keep Tutorial.ScreenGui, IntroFrame, Loading and all authored children; remove only its old Handler LocalScript after syncing.

IntroController starts the map orbit/blur before data readiness and shows the authored Play intro for every join, including owner tutorial replays. It uses MyCityLoaded rather than relying on a one-shot completion event. Camera ownership retries late character/camera/SpawnCam replication each frame, anchors the character through loading, and restores captured camera/root/blur state on exit. If Lighting.Blur is absent, it creates and later destroys its own BlurEffect. MyCityIntroActive gates tool previews. HUD stays disabled during controller setup; tutorial status explicitly hides CashDisplay/FriendBoost before it is shown. Scope cleanup cancels reveal tasks, tweens and listeners on HUD replacement. Completed intro does not repeat on respawn; late replacement Tutorial screens are disabled. Missing/broken optional intro presentation releases ownership, while HudBootstrap still requires server readiness.

Run tools/test_intro.luau and test_startup.luau for loaded-before-Play, delayed tutorial status, single handoff, cancellation/camera restoration and GUI replacement checks. Studio appearance, audio asset access and real respawn remain unverified. The Handler source request is now fulfilled.


## Placement lifecycle and owner replay regression fixes

Placement Session modules must retain the same Context.state table for their entire lifetime. Cleanup disconnects and resets that table in place, destroys only the session's preview, and changes UI only for an active session. Request generation checks prevent an old server response from cleaning a later equip. Failed placements retain the preview for repositioning. Tutorial tile highlights follow the local MyCityPlacementTool attribute and actual equipped Bank/Shack at stages 1/5; delayed equip remotes cannot recreate them after unequip. No count-of-existing-buildings restriction is introduced for replay; owned-land/overlap checks still apply, so new placements need free space.

Client previews use Base, while the server saves authored PrimaryPart transforms. Placement converts between these frames and validates Base height; server placement no longer sends CleanupPreview before a successful commit. Collected/instant Bank milestones advance immediately after commit, before optional prompt/visual setup. City data and replay cash policy are unchanged. Run test_placement_lifecycle, test_intro, test_tutorial_client, test_security, test_startup and test_progression; these are mocked source checks, not Studio playtests.


## Cosmetic civilians

server/systems/world/CivilianSystem is initialized once by ServerBootstrap. It is split into Config, Geometry, Rig, Animations and Movement. Keep an archivable, jointed R6/R15 Model at ServerStorage.Civilian with a Humanoid and HumanoidRootPart; the source creates plot.CivilianNPCs and clones the authored model without changing its appearance/scale. Embedded Scripts/LocalScripts/prompts are removed from clones, physics ownership is server-side, and parts cannot touch/query/block gameplay. No gameplay population, data, inventory, tutorial stage or currency fields are changed.

Current KingdomWars VillageNpcService supplied the walk/idle animation IDs (R6 walk 180426354, R15 walk 507777826), WalkSpeed=3 and 1.4-3.2-second pauses. MyCity uses zero civilians for an empty city, otherwise max(1, floor(completedBuildingCount/2)), capped at 8 per city and 24 globally, fairly distributed. Counts reconcile every second, spawning at most one per city per pass. Placed buildings count; unfinished construction is an obstacle but does not add residents. Rebirth preserves cities, so it preserves the corresponding cosmetic count.

Civilians visit free building-side/owned-land points, validate routes against land boundaries and building/construction footprints, use bounded PathfindingService requests when direct routes are blocked, and stop/retry when stuck. Late path results cannot resurrect removed NPCs. Departure, readiness loss and plot reassignment clear the city's owned actors/folder. No free walkway means a cosmetic count can remain below its target; expose TargetCount/VisibleCount on CivilianNPCs for diagnosis. Local test_civilians covers budgets, geometry, walking/stuck behavior, path cancellation and cleanup. Actual rig joints, floor movement and animation playback require Studio validation.


## Gameplay audit (2026-09-09)

See docs/GAMEPLAY_REVIEW.md for coverage and unresolved production blockers. Quests now count committed building completions (onConstructionStarted is retained as a no-op compatibility API), recover satisfied/legacy completed state, and send reward metadata with UpdateQuest. Sync client quest UI with the server: completed rejoin uses AllQuestsDone(true), and stale effects never overwrite current snapshots. Daily building claims defer without Backpack; cycles are clamped and the countdown uses elapsed time. Rebirth still preserves city and cash-reset policy; 0.15 additive bonuses remain, with two-decimal UI display. The 100-to-16,500 second-rebirth requirement jump is documented for balancing, not silently changed.

Cash purchases return success and avoid leaking undelivered tools. Failed Robux prompts retire their own unbound intent; receipts respect target ownership. Older ambiguous intents and changed cross-player steal targets still require recovery design. Placement checks all owned footprint samples and tolerates oversized previews; instant/collected placement bypasses builder capacity. Income accrual retains elapsed-time remainder and collection credit/reset precede optional quest work. Tests test_gameplay_audit, test_purchase_intents, expanded receipts/placement tests plus the existing suite cover local behavior. tools/audit_commerce_studio.luau reads actual product metadata and validates all authored catalog models; it is not run automatically.


## City loading and performance (2026-09-09)

RestoreBudget shares a six-object / approximately three-millisecond work slice across joining players, yielding between building/construction setup and final stat records. A single authored model clone cannot be preempted. Checkpoints cancel departed/leaving players into the existing partial-load abandonment path. BuildingData publishes configured models, parses saved CSV once and does no per-building income scans. PlayerLifecycle finalizes stats after both building and construction restoration, before setupPlayerIncome/readiness. Do not add independent per-building finalization or arbitrary setup sleeps. Removed prompt 0.1s/building, building-final 0.5s and construction-final 1s sleeps; authored readiness is still required.

BuildingStats/Snapshot enumerates each plot once and groups only relevant service providers/decorations. Snapshots are local to each evaluation, not a persistent stale cache; nearest-provider balancing is unchanged. Level-up recalculates the changed building's stats only. Owner lookup uses the assigned plot CityId and verifies the player's PlotInfo instead of scanning every city's buildings. XP waits for readiness, stops at max level and skips departing owners. Periodic stat fallback spreads separate plots across frames.

GamePassOwnership shares successful true/false results for 60 seconds across building/builder/construction-speed/income checks, joins simultaneous lookups, immediately records successful server purchase events, retries failed lookups and clears on departure. Construction restoration updates builders once at the end instead of queuing an update per site. Building prompt bars replicate final sizes instead of server tween samples; crime/happiness no longer trigger unrelated XP label redraws. Civilian routes are rechecked before each MoveTo refresh rather than every movement tick; current ground/obstacle checks still run each tick.

Run all tools/test_*.luau; test_loading_performance covers 100 real loader records, mixed construction recovery, 1,000-building stat equivalence, shared frame budgets and cancellation. test_gamepass_cache covers concurrency/purchase races/expiry/failure. test_civilians covers command-throttled route validation. These are mocked operation-count checks, not measured Studio FPS/loading times. docs/LOADING_PERFORMANCE.md lists engine/asset profiling still needed. No save namespace/schema changes.


## Current Studio hierarchy and join handoff (2026-09-09)

The latest user hierarchy supersedes earlier asset/Map references: authoritative building templates are ServerStorage.Buildings; plots are Workspace.Plots. WorldRuntime creates Workspace.Misc.PlayerAnchors, PlayerPreviews and Effects. Runtime tutorial anchors, local placement previews and VFX use those folders. Map still owns Interactives, Enviorment and SpawnCam. Client placement uses ReplicatedStorage.Assets.BuildingPreviews, generated once at startup from server templates with embedded behavior/UI/effects stripped; never require ServerStorage from client code. Server validation/restoration/construction/held tools all read ServerStorage.Buildings directly.

EarlyLoading runs FIRST in Initialization, before Network.wait or gameplay module requires. It activates authored Tutorial.Loading, blocks player actions and hides HUD/core Backpack/custom ScreenGuis (including late Satchel UI) until the Play handoff finishes. IntroController alone owns orbit/blur and reveals the authored icon/Play before waiting for MyCityLoaded after Play. Successful completion explicitly selects CameraType.Custom and the current character Humanoid; it never restores a stale Scriptable camera or its old CFrame. Cancellation restores captured state. HudBootstrap requires gameplay UI controllers only after this intro succeeds, then initializes tutorial/UI and releases inventory. Notification event preparation must not require UIController before Play. SpawnGuard anchors initial/late/replacement character roots before server dependency waits and releases original anchored states on the new Loading.IntroFinished remote after MyCityLoaded. No save changes. Intro presentation errors no longer silently skip Play; missing authored intro dependencies keep the join blocked with a diagnostic.

NotificationController exclusively owns HUD.NotificationCenter.Template. It follows current KingdomWars NotificationFeed's authored text-card, fade, duplicate suppression and bounded-feed approach with MyCity's existing notification API. Message/TextLabel descendants are resolved; authored layout/aspect/stroke objects survive cleanup. Errors, purchases, rewards, theft and likes/code feedback use the common feed, including tutorial errors. No NotificationsFrame or StoleAlert dependency. CollectIncome must not create feed notifications; the animated cash counter remains. NotificationController.prepare binds during the intro; a bounded pending queue flushes only after HUD/tutorial setup and inventory release. The user withdrew the nuke request after neither current source nor either pre-refactor backup contained any nuke code: no nuke system/event was added.

ShopPrompt owns Workspace.Map.Interactives.BuyArea.Model.Prompt.ShopPrompt. Keep that authored ProximityPrompt; its old child Script is deleted by the user. The server opens Events.UI.OpenItemShop only for loaded players outside the tutorial. Sell binding remains separate and unchanged at its existing Interactives.SellArea path.

Sync the whole src/server, src/client and src/shared trees together (Network now has 81 RemoteEvents and two RemoteFunctions). New bootstrap modules must exist before starting Play. Run all 22 test scripts plus compile/path/dependency checks. test_join_hierarchy exercises new folders/preview stripping, spawn hold, early UI hiding and buy prompt; test_notification_center exercises authored-template retention, queue limits, teardown and actual event dispatch. Updated existing mocks use the new hierarchy. Local tests do not verify Studio visuals, streaming, authored PlotSpawn placement or the external Satchel script.


## UI scripts moved into client controllers (2026-09-09)

The former Construction.Frame.Handler, Settings audio/codes scripts, MobilePlacement.PlacementMobile.Script and Buttons.Builders.Script are replaced by client modules. Keep the authored UI and remove only those old scripts. UIController owns Construction (with Rows), Settings (Audio/Codes), BuilderDisplay, and the placement/MobilePlacement binding; its lifecycle initializes these before Loading.ClientReady and clears signals/timers/tweens/generated rows on HUD replacement. No new automatic LocalScripts.

ConstructionTemplate is exactly ReplicatedStorage.Assets.ConstructionTemplate, containing BuildingName, Timer and Frame (fill). HUD.Frames.Construction.Frame retains ScrollingFrame/ErrorFrame. Rows use the server construction identifier, never display names; UpdateConstructionUI sends start/remove by Id and a full snapshot on ClientReady. Snapshot includes only active sites owned by the player and their remaining/total duration. Construction timers count actual elapsed waits; the client displays elapsed progress but only server removal confirms completion. Sync client and server together.

Settings controls are resolved by exact names within HUD.Frames.Settings: MusicToggle, SFXToggle, Holding.RedGradient/GreenGradient, CodeStatus, CodeSubmit and TextBox. Audio follows SoundService.SFX; Ambience is music. Sound volumes are retained per Instance (including authored zero volume), newly added sounds respect toggles, and local preferences survive HUD replacement for this session. Codes use the existing CodeFeeback spelling and server authority; inline colors/reset cancellation/request timeout are handled locally, with feedback sounds/feed owned by NotificationController. No cash collection feed notifications were reintroduced. Builders Count retains green/yellow/red occupancy. MobilePlacement has a HUD-lifetime CleanupPreview listener even without a Tool session.

Run tools/test_migrated_hud.luau alongside the existing tests (23 total). New source paths and authored dependencies are checked by the read-only Studio audit, but authored UI rendering and real Studio networking remain unverified locally.


## Selling versus placement (2026-09-09)

ToolsModule.Session checks HUD.Frames.SellTool.Visible before acquiring placement and before submitting placement requests. An equip while selling keeps the server-created held miniature and normal sell item updates, but creates no world preview, highlights, placement controls, or placement UI changes. Opening SellTool cancels active placement through its existing scoped cleanup; each tool disconnects its visibility listener on destruction. Closing the shop does not automatically place or begin a placement session (sale responses may still be removing the tool); the next equip outside the shop behaves normally. The sell menu retains its own existing blur/navigation behavior; equip does not alter it. test_placement_lifecycle covers these transitions and request suppression.


## Smooth placement preview and network startup (2026-09-09)

Session.Motion owns retargetable Sine-out movement (0.16s) and rotation (0.18s) using RenderStepped elapsed time. Rotation accumulates clockwise quarter-turns without snapping/reversing on wrap. Cleanup drops motion state; no extra tween objects or persistent render listeners. Geometry, collision, button validity and PlaceBlock submission use the snapped target position/quarter-turn rotation, never the intermediate visual transform. Keep the authored Base-to-PrimaryPart conversion when submitting to the server. Stationary previews avoid repeated transform writes. Sell/intro gates remain unchanged.

ServerBootstrap creates remotes BEFORE WorldRuntime's per-model preview cloning yields. Network.wait checks all descendants with one 60-second deadline and an explicit missing-path/server-startup diagnostic on failure; it never creates remotes client-side and never uses an unbounded WaitForChild. Existing remotes and class checks remain unchanged. Run all 24 test scripts; test_preview_motion checks easing, retargets, wrap, frame-rate equivalence, exact targets and actual bootstrap call order, while test_network checks delayed leaves and timeout diagnostics. Studio animation feel/replication latency still require a Play test.


## HUD travel buttons (2026-09-09)

UIController.TravelButtons binds the authored HUD.Buttons.Up.Buy/City/Sell GuiButtons through Activated and the HUD ConnectionScope. Their old child Handler LocalScripts must remain removed. Buy goes to (-152.191, 5.194, -13.936), Sell to (-152.191, 5.194, 11.564), both yaw 90 degrees. City resolves the current Data.PlotInfo.Plot and Workspace.Plots.Plot<number>.PlotSpawn every click. This preserves the supplied local character teleport approach; no new remotes or server teleports. Missing/not-yet-ready characters/plots safely do nothing; startup/anchored-character holds remain respected. Root velocity is cleared on teleport. No automatic shop opening or menu/camera changes.


## Tutorial completion, owner quest replay and UI motion (2026-09-09)

The full gameplay tutorial remains welcome -> Bank placement/construction -> taxes -> buy Shack -> Shack placement/construction -> completion. Owner replay may reuse a collected Bank, so its construction can finish instantly. Restored tax/purchase narration pauses and the full 7.5-second Shack orbit/zoom plus a readable completion subtitle. Server stage 7 still gates completion. Tutorial cleanup now runs under a cancelable white fade; UIController.Presentation restores the gameplay HUD with Word Hunt-style staggered slide/scale entrances. Standard menu and placement UI exits/entrances use shared.ui.Transitions. Authored Position/Size/UIScale and input state are restored, nested/reversed transitions cancel predecessors, and HUD cleanup cancels active effects. Intro camera ownership is unchanged. Standard navigation no longer drops the next tutorial panel because its predecessor is closing.

The owner explicitly requested post-tutorial quest restart each join: prepareForJoin resets ONLY owner 1790165114's QuestProgression/PostTutorialQuestProgress/PostTutorialQuestComplete alongside tutorial state, once per join, before PostTutorialQuest initializes. Other players keep quest progress; city, inventory and existing balance are preserved. Owner can earn quest rewards again by completing the replayed objectives. Five quests remain Collect Income, Construct 3 buildings, Have 8 buildings, Place 5 roads, Reach 100 population.

Quest UI buffers the latest snapshot while tutorial/white transition is active, renders when the replicated tutorial flag changes, and requests an existing ClientReady refresh after the completion transition. Completion effects cannot overwrite a newer snapshot. Tests cover this replication race, owner-only resets, complete tutorial acknowledgment, UI cancellation/nesting/authored restoration and the existing five objective/reward paths. 25 local tests; actual Studio transition feel and authored template geometry still require verification.


## Rebirth confirmation and civilian appearance (2026-09-09)

RebirthConfirmation owns confirm buttons and RebirthRewards renders only its tagged generated content. Optional IncomeBoostTemp/PopulationBoostTemp/BuildingTemp remain supported under UIController, with readable dark-text fallback rows when missing. Always show income/population/building-XP multipliers, the actual next-level shop unlocks (not free grants), city preservation and cash reset. Automatic canvas sizing keeps long lists scrollable. Levels without building unlocks explicitly say so. First rebirth is x1.15 for all three bonuses, $15,000 starting cash and Ice Cream Store/Donut Store shop access. Rebirth balance formulas remain unchanged.

CivilianSystem.Appearance runs once on cloned rigs before entering Workspace: seven coherent skin tones, eight shirt colours and four trouser colours, R6/R15 body-part mapping and R15 shoes. Classic Shirt/Pants/ShirtGraphic instances are removed from clones so solid-colour outfits show; source ServerStorage.Civilian and accessories/root parts are preserved. No per-frame recolouring or appearance network requests. Existing count/AI/animation budgets stay unchanged. test_rebirth_appearance checks confirmation fallbacks/refresh/authored retention and rig palette assignment/template preservation. 26 local tests; actual textured meshes/appearance and UI contrast still need Studio viewing.


## Collapsed tutorial panels and irrelevant tutorial alerts (2026-09-09)

Navigation-managed popups, including StageOne/StageTwo/StageThree/TutorialItemShop, retain the original expanded Position=(0.5,0.5), Size=(1,1) contract. Transitions.panel explicitly tweens Size from zero to full size and shrinks on exit; generic HUD transitions still preserve authored sizes. Cancellation settles the expanded size so rapid close/reopen or transition cleanup cannot strand a zero-size panel. Do not replace panel Size tweening with UIScale alone: authored tutorial panels may start at Size=(0,0).

BuildingLevelUp remote notices are discarded while IsInTutorial is true (or tutorial data has not replicated), before NotificationController's pending queue. They must not replay on tutorial completion. Ordinary building level-up notifications still display afterward; XP progression and other notification kinds remain unchanged. test_ui_transitions covers collapsed panels/reversal; test_notification_center covers tutorial suppression before buffering and normal gameplay.


## UI transition rollback and plot equip distance (2026-09-09)

User removed the Word Hunt UI effect: shared.ui.Transitions now contains only original centered 0.3s popup Size tweens, cancellation and immediate visibility. No white transition overlays, staggered entrances, UIScale drivers or movement for the regular HUD/placement controls. Tutorial completion reveals the HUD immediately and retains quest refresh/replay fixes. Placement preview move/rotation easing is separate and remains enabled.

TutorialQuests alone slides from (0.5,-0.2) to the explicitly requested Position=(0.5,0.21) over 0.35s on first reveal. Progress snapshots do not restart its entrance; its position/fill tweens clean up with HUD replacement. Building-level-up suppression during tutorial is unchanged.

PlacementAccess checks shared.util.PlacementRange before preview/UI/control acquisition and before submission. Limit is 24 studs from the nearest owned land tile (3D distance to tile bounds), not plot center. A distant equip returns the tool to Backpack and uses the existing NotificationCenter with a throttled Too far message. Open SellTool still permits held-only equip regardless of plot distance. Server BuildingValidation uses the same range for placement requests. No changes to hotbar bindings: user withdrew the 1-9 task and will provide a custom inventory.

Validation of this rollback: all 26 local test scripts and compilation of 244 source / 31 tooling files passed. The path audit flags a newly synced, unmodified Satchel dependency: its bundled TopbarPlus Packages/Janitor requires ReplicatedStorage.Framework in the promise helper, which is absent from exported source. This is separate from the requested changes; Studio availability/use is unverified.

NotificationCenter follows TutorialQuests visibility with a 0.35-second Quad Out Position tween: (0.5,0.28) while quests show, (0.5,0.15) when hidden. Initialization/cleanup restore the default immediately; rapid visibility changes cancel the previous tween. The local gameplay audit verifies both target positions; Studio visuals remain unverified.

## Satchel inventory compatibility (2026-09-09)

Compared the earliest available before-deep-refactor backup's BuildingTools, ToolsModule and ToolSetup. It uses ordinary Backpack/Character Tools with ToolName/IsValid markers and catalog TextureId. Current ToolFactory/Serialization preserve that contract and level/XP/mutation/paid metadata; the backup does not contain Satchel itself. Keep the requested code-generated held models, sell-only equip and 24-stud placement limit.

Satchel loader now claims MyCitySatchelActive before require to avoid duplicate exported loaders. EarlyLoading does not re-enable Roblox Backpack when Satchel owns it. Satchel gates UI, icon and input until MyCityIntroActive=false, honors menu/disabled state, avoids repeated gamepad binding, tolerates missing chat config and ignores equip during character replacement/death. Bundled Janitor promise cleanup no longer requires another game's ReplicatedStorage.Framework (the earlier audit finding is resolved).

BuildingTools observes late marker children instead of abandoning tools after five seconds. Placement ownership is shared between sessions so delayed old cleanup cannot clear a new tool's HUD/highlights attribute; stale Equipped callbacks outside Character are ignored. HUD replacement rebinds sell/mobile controls, raycasts use the current character, and missing preview folders/optional button decorations cannot strand an active session. Original server inventory storage and grant/purchase behavior are unchanged.

Validation: 27 local test scripts pass; 244 source and 32 tooling files compile; path/helper checks pass. test_satchel_integration executes the loader, actual visibility/input handoff function, marker initialization and Janitor cleanup. Placement tests cover delayed equip, HUD replacement and ownership cleanup. These are local mocked tests, not Studio/device validation.

## Daily quest board and full owner reset (2026-09-09)

The Quests button at HUD.Buttons.Left.Quests now opens a generated, responsive DailyQuests panel under HUD.Frames. UIController.DailyQuests owns View/QuestRow/Widgets, six progress cards, cash rewards, explicit claim buttons, claimed states and the countdown. It uses the existing popup navigation and notification center. Generated instances/connections/tweens clean up on HUD replacement. No LocalScripts or authored templates need to be added to the UI. Existing five post-tutorial quests remain separate and unchanged.

DailyQuestCatalog defines 40 objectives over income collections, earned city income, cash building purchases, cash spent in that shop, completed non-road city buildings, road pieces, population and online time. Each board has two Easy, two Medium and two Hard entries with distinct metric families; cash rewards range from $200 to $16,000. Boards change at midnight UTC every 24 hours, exclude the previous board's quest IDs, and persist across rejoins. City/population goals use peak totals for the day; picking up/replacing one building cannot increment an additive placement counter. Other counters track new gameplay after tutorial. QuestSignals accepts only server gameplay facts from successful income collections and cash purchases; it is not a remote. No Robux purchase is required.

DailyQuests.Board contains deterministic selection, validation, progress, claim and snapshot rules; Runtime watches city changes and elapsed online time; init owns lifecycle/remotes/reward saving. Progress/claimed flags persist as DailyQuests in the existing Data_1 envelope. Claims validate the current day, active quest, completion and claimed marker under RequestGuard. Cash and the claim marker are saved in the same profile snapshot. On transient save failure the in-session marker remains claimed and normal autosave retries; repeated requests cannot credit cash again. Online/offline midnight rollover is handled; there is no unclaimed reward carryover.

Latest user instruction supersedes earlier owner city/balance preservation: TutorialConfig.ResetProgressEveryJoin=true applies ONLY to owner 1790165114. OwnerReset discards gameplay data, leaderboard data, daily quests and code redemptions before restoration on every join. Owner starts with $500, no buildings/constructions/inventory/expansions, zero rebirths, default city name, tutorial stage 0 and default daily/post-tutorial progression. The legacy code store is bypassed only for this server-marked fresh test session; codes still redeem once per join. Lease, receipt and transfer records remain intact. Other users keep their profiles. Existing Roblox gamepass/badge ownership is not changed.

Validation: 29 local test scripts pass, including 2000 balanced board rotations, all 40 objective/reward paths, saved rejoin, duplicate/concurrent/stale claims, failure-safe claim retry, online midnight, city sampling, six generated UI cards and owner full-reset loader/save/rejoin. All 254 source and 34 tooling files compile; path/helper audits pass. Studio UI layout, live saves and multiplayer/device behavior remain unverified.

## Quest panel visibility, tutorial notifications and placement highlights (2026-09-09)

User confirmed the main tutorial was finished; active post-tutorial quests must not block the daily quest panel. DailyQuests now opens explicitly (recovering a collapsed or locked popup), restores HUD.Frames visibility, starts with full root dimensions, and uses ZIndex 100 with increasing child layers so authored HUD artwork cannot cover its generated contents at lower layers. Six disabled loading cards render before the server snapshot. Main tutorial and active-placement restrictions remain; the five post-tutorial objectives are independent. Studio layout has not been inspected, so the exact prior visual obstruction is unconfirmed.

NotificationController owns the entire NotificationCenter visibility. It hides and clears it while tutorial data is unknown, IsInTutorial=true or the intro is active; property/attribute listeners keep that gate current and prevent other UI handlers from revealing it. All notification kinds are discarded before queue/sound/clone work during tutorial, so none burst out afterward. Existing default/quest-offset positioning remains.

Restored the previously commented-out general placement land highlights: one green SelectionBox per owned BasePart with visible outlines and translucent fill. Session creation/cleanup owns them for all building previews, including tutorial placement. TutorialController now only clears its older copies, avoiding duplicate owners. Selling held-only tools and rejected distant equips do not create world highlights. Re-equipping clears old boxes first.

Validation: all 29 local test scripts pass, including six pre-snapshot loading cards, recovered collapsed panel/hidden parent, layer inheritance, daily panel while post-tutorial quests show, full tutorial notification suppression and direct highlight creation/recreation/cleanup. Studio visual/input verification remains pending.

## Civilian walking and stuck recovery (2026-09-09)

CivilianSystem now chooses reachable nearby walking targets before requesting navmesh paths, accepts a 1.1-stud waypoint arrival distance compatible with Humanoid stopping, and uses short 0.35-0.9 second pauses. Completed Road models are walkable instead of obstacles; unfinished constructions and buildings still block routes. Low road surfaces are included in ground height. R6 navigation clearance includes body height, and cloned rigs clear Sit/PlatformStand before moving.

Actual travel resets a separate inactivity watchdog. Stalls retry quickly; three failed movement attempts or 15 seconds without travel retire the actor so the existing capped scheduler can replace it. Errors are logged once per city instead of silently removing every failed actor. Counts, server cap, random appearances and KingdomWars walk animation IDs remain unchanged.

Validation: civilian movement/geometry/scheduler regression tests and rebirth/appearance tests pass. All 254 source and 34 tooling files compile; module-path/helper audits pass. These are local mocked tests; actual ServerStorage.Civilian physics, animation permissions and city movement still require Studio verification.

## Quest button and independent generated display (2026-09-09)

The latest quest fix supersedes the prior HUD.Frames.DailyQuests location. View now owns PlayerGui.MyCityDailyQuests (ScreenGui), ordered above HUD and enabled with HUD. Its generated DailyQuests frame opens/closes immediately at full size; authored Frames position, size, clipping and layouts cannot hide it. Navigation retains shared currentOpenFrame behavior, closes it when another menu opens, and clears it during stuck-effect cleanup. Cleanup destroys the whole generated ScreenGui.

DailyQuests.ButtonBinding binds GuiButtons named Quests anywhere under HUD.Buttons, explicitly enables Active/Interactable, and observes late/replaced buttons without duplicate bindings. Setup runs before unrelated authored menu initialization; Buttons no longer separately binds Quests. Main tutorial and placement restrictions remain, but the five post-tutorial quests do not block it. Six loading cards appear before a server reply. Sync the new ButtonBinding child module as well as View/init, Navigation, Buttons and Lifecycle.

Validation: test_daily_quest_ui now executes button events through actual Navigation with disabled button input and hidden/zero-size authored Frames; verifies opening, closing, reopening, late button binding, HUD enable mirroring, six cards, claims and screen cleanup. Quest UI, placement lifecycle and transition tests pass; all 255 source and 34 tooling files compile; path/helper audits pass. The user's precise Studio obstruction remains unconfirmed without live hierarchy/input inspection.

Civilian pace update: WalkSpeed is now 1.5 studs/second, half the previous 3, per user request. Both spawn and movement retries read this shared config.

## Group Police Station after tutorial (2026-09-09)

PlayerRewards.giveGroupReward now runs deferred from Loading.ClientReady, after the client has observed tutorial completion. The server checks MyCityLoaded/inventory readiness, IsInTutorial=false, saved GroupRewardClaimed=false and membership in group 1050526813. The load-time and TutorialSystem.finishTutorial grants are removed so the reward alert is not sent while tutorial notifications are suppressed. The existing tutorial completion presentation already requests ClientReady; returning completed members are also eligible.

The grant uses RequestGuard plus a per-player in-flight guard, retries temporary membership errors/busy inventory, rechecks eligibility after yields, creates PoliceStation through ToolFactory, and saves the tool and claim flag together via PlayerDataModule's inventory snapshot hook. No rank threshold or existing PoliceStation inventory-name check blocks membership rewards. Transient save failure retains the in-session tool/marker for normal autosave retry. A persisted claim prevents repeat grants; the existing explicit owner fresh-profile reset resets it for owner testing. NotificationCenter displays exactly 'Group reward: Police Station'.

Validation: new test_group_reward executes membership/tutorial gates, temporary lookup failure, concurrent/repeated calls, saved claim on rejoin, backpack recovery, failed-save duplicate prevention and departure/tutorial rechecks. It and progression/startup/cleanup tests pass; all 255 source and 35 tooling files compile, helper checks pass. Studio group lookup, inventory presentation and live saving remain unverified.

## Authored Daily Quests panel (latest, 2026-09-09)

The user replaced the generated quest display with HUD.Frames.Quests.Frame. DailyQuests.View now binds that authored panel, its Header descendant TextLabel, Content ScrollingFrame, Template and X. The old MyCityDailyQuests ScreenGui generator and Widgets module are removed. Only legacy instances tagged MyCityGenerated are removed; authored UI is preserved. Keep ButtonBinding's enabled input/late binding and Navigation's immediate quest opening.

Clone Template directly into Content six times with LayoutOrder 1-6. User explicitly confirmed Content.Top and Content.Bottom are padding frames, NOT row containers: preserve their sizes/children, set orders 0 and 7, retain the existing UIListLayout with LayoutOrder sorting and use automatic vertical canvas sizing. Template remains hidden. Cleanup/day replacement destroys only owned clones; never clear Content or destroy the authored panel. No frames or text labels are manufactured as UI replacements.

Each clone uses Title, Difficulty TextLabels, Reward (explicitly confirmed Template.Reward), Progress TextLabel, Progress Frame.Fill and Claim.TextLabel. Resolve duplicate Progress names by class; do not confuse the bar Frame with the text label. Header reads Daily Quests (19H 20M), based on server reset time and elapsed client time. ClaimStyle restores the exact ready state: text Claim, stroke RGB(31,106,40), gradient #44ff0b to #aeff45. Loading, In progress, Claiming... and Claimed are disabled grey states. Failed claims restore eligibility/green from the current snapshot. Server claim validation and daily reset/persistence are unchanged.

Validation: authored template cloning, six ordered direct Content children, preserved Top/Bottom dimensions, nested header countdown, Reward binding, duplicate Progress lookup, exact gradient endpoints, disabled/ready/retry states, day replacement and authored cleanup all pass in test_daily_quest_ui. Transition/placement regressions and required network/startup/persistence/receipt/security/cleanup/progression checks pass. All 255 source and 35 tooling files compile; path/helper audits pass. Studio's actual authored layout and device appearance remain unverified.

Quest button wording: incomplete quests show Locked (grey/disabled), replacing In progress. Other claim states are unchanged.

## UIController templates in Assets (latest, 2026-09-09)

User moved every authored template formerly under UIController directly into ReplicatedStorage.Assets. RebirthConfirmation now passes Assets to RebirthRewards, resolving IncomeBoostTemp, PopulationBoostTemp and BuildingTemp there. Weather resolves Assets.WeatherTemplate, makes its clone visible and safely defers if the template has not replicated. No authored template lookup remains under UIController. The authored daily quest Template remains HUD.Frames.Quests.Frame.Template per its separate explicit hierarchy. ConstructionTemplate was already in Assets. Sync RebirthConfirmation and remotes.Weather; the Studio audit now checks the four moved templates in Assets.

Existing rebirth/appearance tests and compilation of 255 source / 35 tooling files pass. Studio template rendering remains unverified.

## Remaining script-owned assets moved to Assets (2026-09-09)

Audited all exported script-relative lookups after the user's broader relocation request. ToolsModule.Session.Preview now clones ReplicatedStorage.Assets.ArrowsGUI and BaseSelection; arrows are explicitly enabled/adorned and cleanup still belongs to the placement session. TutorialController.Guidance now clones Assets.TutorialBeamAnchor and BeamTemplate into the existing Workspace.Misc.PlayerAnchors runtime folder. BuildingXP.Effects now reads Assets.SparklesGold, SparklesBlue and SparklesPink. ProximityPromptController also resolves named Theme BillboardGui templates from Assets, with Assets.Default fallback. Source templates stay untouched.

No remaining game asset lookup is rooted under a script/module in exported source; relative requires still intentionally resolve code modules. Satchel's package/module references and style attributes remain code dependencies. ItemName appears as a live HUD/shop template label (SellTool.Frame.ToolItem.ItemName and item cards), not a script-owned template. PlacementHighlight has no active asset lookup; owned-land highlights are still code-created SelectionBoxes. The earliest before-deep-refactor backup confirms the same sell ItemName binding and old ToolsModule ArrowsGUI/BaseSelection names. Do not revive unused assets or move live HUD labels based on their names. Hidden scripts inside Studio assets are outside this source audit.

Validation: placement regressions now execute Assets arrow/selection cloning and tutorial anchor/beam creation/cleanup with no script-owned templates. XP particle tests verify all three tier sources, replacement and source preservation. Required core checks, tutorial tests, source compilation (255 source / 35 tools) and path/helper audits pass. Live Studio hierarchy/visuals are not verified.

## Daily quest display priority (2026-09-09)

DailyQuests sorts the six display cards on each render: completed/unclaimed first (including pending claims), unfinished next by descending progress/target percentage, claimed last. Equal progress retains original board order. The server snapshot is not reordered and claims still use quest IDs. All card LayoutOrder values, including loading placeholders, are 2-7. User-confirmed padding orders are Content.Top=1 and Content.Bottom=100, superseding earlier 0/7 values. Local authored quest UI tests cover mixed states, percentage versus raw totals, completion/claim movement, ties and all layout bounds.

## Train movement and ambient traffic cleanup (2026-09-09)

TrainSystem and HighwayTrafficSystem are now small configuration modules delegating to systems.world.AmbientTraffic (init, Model, Routes). One shared Heartbeat updates all active vehicles. Each train/car gets one whole-model PivotTo derived from its captured start/end CFrames and elapsed trip time. Removed train PrimaryPart tween plus SetPrimaryPartCFrame feedback, per-vehicle connections, completed-car connection retention and sleeping spawn loops that survived rapid stop/restart. Model preparation anchors all parts and disables collisions/touches/queries, strips embedded scripts/prompts before parenting, and preserves authored primary-to-pivot and carriage offsets. Source assets remain untouched. Whole-model movement is still server-replicated each frame; this does not claim to eliminate replication bandwidth.

Train routes retain Point3->Point4 / Point1->Point2, +90-degree authored rotation and 40-second trips with 20-40 second spawn intervals. Only one train occupies each route, so the two available routes permit at most two visible trains despite the existing global cap of three. Cars retain Point3->Point4 (-90) / Point6->Point5 (+90), speed 5, cap 25, 1-4 second spawns and +/-1.8 lane offset; offsets and rotation now stay consistent throughout the trip. Missing ActiveCars is created. Invalid/zero-length routes are skipped; delayed frames retire completed trips without overshoot or bursts of catch-up spawns. Initialization and stop/restart are idempotent.

WorldRuntime batches stripped building preview preparation using a six-model / approximately 3ms slice instead of an unconditional task.wait per model. Large descendant scans check the time budget every 64 children while the clone remains detached. Once complete, repeated start does not reclone every asset. Authoritative restore/save ordering and early loading UI stay unchanged.

InventorySystem.loadInventory now shares RestoreBudget across saved tool decoding, reducing uninterrupted work when multiple large inventories join. It stages tools until validation completes and destroys all staged tools on decoding failure/departure/backpack replacement. Saved inventory records and ToolIds are unchanged; failure still refuses partial restoration.

Validation: full local test suite passes, including new ambient vehicle rigidity/one-writer/shared-connection/route-cap/delayed-frame/restart tests and a 60-tool inventory restore/failure/departure test. The mocked 24-template startup now yields three times instead of the former 24 forced waits. All 258 source / 37 tooling files compile and path/helper audits pass. This is source/mock evidence; actual train flicker, authored model appearance, Studio FPS/replication and join durations still require a Play/profile check.


## Claim badges and template-only rebirth confirmation (2026-09-09)

ConstructionTimer no longer emits BuildingStarted notices and NotificationController no longer binds or styles that notification. The unused network entry is retained for compatibility; construction tracking/progress and completion notices remain active.

UIController.ClaimAlerts binds the authored Alerts child (plural) of DailyReward and Quests GuiButtons under HUD.Buttons, including late-replicating badges. Both initialize hidden. Daily rewards use the authoritative canClaim/currentDay/claimedDays snapshot; the eligibility deadline keeps requesting updates while the panel is closed, with request throttling. A successful claim's snapshot clears the badge. Quests show the badge for any completed, unclaimed, non-pending quest; rejected claims restore it, claimed snapshots clear it, and expired boards hide it and request a fresh board even while closed. HUD connection scope owns the listeners/timers. No badge UI is created.

RebirthRewards now clones only Assets.IncomeBoostTemp, PopulationBoostTemp and BuildingTemp (and optional XPBoostTemp if authored). Boost cards retain Now/Next values and building cards retain BuildingName/BuildingIcon binding. Removed generated summary, fallback boost/building labels, headings, empty-level text and generated UIListLayout. Missing templates produce no substitute UI. Cleanup only deletes tagged reward clones, preserving authored children/layouts. Gameplay rewards and the existing city-preserving/cash-reset policy are unchanged; the former generated preservation/reset summary is no longer inserted.

Validation: test_daily_quest_ui covers authoritative daily eligibility, closed-panel deadlines, late badges, rejected/pending/claimed quests and expired boards; test_notification_center verifies construction starts are silent; test_rebirth_appearance verifies template-only rendering, missing templates and authored-child preservation. Required network/startup/persistence/receipt/security/cleanup/progression checks, source compilation (259 source / 37 tooling files), and path/helper audits pass. These are local mock/source checks, not a Studio visual test.
