# MyCity backend audit and refactor

## Current rollback backend audit (2026-09-28)

- Replaced UIController's unsynced root TopbarPlus wait with the project's already synced Satchel package. Source path validation now resolves all 466 literal local requires.
- Placement and paid skip paths require current plot ownership; paid skips also require the site's `OwnerUserId`. Military Base and Airport previews now use their intended half-grid alignment.
- All builder-cap rejection paths report eighth-builder pass eligibility. The client prompts pass `1407360513` only when an upgrade is available and throttles repeated prompts.
- An unavailable Cash value cannot consume collected income or a sale tool. Income debounce cleanup matches the departing user's exact ID prefix. Shop data requests use the request guard. New Cash and Robux building purchase requests reject missing server model/site assets before spending or opening a prompt.
- 52/57 local tests pass; five remaining scripts carry pre-existing rollback-incompatible expectations for removed v410 UI/commerce features. Source/tool compilation, path audit and diff whitespace checks pass. Studio soak testing remains necessary.

## Empty plot and shop image fallback cleanup (2026-09-27)

- Empty plots say `Welcome to Nothing` on the city sign. The Collect Income pad remains visible and responsive while only its `ButtonInfo` is hidden; like UI/prompt stays hidden until ownership is assigned.
- An empty income touch still plays the button press/release animation and sends no red empty-income alert. A forced empty-plot like displays only `This plot is unoccupied.`
- Valid shop ImageIds keep their images; missing, malformed or failed-to-load images use the fitted 3D building preview. Inventory remains icon/text based. Friend boost presentation is untouched.
- Changes were compiled and statically checked only; Studio transition and visual checks are left to the user.
- Burj Khalifa's info prompt and billboard are lowered by 10 studs through a separate non-colliding UI anchor and billboard offset; the building model and hitbox footprint do not move.

## Targeted v377 restoration and Luxury skyscrapers (2026-09-27)

- Restored development-aware road cars (12/city, 72/server), civilians (10/city, 80/server), server airport flights and client Military Base helicopter flight. Vehicle targets grow gradually and retain global budgets.
- The building shop uses existing positive ImageIds and creates a 3D viewport only for a missing ImageId. Inventory/toolbar keeps image or name text; other image surfaces were not converted.
- Added the Luxury rarity, `Luxury Skyscraper` and `Burj Khalifa` as the final two shop cards. Burj has the highest configured cost, income, build time, population and assumed 6x6 footprint. The source normalizes spaced Studio model names to stable internal keys at startup.
- Studio model Base dimensions and the 5x5/6x6 construction templates were not available as exported source. They require the user's own Studio verification. Static focused checks and source compilation pass; the source path checker still flags the pre-existing Studio-authored root TopbarPlus path.

## City-like confirmation wording (2026-09-27)

- A newly saved like now tells the liker only `Liked <owner DisplayName>'s city`; the former `Success: Like added! Total: ...` developer-style text is removed.
- Duplicate/error titles and the owner's incoming-like notice are unchanged. Persistence and reward settlement are unchanged.


## Pack price and purchase-close correction (2026-09-27)

- `Buttons.Right.BuilderPack.TextLabel1` now resolves developer product `3388944230` with `Enum.InfoType.Product`; it no longer displays eighth-builder game pass `1407360513` pricing.
- A successful Starter/Skyline product `3714990977` prompt result immediately closes `Frames.Starterpack`, deselects its topbar icon and suppresses the later reminder. Receipt granting remains server-authoritative.


## Creator chat and repeatable owner testing (2026-09-27)

- Only `1790165114` and `2044711693` receive the white `[CREATOR]` chat prefix. Staff, member/group and Premium custom tags were removed.
- Owner `1790165114` still receives a fresh gameplay profile every join, but tutorial preparation immediately completes/skips the tutorial.
- The fresh profile resets `FirstRare`, `FirstEpic` and `FirstLegendary` to false, so all first-rarity VFX paths can run again each owner session. Purchase receipt/session metadata remains preserved.
- Epic construction completion is now included in the server first-rarity check. It has an independent persisted flag/announcement and reuses the authored purple RareVFX/RareBuilding assets because no Epic-specific asset exists.


## Development-scaled city life (2026-09-27)

- Road cars scale from streets plus building/population demand, require at least two road pieces, and remain capped at 12 per plot / 72 per server.
- Car targets are globally allocated round-robin, excess trips retire before new ones spawn, and each city adds at most one trip per second. Cars remain client-rendered immutable descriptors.
- Civilians scale independently from completed non-road buildings, roads and diminishing-return Population, capped at 10 per plot / 80 per server with gradual one-per-sync growth.
- No persistence or economy values are changed. Studio should verify visual density and server/client frame time with eight mature occupied plots.


## TopbarPlus startup hang fixed (2026-09-27)

The 13:54 Studio log showed UIController blocked at `ReplicatedStorage:WaitForChild("TopbarPlus")`. TopbarPlus has since been source-synced under `ReplicatedStorage.shared.TopbarPlus.Icon`; UIController now requires that exact path, and both the hierarchy audit and source-path checker reject the removed root path. This allows UIController initialization, including pack buttons and all downstream HUD bindings, to proceed.

Local validation: UI transition regression and all-source compilation pass; 301 source and 55 tooling files compile, and 473 literal local requires resolve with zero Studio-only targets.

The two `6525690145` failures are unrelated authored Sound permission warnings. That ID is absent from exported source, so it was not replaced blindly; the Studio Sound must use an experience-owned/approved asset.

## Builder-limit upgrade prompt (2026-09-27)

Builder-limit rejection now carries a server-computed `canUpgrade` flag through `Notifications.BuilderLimitReached`. The client retains the limit notice and shop navigation, and additionally prompts game pass `1407360513` only when it can raise the player from seven to eight simultaneous builders. Existing pass owners at their cap are not prompted. Both validation and the final construction reservation race emit the flag; the prompt is cooldown-protected, while legacy argument-less events perform an ownership lookup first.

Local validation: all 50 suites pass, including the exact builder-pass prompt regression; current compilation/path totals are recorded in the TopbarPlus section above. Studio still needs a native purchase-overlay test.

## Shop embedded commerce script migrated (2026-09-27)

The supplied `Shop.Frame.DevProductsClientScript` behavior now lives in centralized client `UIController/DevProducts`, with HUD lifecycle-owned connections/tasks. It binds the current direct `MainBG.<Card>.Buy` hierarchy instead of obsolete `.Pattern.Buy`, retains all eight developer-product IDs and three game-pass IDs, prompts the correct marketplace API, and refreshes personalized client prices every 60 seconds. A still-authored legacy LocalScript is disabled and destroyed at runtime to prevent duplicate prompts until it is removed from the Studio GUI.

Building-shop PurchaseFrame clones now update `Buttons.RobuxBuy.TextLabel`, and locked ItemTemplate clones update `Locked.Buy.Cost`, from the selected cash tier's actual developer-product ID using the same client-local lookup. Both use `<price>`. Successful values cache for 60 seconds, simultaneous same-tier cards share one in-flight request, and async completion checks live/current UI before writing. PurchaseFrame also supports alternate authored casing `Textlabel`.

Commerce-surface validation totals are included in the current builder-limit section above. Studio still needs visual and live prompt tests against the authored Shop hierarchy.

## Starter Pack UI and receipt grant (2026-09-27)

`HUD.Frames.Starterpack` is the independent Petronas Towers/Apex Tower/Military Base Skyline offer. Its authored Close/PurchaseButton controls are bound directly, product `3714990977` is prompted as a developer product, and client `GetProductInfoAsync` writes its regional/optimized `PriceInRobux` as an unspaced Robux glyph and number to the exact `PurchaseButton.Frame.TextLabel`. The authored reward card still named Airport is remapped to PetronasTowers; the receipt-safe server plan grants PetronasTowers, internal `SkyscraperGeneric` (displayed as Apex Tower), and MilitaryBase. As a developer product, the pack can be bought again; every individual receipt remains idempotent through the existing ledger.

The existing `Buttons.Right.BuilderPack` remains mapped to the separate `HUD.Frames.BuilderPack`, including its original `Frame.X` close binding. Its `TextLabel1` independently displays the localized price of eighth-builder game pass `1407360513`; it is not populated from Starter Pack product `3714990977`.

A distinct single-image TopbarPlus Skyline Pack icon uses `rbxassetid://98703767607590`, left alignment and order 2 beside the existing Settings/Inventory icons. The icon has no persistent text label; its caption displays the localized product `3714990977` price and it toggles only `Frames.Starterpack`. No `Buttons.Right.SkylinePack` clone is created. It blocks during tutorial, deselects from the panel's Close button and is destroyed on HUD replacement.

The offer auto-opens after four minutes and once more 30 minutes after the first reminder, waiting through the tutorial or another open modal rather than interrupting it. It stops after those two offers, and a successful prompt result suppresses the second. That client result affects presentation only; rewards still require the authoritative receipt.

The panel uses the supplied three reward cards and their authored ViewportFrames/sunbursts; the legacy Airport card now displays Petronas Towers. It applies the GuessTheSize timing/amplitudes for background rotation, breathing bursts, staggered reward pops and recursively collected independently drifting/fading/spinning background stars. PurchaseButton now intentionally keeps only the sweeping UIGradient and bounded 1.8-degree periodic shake; hover/press scaling, size pulse and stroke animation were removed. All three models spin around their visible centre at 18 degrees/second from a 180-degree facing correction. Preview cameras fit visible bounds, move gently and use a stronger 0.28 vertical direction to show more top/front surface. Hidden/cleaned HUDs restore motion/input state and destroy generated preview instances. Visual composition and Marketplace prompting still require a Studio/published-game check.

The Military Base preview replaces its static Heli with a sanitized independent viewport copy flying a compact variable-altitude orbit; MainBlades spin on Y and RearRotor on Z. The removed Airport reward's aircraft preview was also removed. The helicopter remains a WorldModel-only cosmetic with no live-world or replication effect.

Local validation is included in the current Shop commerce section above.

## Military Base grid adjacency (2026-09-27)

Placement Geometry now explicitly applies the existing half-grid snap rule to `MilitaryBase`, matching Airport/Stadium. This avoids a 0.5-stud adjacency mismatch when the model's authored Base dimensions do not express its configured odd 5x5 footprint. Collision and land-boundary rules were not loosened.

Airport correction: its authored Base is 8 x 13.5 studs, so the former explicit two-axis half-grid offset misaligned the even side. Airport now offsets only the long Z axis at 0/180 degrees and swaps that offset to X at 90/270 degrees. Server validation remains unchanged.

## Empty income collection is silent (2026-09-27)

IncomeSystem.Collection no longer fires `ErrorEvent` with "No income to collect!" when the collection total is zero. It simply releases the collection debounce and returns. Ownership/security errors remain visible, and successful collection still credits cash, advances quests/tutorial state and drives the existing cash feedback.

## Central airport aircraft system (2026-09-27)

The supplied Airport-embedded script repeatedly searched attachments, drove only PrimaryPart through long TweenService movements, paused at every taxi waypoint, chained overlapping arrivals through a BindableEvent and left its orientation offset at zero. `server.systems.world.AirportSystem` now owns the complete lifecycle for every placed Airport. It caches the existing A1/D1 routes, permits one aircraft per runway, moves the whole anchored/collisionless Model with real-time phase speeds, blends headings into turns, waits only at an explicitly paused point or the arrival gate, and cancels cleanly when Airport is removed. After the first central speeds still made the compact route complete too quickly, movement was reduced to 2 studs/s airborne, 1.5 braking/takeoff and 0.2 taxi/gate, with 4-6 second minimum legs. The full cycle now plays over minutes rather than seconds. Legacy BaseScripts are disabled in both the server template and placed Airport.

Follow-up: construction sites also expose `BuildingType=Airport` but do not contain A1/D1 route Attachments. Detection now requires the Airport model to be directly inside `Buildings.Placed`, eliminating false missing-ApproachPoint warnings and delaying traffic initialization until construction completes.

The first +90-degree yaw correction did not match the imported model in Studio. Per the observed pose, the defaults now add another 90 degrees right (`PlaneYaw=180` total) and pitch 90 degrees down (`PlanePitch=-90`). Per-template or per-Airport attributes can override either correction. Route height remains authored entirely through Attachment positions.

Follow-up runway presentation: all route positions are lowered 0.2 studs total at runtime (raised 0.05 from the prior -0.25 setting). Touchdown now uses sine in/out interpolation and smoothly develops a 7-degree flare during its final 45%; the braking leg uses cubic ease-out for continuous deceleration and removes the flare smoothly as the aircraft settles. Gate and takeoff-start motion also use smootherstep, while taxi heading blending remains active.

Departure pitch-jump fix: the movement fallback previously read the visually corrected plane Pivot LookVector. Because the imported model uses a -90-degree pitch correction, overlapping/near-zero D1 legs interpreted that visual axis as flight direction and pitched vertically at waypoints. Heading fallback now comes only from next/previous route geometry, and all braking/gate/taxi/takeoff-start directions are projected onto X/Z. Liftoff and Departure retain their authored vertical climb.

## Shop lower-edge clipping padding (2026-09-27)

One transparent, non-interactive 1x0.9-scale layout frame with a width-dominant aspect ratio of 3 is now appended after the final shop item on every refresh. It is visually empty but remains layout-visible, extending the automatic canvas so the Airport/final catalogue cards can scroll above the lower clipping edge.

## Builder Pack label/icon attention (2026-09-27)

The Builder Pack HUD button now runs two independent, occasional cleanup-owned animations: TextLabel1 pulses to 1.14x while moving through -25/-15/-25 degrees, and Icon pulses to 1.16x while rocking +12/-8 degrees around its authored rotation. Both restore authored rotation and UIScale after each pass and during HUD teardown. No background, stroke, shine or whole-button effect was reintroduced.

## Building icons replaced by shared 3D previews, excluding inventory (2026-09-27)

Shared client BuildingViewport now replaces building ImageLabel content in Shop, SellTool, both BuildingInfo layouts, rebirth building-unlock cards and post-tutorial building rewards. It clears each old image and mounts a transparent ViewportFrame/WorldModel/camera using Assets.BuildingPreviews. Inventory is intentionally unchanged: ToolFactory still authors TextureId and Satchel still assigns it to ToolIcon. Unrelated player, currency, weather, settings and input images remain. Rebirth unlock payloads now include the stable BuildingConfig key needed to resolve models.

Models are bounds-centered, rotate at 18 degrees/second and exclude Hitbox. The user reverted live world/color-correction mapping to the original fixed viewport lighting: Ambient RGB(145,145,155), warm LightColor RGB(255,244,225), direction (-1,-1,-0.65). One 30 Hz renderer serves every surface; hidden/offscreen models release after two seconds and return on visibility. Shop additionally clips work to its ScrollingFrame. Preview geometry is anchored/non-colliding and stripped of scripts, prompts and LayerCollectors.

Local validation: all 46 suites pass, including all five viewport consumers, restored fixed lighting, rebirth keys and explicit Satchel TextureId preservation. All 277 source and 51 tooling files compile; 456 literal local requires resolve with only the existing Studio-authored TopbarPlus target, and extracted dependency checks pass. Studio remains required for visual and mobile-cost verification.

## Military Base flight and new buildings (2026-09-27)

Added the authored `MilitaryBase` model to Epic and internal `SkyscraperGeneric` model to Legendary under the player-facing name **Apex Tower**. Their catalogue unlocks are 24 rebirths / 125,000 population, with limits 1 / 2. Their 5x5 and 4x4 construction sizes are best-fit assumptions because the synced source does not contain the Studio model dimensions; the existing startup template audit will identify a mismatch. Both omit ImageId; the shop now uses their models directly, while other icon-based surfaces still need real icon assets.

MilitaryHelicopterController renders completed Military Base helicopters entirely on each client. Its sanitized clone flies inside a closer 9-stud default boundary, using smooth deterministic radius/offset/altitude harmonics for tighter/wider and lower/higher passes. Orbit speed is now 0.88/3 rad/s, twice the previous 0.44/3 setting. A +90-degree default yaw corrects the reported left-side-leading orientation; dynamic bank ranges 5-15 degrees and pitch varies +/-4 degrees along the 3D route. Default centre altitude is two studs below the authored Heli height (minimum 8), with smooth variation around it. Every clone BasePart resets LocalTransparencyModifier to zero. Direct Heli children `MainBlades`, `Body` and `RearRotor` remain the preferred layout, with legacy aliases and replication-aware startup. The clone is collisionless, contains no scripts/constraints/prompts, cleans up with the building and does not affect persistence or server replication.

Local validation: all 46 suites pass, including the catalogue/flight/blade regression. All 277 source and 51 tooling files compile; 456 literal local requires resolve, with only the existing Studio-authored TopbarPlus target; extracted dependency checks pass. Studio still needs verification of Base footprints, flight facing/height and blade pivots.

## Lifetime progression analytics (2026-09-27)

The former onboarding funnel stopped after nine tutorial events, omitted TutorialStarted in live calls, combined Shack placement with construction completion, and had all post-tutorial analytics commented out. A single new `NewPlayerProgression_v1` funnel now records 49 ordered milestones: new profile joined; TutorialStarted, Bank received/equipped/placed/constructed, income, shop, Shack purchased/equipped/placed/constructed, tutorial complete; every one of the 35 append-only quest completions; and the final all-progression completion.

Enrollment is limited to genuinely new profiles created after deployment. DataSchema adds persisted `ProgressionFunnelVersion` and `ProgressionFunnelId` values without changing schema version 5; existing profiles normalize to version 0 and are excluded. New-profile status comes from the acquired envelope before restoration. Rejoins reuse the saved funnel session and reconcile durable tutorial/quest progress. Quest events occur after reward delivery and progression-state advancement. Analytics errors remain isolated from gameplay, and the owner is excluded.

Local validation covers the exact step mapping, fresh/established/owner enrollment boundaries and rejoin reconciliation. All 44 test suites pass; 274 source and 49 tooling files compile; path and extracted-module dependency audits pass. Creator Analytics ingestion and display require a published-server test; no publish was performed.

## Epic stock availability (2026-09-20)

The supplied feedback describes four missed Shopping Mall restocks. Source confirmed that the Mall's limited-building override gave only a 26.7% chance of positive stock (60% immediate rejection, then a uniform 0–2 roll). Four consecutive misses had about a 28.9% probability. This supports the complaint without proving which published version the player used.

All Epic buildings now take the Epic branch before the limited-building override: 65% positive-stock chance and 2–6 copies. Three consecutive empty generations guarantee positive stock on the fourth. The threshold is EPIC_MAX_MISSES=3 in ShopSystem/init.luau. Each player's Data.ShopEpicMisses stores a separate IntValue per Epic. Positive stock resets the streak immediately; buying all available copies is not a failed restock. Existing stock generation on join/manual resets counts; ordinary shop snapshots, stat changes and rebirth synchronization reuse current stock. Locked buildings still roll but retain their eligibility requirements. There is no offline accrual.

DataSchema creates the empty dynamic folder for old/new profiles; existing recursive profile encoding persists counters with normal autosave/departure saves. Normal rejoin preserves progress, subject to the existing save guarantees; an unsaved crash can lose recent progress. The requested owner fresh-profile reset continues to reset gameplay counters. No new DataStore, schema-version change or authored object is required. Pre-load and departing-player stock generation is skipped; ClientReady supplies the first snapshot after profile readiness. Non-Epic stock rules, the 300-second timer, costs and purchase validation remain unchanged. Land expansion is outside this change.

Validation: test_shop_stock forces unsuccessful rolls for all actual Epic catalogue entries and executes the fourth-roll guarantee, stock quantity/chance boundaries, early-success reset, per-player/per-building isolation, stable repeated snapshots/rebirth sync, unchanged Mall eligibility and non-Epic limited behavior, pre-load/departure refusal and actual codec/schema save/rejoin. Eleven suites pass: shop_stock, network, startup, persistence, receipts, security, cleanup, progression, data_schema, gameplay_audit and refactor_regressions. Compilation passes for 266 source and 46 tooling files; path/helper audits pass.

Studio procedure: sync server.systems.economy.ShopSystem with all children and server.persistence.PlayerDataModule.DataSchema, then start fresh servers. With an ordinary loaded test player, verify the Mall unlock still requires 35,000 population and costs 500,000 cash. In a disposable Play session, set Data.ShopEpicMisses.Mall.Value to 3 on the server and call ShopSystem.resetPlayerShop(player); confirm 2–6 Mall stock and counter 0. Reopen the UI and verify the same stock. Test a normal saved leave/rejoin and two players with different counters. Do not use the owner fresh-profile account to verify retained gameplay counters. Real storage, authored shop display and published behavior remain unverified; no publish was performed.

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

## Placement refused at land edges/corners (2026-09-23, player report)

Symptom: a building placed flush against an edge or corner of owned land, not overlapping locked land, was refused while the preview looked valid, with no message.
Cause: server overlap treated every descendant of Land.Locked (expansion signs, locked scenery overhanging owned land) and neighbours' Hitboxes as blockers; the client checked different parts. The client's failure notice used FireServer on a remote the server never handles.
Fix: shared.util.PlacementRules (owned-tile coverage + Base-footprint separating-axis overlap, 0.05 stud tolerance) is used by both preview and server; rejections return a reason shown in the notification feed.
Verify in Play: buy land so a locked tile with its sign borders your city; place 2x2 and larger buildings flush in that corner at all four rotations (expect success); nudge one stud onto locked land (expect "outside your land"); place flush beside another building (success) and one stud into it (expect "overlaps another building").

## Stuck Robux purchases (2026-09-23)

Symptom: after a lost cancellation or disconnect, every later purchase at the same Robux price was refused with "needs recovery"; receipts with no recorded choice stayed pending forever.
Fix: prompts archive an unbound old choice instead of refusing; receipts resolve open choice -> archived choice -> equal-value compensation (best building in that Robux tier); overdue blocked steals deliver the saved snapshot after 10 minutes. See AGENTS.md for the exact order.
Verify in Play (test products): open a building prompt and leave the server before answering, rejoin, and buy a different building at the same price (expect the prompt to open). Buy two buildings at one price in quick succession (expect both granted). Check the Output for "[Receipts] Deferred" warnings.
# Authored SFX integration (2026-09-27)

- All gameplay/UI audio now resolves from `SoundService.SFX`; the temporary `GuessTheSize` sound-bank integration was completely removed.
- Specific mappings cover Hover, Click, Swoosh, Notification/NotificationLow, Error, Purchase, Reward, CaChing, PlaceSound, RotateSound, DestroySound, BuildingComplete, Popin, RareBuilding, LegendaryBuilding, StartUp and Ambience.
- Daily/quest reward audio waits for server confirmation. Rarity notices do not add a generic sound over the RareBuilding/LegendaryBuilding VFX cue, and rebirth does not layer a second completion sound.
- `Ambience2`, `Construction`, and `Nuke` remain unbound because there is no separate matching gameplay event; forcing them would overlap or misrepresent existing actions.
