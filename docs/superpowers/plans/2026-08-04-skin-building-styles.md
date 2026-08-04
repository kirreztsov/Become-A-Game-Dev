# Studio Skins as Blender Building Styles Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task (INLINE, not subagent-driven — the Blender/Studio steps are interactive and human-in-the-loop). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make each studio skin (Gold/Neon/Midnight) restyle the whole growing studio inside and out with Blender building pieces — buying a floor adds a floor in the equipped skin — while Default keeps today's look and gameplay is unchanged.

**Architecture:** Thread the player's `activeSkin` through the studio build chain (`buildHouse → buildStudioBuilding → buildOneFloorShell`). When a skin with a synced mesh kit is active, each floor places that skin's hollow Blender floor module (and a roof cap on the top floor) INSTEAD of the procedural outer walls/roof/facade, and recolors the interior slab/trim to the skin theme; the floor slab, elevators, stations, and interior stay procedural and untouched. If the mesh isn't synced yet, the floor falls back to procedural walls + interior theme (so wiring works before any mesh exists). We wire + verify the fallback path first, then drop in Gold, then Neon/Midnight.

**Tech Stack:** Roblox / Luau, Rojo (globs `assets/`), Blender (Python-scripted, `.blend → out/*.fbx → Studio Import → assets/studio/*.rbxm`), the existing `StudioModels` helper, `PlotManager`, `GameData.StudioSkins`.

## Global Constraints

- **Cosmetic only.** No gameplay change: stations (New Project/Coding/Map Building/Testing), PC, Workers computer, elevators, seats, prompts, floor slab, floor cash multipliers, and costs are all unchanged. Gold and Default play identically.
- **Studio still grows.** Buying a floor adds a floor (as today), built in the equipped skin. Switching skins re-skins the whole current building.
- **Swap only the shell + interior colors.** A skin replaces the outer walls/windows/roof/front-facade and recolors the interior slab-top + trim. It must NOT remove/hide/block/move stations, elevator pads, floor slabs, or interior props.
- **Blender risk (M7).** Whole-building meshes previously imported with floating trim/gaps and were reverted. Mitigate: one cohesive hollow model per floor (not a facade overlay); build chunky (few solid pieces); prove **Gold** end-to-end in Studio before Neon/Midnight; fall back to procedural per skin if a mesh imports broken.
- **Exact footprint/height** (author Blender at these stud proportions so uniform scaling to width 48 yields the rest): half-width `BUILDING_HALF_W = 24` (→ 48 wide), half-depth `BUILDING_HALF_D = 16` (→ 32 deep), `WALL_HEIGHT = 12`, `FLOOR_HEIGHT = 13`, ground slab top `FLOOR_TOP = 1`. Building front faces **-Z** (the facade sits at `base + (0, slabTop, -halfD)`), so the **door opening goes on the -Z wall of the ground floor**.
- **Graceful fallback:** if `StudioModels.has(skin.floorAsset) == false`, that floor builds the procedural shell (no error/hole), mirroring `placeStudioFacade`/`placeDeskMesh`.
- **Backward compatible:** `data.activeSkin` already exists (M8; `"Default"/"Gold"/"Neon"/"Midnight"`). No new persisted fields. `GameData.StartingCash` stays `0`. `assets/` is Rojo-globbed, so new `.rbxm` files sync with no `default.project.json` change.
- **Verification = `./rojo-bin/rojo build default.project.json -o /tmp/x.rbxl` + Studio playtest.** No unit tests (geometry/assets — nothing pure to assert).

---

### Task 1: GameData — skin building-kit config

**Files:**
- Modify: `src/shared/GameData.luau` (the `GameData.StudioSkins` table, ~line 255)

**Interfaces:**
- Produces: each non-Default entry in `GameData.StudioSkins` gains `floorAsset` (string) and `roofAsset` (string) naming its Blender kit; existing `wall`/`accent`/`wallMat`/`accentMat` fields stay (used for interior theming).

- [ ] **Step 1: Read the current `GameData.StudioSkins`** (from ~line 255) to see the exact existing fields.

- [ ] **Step 2: Add kit-asset names to each skin.** Edit each non-Default entry to include its floor + roof asset names. Example (match the existing table's key style; keep existing color/material fields exactly as they are):

```lua
	Gold     = { wall = <existing>, accent = <existing>, wallMat = <existing>, accentMat = <existing>,
	             floorAsset = "SkinFloorGold",     roofAsset = "SkinRoofGold" },
	Neon     = { wall = <existing>, accent = <existing>, wallMat = <existing>, accentMat = <existing>,
	             floorAsset = "SkinFloorNeon",     roofAsset = "SkinRoofNeon" },
	Midnight = { wall = <existing>, accent = <existing>, wallMat = <existing>, accentMat = <existing>,
	             floorAsset = "SkinFloorMidnight", roofAsset = "SkinRoofMidnight" },
```

(Default stays with no `floorAsset`/`roofAsset` → procedural.)

- [ ] **Step 3: Compile check**

Run: `./rojo-bin/rojo build default.project.json -o /tmp/x.rbxl`
Expected: `Built project to x.rbxl`.

- [ ] **Step 4: Commit**

```bash
git add src/shared/GameData.luau
git commit -m "feat(skins): add building-kit asset names to StudioSkins"
```

---

### Task 2: Skin-aware shell wiring (with procedural fallback)

Thread `skinKey` through the build chain and make each floor place the skin mesh when present, else build procedurally. Because no mesh exists yet, this task is verified with the **fallback path** (skinned = procedural walls + interior theme), proving the plumbing before any Blender work.

**Files:**
- Modify: `src/server/PlotManager.luau` — `buildHouse`, `buildStudioBuilding`, `buildOneFloorShell`, `rebuildHouseForPlayer`, `applySkin`; the initial plot-build call site.

**Interfaces:**
- Consumes: `GameData.StudioSkins[skinKey]` with `.floorAsset`/`.roofAsset` (Task 1); `StudioModels.has(name)`, `StudioModels.place(name, parent, cframe, {name=, targetWidth=})`.
- Produces: `buildOneFloorShell(parent, base, f, floorCount, pcTier, skinKey)`, `buildStudioBuilding(parent, base, houseTier, pcTier, skinKey)`, `buildHouse(plotFolder, origin, houseTier, pcTier, skinKey)`; `PlotManager.applySkin(player, skinKey)` now sets skin + rebuilds.

- [ ] **Step 1: Add a skin-mesh helper + thread the parameter.** In `buildStudioBuilding` and `buildHouse`, add a trailing `skinKey` parameter and pass it down to `buildOneFloorShell`. In `buildOneFloorShell(parent, base, f, floorCount, pcTier, skinKey)`, near the top (after `slabTop`/`halfW`/`halfD` are computed), decide whether a mesh shell is in play:

```lua
	local skin = skinKey and GameData.StudioSkins[skinKey] or nil
	local useSkinMesh = skin ~= nil and skin.floorAsset ~= nil and StudioModels.has(skin.floorAsset)
```

- [ ] **Step 2: Gate the procedural outer shell.** Wrap ONLY the outer-wall + window + roof + front-facade blocks of `buildOneFloorShell` in `if not useSkinMesh then ... end`. Leave the floor slab, interior, elevator pads, floor-number sign, floor motif, and (for `f>0`) the station copies OUTSIDE the gate so they always build. (Read the function fully; the facade/roof/wall blocks are the ones between the slab build and the interior/station build.)

- [ ] **Step 3: Place the mesh shell when skinned.** Where the gated procedural walls would have gone, add:

```lua
	if useSkinMesh then
		-- Hollow floor module, base sitting on this floor's slab top, centred on the footprint.
		StudioModels.place(skin.floorAsset, parent, CFrame.new(base + Vector3.new(0, slabTop, 0)), {
			name = prefix .. "SkinFloorMesh",
			targetWidth = width, -- 48; uniform scale sets depth 32 + height 12 from authored proportions
		})
		-- Roof cap only on the top floor.
		if f == floorCount - 1 and skin.roofAsset and StudioModels.has(skin.roofAsset) then
			StudioModels.place(skin.roofAsset, parent, CFrame.new(base + Vector3.new(0, slabTop + WALL_HEIGHT, 0)), {
				name = prefix .. "SkinRoofMesh",
				targetWidth = width,
			})
		end
	end
```

- [ ] **Step 4: Interior theming.** After the floor slab + interior are built (still inside `buildOneFloorShell`, unconditional), recolor interior surfaces to the skin theme when `skin` is set. Recolor the slab-top and interior trim/accent parts (NOT stations, NOT glass), reusing the M8 color fields:

```lua
	if skin then
		for _, d in ipairs(parent:GetDescendants()) do
			if d:IsA("BasePart") and d.Name:sub(1, #prefix) == prefix then
				local isTrim = string.find(d.Name, "Trim") or string.find(d.Name, "Slab") or string.find(d.Name, "Floor")
				local isProtected = string.find(d.Name, "Monitor") or string.find(d.Name, "Screen")
					or string.find(d.Name, "Desk") or string.find(d.Name, "Seat") or d.Material == Enum.Material.Glass
				if isTrim and not isProtected then
					local isAccent = string.find(d.Name, "Trim") or string.find(d.Name, "RailCap") or string.find(d.Name, "Lintel")
					d.Color = (isAccent and skin.accent) and skin.accent or skin.wall
					d.Material = (isAccent and skin.accentMat) or skin.wallMat or d.Material
				end
			end
		end
	end
```

(Exact name substrings will be tuned against the real slab/trim part names during the Studio verify step; adjust `isTrim`/`isProtected` so only interior surfaces recolor.)

- [ ] **Step 5: Read the owner's skin on the initial plot build.** Find where the plot's studio is first built (the initial `buildHouse(...)` call when a plot is assigned). Pass the owner's `data.activeSkin` (default `"Default"`) as the new `skinKey` argument. If player data isn't available at that point, pass `"Default"` and rely on the `rebuildHouseForPlayer` that runs after data loads.

- [ ] **Step 6: Make `rebuildHouseForPlayer` pass the skin, and `applySkin` rebuild.** Change `rebuildHouseForPlayer` to read `data.activeSkin` and pass it into `buildHouse(...)`, and REMOVE its trailing `PlotManager.applySkin(...)` call (theming now happens inside the build). Replace `PlotManager.applySkin(player, skinKey)` body so it sets the skin and rebuilds:

```lua
function PlotManager.applySkin(player, skinKey)
	local data = PlayerData.get(player)
	if data then
		data.activeSkin = skinKey or "Default"
		PlotManager.rebuildHouseForPlayer(player, data.houseTier or 0, data.pcTier or 0)
	end
end
```

(The M8 `RequestSetSkin` handler already validates ownership, sets `data.activeSkin`, and calls `PlotManager.applySkin` — that flow keeps working; applySkin now rebuilds in the new skin. Setting `activeSkin` here too is idempotent/safe.)

- [ ] **Step 7: Compile check**

Run: `./rojo-bin/rojo build default.project.json -o /tmp/x.rbxl`
Expected: `Built project to x.rbxl`.

- [ ] **Step 8: Studio verify (fallback path — no mesh yet)** — with Rojo synced + a plot: Default builds the normal studio; equip Gold (temporarily grant the pass server-side) → studio rebuilds with interior surfaces themed gold, walls still procedural (fallback), stations reachable, no errors; buy a floor → new floor also themed; switch back to Default → restores. Confirm no gameplay breakage.

- [ ] **Step 9: Commit**

```bash
git add src/server/PlotManager.luau
git commit -m "feat(skins): skin-aware floor shell + interior theming (procedural fallback)"
```

---

### Task 3: Gold Blender kit (floor module + roof cap) — the proof

Author + import the first real skin building. **Interactive:** I write the script; you run Blender, export, import to Studio, and save the `.rbxm`s; we look at screenshots and iterate on scale/orientation/holes.

**Files:**
- Create: `blender/skin_gold.py` (builds both the floor module and the roof cap, exports two FBX to `blender/out/`)
- Create (via Studio import + save): `assets/studio/SkinFloorGold.rbxm`, `assets/studio/SkinRoofGold.rbxm`

**Interfaces:**
- Consumes: nothing (standalone Blender script).
- Produces: assets named `SkinFloorGold` / `SkinRoofGold` so `StudioModels.has("SkinFloorGold")` is true after sync, satisfying Task 2's `useSkinMesh`.

- [ ] **Step 1: Author `blender/skin_gold.py`.** A hollow floor module authored at real stud proportions (48 wide × 32 deep × 12 tall, base at Z=0, 1 unit = 1 stud, Z-up), built as a few chunky solid pieces so the importer keeps them:
  - Four perimeter walls (thickness ~0.6) around the 48×32 footprint, 12 tall.
  - Rectangular **window openings** cut into the side/back walls (leave solid mullions between — chunky, not lace).
  - A **door opening** in the **-Z (front)** wall (about 6 wide × 9 tall, centered).
  - Name pieces so in-game coloring is easy: `SkinFloorGoldWall`, `SkinFloorGoldTrim` (a band near the top edge = gold accent), `SkinFloorGoldMullion`.
  - The roof cap: a peaked/gabled gold roof sized to the 48×32 footprint, named `SkinRoofGoldRoof` / `SkinRoofGoldTrim`.
  - Export `blender/out/SkinFloorGold.fbx` and `blender/out/SkinRoofGold.fbx`. Include the standard header note (mirror-X warning, "1 unit = 1 stud", run + import + save instructions), matching `blender/trophy.py`.

- [ ] **Step 2 (you, in Blender):** Scripting → Open `blender/skin_gold.py` → Reload → Run. Confirm two FBX files appear in `blender/out/`.

- [ ] **Step 3 (you, in Studio):** Import `blender/out/SkinFloorGold.fbx`; confirm it comes in as a Model, rename the Model to `SkinFloorGold`, and Save it to `assets/studio/SkinFloorGold.rbxm` (right-click → Save to File, into `assets/studio/`). Repeat for `SkinRoofGold` → `assets/studio/SkinRoofGold.rbxm`. Reconnect Rojo so the new files sync.

- [ ] **Step 4: Verify a single imported floor** (I drive this in Studio via the MCP): place one `SkinFloorGold` at a plot's ground-floor position and screenshot. Check: correct scale (≈48×32×12 after `targetWidth` scaling), right orientation (door on the -Z/plaza side — if mirrored, flip in the script per the header note), hollow + walkable, door + windows are real openings, no floating/detached pieces. Iterate on the script (Steps 1–3) until clean.

- [ ] **Step 5: Verify in-game via the skin path.** With the assets synced, equip Gold on a test plot → the studio rebuilds using the Gold mesh floor (Task 2's `useSkinMesh` now true). Screenshot + walk in: stations reachable, slab intact, door lines up, interior themed gold, roof cap on top. Iterate script if alignment is off.

- [ ] **Step 6: Commit** (the script + the two assets)

```bash
git add blender/skin_gold.py assets/studio/SkinFloorGold.rbxm assets/studio/SkinRoofGold.rbxm
git commit -m "feat(skins): Gold Blender building kit (floor module + roof cap)"
```

---

### Task 4: Gold stack + switch verification

Prove multi-floor stacking and skin switching before building the other two skins.

**Files:** none (verification; small script tweaks only if alignment is off).

- [ ] **Step 1: Compile check** — `./rojo-bin/rojo build default.project.json -o /tmp/x.rbxl` → `Built project to x.rbxl`.

- [ ] **Step 2: Studio playtest (I drive via MCP + screenshots):**
  - Equip Gold, buy up to 2–3 floors → the Gold floor modules **stack with aligned walls** (each floor at `f * FLOOR_HEIGHT`), exactly **one roof cap** on the top floor, no gaps between floors.
  - Elevators work between floors; every floor's stations are reachable; floor-number signs present.
  - Switch Gold → Default → the procedural growing building comes back; Default → Gold re-skins live.
  - No console errors on rebuild/switch/buy-floor.

- [ ] **Step 3: Commit** any alignment fixes (script re-export or a PlotManager offset tweak); otherwise nothing to commit.

```bash
git add -A
git commit -m "fix(skins): Gold stacking + switch alignment" # only if changes were needed
```

---

### Task 5: Neon Blender kit

Repeat Task 3 for Neon, now that the pipeline + wiring are proven.

**Files:**
- Create: `blender/skin_neon.py`; `assets/studio/SkinFloorNeon.rbxm`, `assets/studio/SkinRoofNeon.rbxm`

- [ ] **Step 1: Author `blender/skin_neon.py`** — same footprint/proportions + door/window layout as Gold, restyled Neon: dark walls, a glowing **accent trim only** (project Neon-accent-only rule — neon material lives on a thin trim band named `SkinFloorNeonTrim`, never whole walls), flat modern roof (`SkinRoofNeon`). Names: `SkinFloorNeonWall`, `SkinFloorNeonTrim`, `SkinFloorNeonMullion`, `SkinRoofNeonRoof`.

- [ ] **Step 2 (you):** Run the script in Blender → export FBX.

- [ ] **Step 3 (you):** Import → rename Models `SkinFloorNeon` / `SkinRoofNeon` → save `assets/studio/SkinFloorNeon.rbxm` / `SkinRoofNeon.rbxm` → reconnect Rojo.

- [ ] **Step 4: Verify** (I drive): equip Neon → studio rebuilds Neon; single floor clean, then stacked, stations reachable, neon only on trim, interior themed dark+neon. Iterate script if needed.

- [ ] **Step 5: Commit**

```bash
git add blender/skin_neon.py assets/studio/SkinFloorNeon.rbxm assets/studio/SkinRoofNeon.rbxm
git commit -m "feat(skins): Neon Blender building kit"
```

---

### Task 6: Midnight Blender kit

Repeat for Midnight.

**Files:**
- Create: `blender/skin_midnight.py`; `assets/studio/SkinFloorMidnight.rbxm`, `assets/studio/SkinRoofMidnight.rbxm`

- [ ] **Step 1: Author `blender/skin_midnight.py`** — same footprint/proportions, restyled Midnight: deep midnight-blue walls, silver-grey trim (`SkinFloorMidnightTrim`), flat roof (`SkinRoofMidnight`). Names: `SkinFloorMidnightWall`, `SkinFloorMidnightTrim`, `SkinFloorMidnightMullion`, `SkinRoofMidnightRoof`.

- [ ] **Step 2 (you):** Run in Blender → export FBX.

- [ ] **Step 3 (you):** Import → rename `SkinFloorMidnight` / `SkinRoofMidnight` → save the two `.rbxm` → reconnect Rojo.

- [ ] **Step 4: Verify** (I drive): equip Midnight → rebuilds Midnight; single → stacked, clean, stations reachable, themed. Iterate if needed.

- [ ] **Step 5: Commit**

```bash
git add blender/skin_midnight.py assets/studio/SkinFloorMidnight.rbxm assets/studio/SkinRoofMidnight.rbxm
git commit -m "feat(skins): Midnight Blender building kit"
```

---

### Task 7: Final all-skins playtest

**Files:** none (verification).

- [ ] **Step 1: Compile** — `./rojo-bin/rojo build default.project.json -o /tmp/x.rbxl` → `Built project to x.rbxl`.

- [ ] **Step 2: Studio sweep (I drive):** cycle Default → Gold → Neon → Midnight → Default on a test plot; for each: rebuilds correctly, stacks across floors, stations/elevators/PC/Workers all reachable and working, interior themed, no gaps, no console errors; buy a floor under each skin → new floor in that skin. Confirm buying floors still costs/pays the same (gameplay unaffected).

- [ ] **Step 3: Note for the user** — grant/ownership: skins still require owning the matching M8 pass; on a live server the real passes gate selection (in Studio we flip `data.passes` to test). No further action.

---

## Self-Review

**Spec coverage:**
- Skin restyles growing building outside → Tasks 2 (wiring) + 3/5/6 (kits). ✅
- Interior matches theme → Task 2 Step 4 (interior recolor) + themed meshes (Tasks 3/5/6). ✅
- Buying a floor adds a floor in equipped skin → Task 2 (skinKey threaded through the per-floor build; no special-casing) + Task 4/7 buy-floor checks. ✅
- Default unchanged; cosmetic-only; gameplay intact → Global Constraints + Task 2 gates only walls/roof; Tasks 4/7 verify stations/cash. ✅
- Blender via M7 pipeline; prove Gold first; procedural fallback → Tasks 3 (Gold first) + Task 2 `useSkinMesh` fallback + Constraints. ✅
- Footprint/height/door-side exact values → Global Constraints + Task 3 Step 1. ✅
- Private enter-with-E room explicitly excluded → not in this plan (separate feature), per spec Non-goals. ✅

**Placeholder scan:** The Blender scripts are described at the geometry level (chunky hollow walls, named pieces, door on -Z, export paths) rather than as final vertex code, because the models are authored and tuned iteratively against Studio screenshots — this is inherent to mesh work (same as M7's tree/mountain/trophy scripts) and the header/run/import/save procedure is concrete. The Luau steps contain complete code. The interior-theming name substrings are explicitly flagged to be tuned against real part names in Task 2 Step 8 — not a hidden TODO.

**Type consistency:** `skinKey` (string) threads `buildHouse → buildStudioBuilding → buildOneFloorShell` consistently; `GameData.StudioSkins[skinKey].floorAsset`/`.roofAsset` names match the asset filenames (`SkinFloor<Name>` / `SkinRoof<Name>`) and the Studio Model names saved in Tasks 3/5/6; `StudioModels.place(name, parent, cframe, {name=, targetWidth=})` matches the real signature; `PlotManager.applySkin(player, skinKey)` keeps its M8 call signature.

**Execution note:** This plan is **inline/interactive** — the Blender authoring, FBX export, Studio import, and `.rbxm` save are human-in-the-loop with visual iteration, unsuitable for autonomous subagents. Task 2 is the only pure-code task and is verified via the fallback path before any mesh exists.
