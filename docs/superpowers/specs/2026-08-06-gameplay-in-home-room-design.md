# Gameplay in the Home Room — Design Spec

**Date:** 2026-08-06
**Status:** Approved design, pre-plan
**Related:** `2026-08-06-home-room-design.md` (the Home room this builds on)

## Goal

Move the entire game-making loop out of the per-plot studio building and into
each player's private **Home room**. The Home room becomes the player's *studio
interior*: work stations + furniture customization in one big private space. The
studio building on the plot stays as an empty walk-up exterior that leads into
the room. **No gameplay math changes** — this is a "relocate + re-wire where
things live" refactor, not a redesign.

## Global Constraints (carry into every task)

- `GameData.StartingCash` stays **0**.
- Mini-games, trend/cash math, worker logic, prices: **unchanged**. Reuse the
  existing modules and formulas verbatim.
- Neon material only ever uses the accent colour (existing project rule).
- New game passes / monetization ids must never error at id 0 (unchanged).
- **Save compatibility:** existing `PlayerData` carries over untouched. The
  `houseTier` field is reused as **room-size tier** (same 0..`HouseTierCount-1`
  range, same `getHouseUpgradeCost`). `roomsOwned` (Arcade/Merch) carries over.
  `homeItems` (furniture) carries over. No migration/wipe.
- Server stays the sole authority for placement, purchases, prompts, teleports
  (client only requests + displays).

## Current State (what we're moving)

Built today by `PlotManager` into the studio building on the plot
(`workspace.Plots.Plot<i>`):

- **4 dev stations** (`STUDIO_LAYOUT`): `NewProject`, `Coding`, `MapBuilding`,
  `Testing` — each a desk + `Seat` named `<name>Seat`. The client shows that
  station's panel while the player occupies its seat
  (`STATION_NAMES`/`STATION_PANELS` in `UI.luau`). `NewProject`'s monitor is the
  **PC** and carries `PCUpgradePrompt` (scales with `pcTier`).
- **Workers desk** (`buildWorkersDesk`) + worker NPCs (`refreshWorkerNPCs`).
- **Trends board** (`buildTrendsSign`) on the back wall.
- **House upgrade NPC** (`buildUpgradeNPC`) carrying `HouseUpgradePrompt`; today
  `RequestUpgradeHouse` (HouseService) bumps `houseTier` → adds a studio floor.
- **Arcade + Merch idle rooms** (`buildInteractiveRoom` → `ArcadeRoom`,
  `MerchRoom`): walled wings with a green `BuyPad`, a `CollectPrompt`, and
  passive income; gated by `roomsOwned` / `RequestBuyRoom`.

The Home room today (`HomeService`, `workspace.Homes.Home<i>`) is a sky room
(`GameData.Home`: 64×48, cell 4, 16×12 grid, wallH 20, skyY 10000, spacing 400)
with server-authoritative furniture grid placement only.

## Target Architecture

### The room is the studio interior

`HomeService` builds each room shell, then **populates it with the gameplay
fixtures**. To avoid duplicating `PlotManager`'s builder helpers (they depend on
many file-local helpers), `PlotManager` exposes ONE entry point:

```
PlotManager.populateHomeInterior(roomFolder, interiorBase, tier, pcTier)
```

which places, relative to `interiorBase` (a Vector3 anchored to the room's back
wall): the 4 dev stations + Workers desk + Trends board + PC/`PCUpgradePrompt` +
room-size `HouseUpgradePrompt` + Arcade/Merch buyable zones. `HomeService`
rebuilds calls it (see data flow). Worker NPCs are placed by the same call
(reusing the existing NPC builder against the room's workers desk).

### Room zones

The room floor is split into two regions:

- **Work zone** — a fixed band along the **back** wall holding all fixtures
  (stations line the back; Trends board on the wall above; Workers desk beside
  them; room-upgrade prompt at one end). Furniture **cannot** be placed here.
- **Living zone** — the remaining front/centre floor, the grid area the player
  decorates with furniture.

Furniture placement is restricted to the living zone: the existing
`homeInBounds`/`homeOverlaps` checks gain a reserved-region check (a helper like
`homeCellFree(gx,gz,w,d)` that also rejects cells inside the work zone and any
owned idle-zone footprint). The client ghost mirrors the same rule (red over the
work zone).

### Arcade + Merch as in-room corner zones

The two idle rooms become **compact corner zones** in the room (not walled
15×16 wings). Each: a `BuyPad` + buy sign until purchased; once `roomsOwned`,
its fixture (a small arcade-cabinet cluster / merch stand) + `CollectPrompt`
appear. Same `RequestBuyRoom` / income / `CollectPrompt` server logic — only the
geometry and location change. Their footprints are reserved from furniture.

### Room grows with tier

`houseTier` (0..2) now selects room **size**. Add to `GameData.Home`:

```
Home.tiers = {
  [0] = { roomW = 64,  roomD = 48, cols = 16, rows = 12 },
  [1] = { roomW = 80,  roomD = 56, cols = 20, rows = 14 },
  [2] = { roomW = 96,  roomD = 64, cols = 24, rows = 16 },
}
```

`roomW/roomD/cols/rows` become **derived from the player's tier** at build time
(the flat top-level `roomW=64...` stays as the tier-0 default / fallback). The
back work zone stays anchored to the back wall, so growth only adds living-zone
space toward the front — **already-placed furniture stays in bounds** (growth
never shrinks). Pure helpers that take grid dims (`homeInBounds`, `homeOverlaps`,
`homeCellToWorld`) gain a `dims` argument (or read a passed-in room config)
instead of the module-level constants.

### Studio building = empty exterior + entrance

`PlotManager` stops building stations/trends/upgrade/idle-rooms in the studio and
stops adding floors: the studio is always a **single-floor empty shell** +
exterior + landscaping (skins still apply cosmetically). Entry to the room:

- The **🏠 My Home** HUD button (exists) → `RequestEnterHome`.
- **Walking through the studio door** → enters the room too (now safe: the studio
  is empty, so the earlier walk-through conflict is gone). Re-add a doorway
  trigger that fires `enter()`; leaving still lands at the studio entrance
  (`getStudioEntranceCFrame`), outside the door, so no loop.
- The lobby **Studio Kiosk** (press E) still travels to the studio exterior.

### Client retarget

`UI.luau` currently scans `workspace.Plots.Plot<i>` for the player's `Seat`s and
the tutorial/prompts assume the plot. Gameplay now lives in the room, so the
client resolves the player's **Home folder** (`workspace.Homes.Home<i>` by
plotIndex) and scans it for `<name>Seat`s and prompts. Seat→panel logic,
`updateSeatedStation`, and the seated-HUD behaviour are otherwise unchanged.

### Server prompt ownership

`PlotManager.start`'s `ProximityPromptService.PromptTriggered` gate today checks
the prompt is a descendant of the player's own plot. It must also accept prompts
inside the player's own **Home folder** (the room belongs to the player). Same
handlers (`ElevatorPrompt` no longer applies — single floor; `CollectPrompt`,
`PCUpgradePrompt`, `HouseUpgradePrompt`, workers) run unchanged otherwise.

## Data Flow Changes

- **Join:** `HomeService` builds the room shell **and** the interior (via
  `populateHomeInterior`) sized to the player's `houseTier`, then places worker
  NPCs and furniture. `PlotManager` builds the empty studio shell only.
- **PC upgrade** (`pcTier` change): rebuild the **Home room** interior (the
  monitor/PC lives there now), not the studio.
- **Room upgrade** (`RequestUpgradeHouse` → `houseTier++`): rebuild the **Home
  room** at the new size (keep furniture; re-anchor work zone). Cost/cap logic in
  `HouseService` + `getHouseUpgradeCost` unchanged.
- **Buy Arcade/Merch** (`RequestBuyRoom`): unchanged logic; the zone fixture +
  `CollectPrompt` appear in the room on rebuild.
- **Furniture place/move**: unchanged remotes; server now also rejects cells in
  the work zone / owned idle-zone footprints, and uses the player's tier dims.

## Testing (per round, in Studio)

For each round: `rojo build` compiles; start play; inspect `workspace.Homes` via
`execute_luau`; confirm no new console errors (DataStore-off notices expected).
Specifically verify: the seat→panel loop works from the room; sitting at New
Project starts a dev cycle and mini-games run; hiring a worker works; Trends
board shows trends; PC upgrade + room upgrade rebuild the room correctly and keep
furniture; Arcade/Merch buy + collect work; furniture can't be placed on the work
zone; leaving returns to the studio entrance; the studio building is an empty
exterior with a working door-entry.

## Rounds (implementation order)

1. **Room sizing by tier** — `GameData.Home.tiers` + make the pure home helpers
   take dims; `HomeService` builds the shell at the player's tier size. (Furniture
   still works; no fixtures yet.)
2. **Stations + Trends + PC in the room** — `PlotManager.populateHomeInterior`
   places the 4 dev stations + Trends board + PC/`PCUpgradePrompt` into the work
   zone; client retargets seat/panel scanning to the Home folder; reserve the
   work zone from furniture.
3. **Workers in the room** — Workers desk + worker NPCs in the room; WorkersPanel
   works; server prompt-ownership accepts the Home folder.
4. **Room upgrade + PC upgrade rebuild the room** — re-wire `RequestUpgradeHouse`
   and `pcTier` changes to rebuild the Home room (size / PC), keep furniture;
   stop `PlotManager` adding studio floors (studio = single empty shell).
5. **Arcade + Merch in the room** — compact corner buy-zones + `CollectPrompt`,
   gated by `roomsOwned`; reserve their footprints from furniture.
6. **Studio door entry + cleanup** — walking through the studio door enters the
   room; remove now-dead studio-interior building code from `PlotManager`; update
   the tutorial if a step points at a studio fixture.

Each round ends with a compiling build + a Studio smoke test and its own commit.

## Risks / Notes

- **Biggest risk:** the client seat/prompt retarget (plot → Home folder). Keep
  the seat-name suffix convention (`<name>Seat`) so `stationForSeatName` is
  unchanged; only the *folder being scanned* changes.
- Rooms are far apart in the sky (spacing 400) and grow to ≤96 deep, well within
  spacing — no overlap between players' rooms.
- Tutorial: step 2 ("Sit at the New Project computer") now resolves the seat in
  the Home room; ensure onboarding still finds it.
- YAGNI: Arcade/Merch stay single-instance buyable zones (no multiples); room
  tiers stay at 3 to match `HouseTierCount`.
