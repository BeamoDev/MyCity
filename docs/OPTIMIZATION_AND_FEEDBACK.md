# MyCity: current systems and player feedback

**2026-09-10 update:** See [SYSTEM_HARDENING.md](SYSTEM_HARDENING.md) for the latest fixes, approved gameplay changes and verification limits. The dated findings below describe earlier source; client ambient rendering, shared simulation scheduling, income caching, best service coverage, city-preserving Store/rebirth and paid-target recovery now supersede the corresponding recommendations.


Reviewed 2026-09-08 against the local standalone MyCity source and the 28 comments supplied in chat. This is a source audit, not a Studio performance capture or an analysis of live retention. Historical complaints are not automatically bugs in the current version.

## Recommendation

Make the next update about **keeping your city safe, making it easy to edit, and getting to building faster**. Then add life to the city: working trains, visiting, street-level exploration and traffic. The feedback supports a relaxing miniature-city identity more strongly than disruptive stealing or repeatedly losing a carefully built city.

The cash effect is implemented locally. The other items below are findings and proposed work, not changes already shipped.

## Cash feedback implemented

- Uses the current KingdomWars NumberCounter implementation and its 0.2–0.7 second cubic-out timing.
- Starting balance appears immediately. Subsequent gains and spending count up/down from the number currently displayed, including changes arriving during an animation.
- Green/red floating amounts represent the actual target-balance change, rather than the unfinished visual animation. The label briefly changes color and returns to its authored color.
- At most three floating amounts exist; RenderStepped disconnects when animation finishes. HUD replacement/destroy disconnects and destroys the effect.
- Currency stays authoritative on the server. Formatting still uses the existing dollar/comma formatter.

Ownership: `shared/util/NumberCounter.luau` handles numeric interpolation; `client/controllers/ui/CashFeedback.luau` handles presentation; `UIController/CashDisplay.luau` binds the replicated balance. No template or extra remote is needed. Remove the old HUD.CashDisplay LocalScript after syncing so it cannot overwrite animated text.

`tools/test_cash_feedback.luau` executes the real modules with controlled time/signals and checks initial display, gains/spending, retargeting, popup limits, idle disconnection, hidden/destroyed HUD, repeated binding and replacement cleanup. Final visual placement, clipping by authored ancestors and readability on phone/tablet still need Studio/device checks.

Local validation passed: all 186 source files and 14 Luau tooling files compile; 337 literal local requires resolve; extracted-dependency checks and cash/startup/cleanup/refactor regression suites pass. TopbarPlus remains an external authored dependency. No Studio session or published-place test was run.

## Biggest systems

Counts include comments and blank lines; these describe maintenance size, not measured performance cost. At the cash-review snapshot, source had 186 Luau files and approximately 20,062 lines; the later tutorial follow-up adds TutorialConfig and changes tutorial code. The counts below describe that snapshot.

| System | Files | Lines | Why it matters |
| --- | ---: | ---: | --- |
| Server BuildingSystem | 23 | 2,705 | Placement, pickup/deletion, stats, XP, saved buildings and stealing interact here |
| Client UIController | 17 | 2,025 | Many unrelated screens still share one State/Context |
| Server ConstructionSystem | 14 | 1,375 | Timers, builders, restoration and conversion into completed buildings |
| Client ToolsModule | 9 | 1,111 | Placement preview, touch/mouse input, validity and cleanup |
| Server IncomeSystem | 6 | 983 | Per-building accrual, population, collection and plot UI |
| Client TutorialController | 7 | 787 | Authored tutorial presentation and guided actions |
| PlayerDataModule | 5 | 504 | Much smaller, but very high consequence: load/save/lease/schema |
| MarketPlaceHandler | 8 | 426 | Small but high consequence: paid intents, receipts and transfers |

Largest individual implementation files are ProximityPromptController/Renderer (542 lines), UIController/Rebirth (308), ShopController/StockDisplay (294) and BuildingPrompts (274). Catalogue files are mostly data; splitting them further offers less value. Further cleanup should reduce shared responsibilities: separate prompt input glyphs from prompt appearance; move rebirth presentation and city-name/daily-reward screens into independent controllers. More files alone will not improve frame time or correctness.

## Highest-priority correctness and recovery work

### 1. Verify save recovery and finish purchase recovery

The earlier LastUpdate restoration failure has a local schema fix and loader/save/rejoin tests. Do not count it as a newly discovered unfixed error. Successful real-player load/rejoin and deployment of all matching modules are still unverified. The historical reset complaint makes this the first release check.

Current purchase limits remain concrete: [PurchaseIntents](../src/server/services/MarketPlaceHandler/PurchaseIntents.luau) saves an intent before opening the prompt and rejects another prompt for that product while it exists. Prompt failure or departure before a cancellation callback can leave it pending. [ReceiptLedger](../src/server/services/MarketPlaceHandler/ReceiptLedger.luau) can also keep transfers pending when the target is gone or the owner is active on another server; see [BUG_AUDIT](BUG_AUDIT.md).

Add explicit recovery states and visibility into pending purchases. Reconcile against durable receipt/transfer evidence; do not expire an uncertain paid target blindly or acknowledge an unfulfilled receipt. Monitor load failures, pending-receipt age, save latency/failure, lease conflicts and serialized profile size. Retain the existing Data_1 namespace and duplicate-grant protection.

### 2. Income accrual uses ticks instead of actual elapsed time

[IncomeSystem/Lifecycle](../src/server/systems/economy/IncomeSystem/Lifecycle.luau) passes exactly `1` into accrual, processes every player, then waits one second. Processing time and scheduling delays are extra, so slow servers award less income per real second. This is a source-level timing defect; its production magnitude has not been measured.

Track per-player elapsed time with a monotonic clock and settle accrual at rate-changing operations. Avoid awarding time before loading finishes or counting the same interval during collection/leave. Verify a fixed city earns the same amount over a timed interval with artificially delayed updates. Population totals can update when buildings or relevant values change instead of scanning each second.

### 3. Service coverage chooses nearest rather than best coverage

[BuildingStats/Safety](../src/server/systems/building/BuildingSystem/BuildingStats/Safety.luau) and [Health](../src/server/systems/building/BuildingSystem/BuildingStats/Health.luau) choose the nearest service building before considering its range. Ranges differ: SheriffOffice/FireShed/Clinic cover 20 studs; PoliceStation/FireStation/Hospital cover 30.

Example derived from the current formulas: a Clinic 22 studs away wins over a Hospital 25 studs away. The resulting health is 97 even though the hospital covers the building and should supply 100 under the existing coverage rule. Police/fire coverage has the same selection problem. Adding a nearer weaker service can therefore reduce coverage.

Evaluate each applicable service's contribution and use the best result. Preserve the intended no-service baseline. Test mixed service tiers, removal, exact range boundaries and multiple overlapping providers before optimizing the lookup.

### 4. Editing and rebirth can destroy the thing players value

[BuildingActions](../src/client/controllers/ui/UIController/BuildingActions.luau) fires Delete and closes the panel immediately. [BuildingConfig.deleteBuilding](../src/server/systems/building/BuildingSystem/BuildingConfig.luau) removes both the model and saved entry. There is no undo in this path. Pickup is a separate action that returns a tool, so terminology and mobile discoverability matter.

Make selection expose clear **Move / Store / Delete** actions. Store should be the safe, prominent option. Add a deliberate permanent-delete step or a server-owned undo transaction; closing a panel must not look like success if a request was rejected. Test selection and buttons on actual touch devices before treating the two historical deletion complaints as resolved.

[RebirthSystem/Reset](../src/server/systems/progression/RebirthSystem/Reset.luau) deliberately removes non-paid buildings/constructions/tools and resets cash; paid buildings are preserved. This directly matches the rebirth complaint. Show an exact loss/preservation preview immediately. Longer term, consider saved city blueprints or an archived showcase city across rebirth. Restoring a blueprint must have explicit cost/progression rules so it cannot duplicate value.

## Best optimization candidates

These priorities come from code structure. Use a populated test server and representative mobile devices to measure before claiming a speedup.

| Priority | Current work | Proposed improvement | Evidence/verification |
| --- | --- | --- | --- |
| High | Whole-plot statistics call several whole-plot searches per building: approximately quadratic work | Index service/decorative buildings, cache contributions, update affected neighbors and batch multiple edits | BuildingStats Aggregation/Safety/Health/Happiness; BuildingSystem/init also recalculates all plots every 30 seconds. Compare profiler captures during mass placement/level-ups |
| High | Builder count scans constructions, checks gamepass ownership and sends a UI remote every second per loaded player | Cache ownership with purchase refresh and retry for failed lookups; send builder UI only when count/limit changes | ConstructionSystem/init and ConstructionBuilder. Compare remote counts and update costs; verify pass purchases refresh immediately |
| High | Highway cars and trains are positioned continuously on the server | If purely decorative, broadcast route/start data and animate pooled, distance-culled client visuals | HighwayTrafficSystem has a cap of 25 cars; TrainSystem caps at 3. Compare network traffic and low-end frame time, preserving any actual gameplay authority |
| Medium | A task per building wakes for XP and splits/rewrites its saved CSV | One staggered due-time scheduler; stop unnecessary work at max level; update changed records | BuildingXP/Lifecycle. Compare large-city task activity and level/save consistency |
| Medium | Each inventory snapshot JSON-encodes all tools and destroys/recreates every mirrored StringValue | Key updates by ToolId and change only modified entries, keeping the restore guard and consistent save snapshot | InventorySystem.saveInventory and queueSave. Test equip/unequip, respawn, receipts and leaving; compare allocation/replication |
| Medium | Receipt plans, individual reward steps and completion each save the whole profile; replaying completed receipts saves again | Design fewer durable transaction boundaries for eligible same-profile rewards and distinguish durably completed receipts from unsaved in-memory flags | ReceiptLedger. Never remove saves/markers without crash/retry tests; cross-player transfers need separate durable handling |

The double-cash ownership lookup is currently on collection, not every income tick. Builder ownership checks are on the recurring builder update. Keep those costs distinct when profiling.

Roblox specifically identifies frequent server-side animation replication and excessive remote traffic as optimization targets. See [performance improvements](https://create.roblox.com/docs/performance-optimization/improve) and [MicroProfiler workflow](https://create.roblox.com/docs/performance-optimization/microprofiler/use-microprofiler). These recommendations are not measurements of this place.

## What the feedback says

The supplied sample covers October 10, 2025 through May 30, 2026: **28 entries, 19 upvotes and 9 downvotes**. Devices: **15 phones, 10 tablets and 3 computers**. Thus 25/28 comments came from touch-device categories; prioritize touch testing, but do not assume this is the full player-device distribution.

The February 13 reset report and “resolved well” reply are four minutes apart and may be one incident plus its follow-up. Do not count them as two independent resets. Two comments are truncated; their missing text is unavailable. This sample cannot establish retention, revenue impact, or why popularity changed.

| Theme | Specific feedback | Interpretation and action |
| --- | --- | --- |
| City ownership/trust | Update reset; rebirth removes city; one positive voter wants stealing removed | Players can like the game while disliking loss. Investigate reset recovery first, clarify rebirth, and evaluate opt-in stealing or protected cities |
| Editing friction | Android tablet: cannot delete things; iOS phone: change deletion mechanic | Two independent touch reports make editing a stronger signal than another rare building request. Make safe storage and editing obvious |
| Tutorial | iOS tablet explicitly blames tutorial | Current server stages run through Bank and Shack milestones. Prototype a shorter first-build/collect introduction, then contextual guidance. Implement resume/skip through authoritative server states rather than bypassing reward checks |
| Beauty and calm | Excellent models, loved skyscrapers, anti-stress atmosphere, several general positive comments | Protect this strength. Improve variety and city customization without making every session a loss-defense chore |
| A living city | Street view/interiors/neighbor visits; city cars/emergency vehicles; planes; working trains/city tracks | Start with reliable ambient life and a city tour. Interiors and player-laid transport networks are larger projects requiring separate scope |
| Buildings and style | Hotel/mall/airport requests; more detail and less blue; Empire State population request | Hotel, Mall and Airport already exist in current catalogue source. Check unlocking/discovery and actual models before adding duplicates. Art variety is a better broad direction than changing one population number without balance data |
| Social/access | Gifting request; wants to join the group | Make existing group access discoverable. Gifting needs durable ownership transfers and abuse controls; schedule it after purchase recovery |
| Branding | Name is common | A distinctive title/subtitle may help recognition, but it is lower priority than editing and trust. No name availability or acquisition effect was evaluated |

The Spanish deletion comment means the player cannot remove things. The Spanish gifting comment asks to allow gifts; the Spanish art comment asks for more detailed, less-blue buildings. Generic insults and the unsupported copying claim do not identify a reproducible technical defect.

The historical train complaint deserves a specific integration check: current TrainSystem expects `ReplicatedStorage.Assets.Trains.Train` and authored route points under `Workspace.Map.Enviorment.TrainSystem.Points` (`Point1`–`Point4`). Several missing-template/route cases silently return or skip spawning. Verify those objects and valid model primary parts in Studio, then add actionable diagnostics. The old complaint alone does not prove today's train is broken.

## Suggested update sequence and success measures

1. **Trust and editing:** verify the migrated save system with old/new profiles and rejoin; resolve paid recovery cases; improve touch selection, Store/Delete feedback and rebirth loss preview. Measure restore failures, pending paid receipts, rejected editing actions and successful first edits.
2. **Faster first city:** shorten compulsory guidance while preserving server checks and recovery. Measure loading completion, first placement, first income collection, tutorial exit and second-session return, segmented by device. Do not treat a click as a completed server action.
3. **A living city:** ensure trains run, add lightweight city traffic/emergency vehicle ambience, and prototype tours/visiting. Pair this with less repetitive building colors/details. Measure use and return behavior rather than assuming more content improves retention.

Set targets after collecting a baseline; this sample does not justify invented uplift percentages. Roblox's [onboarding guidance](https://create.roblox.com/docs/production/game-design/onboarding) supports getting players into the core activity quickly, while [analytics event types](https://create.roblox.com/docs/production/analytics/event-types) provide funnels/economy/custom events for checking the result. No new analytics events or gameplay changes from this proposed sequence were deployed by this audit.

## Subsequent tutorial cleanup

Owner 1790165114 now replays each join with the saved city/balance retained. Replicated stage presentation, cancellable camera/subtitle work, acknowledged completion and tutorial-only zero-stock Shack purchasing address concrete tutorial failures. This is a correctness pass; a redesigned shorter onboarding experience remains a product proposal. The user still needs to confirm the authored shop ItemTemplate/PurchaseFrame locations and validate the updated Items/Interactives paths in Studio. See BUG_AUDIT.md for the current validation boundary.

## Subsequent rebirth change

The user approved keeping the city and retaining the existing cash reset. Rebirth no longer deletes buildings, ongoing construction, inventory or land, and its confirmation states what stays and the next starting cash. Leaderstats shows only Cash/Rebirths; population remains under Data.PlayerInfo for existing gameplay. Schema 5 migrates old values. Requirements grow after rebirth 50 to avoid endless rebirths at the old cap. This implements the city-preservation portion of the earlier recommendation; permanent deletion/undo and other listed backend issues remain unresolved.
