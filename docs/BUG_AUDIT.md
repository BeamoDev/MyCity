# MyCity backend audit and refactor

## Repeated join refusal recovery (2026-09-14)

The report is a screenshot of a player saying the city-load/rejoin message repeats. The user has no affected username or server error, so the player's specific root cause remains unconfirmed. The current standalone tree has 266 source files.

**Confirmed source defect:** acquisition had three attempts and only 1/2/3-second waits, while the saved session lease lasts 180 seconds. A quick rejoin while the old server is releasing its profile, or after its server crashed, could repeatedly hit the same lease and kick. Acquisition now waits automatically on the loading screen, polling every five seconds through a 190-second window. Successful first attempts remain immediate. Five consecutive service errors use 2/4/8/10-second backoff before refusal. Departure cancels polling within 0.25 seconds; in-flight Roblox requests are not cancellable and may exceed the deadline.

**Failed-load release:** the former one-shot release rewrote the session's working record. SessionStore.release now checks the stored session ID and only removes that lock from the current persisted record, with three attempts on service errors. It also safely cleans up ambiguous acquisitions whose response may have been lost. It preserves gameplay, receipts and a newer server's ownership. Normal loaded-player saves remain unchanged. This uses Roblox's [atomic UpdateAsync cancellation contract](https://create.roblox.com/docs/cloud-services/data-stores#update-data).

**Diagnostics and failure boundaries:** PlayerLifecycle now logs `stage=<stage>` and a traceback, exposes MyCityLoadStage/MyCityLoadErrorCode, and clears both readiness flags before abandoning a failed city load. Optional badge setup runs outside the load-failure boundary. Codes distinguish outstanding sessions, exhausted storage errors, profile restoration, and world restoration stages. No saved building is discarded, guessed, reset or skipped to force a successful join.

Local validation: 40 suites pass. New test_load_recovery executes the real profile loader and SessionStore for delayed release, crashed-server expiry, still-active locks, departure while waiting, temporary/permanent service errors, a committed acquisition with a lost response, release retries, failed restoration, working-record mutation and stale-release protection. Expanded test_shutdown verifies failed Buildings/Quests stages, revoked readiness, traceback reporting, optional badge failure isolation and normal/canceled shutdown saving. All 266 source and 45 tooling files compile; path/helper checks pass.

Integration remains unverified. Sync `ServerScriptService.server.persistence.PlayerDataModule` with its updated `SessionStore` child and `ServerScriptService.server.bootstrap.PlayerLifecycle` together; restart into fresh servers. Test an ordinary returning player switching servers before the old save finishes, and an interrupted join followed by rejoin. Confirm inventory, placed buildings, constructions, cash and receipts remain intact. If the report persists, collect the new kick code and the matching `[Data]` or `[Lifecycle]` server warning with user ID and traceback. A missing authored building/template or malformed saved record still requires its specific repair; repeated rejoining cannot repair that data or asset. No production storage was accessed or release published here.

## Startup/shutdown race fix (2026-09-10)

The supplied Studio log showed PlayerLifecycle registering BindToClose after yielding bootstrap work, when Play was already stopping. New `server/bootstrap/Shutdown.luau` registers once before SpawnGuard, network/assets or system initialization. It marks closure/departure immediately and accepts the lifecycle save callback before any player load starts. A bootstrap resumed during closure returns; preview preparation cancels between work slices. An already-closing Script Sync session refuses startup safely.

PlayerLifecycle is idempotent, rejects queued departing/closing joins, checks cancellation after yielding load stages and abandons partial restorations without a late kick or partial save. A DataStore acquisition returning after departure releases the original record before creating player data. Spawn holds reject late departing-character events, and plot relocation verifies the current character/departure status after its bounded root wait. Normal loaded players retain the shared PlayerRemoving/BindToClose save path.

The separate Studio message `Character cannot be changed as Player ... is being removed` had no source traceback. Exported source contains no LoadCharacter call or direct Player.Character assignment; these guards fix late gameplay work, but an engine or unexported-script origin cannot be confirmed from that message alone. Do not claim that message reproduced or resolved in Studio without a fresh Play/Stop test.

Validation: 39 local test suites pass; all 266 source and 44 tool files compile; path/helper audits pass. New test_shutdown executes early registration, already-closing refusal, stop-during-bootstrap, cancellation while data is loading, queued join refusal and one normal shutdown save. Data-schema tests execute a departure during successful profile acquisition and verify unchanged-record release. Studio stop-during-load remains unverified.

Sync the new ModuleScript `ServerScriptService.server.bootstrap.Shutdown` with the updated server tree, then start a fresh Play session. The read-only audit and migration module-class table include it.



## Latest hardening result ? 2026-09-10

See [SYSTEM_HARDENING.md](SYSTEM_HARDENING.md) for the complete current per-system ledger. Earlier dated findings below are historical where the ledger supersedes them. This pass fixes paid-target compensation, durable ambiguity blocking/feedback, destructive deletion, the early rebirth jump, service-provider selection, recurring simulation work, income rescans, ambient server replication, stale placement responses, daily claim ordering, name failures, social caches and recoverable like cash rewards. It adds six runtime modules and six focused test suites; all source roots must sync together.

Unresolved limits are explicit: ambiguous historical receipts remain pending by user choice; foreign active owner sessions defer transfers; permanent replay-protection history needs archival at extreme scale; authored assets, approved audio, live storage/commerce and device/performance evidence require Studio or published testing. No claim of universal bug freedom or 100/100 production optimization is supported.


Latest hierarchy/join follow-up (2026-09-09): replaced the removed NotificationsFrame/StoleAlert dependencies with authored HUD.NotificationCenter.Template; routed missing income/error/code/like feedback into that feed. Updated server building assets to ServerStorage.Buildings, all plots to Workspace.Plots, and temporary objects to Workspace.Misc. Added generated client-only placement templates, centralized buy-area prompt binding, early loading/hidden inventory before network waits and a server spawn hold until Play/UI handoff. The user dropped nuke work; no nuke system was present in current or original sources. See AGENTS.md and MIGRATION.md for the latest mapping. These updates are locally tested, not Studio-verified.

Latest performance pass (2026-09-09): removed fixed per-building prompt waits and per-restored-building income rescans; added a shared restoration frame budget, grouped plot-stat provider snapshots, direct verified owner lookup, successful game-pass query caching, single builder finalization during restore, and fewer server GUI/route updates. See LOADING_PERFORMANCE.md for local operation-count evidence and remaining engine profiling. Earlier quadratic-scan findings below describe the pre-optimization source; service-provider selection and authored traffic/model costs remain outstanding. The preceding gameplay audit fixed elapsed income accrual; earlier fixed-tick descriptions are historical.

Latest rebirth change: city, construction, inventory and land now survive rebirth; the user retained the existing cash reset. Confirmation now uses authored reward cards only; the later template-only follow-up removes its generated outcome summary. Schema 5 moves Population to Data.PlayerInfo.Population and leaves only Cash/Rebirths in leaderstats. Source consumers and migration tests are updated. Requirements grow beyond rebirth 50 rather than allowing an infinite chain at the old population plateau. Earlier descriptions of destructive rebirth below describe the previous implementation. Permanent Delete, receipt/transfer recovery, income timing and service coverage remain separate outstanding work.

Latest shop follow-up: the user confirmed both ItemTemplate and PurchaseFrame under ReplicatedStorage.Assets.Shop. ShopController/Lifecycle now waits for both there before binding shop updates, fixing the previously unresolved template lookup in local source. The existing regression suite verifies these exact template references. Studio play verification remains pending.

Latest 22:51 log follow-up: the user confirmed `Items` moved to `ReplicatedStorage.Assets.Items` and the sell prompt lives at `Workspace.Map.Interactives.SellArea.Part.ShopPrompt`. All seven runtime Items lookups and the sell binding now use those paths; Studio audit/migration instructions match. The ShopController Clone error is a missing ItemTemplate under ShopController; the current locations of ItemTemplate and PurchaseFrame remain to be confirmed. The read-only Studio audit now prints candidate template paths and Sound instances referencing 6525690145. No substitute UI or sound was fabricated.

Reviewed 2026-09-08 against the standalone local source. Scope: all 61 exported original Luau files, with the current tree expanded into 187 files. There is no local Git repository or branch history to inspect. Studio-only scripts/assets may add behavior beyond this export.

## Major issues repaired

| Area | Previous failure | Current implementation |
| --- | --- | --- |
| Startup and hierarchy | Moved scripts still required old parents; deleted remotes stopped startup | Single client/server entry points, feature folders, corrected paths, complete server-created network schema and client leaf waits |
| Failed loads and overlapping sessions | Default/partial data could be saved after a load failure; simultaneous writers could overwrite a city | UpdateAsync lease in Data_1, strict load failures, original-record abandonment after partial restoration, stale-save refusal |
| Nested data | Deep folders did not round-trip and duplicate scalar keys were ambiguous | Recursive codec, legacy folder-name support, duplicate-key rejection; placed-building saves update existing trackers |
| Inventory and tool creation | Competing global factories and early snapshots could lose inventory | One factory, serialization with unique IDs/paid status, restore-before-snapshot, respawn readiness and central tool initialization |
| Remote authority | Clients could submit foreign objects and unconstrained transforms; mutation races were possible | Owned object/tool checks, finite transforms, footprint/height/overlap validation and per-player mutation guard |
| Construction | Broken timer function name, separate builder tables on restore, missing paid CSV flag and destructive completion order | Canonical timer/builder tables, 12-field persistence, rollback on failed setup, placed record committed before removing construction, deterministic IDs |
| Purchase receipts | Retry/rejoin could grant twice; target selection was mutable; transfer removal was not durable | Persisted intents, receipt plans/applied markers, one-profile reward snapshots, owner transfer markers before buyer grants |
| Tutorial | Free/duplicate client-requested tools or milestones; Shack completion did not advance; reconnect lost stage | Server stages, real cash purchase, Bank grant guard, Shack/offline completion and legacy resume |
| Quests and daily rewards | Duplicate construction count, yielding completion rewarded twice, streak timestamp overwritten before checking, repeated button listeners | Single milestone, completion guard, reward preparation, previous timestamp, one button binding |
| Income/population/friends | Reads minted income ticks; payout and displays used different formulas; advertised friend bonus was unpaid | Shared BuildingEconomy calculations, explicit elapsed accrual, server friendship attributes and client attribute updates |
| Redemption codes | Used-code marker saved separately from cash; malformed/concurrent requests reached storage | Typed/guarded requests; legacy history read; new cash and marker saved together in Data_1 |
| HUD/prompts/chat | HUD replacement retained callbacks; prompt UIs detached without destruction; chat shake connections accumulated | Controller connection/task scopes, initialization cancellation, prompt destruction/cleanup, expiring shake connection and nil sender handling |
| Building presentation | Unsupported task handles in attributes, wrong XP billboard path, missing Residential industry metadata | Private pulse thread tracking, corrected billboard path, explicit residential catalogue metadata |
| Configuration | Optional webhook helper embedded a credential | Active source reads optional ServerStorage.MyCitySecrets.PurchaseWebhook; no outbound webhook called by this work |

## Remaining limits and release blockers

These are not claims that every possible gameplay bug is fixed.

1. **Studio migration and integration are unverified.** Run MIGRATION.md and the hierarchy audit. Authored dimensions, UI names, ModuleScript classes, enabled legacy scripts and TopbarPlus cannot be proven from source. Hidden HUD/loading/tool/admin implementations were not available locally. The local chat relay only forwards its author's commands; authorization in an external ControlPanel server remains outside this export.
2. **Purchase recovery has explicit unresolved cases.** A legacy receipt may have no persisted target. A steal may target an item already sold/deleted/completed or an owner with an active lease on another server. These remain NotProcessedYet; there is no cross-server transfer worker or invented compensation. An intent stranded across a disconnect before the platform confirms/cancels its prompt can block a later prompt of the same product. See the latest hardening ledger for new saved-descriptor compensation and durable ambiguity blocking. Reconcile against actual receipt history rather than discarding it blindly.
3. **Old servers ignore new session locks.** Drain old SetAsync writers during deployment. A blind rollback to old serialization can drop new metadata. Real DataStore throttling, lease contention, shutdown deadlines and receipt retry timing need dedicated tests.
4. **Persistence metadata grows.** Receipt IDs, transfer markers and redemption records remain for replay protection. Monitor profile size before adding high-volume products; introduce archival only with a design that preserves deduplication.
5. **Authored placement needs play coverage.** Server checks cover bounds/height/yaw/overlap, but grid phase, special buildings, rotations on Plot5-8 and all template sizes have not been verified in Studio.
6. **Secondary stores remain separate.** CityNames and CityRatings retain their existing namespaces. City likes are atomically deduplicated, but the owner's small online cash notification/reward is not a cross-store durable transaction. Weather's automatic cycle remains disabled as in the prior source; enabling it would change game behavior.
7. **Infrastructure failures remain possible.** Retry exhaustion is reported and failed loads are refused; no code can guarantee a final write during an outage or server termination. Real recovery, device and long-session testing is still required.

## Local validation

- `validate_source.luau`: compiles every source/tool Luau file without running gameplay.
- `check_paths.py`: resolves local literal requires; TopbarPlus.Icon is explicitly external. Two dynamic imports are manually reviewed.
- `test_network.luau`: empty/idempotent startup, complete schema, delayed descendant replication, server-only creation and wrong-class errors.
- `test_startup.luau`: late/early readiness, tutorial selection, listener ordering and duplicate HUD initialization.
- `test_persistence.luau`: lease contention/expiry/release/stale writes, malformed profiles, recursive/legacy codec and duplicate keys.
- `test_receipts.luau`: receipt replay, partial save failure, same-server retry, simulated crash/rejoin and unloaded-profile rejection.
- `test_security.luau`: owned placement, invalid/foreign tools, malformed/tilted/floating/out-of-bounds/overlapping placement, foreign buildings, guard/rate/leave behavior.
- `test_cleanup.luau`: callback disconnection, task cancellation, stale callback rejection and scope reuse.
- `test_progression.luau`: authoritative tutorial order, Shack completion, legacy resume, malformed/previously redeemed codes, lookup/save failures and retry deduplication.

These are source and mock-runtime checks. No Studio play session, real payment, published server, mobile session or live DataStore operation was executed. The edit-mode migration and read-only Studio audit are provided for the next integration step.

## Follow-up fixes from the supplied Studio log

- Corrected five extracted-helper references that remained bare after `..` or `...`: Shop UpdateShop, shop countdown formatting, two rebirth population labels and building-info number formatting. Compilation alone did not catch these runtime nil calls; a new dependency check and executed callback tests cover them.
- Replaced the shop timer's nested Heartbeat wait with its deltaTime argument.
- Moved default prompt lookup to Assets.Default, as confirmed by the user. Prompts without PromptVal are treated as unrelated prompts and skipped without log spam.
- Split eight remaining server implementations into 34 additional child modules. Updated the migration manifest and full Studio source audit.
- Supplied an idempotent Edit-mode repair for GUI-embedded FX scripts referencing Modules. These scripts were not exported locally; the repair must be run in Studio.
- The supplied log still runs the old server data loader. Current local modules passed checks, but complete sync and a new Studio test are required. The denied sound is an authored asset permission issue, not a source path fixed by the refactor.

## Latest restoration fix: code-defined player data

The newest user log confirms modular bootstrap v2, a generic restoration kick, quest/rebirth waits and missing-Data cleanup errors. The user then explicitly removed the data-template requirement. DataSchema now supplies all static defaults from code; no PlayerDataModule.Data or leaderstats assets are read. The old hidden exception could have been a missing template, but the log alone did not prove its exact cause.

Restoration now reports its actual exception, preserves the original record on failure, and fills missing quest/daily/tutorial fields without overwriting existing saved values. Progression initialization runs from PlayerLifecycle after data restoration; plot cleanup handles players without Data and checks current ownership. test_data_schema.luau covers these paths against the actual implementation. The external GUI FX repairs and sound approval remain Studio-side work.

## LastUpdate rejection: repaired in schema 4

Schema 3 accepted numeric StringValue timestamps but rejected empty/non-numeric strings and other historical scalar classes. Schema 4 normalizes known saved fields before creating Instances and before saving, matching Word Hunt's normalize/load/mirror/save pattern. Valid timestamps convert to IntValue; invalid timestamps use the current time. Valid saved balances/items and receipt/transfer records are preserved. The actual loader/save/rejoin regression test passes with a blank legacy StringValue LastUpdate and verifies that the normalized record reloads successfully.

Sync DataSchema.luau and PlayerDataModule/init.luau together. There is no DataStore reset or key/namespace migration. Studio/live verification is still pending.

## Cash feedback and current optimization review

Cash display now animates with the current KingdomWars counter, bounded floating deltas and owned teardown. tools/test_cash_feedback.luau covers real effect/binding code under mocks, including rapid reversal and HUD replacement. This is not Studio visual evidence.

[OPTIMIZATION_AND_FEEDBACK.md](OPTIMIZATION_AND_FEEDBACK.md) records source-backed unresolved income timing and mixed-range service coverage defects, recovery limits, system sizes, optimization candidates and the supplied historical feedback. Those backend findings were documented rather than silently changing economy/coverage rules as part of the UI effect. In particular, the earlier fix preventing reads from minting income does not fix the scheduler's fixed-one-second accrual drift.

## Owner replay and tutorial cleanup

Implemented owner-only replay for 1790165114 (verified in Word Hunt source), preserving the existing city/balance. Fixed stale delayed stage presentation, missed-event dependence, subtitle completion races, uncanceled delayed camera zoom, unconditional camera/root cleanup, and touch/controller Start bindings. Completion retries until acknowledged by the server. A required tutorial Shack purchase no longer fails solely because randomly generated stock is zero; cash requirements remain. Old city evidence and old construction completions cannot skip the owner's new replay. Tutorial analytics failures no longer interrupt gameplay; owner replay events are excluded.

Source/mock tests cover owner vs normal-player startup, repeated preparation, retained city collections, Bank tool reuse, unrelated completion rejection, zero-stock paid Shack gating, replicated client catch-up, stage cancellation, completion retries/acknowledgment, stale subtitle callbacks and camera restoration/canceled zoom. These are not Studio results. Biggest remaining errors: missing shop template hierarchy and sound access from the supplied log; safe restore needs a new Studio play test after Items/Interactives sync. Highest backend priorities remain pending purchase/transfer recovery, fixed-tick income drift and nearest-provider coverage selection; highest performance candidates remain plot-stat scans, recurring builder updates, ambient traffic replication and per-building XP work. See OPTIMIZATION_AND_FEEDBACK.md for evidence and proposed fixes.

## Removed ToolBuildings startup dependency

ToolFactory formerly waited at module load for the deleted Assets.ToolBuildings folder, potentially stalling all dependent systems. Tools now come from code and held miniatures come from Assets.Buildings through HeldBuildingVisual. The Studio audit no longer requires ToolBuildings or Assets.Tool. Local tests execute real factory/serialization code and mocked model geometry to verify identity/metadata round trips, miniature scale/weld setup, script removal, original model preservation and absent-visual fallback. Actual Roblox Model scaling/hand appearance and placement remain Studio checks. The separate GUI Tutorial.Handler legacy Client lookup still requires the unexported Handler source from the user.

## Supplied Tutorial.Handler integrated

The previously unexported Handler is now implemented in IntroController (init/Camera/Presentation), owned by HudBootstrap. Fixed the old Client.Init wait, completion-listener race after Play, tutorial classification before data readiness, frame-rate-dependent orbit, uncanceled reveal work and duplicate initializer ownership. Intro cleanup restores the camera/root/blur it acquired. Local intro and bootstrap tests pass. The user must remove StarterGui.Tutorial.Handler after syncing; authored UI/assets stay in place. This resolves the outstanding request for that source; Studio/live behavior remains to be verified.


## 2026-09-08: equip/replay/intro regressions repaired

- **High, fixed in source:** Session/Lifecycle replaced only its local state table during cleanup, splitting equip state from placement/input/preview state. Shared state is now reset in place; stale placement replies cannot clean a new equip, and cleanup no longer scans/destroys all preview-named models.
- **High, fixed in source:** Intro bypassed tutorial players and began only after data-dependent controller initialization. It now starts loading camera/blur early, shows Play on owner replay too, handles late camera/character/map replication, and restores ownership on exit.
- **Medium, fixed in source:** Tutorial green tiles only listened for equip. They now follow actual placement/equipped state, clear on unequip/cancel/destroy/stage change, and ignore late equip remotes.
- **Medium, fixed in source:** UI initialization forced CashDisplay visible during tutorial. Tutorial status now owns CashDisplay/FriendBoost visibility.
- **High, fixed in source:** Preview Base CFrame was sent as the authored PrimaryPart CFrame; differing model pivots could cause rejection or shifted placement. The client converts the transform, and server height checks use Base. Owned land and overlap validation remain enforced.
- **High, fixed in source:** Server cleanup notifications removed previews before construction validation/commit; rejected placements can now be repositioned. Instant Bank replay milestones now happen before optional visual/prompt work that may yield.

Validation: local intro, placement lifecycle, tutorial, startup, progression and spatial security regression tests. Existing city/cash are preserved. A full plot still requires a free building footprint. Studio placement, authored UI/SpawnCam and mobile controls remain to be exercised.


## Civilian system added (2026-09-08)

New ambient residents use the authored ServerStorage.Civilian rig. Local regression tests cover completed-building counts, fair 24-server/8-city caps, gradual spawning, shrinkage, duplicate init, departure/reassignment cleanup, owned-land/building avoidance, unowned gaps, stuck recovery and canceled asynchronous paths. Geometry/count reconciliation runs at 1 Hz; movement runs at 10 Hz; at most one path computation is in flight with a 0.25-second request interval. Embedded NPC scripts are removed from clones, actors have no touch/query/collision gameplay effects, and no remote or save changes are involved.

Outstanding Studio checks: Civilian rig is jointed and correctly scaled for city walkways; R6/R15 animations play; Humanoid movement grounds correctly on authored tiles and navmesh routes around dense buildings. Dense/full cities may have insufficient free space, so visible actors intentionally stay below the configured budget. Existing gameplay population remains separate from visual NPC counts.


## 2026-09-09 gameplay audit

Detailed findings, fixes, local coverage and unresolved live/payment blockers are in GAMEPLAY_REVIEW.md. Fixed: construction quest event mismatch/premature credit, completed/unchanged-progress recovery, reward UI mismatch and stale callback overwrite; daily missing-Backpack/cycle/countdown issues; failed-prompt and receipt-target association bugs; oversized-preview clamp/interior-gap acceptance and builder-limit rejection of collected tools; imprecise rebirth multiplier display/stale alert; elapsed income loss and collection ordering/lock duration. Existing Data_1 and rebirth reward/requirement balance are preserved.

Not a production sign-off: historical unresolved same-price intents, changed steal targets, the steep second-rebirth curve, live product metadata, external GUI bindings and authored model/device behavior remain documented limitations. New tests exercise all 82 catalog entries and all five/seven quest/daily steps with mocks.


## 2026-09-09: original intro handoff and cash notification correction

The intro rewrite could restore a captured Scriptable camera after Play, leaving the view at SpawnCam. EarlyLoading and IntroController also both owned camera state, and gameplay UI module requires could stall before the intro ran. EarlyLoading now owns only the initial overlay/input hiding; IntroController owns orbit/blur. The authored icon/Play reveal runs before waiting for city readiness, matching the original Handler's order. After Play and readiness, camera ownership returns explicitly to Custom/current Humanoid without restoring the old camera position. Interrupted intros still restore captured state. Gameplay UI controller requires now run after the intro, including the UIController dependency formerly pulled in by notification preparation.

Removed CollectIncome notification binding. The animated cash counter and other notifications remain. Regression checks cover initial Scriptable cameras, actual orbit motion, Play before readiness, delayed loading, cancellation, deferred controller requires, early overlay/input hiding, and absence of cash collection feed cards. These are local source/mock checks; Studio camera/GUI behavior still needs a play test.


## 2026-09-09: remaining authored HUD scripts migrated

Moved construction list, settings audio, code redemption, mobile cleanup and builder count into scoped client modules. Fixed ambiguous construction row removal for duplicate/display-name buildings, lost pre-UI restore events through a ready-time server snapshot, fixed-tick construction countdown drift, overlapping progress tweens, permanent code-submit lock when no response arrives, stale code-status resets, ignored status colors, and volume collisions between sounds with equal names. HUD teardown cancels listeners/tasks and deletes only generated construction rows. Audio preferences remain session-local; no new DataStore fields or reward logic.

Local test_migrated_hud covers actual row rendering/sorting/removal, own-player snapshot filtering, code submit/timeout/color/reset races, audio restoration/late sounds/HUD replacement, builder colors and mobile cleanup. Studio still needs confirmation of authored ConstructionTemplate children and Settings controls, plus actual click/remote/tween behavior.


## 2026-09-09: sell menu equip isolation

Fixed building equips hiding the open sell frame and acquiring placement controls/highlights. The placement session now gates on SellTool.Visible, cancels active placement when the sell menu opens, and checks the same condition before a placement request. Held tool visuals and sell valuation updates remain independent. Closing the menu does not automatically activate a possibly pending sold tool; normal placement resumes on re-equip outside selling. Local placement regression tests cover open/equip/close/destroy and intro-completion interactions. Studio sell-menu blur, held-model appearance and mobile input still require visual verification.


## 2026-09-09: placement motion and early network startup

Fixed preview rotation snapping and frame-rate-dependent drag smoothing with short retargetable visual easing. Target collision/land checks and submission now use the intended snapped position and exact quarter-turn, preventing mid-animation fractional rotation/off-grid submissions. Repeated rotation continues forward across 360 degrees. Existing sell/intro cleanup still owns cancellation.

The supplied Events infinite-yield log matched ServerBootstrap delaying remote creation behind WorldRuntime's yielded preview cloning. Remotes now precede that work; client descendant waits share an explicit 60-second deadline with a missing-path diagnostic. No client-created remote stand-ins. Source/mock tests verify bootstrap order, delayed remote replication, missing-root timeout, tween motion and exact-target placement. Actual Studio loading time and placement feel remain unmeasured.


## 2026-09-09: Buy/City/Sell HUD handlers migrated

Moved the three HUD.Buttons.Up travel handlers into UIController.TravelButtons with HUD-scoped connections and touch/gamepad-compatible Activated bindings. Corrected City from the retired Workspace.Map.Plots path to Workspace.Plots and resolves the player's current plot on each click. Missing characters/spawns do not index nil or yield indefinitely. Buy/Sell retain the supplied positions and yaw. Local compile/path checks do not verify the coordinates against the authored Studio map.


## 2026-09-09: full tutorial presentation and post-tutorial handoff

Verified current eight server stages against the original backup tutorial: gameplay still includes Bank/taxes/Shack; owner reuse of a collected Bank can skip its construction wait legitimately. Restored removed tax/purchase pauses and completion reading time. Extended the Shack reveal from 3 seconds to its configured 2-second delay + 2.5-second zoom + 3-second viewing time. Fixed closing-menu transition locks dropping the next tutorial panel.

Fixed UpdateQuest discarding snapshots when remote delivery precedes IsInTutorial=false replication. Latest state is buffered and shown after tutorial/white handoff; the client requests a ready snapshot again. Owner 1790165114 now resets all three quest progression fields per join as explicitly requested, while other profiles remain unchanged.

Adapted WordSearch shared/ui/UIEffects animateGame/white transition behavior into shared.ui.Transitions: staggered slide/scale in/out, full white tutorial-to-HUD switch, cancellation and authored geometry/scale/input restoration. Menus, placement controls and regular gameplay HUD use it. Local transition tests cover rapid reversals, nested effects, teardown and late callbacks. No Studio visuals or owner saved record were read; real account state and visual feel remain unverified.


## 2026-09-09: blank rebirth content and civilian variety

Rebirth confirmation relied on optional template rows and used white fallback text on the shown white panel. Added readable generated fallback rows for all three boosts (including previously omitted building XP), exact shop unlocks, explicit empty-unlock levels and retained-city/cash-reset explanation. Cleanup now removes only owned generated content; authored decorations/templates survive. The first rebirth unlocks Ice Cream Store/Donut Store shop access with x1.15 income/population/XP and $15,000 starting cash; no formula changes.

Civilian clones now get randomized coherent skin/shirt/trouser palettes with R6/R15 part support; classic clothing is removed on clones to expose the part colours. Source template and locomotion/caps stay unchanged. Local tests verify fallback rendering, unlock refresh, authored retention and distinct light/dark outfits; real rig textures and Studio UI remain unverified.


## 2026-09-09: tutorial panels collapsed by generic transition

The new generic UIScale transition preserved the authored zero Size of tutorial popups, making them invisible. Restored explicit centered, Size=(1,1) opening targets for Navigation-managed popups with a 0.3-second Size tween and shrinking exits. Generic HUD movement still preserves authored geometry. Added regression coverage for initially collapsed frames and rapid close/reopen.

BuildingLevelUp notices now check tutorial state before buffering, so ambient building XP messages neither interrupt tutorial instructions nor appear as stale notifications afterward. Normal post-tutorial level-up messages remain. Source/mock checks only; verify StageOne/StageTwo/TutorialItemShop visibility in Studio after client/shared sync.


## 2026-09-09: remove Word Hunt UI effects; distance and quest position

Removed white/tutorial screen fades and staggered slide/scale UI effects at the user's request; original full-size popup tweens remain. HUD/placement UI visibility switches immediately. TutorialQuests has the separately requested downward Position tween to (0.5,0.21), retaining cached quest snapshots and preventing progress updates from restarting the entrance.

Added client equip/submission and server placement checks within 24 studs of an owned tile edge. Far equips are returned to Backpack before placement controls/preview creation and report Too far through NotificationCenter. Sale-only equipping remains allowed. Tests exercise edge/vertical/expanded-land geometry, rejection before UI acquisition, tool return and notification throttling. User canceled the numeric hotbar work in favor of a future custom inventory; no hotbar code was changed. Studio distance feel and actual UI positioning remain to be verified.

Validation: 26 local test scripts and source/tool compilation passed. The full path audit additionally flags the newly synced Satchel TopbarPlus Janitor promise helper requiring ReplicatedStorage.Framework, absent from this export. Satchel was left untouched per the canceled inventory task; whether that helper runs and the dependency exists in Studio remains unverified.

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

## Civilian idle-loop fixes (2026-09-09)

Fixed overly tight waypoint arrival checks that could classify normal Humanoid stops as stalls, completed roads being treated as solid building obstacles, long pauses, and repeated failures without a cumulative inactivity limit. Civilians now prefer reachable local walks, clear seated/platform states, retry stalls, and are replaced after repeated failures or 15 seconds without travel. R6 path clearance now includes body height. Existing population/city caps and actual-travel animation switching remain.

Local civilian regressions cover safe nearby routes, walkable roads versus blocked buildings/constructions, normal waypoint stopping, resuming movement, watchdog replacement, bounded path work and canceled late paths. Civilian and appearance tests, compilation and source audits pass. Live rig physics and visual movement are not verified without Studio.

## Repeated missing quest panel report (2026-09-09)

Removed two fragile dependencies: quest presentation inside authored HUD.Frames and quest binding after unrelated Shop/Rebirth controls. The panel now owns PlayerGui.MyCityDailyQuests above HUD, mirrors HUD.Enabled and opens immediately at full size. ButtonBinding enables and connects existing/late Quests GuiButtons under HUD.Buttons once. Navigation preserves menu exclusivity, placement cleanup and close behavior. Setup precedes other authored menu work. Main tutorial restrictions remain separate from post-tutorial quest progress.

Tests now exercise actual button callbacks plus Navigation rather than replacing openUIFrame with a fake that always succeeds. Hidden/collapsed Frames, disabled input, close/reopen, late bindings, six loading cards, claim processing and generated-screen teardown pass, as do placement/transition regressions and compile/path/helper checks. This addresses source-level failure paths; exact Studio cause and actual on-screen appearance are not yet verified.

Civilian pace adjustment: reduced configured WalkSpeed from 3 to 1.5 studs/second per user request; routing and stuck recovery are unchanged.

## Group reward timing and duplication fix (2026-09-09)

The previous load-time grant could give PoliceStation during the tutorial and lose its suppressed notification; a redundant rank request and obsolete inventory-name check could also prevent the grant. Reward execution now follows ClientReady with server-side completed-tutorial/membership checks. Removed the eager loading/tutorial-finish grants, added request/in-flight guarding, transient lookup/busy-backpack retries and an immediate profile save containing both tool and claimed marker. The notification reads 'Group reward: Police Station'. Existing claims are respected, including after rejoin; owner fresh-profile testing keeps its configured resets.

Group reward regressions, progression/startup/cleanup tests and compilation/helper checks pass locally. Real Roblox group membership, saved inventory and NotificationCenter display still require Studio/live verification.

## Authored quests UI replaces generated screen (2026-09-09)

Per user correction, the UI now binds HUD.Frames.Quests.Frame and clones its Template directly into the Content ScrollingFrame, LayoutOrder 1-6. Top and Bottom remain padding frames at orders 0/7; their content and sizing are preserved. Header text shows Daily Quests (19H 20M), counting down to the daily reset; Template.Reward displays cash. ClaimStyle owns exact green RGB(31,106,40)/#44ff0b/#aeff45 restoration and disabled grey states. Duplicate Progress bar/text names are resolved by class. Widgets and the generated ScreenGui code are deleted; cleanup retains authored UI and removes only cloned quest rows.

Local authored-hierarchy mock tests cover cloning/order/spacers, header time, rewards, claim transitions/retry and teardown. Required core checks, placement/transition regressions, compile and path/helper audits pass. Actual Studio hierarchy dimensions and visual behavior still require a play test.


Quest wording update: incomplete claim buttons now read Locked; grey styling and eligibility rules are unchanged.

## UIController template relocation

Rebirth card lookups now use ReplicatedStorage.Assets.IncomeBoostTemp, PopulationBoostTemp and BuildingTemp; weather clones ReplicatedStorage.Assets.WeatherTemplate. Removed the old UIController-relative asset references and guarded missing weather templates/icons. The authored quest template stays inside its Quests frame. Rebirth regression checks and source compilation pass; Studio rendering is pending.

## Remaining template relocation audit (2026-09-09)

Updated old ToolsModule assets ArrowsGUI/BaseSelection, TutorialController assets TutorialBeamAnchor/BeamTemplate, and XP SparklesGold/SparklesBlue/SparklesPink to direct ReplicatedStorage.Assets lookups. Named proximity prompt themes also resolve from Assets. The exported game code now has no remaining script-child cosmetic template lookups. Module requires and Satchel module/style references remain intentional.

No script-owned ItemName or PlacementHighlight lookup exists in current source. ItemName is used inside live sell/shop UI; placement land highlights are generated SelectionBoxes. This also matches the inspected original sell/placement backup for ItemName/ArrowsGUI/BaseSelection. Local cloned-asset, XP-tier, placement/tutorial and required core checks plus compile/path/helper audits pass; authored Studio behavior remains pending.

## Daily quest priority and reserved padding orders

Cards now sort claimable first, remaining quests by descending progress percentage, then claimed last. Ties retain server board order. Card/placeholder LayoutOrder is restricted to 2-7; Top/Bottom padding uses 1/100 per user correction. Server quest order and claim IDs stay intact. The local quest UI regression suite passes mixed-state ordering, percentage comparisons, ties and padding bounds.

## Train flicker, ambient vehicles and join work (2026-09-09)

The old train code tweened PrimaryPart while separately calling SetPrimaryPartCFrame(primary.CFrame) every Heartbeat, and cloned original scripts/physics settings. Replaced that conflicting/incomplete movement setup with anchored, sanitized model clones and one whole-model PivotTo writer. Route occupancy prevents identical trains overlapping on a lane. The old car implementation also leaked completed-vehicle connection references, changed orientation on the first movement tick and steered lane offsets back to the lane center. Shared AmbientTraffic replaces both implementations with stable routes and one scheduler; no per-vehicle connections or uncancelled spawn loops remain.

Cold-start preview preparation no longer forces a frame delay per building template. It batches work under model/time limits and yields during large detached sanitization passes. Inventory restoration now shares the city work budget and cleans staged tools on failure/cancellation rather than leaving detached instances. These changes preserve profile/receipt safety and inventory metadata.

Full local regression suite, compilation and path/helper checks pass. New tests cover rigid carriage spacing, one transform per frame, template preservation, car/train caps, route occupancy, large frame delays and restart cleanup. A mocked 24-template startup uses three frame waits; this is not a measured production load-time claim. Actual flashing cause/visual resolution and performance need Studio profiling; external Studio scripts and duplicate unsynced runtime systems are outside this source verification.


## Claim badges and template-only rebirth confirmation (2026-09-09)

ConstructionTimer no longer emits BuildingStarted notices and NotificationController no longer binds or styles that notification. The unused network entry is retained for compatibility; construction tracking/progress and completion notices remain active.

UIController.ClaimAlerts binds the authored Alerts child (plural) of DailyReward and Quests GuiButtons under HUD.Buttons, including late-replicating badges. Both initialize hidden. Daily rewards use the authoritative canClaim/currentDay/claimedDays snapshot; the eligibility deadline keeps requesting updates while the panel is closed, with request throttling. A successful claim's snapshot clears the badge. Quests show the badge for any completed, unclaimed, non-pending quest; rejected claims restore it, claimed snapshots clear it, and expired boards hide it and request a fresh board even while closed. HUD connection scope owns the listeners/timers. No badge UI is created.

RebirthRewards now clones only Assets.IncomeBoostTemp, PopulationBoostTemp and BuildingTemp (and optional XPBoostTemp if authored). Boost cards retain Now/Next values and building cards retain BuildingName/BuildingIcon binding. Removed generated summary, fallback boost/building labels, headings, empty-level text and generated UIListLayout. Missing templates produce no substitute UI. Cleanup only deletes tagged reward clones, preserving authored children/layouts. Gameplay rewards and the existing city-preserving/cash-reset policy are unchanged; the former generated preservation/reset summary is no longer inserted.

Validation: test_daily_quest_ui covers authoritative daily eligibility, closed-panel deadlines, late badges, rejected/pending/claimed quests and expired boards; test_notification_center verifies construction starts are silent; test_rebirth_appearance verifies template-only rendering, missing templates and authored-child preservation. Required network/startup/persistence/receipt/security/cleanup/progression checks, source compilation (259 source / 37 tooling files), and path/helper audits pass. These are local mock/source checks, not a Studio visual test.
