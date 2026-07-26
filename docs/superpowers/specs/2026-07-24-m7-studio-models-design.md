# M7 — Blender Model & Animation Polish: Studio Building (Design Spec)

**Milestone:** M7 of the v1.0 launch roadmap (the Blender model/animation pass).

**Scope of THIS spec:** the **studio building** only — the first model batch. Other batches (desks/PCs, worker characters, lobby props) and animations are future rounds under the same milestone, each with their own spec/plan.

**Goal:** Replace the blocky procedural-Part studio building with detailed, premium **Blender meshes**, while keeping the interior walkable, the glass see-through, and the floors still growing with upgrades.

---

## Decisions locked in brainstorming
- **Pipeline:** Blender (user runs my scripts) → export → import to Studio → save as a model file in the repo → Rojo syncs it → game code clones + places it. The user does the run/export/import clicks; I write the Blender scripts and the game code.
- **Storage = Option A:** finished models are saved as `.rbxmx` files in the repo and synced by Rojo. **No uploading to Roblox, no asset IDs, no moderation wait.** Everything stays in version control.
- **First batch = the studio building**, done in full ("all of them"), sequenced small → big.
- **Detail level:** meshes should be **detailed and premium**. Phones handle static meshes easily, and we reuse the *same* mesh across every floor and every player's plot, so Roblox instances it cheaply — detail on a reused mesh is essentially free. We only sanity-check genuinely extreme triangle counts.
- **Style:** keep the current bright, modern RoTube-Life-2 look (warm white walls, big windows, wood/neon touches), just refined and smooth instead of blocky.
- **Neon rule:** Neon material used as an *accent only* — here, just the glowing sign.

---

## Current building facts (what the meshes must match)
From `src/server/PlotManager.luau`:
- Footprint: `BUILDING_HALF_W = 18`, `BUILDING_HALF_D = 16` → **36 × 32 studs**.
- `WALL_HEIGHT = 12`, `SLAB_THICKNESS = 1`, `FLOOR_HEIGHT = 13` (vertical spacing between floors).
- Front door on the **−Z side**, `DOOR_WIDTH = 4`, `DOOR_HEIGHT = 6`.
- **Multi-floor + grows:** `floorCount = (data.houseTier or 0) + 1`. The house folder is rebuilt when the tier changes; each floor `f` is built at `base + (0, f * FLOOR_HEIGHT, 0)`.
- Current per-floor walls (`buildOneFloorShell`): solid back wall, glass left/right walls with mullions, glass or doored front wall, corner columns; the top floor also gets a rooftop terrace (deck, glass rails, pergola, planters, lamps).

---

## Architecture

### What the mesh replaces vs. keeps
The Blender work swaps **only the exterior wall shell of each floor**. Everything structural/interior is kept as procedural Parts.

- **Replace with a mesh (per floor):** the outer wall shell — back wall, side walls, front wall, window frames/mullions → **one "facade module" mesh per floor**, with the window areas as **actual holes in the mesh** and a door-sized hole in the front. (Decorative corner pillars/trim are a separate Round-3 piece, see below.)
- **Keep as Parts (unchanged):**
  - **Floor slabs** — walked on; structural.
  - **Glass panes** — thin Roblox `Glass`-material parts placed behind the mesh's window holes, so glass stays real (transparent + reflective). The mesh provides the frames/mullions around them; the parts provide the see-through glass.
  - **Door opening** — the front hole lines up with the existing door position; the entrance stays walkable.
  - **All interior** — desks, PCs, monitors, workers, stations, Trends board, spawn, rooftop terrace furniture.

Result: premium mesh exterior; interior identical to today; still stacks per floor; glass still see-through.

### The building's mesh pieces
1. **Facade module** (`FacadeModule.rbxmx`) — one floor's exterior wall shell (36×32 footprint, 12 tall) with window openings + a front door opening. Cloned and stacked once per floor. This is the big one.
2. **Roof crown** (`RoofCrown.rbxmx`) — a detailed roof/parapet cap placed on the **top** floor only (augments/replaces the current bare roof slab; the walkable terrace deck + furniture stay).
3. **Entrance canopy + sign** (`EntranceSign.rbxmx`) — a canopy over the front door plus a glowing "STUDIO" sign (Neon accent). Placed once, at the ground-floor front. **This is the Round-1 pipeline test piece.**
4. **Corner trim** (`CornerTrim.rbxmx`) — decorative pillars/trim at the building's corners (Round 3 detail).

### Placement, growth & safety (the game code)
- A small helper — **`src/server/StudioModels.luau`** — owns "clone this asset and place it at this CFrame," plus the **fallback**: if the asset is missing from `ReplicatedStorage`, it signals the caller to build the old procedural parts instead. This keeps the swap safe at every step.
- `PlotManager.luau`'s `buildOneFloorShell` changes to: *if the facade asset exists*, clone + position it for this floor (and place the glass panes + slab); *else* build the current procedural walls. Same pattern for roof crown (top floor), entrance sign (ground floor), corner trim.
- Because placement is keyed off `floorCount` in the existing rebuild path, **growth just works** — buying a floor adds another cloned facade module.

### Rojo asset wiring
- Add one mapping to `default.project.json`, e.g. `ReplicatedStorage.Assets` → repo folder `assets/`, so `assets/studio/*.rbxmx` sync into `ReplicatedStorage/Assets/Studio`.
- ⚠️ **A `default.project.json` change requires restarting `rojo serve`**, after which the user must click **Connect** again in the Rojo Studio plugin (known workflow gotcha this session).

---

## Pipeline (the repeatable loop, per model)
1. **I write** a Blender Python script → `blender/<piece>.py`. It builds the piece at exact game dimensions (modelled so **1 Blender unit = 1 stud**; door/window holes at the real positions) and can auto-export.
2. **User runs it** in Blender: *Scripting* tab → open `blender/<piece>.py` → **Run**.
3. **User exports** a mesh file (`.fbx` or `.obj`) — the script writes it to a known folder, or one **File → Export**.
4. **User imports** into Studio via the **3D Importer**, checks scale/orientation, then **right-click → Save to File** as `assets/studio/<Piece>.rbxmx` in the repo (and drags a copy under `ReplicatedStorage/Assets/Studio` so it's live). Rojo keeps it synced.
5. **I wire the code** to clone + place it (with the parts fallback) and we playtest.

Format note: `.fbx`/`.obj` chosen at plan time; solid colors can be set on the imported mesh in Studio, glass is a separate Roblox `Glass` part (never a baked mesh), and the sign uses `Neon`.

---

## Build sequence (each round is a tested checkpoint)
- **Round 1 — pipeline proof:** `EntranceSign` (canopy + glowing sign). Small, standalone, easy to place. Proves Blender → export → import → `.rbxmx` → Rojo → code → in-game, end-to-end, before touching structure.
- **Round 2 — the facade:** `FacadeModule` (per-floor wall shell with window/door holes) + `RoofCrown` on the top floor. Glass panes + slabs kept as parts. Verified at 1, 2, and 3 floors.
- **Round 3 — details:** `CornerTrim` + any polish.

---

## Data flow
Pure geometry/cosmetics — **no player-data changes, no new remotes, no saved state.** The building's appearance is server-built from cloned assets exactly where parts are built today. (M8's studio *skins* will later add saved data on top of this.)

## Error handling / edge cases
- **Missing or failed asset** → automatic fallback to the current procedural parts, so the studio never breaks mid-migration.
- **Floor growth** → handled by the existing tier-rebuild path; one facade clone per floor.
- **Glass alignment** → glass parts placed to sit exactly in the mesh's window holes; verify no z-fighting or gaps.
- **Import scale/orientation** → confirm 1 unit = 1 stud and correct facing (door on −Z) at import; the Blender script sets a consistent origin/pivot so placement math is simple.
- **Rojo restart** after the `default.project.json` change; user reconnects the plugin.
- **DataStore off in Studio** — irrelevant here (no data), but building rebuilds on tier change must still be tested with default data.

## Testing (no unit tests — Rojo build + Studio playtest)
- `rojo build` compiles clean after each round.
- In Studio: building looks right and premium at **1, 2, and 3 floors**; **glass still see-through**; **door still walkable**; **interior (desks/workers/stations) intact**; **fallback works** (temporarily hide the asset → parts return, no errors); no console errors; smooth on a phone-size view (M5).
- User confirms the look.

## Out of scope (future M7 rounds / milestones)
- Other model batches: desks/PCs, worker characters, lobby/city props.
- Custom **animations** (worker typing, celebrations) — a later M7 round.
- M8 **studio skins** (swappable exteriors for Robux) — builds on this, separate milestone.
- Uploading meshes to Roblox / asset-ID workflow (we chose Option A).
