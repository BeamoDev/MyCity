# Gameplay reliability review ? 2026-09-09

**2026-09-10 update:** See [SYSTEM_HARDENING.md](SYSTEM_HARDENING.md) for the latest fixes, approved gameplay changes and verification limits. The dated findings below describe earlier source; client ambient rendering, shared simulation scheduling, income caching, best service coverage, city-preserving Store/rebirth and paid-target recovery now supersede the corresponding recommendations.


The reviewed source has been repaired and locally tested. This is **not a 100% production sign-off**: Studio assets, UI scripts outside the export, product availability, real receipt delivery, device input and live persistence still need verification. No live purchases, DataStore changes or publishing were performed.

## Verified and repaired

| System | Findings and resulting behavior | Local evidence |
| --- | --- | --- |
| Post-tutorial quests | Construction attempts previously counted before completion, while placement checked a mismatched quest ID. Committed completions now advance the quest; duplicate IDs do not. Completed/legacy saves hide the quest correctly; an already-satisfied objective can retry a deferred reward without new progress. Server supplies the actual reward to the UI. Old completion effects cannot overwrite a newer objective. | All 5 quests, cash total $3,500 plus SheriffOffice/Apartments, duplicate events, failed reward/retry, world-state catch-up, completed rejoin and GUI without optional RewardSection. |
| Daily rewards | Missing Backpack now defers building grants without consuming the day. Invalid cycle numbers are clamped to 1?7; a first claim starts streak 1. Countdown follows elapsed time. Failed/busy claims always provide usable error text. | All 7 days; $140,000 total cash plus Mansion/LuxuryCondo/AuroraTower; no duplicate claim; 24h boundary; 48h streak behavior; missing Backpack; day-7 rollover. |
| Cash shop | Successful calls now return success; failed tool delivery leaves cash/stock intact and cleans the detached tool. Mobile/gamepad purchase buttons use Activated. | All 82 configured entries: exact cash deduction, stock decrement and requested tool. Reject locked, sold-out, unaffordable and malformed requests. |
| Robux purchases | A failed prompt retires only its own unbound intent. Pending targets cannot be overwritten. A second receipt cannot reuse an intent already bound to a different receipt. Completing an older receipt does not clear a newer intent. UI reports a blocked pending purchase instead of silently doing nothing. | All 82 building grant plans/actions and paid flags, all configured fixed cash/building bundles, skip/refresh dispatch, duplicate receipts, save failures, retry/rejoin continuation and target ownership. Product calls/storage are mocked. |
| Rebirth | City/inventory/land preservation and existing cash reset remain. Tutorial rejects rebirth requests. The UI displays 1.15x accurately rather than rounding it to one decimal, and its eligibility alert clears correctly. | Existing preservation and eligibility tests; inspected income/population/XP multiplier consumers. |
| Placement | Oversized buildings no longer crash math.clamp. Client checks the entire footprint against owned tiles, matching the server's gap rejection. Collected/instant tools no longer require a free builder. Prior re-equip/highlight/late-reply/Base-vs-PrimaryPart fixes remain covered. | Oversized plot, unowned interior gap, forged tools, tilt/height/overlap/ownership rejection, repeated equips, late replies and preview cleanup. |
| Income | The scheduler pays elapsed whole seconds and retains fractional timing remainder. Gamepass lookup precedes income snapshot; credit/reset happen before optional quest/UI callbacks. Collection debounce no longer holds the player mutation lock for a cosmetic one-second wait. | Delayed-loop timing test plus source review of collection ordering. |

Rewards and their progression markers remain in the existing Data_1 save system; this work does not reset player saves. Tests use mocked Roblox services and are not evidence of real DataStore/receipt delivery.

## Rebirth reward assessment

Each rebirth permanently adds **0.15 to the income, population and XP multipliers** (additive: 1.00x, 1.15x, 1.30x). It retains the complete city, unlocks qualifying shop buildings and resets cash to `floor(10000 * (1 + newRebirthCount * 0.5))`: $15,000 after the first, $20,000 after the second. Because the city survives, production benefits begin immediately. These are meaningful rewards.

**The requirement curve still needs balancing.** Rebirth 1 needs 100 population; rebirth 2 jumps to 16,500. That is a much larger difficulty jump than the 15% additive reward suggests. Recommend a smoother early population curve based on actual time-to-rebirth data. Existing thresholds and reward amounts were preserved during this reliability review; a blanket rebalance would change player progression and unlock pacing.

Daily rewards are also generous relative to early-game prices: day 7 grants AuroraTower (catalog cash cost $5,000,000). That may support returning players, but retention/progression data is needed before increasing rewards further.

## Remaining blockers and limits

> Update 2026-09-23: blockers 1 and 2 below are addressed by intent archiving, equal-value compensation and the 10-minute steal snapshot fallback (see AGENTS.md "Road cars, purchase recovery..."). Live receipt testing is still required.

1. **High ? ambiguous historical paid targets.** An unresolved per-price product intent can block another purchase at that price after a lost cancellation/disconnect. Receipts contain the product ID, not the chosen building. Automatically expiring/replacing such intents could give a paid buyer the wrong item. Failed-prompt recovery is fixed; older ambiguous targets still need a recovery/product-mapping design. Distinct product IDs per building would remove this ambiguity for future sales, but would require Creator Hub product setup and migration.
2. **High ? cross-player steal target changes.** An owner can delete/move/complete the selected target before receipt fulfillment, or be locked in another server. Transfer processing safely defers but can remain unresolved. Buyer compensation/reservation policy and multiplayer recovery tests remain necessary.
3. **Live validation ? assets/products/UI.** Local source does not contain the authored models or all GUI purchase scripts. Bundles and pass buttons are not all prompted from the exported backend. Their Studio bindings cannot be certified here. Product sale status, ownership, displayed prices and regional pricing require current Roblox metadata. Shop labels still use configured price tiers, so check them against live prices.
4. **Device/performance verification.** Footprint sampling and authored construction/primary-part alignment need dense-city and mobile playtests. Server terrain queries, pathfinding and animation cannot be reproduced by local mocks. Initial construction placement, completion, saving/rejoin and instant placement must all be visually checked.

Robux fulfillment remains server-owned through [Roblox ProcessReceipt](https://create.roblox.com/docs/production/monetization/developer-products); prompt-finished events do not grant rewards. Product metadata checks use the documented [GetProductInfoAsync API](https://create.roblox.com/docs/reference/engine/classes/MarketplaceService#GetProductInfoAsync).

## Final local validation

All **18 test scripts** passed. All **197 source files and 23 tooling files** compiled. Literal module paths and extracted module dependencies passed. The deliberate failed-quest-reward test emits a warning before verifying retry recovery. None of these checks contacted a live DataStore or purchased a Roblox product.

## Concrete Studio checks

Sync client/server/shared together and restart Play. Run `tools/audit_studio.luau` and the new read-only `tools/audit_commerce_studio.luau` in the Studio Command Bar. The commerce audit checks every catalog building/construction template and queries all configured product/pass metadata; it neither prompts purchases nor grants items.

Then exercise: all five quests through rejoin; daily claim/rejoin and rejection of a second claim; first rebirth with city retained and the stated cash reset; cash shop locks/stock; Robux purchase/cancel/rejoin and each bundle/pass/skip/refresh; placement on mouse/touch, all rotations, occupied/gapped land, full builder queue and large buildings. For unresolved steals, use two test players and test target changes/disconnection. Record the Output errors and actual receipt outcomes before claiming a production pass.
