# Studio Skins as Blender Building Styles Design Spec

**Goal:** Turn the three cosmetic studio skins (Gold / Neon / Midnight) from a simple recolor into full **building styles** — each skin restyles the whole growing studio, inside and out, using Blender-made building pieces. Buying a floor still adds a floor, built in the equipped skin's style. Default keeps today's procedural look. Skins stay cosmetic-only.

**Architecture:** Each skin provides a small Blender **kit** — a hollow, footprint-matched **floor module** (walls + window openings, door opening on the ground floor) and a **roof cap** for the top floor — delivered through the existing M7 `StudioModels` pipeline (`.blend → FBX → Studio → .rbxm → Rojo`). `PlotManager`'s per-floor shell builder becomes skin-aware: Default builds the current procedural walls/roof; a skin places that skin's mesh floor module for each floor and the roof cap on top. The floor slabs, elevators, interior work stations, and all gameplay stay exactly as they are — a skin only swaps the enclosing shell and recolors interior surface/trim to the theme. We prove the whole pipeline on **Gold first**, then replicate for Neon and Midnight.

**Tech Stack:** Roblox / Luau, Rojo, Blender (Python-scripted models), the existing `StudioModels` helper + `assets/studio/*.rbxm` asset pipeline, `PlotManager`, `GameData.StudioSkins`.

## Global Constraints

- **Cosmetic only.** Skins change appearance, never gameplay: work stations (New Project / Coding / Map Building / Testing), the PC, the Workers computer, elevators, seats, prompts, the floor you stand on, floor cash multipliers, and costs are all unchanged. A Gold studio and a Default studio play identically.
- **Studio still grows.** Buying a floor adds a floor as it does today; the new floor is built in the equipped skin's style. Switching skins re-skins the whole current building live.
- **Swap the shell, keep the interior.** A skin only replaces the outer floor shell (walls + windows + roof + ground-floor doorway) and recolors interior surfaces/trim. It must NOT remove, hide, block, or move the persistent ground-floor stations, the per-floor station copies, elevator pads, or the floor slabs.
- **Blender risk is real (M7 lesson).** Whole-building meshes previously imported with floating trim + gaps and were reverted; the memory rule is "Blender pays off on detailed/organic stuff, not flat boxy walls." Mitigations: (a) each skin's building is ONE cohesive hollow model per floor, not a facade overlaid on procedural walls (the thing that failed); (b) build chunky — few solid pieces, no tiny details the importer merges/drops; (c) **prove Gold end-to-end in Studio before building Neon/Midnight**; (d) if a skin's mesh comes out broken, fall back to a procedural-Parts style for that skin (same result, no import risk).
- **Footprint + height must match the existing studio exactly** so meshes align with slabs/stations across stacked floors: half-width `BUILDING_HALF_W = 24` (48 wide), half-depth `BUILDING_HALF_D = 16` (32 deep), wall height `WALL_HEIGHT = 12`, floor-to-floor `FLOOR_HEIGHT = 13`, ground slab top `FLOOR_TOP = 1`, building offset within the plot `HOUSE_LOT_OFFSET = (0, 0, 45)`.
- **Graceful fallback if an asset is missing:** if a skin's mesh isn't synced yet (`StudioModels.has(...) == false`), that floor falls back to the current procedural shell so the game never errors or shows a hole (mirrors how `placeDeskMesh`/`placeInteriorProp` already fall back).
- **Backward compatible:** `data.activeSkin` already exists (M8, values `"Default"/"Gold"/"Neon"/"Midnight"`); no new persisted fields required. `GameData.StartingCash` stays `0`.
- **Verification is `rojo build` + Studio playtest** (no CI; the look can only be judged in-engine).

## The skins

`GameData.StudioSkins` already maps each skin to wall/accent colors + materials (M8). We extend each skin entry with the names of its Blender kit assets and keep the color/material fields for interior theming.

| Skin | Building style (Blender) | Interior theme (recolor of slab + trim) |
|------|--------------------------|------------------------------------------|
| Default | none (procedural, as today) | none (as today) |
| Gold | warm gold walls, metal trim, peaked gold roof | warm/gold floor + gold trim |
| Neon | dark walls, glowing neon accent strips (accent only — project Neon rule), flat modern roof | dark floor, neon accent trim |
| Midnight | deep midnight-blue walls, silver trim, flat roof | dark blue floor, silver-grey trim |

## Component 1 — Blender kits

Per skin, two models built with a Blender Python script (like `blender/trophy.py`, `blender/mountain.py`):

- **`SkinFloor<Name>`** — a hollow floor module: four walls around the `48 × 32` footprint, `WALL_HEIGHT = 12` tall, with rectangular **window openings** and, for the ground floor, a **door opening** on the entrance side (the -Z / plaza-facing side, matching where the current entrance is). Interior is empty (the slab + stations live inside). Modeled as a few solid wall pieces (not one boolean-cut cube if that risks a bad import) so the importer keeps them.
- **`SkinRoof<Name>`** — a roof cap sized to the footprint, in the skin's style (peaked for Gold, flat for Neon/Midnight).

Pipeline (per the `blender-roblox-pipeline` memory): FBX export mirrors X and imports ~100× scale and merges/drops small parts — so keep pieces chunky, verify orientation on import, and save each as `assets/studio/SkinFloor<Name>.rbxm` / `SkinRoof<Name>.rbxm`, wired into `default.project.json` so Rojo syncs them and `StudioModels.get(name)` returns them.

## Component 2 — Skin-aware shell in PlotManager

`buildOneFloorShell(parent, base, f, floorCount, pcTier)` gets a skin parameter (or reads the player's `activeSkin` via the existing rebuild path). Behavior:

- **Default (or skin asset missing):** build the procedural walls/windows/roof exactly as today (no change).
- **A skin with meshes present:** skip the procedural outer walls + roof for that floor and instead:
  - Place `SkinFloor<Name>` at that floor's shell position (`base + (0, f * FLOOR_HEIGHT, 0)`, aligned to the footprint), scaled to `48` wide via `StudioModels.place`/`placeColored`.
  - If `f == floorCount - 1` (top floor), also place `SkinRoof<Name>` on top.
  - Keep everything the procedural shell keeps that isn't the outer wall/roof: the **floor slab**, **door opening alignment**, **elevator pads**, **floor-number sign**, **windows are part of the mesh**. The persistent ground-floor stations and the `f > 0` station copies are built by their existing code paths and are untouched.

The mesh floor module is themed in Blender (walls gold/neon/etc. inside and out), so the *walls* are themed automatically. **Interior surface theming** (the floor slab top + interior trim/accent parts) is done by recoloring those specific parts to the skin's `wall`/`accent` colors + materials — reusing the M8 `applySkin` recolor logic, now scoped to interior/slab/trim parts (the outer walls are the mesh, no longer recolored). Neon accent stays **accent-trim-only** (project rule).

## Component 3 — Applying + switching skins

- On **studio (re)build** (`rebuildHouseForPlayer` / plot build): read `data.activeSkin`; build each floor's shell per Component 2; then apply interior theming.
- On **skin change** (`RequestSetSkin` → `PlotManager.applySkin`, existing M8 remote/flow): rebuild the building shell for all current floors in the new skin (or switch to procedural for Default) and re-theme the interior. Validate ownership exactly as M8 does (own the matching pass, or `"Default"`).
- On **buying a floor** (`RequestUpgradeHouse` / house tier up): the added floor is built in the equipped skin via the same skin-aware shell path — no special-casing.

## Data & files

```
blender/skin_gold.py / skin_neon.py / skin_midnight.py   -- CREATE: build each skin's floor module + roof cap
assets/studio/SkinFloorGold.rbxm / SkinRoofGold.rbxm ...  -- CREATE (per skin): imported, saved meshes
default.project.json                                      -- MODIFY: sync the new asset files (if not covered by a glob)
src/shared/GameData.luau                                  -- MODIFY: add per-skin building asset names to StudioSkins entries
src/server/PlotManager.luau                               -- MODIFY: skin-aware buildOneFloorShell (mesh shell vs procedural); interior-only recolor in applySkin; rebuild-on-change
src/server/StudioModels.luau                              -- (reuse; add a helper only if placement needs it)
```

No client changes: the Store skin picker + `RequestSetSkin` from M8 already drive skin selection; this only changes what the server builds when a skin is active.

## Data flow

```
Equip skin (Store) -> RequestSetSkin -> validate ownership -> data.activeSkin = key
                    -> PlotManager.applySkin -> rebuild shell (mesh per floor + roof cap) + re-theme interior
Buy floor -> house tier up -> rebuild -> new floor's shell built in data.activeSkin's style
Join / respawn plot build -> read data.activeSkin -> build shells accordingly
Asset missing (not synced) -> that floor falls back to procedural shell (no error/hole)
```

## Build sequence (prove Gold first)

1. **Gold kit** — script + import `SkinFloorGold` + `SkinRoofGold`; verify a single imported floor in Studio: correct scale/orientation, hollow, walkable, door + windows open, clean (no gaps/floaty trim).
2. **Wire Gold** — skin-aware `buildOneFloorShell`; equip Gold → studio rebuilds in Gold; verify stations reachable, slab/elevators intact, interior themed.
3. **Stack test** — buy floors → 2–3 Gold floors stack with aligned walls + one roof cap on top; Default still builds the old procedural building; switching Gold↔Default swaps cleanly.
4. **Neon + Midnight** — repeat the kit + wiring once Gold is proven. If any mesh imports broken, use the procedural-Parts fallback style for that skin.

## Testing

- **Compile check** after each code change: `./rojo-bin/rojo build default.project.json -o /tmp/x.rbxl`.
- **Studio playtests** (the only way to judge the look): Gold single floor → stacked floors → interior theme → skin switch → buy-floor-while-skinned → Default restore. Confirm no errors, stations reachable, elevators work, no gaps, door usable.
- **Fallback check:** temporarily simulate a missing asset (`StudioModels.has` false) and confirm the floor falls back to procedural with no error.
- No unit tests (this is geometry/asset work with no pure logic to assert).

## Non-goals (YAGNI)

- **The private enter-with-E customizable big room is NOT part of this spec** — it is a separate, later feature with its own brainstorm/spec/plan.
- No new skins beyond Gold/Neon/Midnight; no per-floor different styles (one equipped skin styles the whole building).
- No gameplay/stat effect from skins; no change to floor costs, cash, or station behavior.
- No animated/tweened re-skin transition — rebuilding the shell instantly is fine.
- Default skin's building is unchanged; we are not re-modeling the procedural studio.
