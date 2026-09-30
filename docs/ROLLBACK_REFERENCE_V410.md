# MyCity pre-rollback feature reference

Source-backed snapshot: 2026-09-27. This inventories the current MyCity workspace around the Roblox v410 build before any place rollback.

Evidence labels:

- **Post-404**: verified source change after the stated 2:18 PM v404 cutoff.
- **In v404-era build**: already present in source by the cutoff, so it should not be counted as a v410-only addition.
- **Current**: present in the current source, but not proven to have first appeared in either published revision.

Roblox Studio logs confirm place revision 404 and later revision 410. A subsequent latest-version check reported 411, so this document is the reliable source/workspace reference; authored Studio-only object differences still require a saved-place or Place Version History comparison.

## Post-404 changes most at risk in a rollback

- **Post-404 — development-scaled city life:** road cars now scale from roads, completed buildings and Population; require at least two roads; cap at 12 per city and 72 per server; use fair round-robin budgets; grow at most one car per city per second; and expose `AmbientCarTarget` on each plot.
- **Post-404 — denser civilians:** civilians scale from completed non-road buildings, road count and diminishing-return Population; cap at 10 per city and 80 per server; retain gradual admission, cached geometry and existing low-frequency movement.
- **Post-404 — first Epic milestone:** persisted `FirstEpic` flag, schema migration, Epic construction-completion routing, purple lighting/camera shake, server-wide first-Epic announcement, and independent milestone state. It reuses `RareVFX` and `SFX.RareBuilding` because no Epic-specific asset exists.
- **Post-404 — creator/test cleanup:** only user IDs `1790165114` and `2044711693` receive the white `[CREATOR]` chat tag. Staff, member/group and Premium custom tags were removed. Owner `1790165114` gets a clean gameplay profile every join, skips the tutorial and re-arms first Rare/Epic/Legendary testing while transaction metadata remains preserved.
- **Post-404 — pack correction:** `BuilderPack.TextLabel1` reads developer product `3388944230` with the player's local Robux price. It is separate from eighth-builder game pass `1407360513` and Skyline product `3714990977`.
- **Post-404 — Skyline close behavior:** a successful product `3714990977` prompt closes the Starterpack panel, deselects the Skyline topbar icon and suppresses the second automatic reminder; grants remain receipt-authoritative.
- **Post-404 — city-like copy:** a successful like now says `Liked <DisplayName>'s city`, without the developer-style `Success:` prefix or internal total. Duplicate/error and owner notifications retain their specific wording.

## City building and construction

- **Current:** server-authoritative building placement, owned-land validation, overlap/collision checks, placement range checks and commit-time revalidation.
- **Current:** smooth client placement preview, rotation, mobile controls, placement HUD, invalid-placement feedback, cancellation/cleanup and reconnect-safe held tools.
- **In v404-era build:** unified footprint rules use configured grid size rather than raw decorative extents; construction and completed models are normalized from authored templates.
- **In v404-era build:** Military Base uses the 0.5-stud half-grid alignment rule. Airport offsets only the axis corresponding to its odd 13.5-stud side after rotation.
- **Current:** active-builder limit and construction reservations prevent race-condition overbooking.
- **In v404-era build:** players without game pass `1407360513` are prompted for the eighth-builder upgrade when placement reaches the seven-builder cap; owners already capped at eight are not reprompted; client prompt has a two-second duplicate guard.
- **Current:** timed construction, restoration after rejoin, construction visuals/rise animation, Robux skip path, completion conversion and completion sound/VFX.
- **Current:** building levels and XP for non-road buildings; road types are explicitly `NoLevels` and hide level UI.
- **Current:** building stats aggregate Population, Happiness, Health and Safety, including penalties and cached snapshots.
- **Current:** building thoughts/speech bubbles, prompts, information panels, pickup/store actions and destroy/remove flows.
- **Current:** building stealing preserves a saved snapshot and supports delayed delivery if the original owner is temporarily unavailable.
- **Current:** Military Base is Epic, 5x5, costs $680,000, unlocks at 24 rebirths and has limit 1.
- **In v404-era build:** internal `SkyscraperGeneric` is presented to players as **Apex Tower**; it is Legendary, 4x4, costs $1,150,000, gives 125,000 Population and has limit 2.

## Shop, stock and monetization

- **Current:** server-owned rotating stock, per-player stock view, timed refreshes, purchase validation, limits and sold-out handling.
- **Current:** Epic stock is guaranteed through an independent rotating slot and persists across server restarts without replacing the normal shared slots.
- **Current:** shop cards support lock state, rarity colors, stock counts, cash price, Robux fallback and purchase confirmation.
- **In v404-era build:** all non-inventory building imagery uses shared 3D viewport previews. Shop cards lazily create/release spinning preview models when visible/offscreen.
- **In v404-era build:** one transparent bottom spacer with aspect ratio 3 prevents the last catalogue card from being clipped.
- **In v404-era build:** centralized `UIController/DevProducts` replaces the embedded Shop LocalScript and binds direct `<Card>.Buy` paths for Cash1-6, MidDeal1, LuxuryDeal and Gamepass1-3.
- **In v404-era build:** developer-product and game-pass buttons fetch player-local prices immediately and every 60 seconds, showing `R$<price>` or `R$???` on failure.
- **In v404-era build:** building purchase panels fetch the selected price-tier product and write `<price>` to `PurchaseFrame.Buttons.RobuxBuy.TextLabel`/`Textlabel` and cloned `ItemTemplate.Locked.Buy.Cost`; requests cache/coalesce for 60 seconds.
- **Current:** developer-product purchase intents are recoverable. Old unbound choices are archived; receipts resolve open choice, then archived choice, then equal-tier compensation instead of permanently blocking future prompts.
- **Current:** receipt ledger is idempotent, binds the chosen grant plan in the same save and preserves transaction metadata through owner test resets.
- **Current:** products include cash offers, building purchases, skip construction, steal delivery and pack rewards; game passes use ownership checks rather than trusting the client.
- **In v404-era build:** Builder Pack remains the original separate side offer. Its label and icon receive occasional bounded attention animation; the whole button/background/stroke does not pulse.
- **In v404-era build:** Skyline Pack is a separate TopbarPlus image icon (`rbxassetid://98703767607590`) beside Settings/Inventory, not a cloned side button.
- **In v404-era build:** Skyline/Starter Pack product `3714990977` grants Petronas Towers, Apex Tower (`SkyscraperGeneric`) and Military Base through the server receipt ledger.
- **In v404-era build:** Skyline price and caption use the player's local Robux price. The panel auto-offers after four minutes, then once more 30 minutes after the first successful show, waits for tutorial/modal clearance and never auto-shows more than twice per session.
- **In v404-era build:** Skyline panel includes rotating gradient, moving/fading/spinning stars, breathing sunbursts, staggered reward pops, spinning 3D rewards and only a gradient shine plus small shake on the purchase button.
- **In v404-era build:** Skyline Military Base preview includes a self-contained orbiting helicopter with spinning main and rear rotors.

## Economy, inventory and selling

- **Current:** building income calculation, offline/elapsed accumulation, city-level cache, plot income displays, collection prompts and cash feedback.
- **In v404-era build:** collecting when no income is available is silent; valid collection still updates cash and progression.
- **Current:** building inventory serializes stored buildings into Tools, restores them safely and keeps Satchel inventory compatibility.
- **Current:** held-building miniatures are cloned from authoritative building templates; retired ToolBuildings/embedded tool-script dependencies are not required.
- **Current:** sell-area prompts, equipped-building sell UI, authoritative valuations and server-owned sale completion.
- **Current:** rebirth reset/preservation behavior keeps the player's city where configured, updates rebirth multipliers/rewards and uses authored confirmation/reward UI.

## Progression and retention systems

- **Current:** complete staged tutorial with intro camera, guidance arrows/highlights, subtitles, bank and shack equip/place/build milestones and server-owned tutorial state.
- **Current:** post-tutorial chain contains 35 append-only quests spanning collection, construction, buildings, rarity, roads, Population, cash, rebirths and land; rewards are granted before progression advances.
- **Current:** daily quests have authored board UI, claim styling, server runtime state, safe reset/claim flow and reserved layout ordering.
- **Current:** daily rewards, group Police Station reward, badges, redeemable codes, claim alerts and player reward messaging.
- **Current:** rebirth requirements, rewards, confirmation preview, unlock display and reset lifecycle.
- **In v404-era build:** `NewPlayerProgression_v1` sends one 49-step lifetime funnel for genuinely new post-deployment profiles: join, 12 tutorial milestones, 35 quest completions and all-progression complete. Existing profiles and the owner are excluded; the funnel ID persists across sessions.

## World simulation and ambience

- **Current:** eight-plot assignment, relocation, reset and scenery ownership lifecycle.
- **Current:** land expansion and unlock validation.
- **Current:** city naming with filtering/validation and city display updates.
- **Current:** weather changes and client weather presentation.
- **Current:** highway vehicle and train systems publish lightweight immutable trip descriptors; clients render/move the cosmetic models.
- **Current:** city road graph supports straight roads, turns, intersections, dead ends, lane direction, right-hand offsets, route replanning and open-end detection.
- **Current:** highway cars can divert into connected player cities through PlotCutOff marker chains, tour city roads and rejoin a compatible carriageway; diagnostics explain failed links.
- **In v404-era build:** centralized server AirportSystem runs one plane at a time through approach, flare, touchdown, braking, taxi, ten-second gate wait, takeoff and departure using real-time studs-per-second movement and model-orientation correction.
- **In v404-era build:** airport attachment height correction, smooth heading blends, ground-direction flattening and fallback departure headings prevent floating, snapping and 90-degree pitch jumps.
- **In v404-era build:** client MilitaryHelicopterController hides the welded source Heli and renders a collisionless local clone in a compact variable-radius/altitude orbit with correct nose heading, bank, pitch and spinning `MainBlades`/`RearRotor`.
- **Current:** cosmetic civilians have varied rigs/appearance, walking and idle animations, cached walk geometry, obstacle handling and stuck recovery.
- **Current:** rarity VFX supports first Rare, first Epic and first Legendary milestones with global announcements, lighting/camera effects and authored rarity sounds.

## UI, previews and player feedback

- **Current:** modular HUD bootstrap, intro/play reveal, frame navigation, cleanup-owned connections and replacement-safe initialization.
- **In v404-era build:** TopbarPlus is source-synced under `ReplicatedStorage.shared.TopbarPlus.Icon`, avoiding the former infinite wait on the missing root dependency.
- **Current:** topbar Settings, Inventory and Skyline controls; side buttons for shop/building flows; travel buttons; construction list; cash/builder displays; weather and city prompts.
- **Current:** mobile HUD scaling and mobile placement support.
- **Current:** centralized queued notification system, claim alerts, error/normal/reward styles and remote event bindings.
- **Current:** custom proximity prompt renderer with hold progress and theme support.
- **Current:** cash gain/loss feedback and number counters.
- **In v404-era build:** shared `BuildingViewport` renders shop, sell, building-info, rebirth-unlock and post-tutorial reward building previews; inventory/Satchel icons remain 2D by design.
- **In v404-era build:** previews use fixed warm lighting, visible-bounds camera fitting, 35-degree camera and 18-degrees-per-second rotation; hidden/offscreen previews are released after two seconds and share one RenderStepped connection.
- **Current:** missing preview/template assets warn without blocking the rest of HUD initialization.

## Audio

- **In v404-era build:** all source audio uses the authored `SoundService.SFX` bank; temporary `GuessTheSize` dependencies were removed.
- **In v404-era build:** mapped cues include Hover, Click, Swoosh, Notification, NotificationLow, Error, Purchase, Reward, CaChing, PlaceSound, RotateSound, DestroySound, BuildingComplete, Popin, RareBuilding, LegendaryBuilding, StartUp and Ambience.
- **In v404-era build:** reward sounds wait for server confirmation; rarity notices do not double generic notification audio; rebirth does not layer a duplicate completion cue.
- **Current caveat:** `Ambience2`, `Construction` and `Nuke` remain intentionally unbound. Authored sound ID `6525690145` is not approved for the experience and cannot be fixed from source alone.

## Social, chat and city engagement

- **Current:** city likes use durable storage, duplicate prevention, owner notification, like-count displays and reward settlement.
- **Current:** city-like rewards are server-owned and recoverable rather than client-trusted.
- **Current:** friend boost system applies eligible social bonuses.
- **Post-404:** successful like copy is player-facing and names the city owner; no internal count is shown in the confirmation.
- **Post-404:** only the two configured creator IDs receive custom role tags; ordinary users keep Roblox's normal chat prefix.
- **Current:** system tips, rarity announcements, camera-shake commands and local command hiding remain in ChatTags.

## Persistence, security and lifecycle hardening

- **Current:** code-defined player schema creates Data/leaderstats and reconciles missing nested values; schema migration normalizes legacy scalar values.
- **Current:** session store has lease handling, load retry/recovery, release/shutdown flushing and repeated-join recovery.
- **Current:** startup waits are bounded, failed loads do not strand plots, and shutdown is coordinated.
- **Current:** request guards rate-limit and reject requests before a profile is ready or while it is leaving.
- **Current:** authoritative server checks cover cash, ownership, inventory, placement, shop purchases, rewards, construction and receipts.
- **Current:** SimulationScheduler and caches reduce repeated per-building work; ambient vehicle rendering is client-side; civilians and density systems use explicit global budgets.

## Validation and known caveats

- **Current:** automated suites cover persistence, loading/shutdown, placement, stock, receipts/recovery, progression/funnel, city social systems, airport/helicopter, road traffic, civilians, UI transitions, mobile scale, viewports and commerce surfaces.
- **Current validation state:** latest recorded source validation compiled 302 source files and 55 tooling files; the full suite previously passed 50 suites, with focused tests rerun after later small changes.
- **Studio-only caveat:** exact authored GUI layout, model dimensions/pivots, Marketplace overlays, sound approval, live DataStore/Analytics delivery and full-server frame time need Studio or published-server verification.
- **Rollback caution:** Roblox place rollback can restore authored Studio objects and embedded scripts that are not represented by the source tree. Preserve/export v410 before reverting if an exact binary recovery point is required.
