# City loading and runtime performance

Implemented against local MyCity source on 2026-09-09. No Studio server, device, MicroProfiler capture or published place was available. All figures below are source operation counts or removed explicit waits, not measured speedups.

## Changes

| Hotspot | Change | Scope |
| --- | --- | --- |
| Prompt setup waited 0.1 seconds for every building | Configure immediately; remove redundant final waits of 0.5s for buildings and 1s for constructions | For 100 completed buildings, this removes 10s of explicit prompt waits; it does not predict total load time |
| Each restored building scanned the growing city for income | No income rescan inside either restoration loop; finalize stats after buildings and constructions, then existing income setup | 100 saved buildings previously caused 100 growing-city income scans (5,050 building visits); now zero during that loop |
| Bursts from simultaneous joins | Shared RestoreBudget yields between objects after six objects or about 3ms of work | Global between checkpoints, not one independent budget per player; clone/asset engine work itself cannot be interrupted |
| Anonymous, partially configured replicas | Configure completed building identity, values, weather and prompts before parenting to Placed | Existing IDs, mirrored plot coordinates, levels, XP and paid flags remain intact |
| Full-city scans for each of four stat categories on each building | One snapshot groups health/police/fire/decorations per plot evaluation | 1,000-building test enumerates Placed once rather than the previous 4,001 enumerations; distance work now visits only relevant candidates |
| Full-plot stats on every level-up | Recalculate only that building, since level only changes its happiness | Structural changes still recalculate the plot; periodic fallback is retained and spreads plots across frames |
| Owner lookup scanned every player and placed model | Resolve plot CityId through Players and verify PlotInfo/plot ancestry | No ownership guessing or accepting arbitrary workspace models |
| Game-pass service call per construction, builder update, collection or placement | Shared 60s successful-result cache and concurrent lookup reuse | Successful purchase immediately updates entitlement; lookup errors are not cached; departure clears the entry |
| Builder recount queued for every restored site | One final restoration recount | Periodic/live placement and completion updates remain |
| Repeated server billboard tween samples and unrelated redraws | Write XP progress target size once; only level/XP changes redraw that label | Progress remains visible, but its server-owned bar snaps to the target instead of tweening |
| Repeated civilian segment samples between movement commands | Validate the segment before each MoveTo refresh (0.45s) | Ground/current-footprint validation still runs every movement step; new obstacles stop the next command |
| XP running during incomplete load or indefinitely at maximum level | Wait for loaded owner, ignore departures and terminate at max level | Saved values and the five-second gameplay XP cadence remain |

## Validation

All 20 `tools/test_*.luau` scripts must pass alongside `validate_source.luau`, `check_paths.py` and `check_module_dependencies.py`.

`test_loading_performance.luau` executes the actual budget, BuildingData loader, construction restoration/codec and stat modules against mocked Roblox objects. It checks shared scheduling for 600 operations, elapsed work budget, departure cancellation, 100 saved buildings, mixed active/offline-completed constructions, missing authored model rejection, metadata preservation and 1,000-building stat equivalence. The original nearest-provider formula is intentionally preserved, including its documented stronger-provider selection issue.

`test_gamepass_cache.luau` verifies 100 repeated checks use one successful API call, true/false expiry, immediate purchases, failed-query retry, concurrent callers, a purchase racing an older response, and departure cleanup. Civilian tests cover route checks between commands and rejection of a newly blocked route.

## Next measurements in Studio

Test a large saved city with several clients joining simultaneously, then normal placement/deletion, near-complete constructions, owner tutorial replay and departure halfway through loading. Confirm the loading intro remains active until MyCityLoaded and all expected city objects appear. Compare server frame times, loading duration and client frame times before/after on the same city and device.

Remaining costs need real measurements: individual authored model clone complexity, meshes/textures and replication bursts, all-world rendering, held inventory model cloning, server-driven traffic/construction effects, civilian geometry/pathfinding and per-building XP tasks. Service/decor-heavy cities still have proportional distance work (all decorations is a worst-case quadratic arrangement). First uncached ownership checks and DataStore requests still depend on Roblox service latency. This pass does not promise zero lag or change streaming settings, model appearance, save schema, cash or income formulas. Consider client-local cosmetic traffic and asset LOD only after measuring their impact and validating authored appearance/streaming behavior.
