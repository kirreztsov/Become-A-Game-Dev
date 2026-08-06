# Personal Home Room — Round 1 Design Spec

**Goal:** A private, customizable **Home** for each player: walk near your studio → a white pad appears → touch it → teleport into your own big room (bigger inside than the studio looks) where you place furniture from a free starter set on a grid, move/rotate/delete it, and it saves. Round 1 = the whole room + entry + grid placement + save with a **free** catalog. Buying with cash (Round 2) and level-unlocks (Round 3) come later.

**Architecture:** A new server module `HomeService` owns one hidden per-player room (placed far up in the sky, offset by plot index so rooms never overlap or touch the map), a white **Home pad** at the studio entrance that teleports the owner in, a **Leave pad** that sends them back, and the placement remotes + persistence. Furniture is server-authoritative: the client `HomePanel` shows the inventory + a grid ghost and only *requests* placement; `HomeService` validates (owner, in-bounds, valid item) and stores it in `PlayerData.homeItems`, rebuilding the room's furniture on entry. Furniture reuses existing detailed Blender assets via `StudioModels` where possible, with a few procedural pieces.

**Tech Stack:** Roblox / Luau, Rojo, existing `PlayerData` / `StudioModels` / `Remotes` / `PlotManager` (plot origins + `plotOfPlayer`) / `MobileScale`, character `PivotTo` teleport.

## Global Constraints

- **Truly private.** Only the room's owner is ever teleported into it; every placement/move/remove remote re-checks that the caller owns the room it targets. No one else can enter or edit another player's Home.
- **Server-authoritative.** The client never places furniture directly — it sends a request; the server validates (item exists in the catalog, target cell is inside the room grid and not overlapping, caller is the owner) and is the only writer of `PlayerData.homeItems`. Rejected requests do nothing (no error).
- **Mobile + desktop.** Placement works by tap (phone) and click (PC); the inventory/controls follow existing `StorePanel`-style UI and scale via `MobileScale`. Tap targets ≥ 44px.
- **Don't disturb the studio/gameplay.** The Home is a separate space; the studio, its stations, plots, and existing decorations system are untouched. The Home pad is additive at the studio entrance.
- **Reuse detailed assets; don't block on new modeling.** The starter catalog is built from existing detailed Blender assets (`assets/studio/*.rbxm`) where one fits, plus a few simple procedural pieces flagged for a later detailed-Blender upgrade (per the user's "models should be detailed" rule — new dedicated furniture models get the full Blender treatment when added, not in this round).
- **Free in Round 1.** All catalog items are placeable with no cost and no unlock; `GameData.StartingCash` stays `0`. Acquisition (buy/unlock) is explicitly out of scope here.
- **Backward compatible.** New `PlayerData.homeItems` defaults to `{}` with migration backfill; existing saves load unchanged.
- **Verification = `./rojo-bin/rojo build …` + Studio playtest.** No unit tests except the pure grid/catalog helpers (see Testing).

## Component 1 — The Home room (per player, in the sky)

- `HomeService.build()` at server start creates a hidden **Homes** folder. Each of the game's plots (indices 1..N, via `PlotManager` plot origins) gets a room reserved at a sky location far from the map and from each other, e.g. `HOME_ORIGIN = Vector3.new(0, 10000, index * 400)`.
- A room is a large box: floor + 4 walls + ceiling + one window strip, plain neutral colors, **bigger than the studio's 48×32 exterior** — `ROOM_W = 64`, `ROOM_D = 48`, wall height `20`. Open interior for decorating.
- A **Leave pad** (white, glowing) sits by the room's entrance; touching it returns the player to their studio (`PlotManager` plot origin / studio entrance CFrame).
- Rooms are built empty at startup; a player's saved furniture is (re)built into their room when they enter (Component 4).

## Component 2 — Entry: the Home pad

- `HomeService` (or `PlotManager` at build) places a **white Home pad** at each plot's studio entrance (just outside the door), named `HomePad`, `CanCollide=false`, glowing (Neon accent, small — per Neon-accent rule) with a floating "🏠 My Home" label.
- **"Opens when near":** a client/proximity effect makes the pad rise + brighten when the **owner** is within a few studs (a `Touched`/proximity check server-side, or a `ProximityPrompt` "Enter Home"). To keep it a "touch the white space" feel: use the pad's `Touched` event — when the owner's `HumanoidRootPart` touches it, fire entry. (A ProximityPrompt is the fallback if `Touched` proves finicky on mobile.)
- On owner touch → `HomeService` teleports the player's character (`PivotTo`) to their room's spawn point, and ensures their furniture is built. Non-owners touching it do nothing.

## Component 3 — Grid placement

- **Grid:** the room floor is a grid of `CELL = 4`-stud cells → `ROOM_W/CELL` × `ROOM_D/CELL` = 16 × 12 cells. An item occupies a whole-number footprint of cells (`cells = {w, d}` from the catalog). Placement snaps the item's footprint to cells; stored as integer cell coords `(gx, gz)` (0-indexed from a room corner) + `yaw` in 90° steps (0/90/180/270).
- **Client (`HomePanel`):**
  - A **Furniture** button (shown only while inside the Home) opens the inventory: a scrollable grid of catalog cards (icon + name).
  - Selecting an item enters **placement mode**: a translucent **ghost** of the item follows the pointer, snapped to the nearest grid cell; the affected cells highlight (green = free, red = occupied/out-of-bounds). **Rotate** with a button / `R` key (90° steps). **Tap/click** a valid cell → send `RequestPlaceHomeItem(itemId, gx, gz, yaw)`.
  - Tapping an already-placed item opens a small menu: **Move** (re-enters placement mode for it → `RequestMoveHomeItem`), **Rotate**, **Delete** (`RequestRemoveHomeItem`).
- **Server (`HomeService`):** validates each request — item id in `GameData.HomeCatalog`, footprint fully inside the grid, cells not overlapping another placed item (except the item being moved), caller owns this room. On success, update `data.homeItems`, (re)build that item in the room, and push confirmation (`HomeStateUpdated` or a targeted rebuild).

## Component 4 — Catalog, save, rebuild

- **`GameData.HomeCatalog`** — ordered array of `{ id, name, icon, cells = {w, d}, asset = "<StudioModels name>" or nil, build = "<procedural kind>" }`. Round-1 set (free): **Desk, Chair, LoungeChair, PicnicTable, Umbrella, Bench, TrashCan** (reuse existing `assets/studio` Blender models), plus procedural **Rug, TV, Bookshelf, Bed, PC** (simple Parts now; flagged for detailed-Blender upgrade later). `getHomeItem(id)` returns the entry.
- **Persist:** `PlayerData.homeItems = { { id, gx, gz, yaw }, … }` (default `{}` + migration backfill). Server is sole writer.
- **Rebuild:** `HomeService.rebuildHome(player)` clears the room's furniture folder and re-places every saved item from the catalog (Blender asset via `StudioModels.place` scaled to its cell footprint, or the procedural builder), anchored, at the grid cell world position. Called on entry and after any placement change.
- Placement world position: `roomCornerWorld + Vector3(gx*CELL + footprintW/2, floorTop, gz*CELL + footprintD/2)`, rotated by `yaw`.

## Data & files

```
src/shared/GameData.luau         -- + HomeCatalog + getHomeItem + Home config (ROOM_W/D, CELL, sky origins); grid helpers (cellToWorld, cellsFree)
src/shared/Tests/RunTests.luau   -- + tests for grid helpers (in-bounds, overlap, cell->world) + catalog lookup
src/shared/Remotes.luau          -- + RequestEnterHome, RequestLeaveHome, RequestPlaceHomeItem, RequestMoveHomeItem, RequestRemoveHomeItem, HomeStateUpdated
src/server/PlayerData.luau       -- + homeItems default + migration
src/server/HomeService.luau      -- CREATE: build rooms + pads, teleport in/out, validate + persist placement, rebuild furniture
src/server/init.server.luau      -- start HomeService; build the Home pads
src/client/HomePanel.luau        -- CREATE: inventory UI + grid ghost + place/move/rotate/delete; Furniture button (in-Home only)
```

No change to the studio, plots, or the existing `decorations`/`DecorPanel` system.

## Data flow

```
Walk near studio -> HomePad glows/rises (owner only)
Touch HomePad -> RequestEnterHome (or Touched) -> HomeService: rebuildHome(player) + PivotTo room spawn
Open Furniture -> HomePanel shows GameData.HomeCatalog
Pick item -> ghost snaps to grid cell (green/red) -> rotate -> tap cell
  -> RequestPlaceHomeItem(id,gx,gz,yaw) -> validate (owner,in-bounds,free) -> data.homeItems += entry -> build item -> HomeStateUpdated
Tap placed item -> Move/Rotate/Delete -> RequestMove/RemoveHomeItem -> validate -> update data.homeItems -> rebuild
Touch LeavePad -> RequestLeaveHome -> PivotTo studio entrance
Re-enter later -> rebuildHome replays data.homeItems -> layout restored
```

## Testing

- **Unit (`RunTests.luau`, pure only):** grid helpers — `cellToWorld` maps a cell to the expected world offset; `cellsFree` returns false when a footprint is out of bounds or overlaps an existing item and true otherwise; `getHomeItem` returns the right entry / nil for unknown id.
- **Studio playtest:** touch the Home pad → land in the private room; open Furniture, place several items on the grid (ghost snaps, red on overlap/out-of-bounds), rotate, move, delete; leave via the Leave pad → back at studio; re-enter → layout persisted (note: cross-session save needs a published server, DataStore off in Studio); a second (simulated) player can't reach or edit your room.
- **Compile check** after each change.

## Non-goals (YAGNI, Round 1)

- No buying furniture with cash (Round 2) and no level-unlocks (Round 3) — everything is free.
- No friends/co-op visiting your Home; no shared/public rooms.
- No wall-mounted items, stacking, or free (non-grid) placement — floor grid only, 90° rotations only.
- No new dedicated Blender furniture models this round (reuse existing assets + simple procedural placeholders; upgrade to detailed Blender later).
- No multiple rooms / house sizes; one room per player.
- The Home is cosmetic — placed furniture has no gameplay effect.
