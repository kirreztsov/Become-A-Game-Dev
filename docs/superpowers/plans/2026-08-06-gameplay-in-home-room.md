# Gameplay in the Home Room — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move the whole game-making loop (stations, workers, trends, PC/room upgrades, Arcade/Merch) out of the per-plot studio building and into each player's private Home room, keeping the studio as an empty walk-in exterior.

**Architecture:** `HomeService` builds each sky room shell (now sized by the player's tier) and then calls a single new entry point `PlotManager.populateHomeInterior(roomFolder, backWallPoint, tier, pcTier)` that reuses PlotManager's existing station/trends/PC/upgrade/idle-room builders to fill the room's back "work zone". The client retargets its seat/prompt/trends scanning from `workspace.Plots.Plot<i>` to `workspace.Homes.Home<i>`. Furniture placement is restricted to the "living zone" (front of the room). PC/room upgrades rebuild the Home room instead of the studio.

**Tech Stack:** Roblox Luau, Rojo (`./rojo-bin/rojo`), Roblox Studio MCP for playtests. No unit-test framework — verification is a compile + a Studio smoke test per task (see Verification Protocol).

## Global Constraints

- `GameData.StartingCash` stays **0**.
- Mini-games, trend/cash math, worker logic, and prices are **unchanged** — reuse existing modules/formulas verbatim; do not re-tune numbers.
- Neon material only ever uses the accent colour.
- New game-pass / monetization ids must never error at id 0.
- **Save compatibility:** no `PlayerData` migration/wipe. Reuse `houseTier` (0..`HouseTierCount-1`, `HouseTierCount = 3`) as the **room-size tier**; `roomsOwned`, `homeItems` carry over unchanged.
- Server is the sole authority for placement, purchases, prompts, and teleports.
- The Home grid cell size is `GameData.Home.cell = 4` at **every** tier (only `cols`/`rows`/`roomW`/`roomD` grow).

## Verification Protocol (every task)

There is no `pytest`. For each task, "run the test" means:

1. **Compile:** `./rojo-bin/rojo build default.project.json -o /tmp/x.rbxl` → expect `Built project to x.rbxl` with no error.
2. **Smoke test in Studio (via MCP):** ensure Rojo is serving (`./rojo-bin/rojo serve default.project.json --port 34872`) and the plugin is connected; `start_stop_play` to start; run the task's `execute_luau` inspection (Server datamodel unless noted); `get_console_output` and confirm **no new script errors** (the `DataStoreService: StudioAccessToApisNotAllowed` / "Failed to load data" notices are expected in Studio and are NOT failures); `start_stop_play` to stop.

A task's "Expected" describes the inspection result that proves it works.

---

## File Structure

- `src/shared/GameData.luau` — add `Home.tiers`, `Home.workRows`, `GameData.homeDims(tier)`; make `homeInBounds` tier-aware + work-zone-aware. (Modify.)
- `src/server/HomeService.luau` — build shell at the player's tier size; call `PlotManager.populateHomeInterior`; place worker NPCs; rebuild on PC/room upgrade; add studio-door entry. (Modify.)
- `src/server/PlotManager.luau` — add `populateHomeInterior`; stop building gameplay + floors in the studio (single empty shell); accept Home-folder prompt ownership; expose `getHomeBackWallPoint`. (Modify.)
- `src/server/HouseService.luau` — room upgrade rebuilds the Home room. (Modify.)
- `src/server/init.server.luau` — on join, rebuild the Home interior; PC upgrade rebuilds the Home room. (Modify.)
- `src/client/UI.luau` — resolve the player's Home folder and scan it (not the plot) for seats/prompts/trends; point the tutorial's plot hook at the Home folder. (Modify.)

---

## Task 1: Room sizing by tier (GameData + shell)

**Files:**
- Modify: `src/shared/GameData.luau:769-829`
- Modify: `src/server/HomeService.luau:35-76` (buildRoom), `113-137` (rebuildHome/enter)

**Interfaces:**
- Produces: `GameData.Home.tiers` (0-indexed map), `GameData.Home.workRows` (number), `GameData.homeDims(tier) -> {roomW,roomD,cols,rows}`, and a tier-aware `GameData.homeInBounds(gx,gz,w,d,dims)`.
- Consumes: existing `GameData.Home.cell`, `GameData.HouseTierCount`.

- [ ] **Step 1: Add tier dims + helpers to GameData**

In `src/shared/GameData.luau`, replace the `GameData.Home = { ... }` block (lines 769-773) with:

```lua
GameData.Home = {
	roomW = 64, roomD = 48, cell = 4, wallH = 20,
	cols = 16, rows = 12,          -- tier-0 defaults (roomW/cell, roomD/cell)
	skyY = 10000, spacing = 400,   -- rooms stacked far up, offset per plot index on Z
	workRows = 4,                  -- back rows reserved for the work zone (no furniture)
	tiers = {
		[0] = { roomW = 64, roomD = 48, cols = 16, rows = 12 },
		[1] = { roomW = 80, roomD = 56, cols = 20, rows = 14 },
		[2] = { roomW = 96, roomD = 64, cols = 24, rows = 16 },
	},
}

-- Room dimensions for a house/room tier (clamped to the valid tier range).
function GameData.homeDims(tier)
	tier = math.clamp(math.floor(tier or 0), 0, GameData.HouseTierCount - 1)
	return GameData.Home.tiers[tier] or GameData.Home.tiers[0]
end
```

- [ ] **Step 2: Make `homeInBounds` tier-aware + work-zone-aware**

Replace `GameData.homeInBounds` (lines 807-809) with:

```lua
-- In-bounds for FURNITURE: inside the grid AND in the living zone (furniture may
-- not sit in the back `workRows` band, which holds the work stations). `dims`
-- comes from GameData.homeDims(tier).
function GameData.homeInBounds(gx, gz, w, d, dims)
	dims = dims or GameData.Home.tiers[0]
	return gx >= 0
		and gz >= GameData.Home.workRows
		and (gx + w) <= dims.cols
		and (gz + d) <= dims.rows
end
```

(`homeOverlaps` and `homeCellToWorld` are unchanged — they don't depend on cols/rows, and `cell` is constant across tiers.)

- [ ] **Step 3: Build the shell at the player's tier size**

In `src/server/HomeService.luau`, change `buildRoom` to accept a tier and size from it. Replace the signature + the `w, d, wh` line:

- Line 35: `local function buildRoom(index)` → `local function buildRoom(index, tier)`
- Lines 42: replace `local w, d, wh = H.roomW, H.roomD, H.wallH` with:

```lua
	local dims = GameData.homeDims(tier)
	local w, d, wh = dims.roomW, dims.roomD, H.wallH
```

Store the tier's dims for later callers: after line 64 (the two `roomCorner[index]` lines) add:

```lua
	roomDims[index] = dims
```

and near the top of the file (after line 23 `local roomSpawn = {}`) add:

```lua
local roomDims = {}    -- [index] = the dims table the room was last built at
```

- [ ] **Step 4: Build all rooms at each player's saved tier**

`HomeService.build()` runs once at server start before players exist, so build rooms at tier 0; `rebuildHome` (Task 4) will resize when a player joins/upgrades. In `HomeService.build()` (line 146-148) leave `buildRoom(index)` as-is — with the new optional `tier` arg it defaults to tier 0. No change needed here beyond Step 3's signature.

- [ ] **Step 5: Compile + smoke test**

Compile per Verification Protocol. Then start play and inspect:

```lua
-- Server datamodel
local out = {}
for _, f in ipairs(workspace.Homes:GetChildren()) do
  local floor = f:FindFirstChild("Floor")
  out[#out+1] = f.Name .. " floor=" .. (floor and tostring(floor.Size) or "none")
end
return table.concat(out, "\n")
```

Expected: 4 `Home<i>` folders each with a `Floor` of size `64, 1, 48` (tier-0 default), no console errors.

- [ ] **Step 6: Commit**

```bash
git add src/shared/GameData.luau src/server/HomeService.luau
git commit -m "feat(home): tier-based room sizing + work-zone furniture bounds"
```

---

## Task 2: Stations + Trends + PC in the room

**Files:**
- Modify: `src/server/PlotManager.luau` (add `populateHomeInterior`, `getHomeBackWallPoint`; near existing station builders ~line 300-395 and public API ~1583-1600)
- Modify: `src/server/HomeService.luau` (call populate in `rebuildHome`)
- Modify: `src/client/UI.luau:1542-1636` (scan the Home folder for seats/trends)

**Interfaces:**
- Produces: `PlotManager.populateHomeInterior(roomFolder, backWallPoint, tier, pcTier)` — builds the 4 dev stations (`NewProject`,`Coding`,`MapBuilding`,`Testing`) via the existing `buildStation`, plus `buildTrendsSign`, into `roomFolder`, positioned relative to `backWallPoint` (Vector3 at the room's -Z wall centre, floor Y). Station seats keep their existing names (`NewProjectSeat`, …) and the NewProject monitor keeps `PCUpgradePrompt`. Also `PlotManager.getHomeBackWallPoint(index) -> Vector3`.
- Consumes: existing file-local `buildStation`, `STATION_CONFIGS`, `buildTrendsSign`, constants; `GameData.homeDims`.

- [ ] **Step 1: Add `getHomeBackWallPoint` + `populateHomeInterior` to PlotManager**

The room centre for plot `index` is `Vector3.new(0, GameData.Home.skyY, index * GameData.Home.spacing)`; floor Y = `skyY`. The back wall (-Z) sits at `centre.z - roomD/2`. Stations sit a few studs in from that wall so they stay anchored to the back as the room grows.

Add near the other public functions (after `getStudioEntranceCFrame`, ~line 1600):

```lua
-- Floor point at the centre of a Home room's back (-Z) wall, for the current
-- room size (tier). Fixtures are placed relative to this so they stay pinned to
-- the back wall when the room grows.
function PlotManager.getHomeBackWallPoint(index, tier)
	local H = GameData.Home
	local dims = GameData.homeDims(tier)
	local centreZ = index * H.spacing
	return Vector3.new(0, H.skyY, centreZ - dims.roomD / 2)
end
```

Add `populateHomeInterior` next to it. It reuses `buildStation` (which builds desk + seat + monitor and, for NewProject, the `PCUpgradePrompt`) and `buildTrendsSign`. Place the 4 stations spread across X, ~6 studs in front of the back wall; Trends board on the back wall:

```lua
-- Home-room fixture layout, local offsets from the back-wall point:
-- 4 dev stations spread along X at z=+6 (facing the player as they enter).
local HOME_STATION_LAYOUT = {
	{ name = "NewProject",  x = -12, z = 6 },
	{ name = "Coding",      x = -4,  z = 6 },
	{ name = "MapBuilding", x = 4,   z = 6 },
	{ name = "Testing",     x = 12,  z = 6 },
}

-- Fill a Home room with the gameplay fixtures. `base` is getHomeBackWallPoint.
function PlotManager.populateHomeInterior(roomFolder, base, tier, pcTier)
	for _, entry in ipairs(HOME_STATION_LAYOUT) do
		for _, config in ipairs(STATION_CONFIGS) do
			if config.name == entry.name then
				buildStation(roomFolder, base, config, entry.x, entry.z, "", pcTier or 0)
				break
			end
		end
	end
	buildTrendsSign(roomFolder, base, "")
end
```

If `buildTrendsSign(parent, base, namePrefix)` places the board on a wall using studio constants (`BUILDING_HALF_D`), verify in Studio that it lands on the room's back wall; if it's off, pass a small forward offset by wrapping the base (e.g. `base + Vector3.new(0, 0, -0.5)`), tuned during the smoke test. Do **not** change `buildTrendsSign` itself.

- [ ] **Step 2: Call populate from `HomeService.rebuildHome` + size the shell to tier**

In `src/server/HomeService.luau`, make `rebuildHome` rebuild the shell at the player's tier and populate the interior. Replace `rebuildHome` (lines 113-126) with:

```lua
function HomeService.rebuildHome(player)
	local index = PlotManager.getPlayerPlotIndex(player)
	if not index then return end
	local data = PlayerData.get(player)
	if not data then return end
	local tier = data.houseTier or 0

	-- Rebuild the shell at the player's current tier size, then the interior.
	local old = homesFolder:FindFirstChild("Home" .. index)
	if old then old:Destroy() end
	local folder = buildRoom(index, tier)
	PlotManager.populateHomeInterior(folder, PlotManager.getHomeBackWallPoint(index, tier), tier, data.pcTier or 0)

	local furn = folder:FindFirstChild("Furniture")
	if furn then
		for _, entry in ipairs(data.homeItems) do
			pcall(buildItem, furn, index, entry)
		end
	end
end
```

Note `buildItem` uses `roomCorner[index]` (set by `buildRoom`) — because we rebuild the shell first, the corner is fresh for the tier. `homeInBounds` calls in `HomeService.start` must pass dims — update the two placement handlers: change `GameData.homeInBounds(gx, gz, w, d)` to `GameData.homeInBounds(gx, gz, w, d, GameData.homeDims(data.houseTier or 0))` at lines ~167 and ~184.

- [ ] **Step 3: Retarget the client to scan the Home folder**

In `src/client/UI.luau`, after resolving `plotFolder` (line 1567), resolve the player's Home folder and use it for gameplay scanning. Replace lines 1602-1621 (the `plotFolder:WaitForChild("NewProjectSeat")` block and the two scanning loops) so they target the Home folder:

```lua
	-- Gameplay fixtures (seats, prompts, trends board) now live in the player's
	-- private Home room, not the studio building on the plot.
	local homeFolder = workspace:WaitForChild("Homes"):WaitForChild("Home" .. plotIndex)

	-- Ensure the interior is populated before scanning.
	homeFolder:WaitForChild("NewProjectSeat")

	for _, inst in ipairs(homeFolder:GetDescendants()) do
		trackSeat(inst)
	end
	local latestTrendText = nil

	homeFolder.DescendantAdded:Connect(function(inst)
		trackSeat(inst)
		if inst:IsA("Seat") then
			updateSeatedStation()
		end
		if inst.Name == "TrendsText" and inst:IsA("TextLabel") and latestTrendText then
			inst.Text = latestTrendText
		end
	end)
```

Then point the tutorial's plot hook and the trends-sign updater at `homeFolder`: change `getPlotFolder = function() return plotFolder end` (line 1596-1598) to `return homeFolder`, and in `updateTrendsSigns` (line 1632-1636) change `plotFolder:GetDescendants()` to `homeFolder:GetDescendants()`.

- [ ] **Step 4: Compile + smoke test**

Compile. Start play, then (Client datamodel) press the My Home button flow by firing enter, and inspect from Server:

```lua
-- Server datamodel: confirm the 4 station seats + trends board exist in a room.
local f = workspace.Homes:FindFirstChild("Home1")
local names = {}
for _, d in ipairs(f:GetDescendants()) do
  if d:IsA("Seat") or d.Name == "PCUpgradePrompt" or d.Name == "TrendsText" then
    names[#names+1] = d.Name
  end
end
return table.concat(names, ", ")
```

Expected: includes `NewProjectSeat`, `CodingSeat`, `MapBuildingSeat`, `TestingSeat`, `PCUpgradePrompt`, `TrendsText`. Then in Studio, walk into the room (My Home button), sit at the New Project computer, and confirm the New Project panel appears and a dev cycle can start (mini-games run). No console errors.

- [ ] **Step 5: Commit**

```bash
git add src/server/PlotManager.luau src/server/HomeService.luau src/client/UI.luau
git commit -m "feat(home): dev stations + trends + PC live in the Home room"
```

---

## Task 3: Workers in the room

**Files:**
- Modify: `src/server/PlotManager.luau` (`populateHomeInterior`; `refreshWorkerNPCs` ~444; the `PromptTriggered` ownership gate in `PlotManager.start` ~1938-1955)
- Modify: `src/server/HomeService.luau` (place worker NPCs on rebuild)

**Interfaces:**
- Consumes: existing `buildWorkersDesk(parent, origin, x, z, namePrefix)`, `buildWorkerNPC`, `PlotManager.refreshWorkerNPCs(player)`.
- Produces: Workers desk + NPCs inside the Home room; prompt-ownership that accepts the player's Home folder.

- [ ] **Step 1: Add the Workers desk to `populateHomeInterior`**

In `populateHomeInterior` (Task 2), after the Trends board line, add the Workers desk beside the stations (a bit further into the room so worker NPCs sit clear of the dev seats):

```lua
	buildWorkersDesk(roomFolder, base, 0, 11, "")
```

- [ ] **Step 2: Point worker-NPC building at the Home room**

Read `PlotManager.refreshWorkerNPCs` (line 444) — it currently finds the plot folder + the plot's WorkersDesk and spawns NPCs there. Change it to resolve the player's Home room folder (`workspace.Homes:FindFirstChild("Home"..index)`) and its `WorkersDesk`/seat, spawning NPCs there instead of in the plot. Keep the NPC visuals (`buildWorkerNPC`) and counts unchanged. (Exact edit: replace the `getPlotFolder(index)` lookup at the top of `refreshWorkerNPCs` with the Homes lookup, and update any `WorkersDesk` search to search the room folder.)

- [ ] **Step 3: Accept Home-folder prompt ownership**

Read `PlotManager.start`'s `ProximityPromptService.PromptTriggered` gate (~1945-1953). Today it early-returns unless the prompt is a descendant of the player's own plot. Add the player's Home folder as an accepted owner. Replace the ownership check with:

```lua
		local ownPlot = PlotManager.getPlotFolder(plotOfPlayer[player.UserId])
		local ownHome = workspace.Homes:FindFirstChild("Home" .. tostring(plotOfPlayer[player.UserId]))
		local inOwn = (ownPlot and prompt:IsDescendantOf(ownPlot))
			or (ownHome and prompt:IsDescendantOf(ownHome))
		if not inOwn then
			return
		end
```

(Keep the rest of the handler unchanged.)

- [ ] **Step 4: Rebuild worker NPCs when the Home room rebuilds**

In `HomeService.rebuildHome` (Task 2 version), after populating the interior, refresh NPCs so they appear/re-seat in the room. Add after the `populateHomeInterior(...)` line:

```lua
	PlotManager.refreshWorkerNPCs(player)
```

- [ ] **Step 5: Compile + smoke test**

Compile. Start play, enter the room, and hire a worker via the Workers desk (or fire `RequestHireWorker`), then inspect:

```lua
-- Server: worker NPCs present in the room?
local f = workspace.Homes:FindFirstChild("Home1")
local n = 0
for _, d in ipairs(f:GetDescendants()) do if d.Name:find("Worker") and d:IsA("Model") then n += 1 end end
return "worker models in room: " .. n
```

Expected: the Workers desk exists in the room; the WorkersPanel opens at the desk; hiring adds a worker NPC in the room; no console errors.

- [ ] **Step 6: Commit**

```bash
git add src/server/PlotManager.luau src/server/HomeService.luau
git commit -m "feat(home): workers desk + NPCs + prompt ownership in the Home room"
```

---

## Task 4: PC + room upgrades rebuild the room; studio becomes an empty shell

**Files:**
- Modify: `src/server/HouseService.luau:29`
- Modify: `src/server/init.server.luau:90-96` (join) and the PC-upgrade path
- Modify: `src/server/PlotManager.luau` (`buildStudioBuilding`/`buildOneFloorShell`/`buildPlot` — stop building stations, upgrade NPC, idle rooms, and extra floors in the studio)

**Interfaces:**
- Consumes: `HomeService.rebuildHome(player)`.
- Produces: room-tier upgrades and PC upgrades that rebuild the Home room; a studio that is a single empty shell.

- [ ] **Step 1: Room upgrade rebuilds the Home room**

In `src/server/HouseService.luau`, replace line 29 (`PlotManager.rebuildHouseForPlayer(player, data.houseTier, data.pcTier)`) with a Home-room rebuild:

```lua
		local HomeService = require(script.Parent.HomeService)
		HomeService.rebuildHome(player)
```

(Require at top of file instead if preferred; a local require inside the handler avoids a load-order cycle with PlotManager/HomeService — verify no circular-require warning at boot.)

- [ ] **Step 2: PC upgrade rebuilds the Home room**

Find where `PCService`/`init.server.luau` handles a `pcTier` change (search `rebuildPCForPlayer`). Wherever `pcTier` increments and the studio PC was rebuilt, call `HomeService.rebuildHome(player)` instead (the PC/monitor lives in the room now). Keep the cash/tier logic unchanged.

- [ ] **Step 3: On join, build the Home interior at the saved tier**

In `src/server/init.server.luau` `onPlayerJoined` (after `local data = PlayerData.load(player)`, ~line 90), ensure the Home room is rebuilt to the saved tier once the plot is assigned. Add:

```lua
	HomeService.rebuildHome(player)
```

(after the existing `PlotManager.rebuild*` calls; `HomeService` is already required at the top of the file). `PlotManager.rebuildHouseForPlayer` may stay (it now builds only the empty shell — Step 4).

- [ ] **Step 4: Studio becomes a single empty shell (no stations / floors / idle rooms)**

In `src/server/PlotManager.luau`:
- `buildStudioBuilding` / `buildOneFloorShell`: build **one** floor regardless of tier (drop the `houseTier`-driven extra floors and their station copies). Remove the `buildStudioStations(...)` call for the studio, the `buildUpgradeNPC(...)` call, and the `buildInteractiveRoom(...)` Arcade/Merch calls from the studio build path (these move to the room — Arcade/Merch in Task 5).
- `buildPlot` (~line 1520): remove the persistent ground-floor `buildStudioStations(plotFolder, ...)` call.
- `rebuildHouseForPlayer(player, tier, pcTier)`: keep the function (still called on join/skin) but have it rebuild only the empty studio shell (ignore `tier` for floor count → always 1).

Leave the exterior, door (auto-slide), landscaping, decor kiosk, and skin logic intact.

- [ ] **Step 5: Compile + smoke test**

Compile. Start play; buy a room upgrade (fire `RequestUpgradeHouse` or use the in-room prompt from Task 2/3) and inspect:

```lua
-- Server: room grew + furniture preserved after upgrade.
local f = workspace.Homes:FindFirstChild("Home1")
return "floor=" .. tostring(f.Floor.Size) .. " seats+trends still present: " ..
  tostring(f:FindFirstChild("NewProjectSeat", true) ~= nil)
```

Expected: after one upgrade the `Floor` size is `80, 1, 56` (tier 1) and the stations/trends still exist; a PC upgrade still works; the studio building has one floor and no stations inside. No console errors.

- [ ] **Step 6: Commit**

```bash
git add src/server/HouseService.luau src/server/init.server.luau src/server/PlotManager.luau
git commit -m "feat(home): PC/room upgrades rebuild the room; studio is a bare shell"
```

---

## Task 5: Arcade + Merch idle rooms in the room

**Files:**
- Modify: `src/server/PlotManager.luau` (`populateHomeInterior`; the Arcade/Merch `buildInteractiveRoom` calls ~1362-1366; `applyRoomOwnership` ~1391; the `CollectPrompt` handler in `PlotManager.start`)
- Modify: `src/shared/GameData.luau` if idle-zone footprints must be reserved from furniture.

**Interfaces:**
- Consumes: existing `buildInteractiveRoom(parent, base, roomKey, centerX, activity)`, `roomsOwned`, `RequestBuyRoom`, `CollectPrompt`, `applyRoomOwnership`.
- Produces: Arcade + Merch buy-zones + collect prompts inside the Home room.

- [ ] **Step 1: Place Arcade + Merch in the room's back corners**

Read the existing Arcade/Merch `buildInteractiveRoom(...)` calls (~1362-1366) to copy their `activity` tables verbatim (title, kind, room key, buyCost, perTick). In `populateHomeInterior`, after the Workers desk, place both zones at the two back corners relative to `base` (X near the side walls). Because `buildInteractiveRoom` was written for wide studio wings (`WING_W=15`), place them at the far ends so they read as corner zones:

```lua
	buildInteractiveRoom(roomFolder, base, "ArcadeRoom", -(dimsRoomW/2) + 9, ARCADE_ACTIVITY)
	buildInteractiveRoom(roomFolder, base, "MerchRoom",  (dimsRoomW/2) - 9, MERCH_ACTIVITY)
```

where `dimsRoomW = GameData.homeDims(tier).roomW`, and `ARCADE_ACTIVITY`/`MERCH_ACTIVITY` are the exact tables from the current studio calls (define them as file-locals so both the old removal and this call agree; since the studio calls are removed in Task 4, define the tables here). Verify placement visually in the smoke test; if the wing geometry is too large for the room, reduce it by passing a smaller footprint (only if `buildInteractiveRoom` already supports it — otherwise leave geometry and just position at the corners).

- [ ] **Step 2: Re-apply room ownership after a Home rebuild**

`applyRoomOwnership(player)` shows/hides the bought fixtures. Call it after populate in `HomeService.rebuildHome` (add after `refreshWorkerNPCs`):

```lua
	PlotManager.applyRoomOwnership(player)
```

Confirm `applyRoomOwnership` finds the Arcade/Merch parts in the Home folder now (it may search the plot folder — if so, update its lookup to the Home room folder, same pattern as Task 3 Step 2).

- [ ] **Step 3: Reserve idle-zone footprints from furniture (if they sit in the living zone)**

If the corner zones extend past the `workRows` band into the living zone, furniture could overlap them. Simplest guard: the zones sit within the back `workRows` band (already furniture-excluded). Verify in the smoke test that the Arcade/Merch footprints are within the back band; if they spill forward, either move them fully into the band or add their cell rectangles to a reservation check in `homeInBounds`. Prefer keeping them in the band (no GameData change).

- [ ] **Step 4: Compile + smoke test**

Compile. Start play; buy the Arcade (fire `RequestBuyRoom` with the arcade room key or use its BuyPad), wait for a tick, and collect:

```lua
-- Server: arcade fixture + collect prompt present after purchase.
local f = workspace.Homes:FindFirstChild("Home1")
return "arcade collect prompt: " .. tostring(f:FindFirstChild("CollectPrompt", true) ~= nil)
```

Expected: the Arcade/Merch buy-zones exist in the room; buying reveals the fixture + `CollectPrompt`; collecting pays cash; furniture cannot be placed on the zones. No console errors.

- [ ] **Step 5: Commit**

```bash
git add src/server/PlotManager.luau src/shared/GameData.luau
git commit -m "feat(home): Arcade + Merch idle zones in the Home room"
```

---

## Task 6: Studio-door entry + cleanup

**Files:**
- Modify: `src/server/HomeService.luau` (door-entry trigger)
- Modify: `src/server/PlotManager.luau` (remove now-dead studio-interior code; tag the door)
- Modify: `src/client/TutorialGuide.luau` if any step points at a now-missing studio fixture.

**Interfaces:**
- Consumes: `HomeService.enter` (make it callable from a door trigger); the studio door part (`Door`, ground floor).

- [ ] **Step 1: Walking through the studio door enters the room**

The studio is now empty, so the doorway can trigger Home entry with no gameplay conflict. In `PlotManager`, when building the ground-floor `Door` (search `prefix .. "Door"`), give it a distinguishing tag/attribute (e.g. `door:SetAttribute("HomeDoor", index)`), or expose the door via a getter. In `HomeService.start`, connect a `Touched` on each plot's studio door that calls `enter(plr)` for the owner. Because leaving lands at the studio entrance **outside** the door (`getStudioEntranceCFrame`, z=23; door at z=29), there is no immediate re-trigger; if a bounce is observed in the smoke test, add a 1.5s per-player debounce local to HomeService.

Concretely, in `HomeService.build()` after `buildRoom(index)` for each index, find the plot's door and wire it:

```lua
		local plot = PlotManager.getPlotFolder(index)
		local door = plot and plot:FindFirstChild("Door", true)
		if door then
			door.Touched:Connect(function(hit)
				local plr = Players:GetPlayerFromCharacter(hit.Parent)
				if plr and PlotManager.getPlayerPlotIndex(plr) == index then
					enter(plr)
				end
			end)
		end
```

(Verify the door part is named `Door` on the ground floor; if the skin mesh replaces it, only wire the procedural door — a skin building bakes its door, so those players use the My Home button. Note this limitation in the commit body.)

- [ ] **Step 2: Remove dead studio-interior code**

Delete the now-unreachable studio-interior builders/paths made dead by Task 4 (station copies on upper floors, the studio `buildUpgradeNPC`, the studio Arcade/Merch calls) **only if** nothing else references them. Keep `buildStation`, `buildTrendsSign`, `buildWorkersDesk`, `buildInteractiveRoom`, `buildUpgradeNPC`, `refreshWorkerNPCs` — they're now called for the Home room. Run a grep to confirm each removed block has no remaining callers before deleting.

- [ ] **Step 3: Fix the tutorial if needed**

Tutorial step 2 ("Sit at the New Project computer") beacons `plotPart("NewProjectSeat")`; since Task 2 pointed `getPlotFolder` at the Home folder, this now resolves in the room. Verify step 2 and step 5 (`PCUpgradePrompt`) beacons appear in the room. If step 1 ("Head to the Studio Kiosk") plus the room entry needs a nudge (the player must press My Home / walk the door after the kiosk), leave step 1 as-is — the kiosk still travels to the studio exterior, and the room is one button/door away.

- [ ] **Step 4: Compile + full smoke test (whole loop)**

Compile. Start play and run the whole loop end to end in Studio: lobby → kiosk (E) → studio exterior → walk in the door (or My Home) → room → sit at New Project → run a dev cycle → release a game → hire a worker → buy a room upgrade (room grows, furniture kept) → buy Arcade → collect → leave (lands at studio entrance). Confirm no console errors throughout.

- [ ] **Step 5: Commit**

```bash
git add src/server/HomeService.luau src/server/PlotManager.luau src/client/TutorialGuide.luau
git commit -m "feat(home): studio-door entry + remove dead studio-interior code"
```

---

## Self-Review Notes (author)

- **Spec coverage:** room-as-interior (T2/T3/T5), empty studio exterior + door entry (T4/T6), bigger-room upgrade (T1/T4), save-compat via `houseTier` reuse (T1/T4, no migration), Arcade/Merch moved (T5), client retarget (T2), prompt ownership (T3), worker NPCs (T3). All spec sections map to a task.
- **Known soft spots to resolve during Studio smoke tests (visual tuning, not logic):** exact station X/Z offsets and Trends board wall placement (T2), Arcade/Merch corner geometry fit (T5), possible door-entry debounce (T6). Each is called out in-task with a concrete starting value and a fallback.
- **Load order:** HouseService/PCService rebuild the room via `HomeService` — use a local `require` inside the handler if a top-level require risks a cycle (T4 Step 1).
- **Skin buildings** bake their door, so door-entry only wires the procedural door; those players use the My Home button (noted in T6).
