# M7 Studio-Building Blender Models — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (inline) to implement this plan task-by-task. **This plan needs a human in the loop** — the user runs Blender, exports, and imports/saves models in Studio — so it is NOT suitable for autonomous subagent execution. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the blocky procedural-Part studio building with detailed Blender meshes, keeping the interior walkable, glass see-through, and floors still growing with upgrades.

**Architecture:** I write Blender Python scripts (in `blender/`); the user runs them, exports, imports into Studio, and saves each as a `.rbxmx` under `assets/studio/` (Rojo-synced into `ReplicatedStorage/Assets/Studio`). A new `StudioModels` helper clones + places these assets with an automatic fallback to the existing procedural parts, so the game never breaks if an asset is missing. `PlotManager` calls the helper instead of building the wall shell directly.

**Tech Stack:** Roblox Luau, Rojo (file sync + `.rbxmx` model files), Blender (Python `bpy`), Studio 3D Importer. Verification = `rojo build` + live Studio playtest (this project has no unit tests).

## Global Constraints
- **Storage = Option A:** models are `.rbxmx` files in the repo, synced by Rojo. No uploading to Roblox, no asset IDs, no moderation.
- **Never break the game:** every mesh placement must fall back to the current procedural parts if the asset is missing.
- **Keep as Parts (do NOT replace with mesh):** floor slabs, glass panes (Roblox `Glass` material), the door, balconies, interior stations/desks/workers, lights, rooftop terrace.
- **Growth:** the building rebuilds per floor via `floorCount = (data.houseTier or 0) + 1`; one facade clone per floor.
- **Building dims (verbatim):** `BUILDING_HALF_W=18`, `BUILDING_HALF_D=16` (36×32 footprint), `WALL_HEIGHT=12`, `SLAB_THICKNESS=1`, `FLOOR_HEIGHT=13`, door on −Z, `DOOR_WIDTH=4`, `DOOR_HEIGHT=6`.
- **Blender modelling scale:** 1 Blender unit = 1 stud. Origin at the floor's horizontal centre, base at Y=0, front face toward −Y in Blender → −Z in Roblox (confirm facing at import).
- **Detail is fine:** meshes should be detailed/premium; the same mesh is reused across floors + players so it instances cheaply. Only sanity-check truly extreme triangle counts.
- **Neon = accent only:** only the entrance sign glows.
- **Rojo restart gotcha:** any `default.project.json` change requires restarting `rojo serve`; the user must then click **Connect** again in the Rojo Studio plugin.

## File Structure
- **Create** `blender/entrance_sign.py`, `blender/facade_module.py`, `blender/roof_crown.py`, `blender/corner_trim.py` — Blender build+export scripts (I write; iterated against the visual result).
- **Create** `assets/studio/EntranceSign.rbxmx`, `FacadeModule.rbxmx`, `RoofCrown.rbxmx`, `CornerTrim.rbxmx` — the imported models (the user produces these from Studio; they are binary/XML, not hand-authored).
- **Create** `src/server/StudioModels.luau` — clone/place helper + missing-asset fallback signal.
- **Modify** `default.project.json` — map `ReplicatedStorage.Assets` → `assets/`.
- **Modify** `src/server/PlotManager.luau` — `buildOneFloorShell` (and the entrance/roof spots) call `StudioModels` with fallback.

---

### Task 1: Rojo asset wiring

**Files:**
- Modify: `default.project.json`
- Create: `assets/studio/.gitkeep` (folder must exist for Rojo to map it)

- [ ] **Step 1 (me): add the Assets mapping.** In `default.project.json`, under the `ReplicatedStorage` node, add an `Assets` child pointing at the repo `assets/` folder (mirrors how `Shared` maps to `src/shared`). Example shape:

```json
"ReplicatedStorage": {
  "Shared": { "$path": "src/shared" },
  "Assets": { "$path": "assets" }
}
```

- [ ] **Step 2 (me): create the folder** so Rojo has something to sync:

```bash
mkdir -p "assets/studio" && touch "assets/studio/.gitkeep"
```

- [ ] **Step 3 (me): compile-check.**

```bash
./rojo-bin/rojo build default.project.json --output /tmp/m7.rbxl
```
Expected: `Built project to /tmp/m7.rbxl` (no errors).

- [ ] **Step 4 (me): restart `rojo serve`** (background) so the new mapping takes effect.
- [ ] **Step 5 (you): reconnect** the Rojo plugin in Studio (click **Connect**).
- [ ] **Step 6 (me): verify** in Studio that `ReplicatedStorage/Assets/Studio` now exists:

```
-- execute_luau (Edit): return game.ReplicatedStorage:FindFirstChild("Assets") ~= nil
```
Expected: `true`.

---

### Task 2: `StudioModels` clone/place helper (with fallback)

**Files:**
- Create: `src/server/StudioModels.luau`

**Interfaces:**
- Produces:
  - `StudioModels.get(name: string): Instance?` — returns a fresh **clone** of `ReplicatedStorage/Assets/Studio/<name>` (a Model or MeshPart), or `nil` if the asset isn't present.
  - `StudioModels.place(name: string, parent: Instance, cframe: CFrame, nameOverride: string?): Instance?` — clones, pivots to `cframe`, parents, returns the clone (or `nil` if missing).
  - `StudioModels.has(name: string): boolean` — whether the asset exists (used to pick mesh vs. fallback path).

- [ ] **Step 1 (me): write the module.**

```lua
-- Clones studio building meshes from ReplicatedStorage/Assets/Studio and places
-- them in the world. Returns nil when an asset is missing so callers can fall
-- back to the procedural Parts build -- the game must never break mid-migration.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StudioModels = {}

local function assetsFolder()
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	return assets and assets:FindFirstChild("Studio") or nil
end

function StudioModels.has(name)
	local folder = assetsFolder()
	return folder ~= nil and folder:FindFirstChild(name) ~= nil
end

function StudioModels.get(name)
	local folder = assetsFolder()
	local template = folder and folder:FindFirstChild(name)
	if not template then
		return nil
	end
	return template:Clone()
end

-- Pivots the clone so its origin sits at `cframe`, parents it, and (for Models)
-- names it. Returns the clone or nil if the asset is missing.
function StudioModels.place(name, parent, cframe, nameOverride)
	local clone = StudioModels.get(name)
	if not clone then
		return nil
	end
	if nameOverride then
		clone.Name = nameOverride
	end
	if clone:IsA("Model") then
		clone:PivotTo(cframe)
	elseif clone:IsA("BasePart") then
		clone.CFrame = cframe
	end
	clone.Parent = parent
	return clone
end

return StudioModels
```

- [ ] **Step 2 (me): compile-check.**

```bash
./rojo-bin/rojo build default.project.json --output /tmp/m7.rbxl
```
Expected: builds clean.

- [ ] **Step 3 (me): behaviour check in Studio** (Edit datamodel), before any asset exists — `has` must be false and `place` must return nil (proving the fallback path triggers):

```
-- require the synced module and assert StudioModels.has("Nope") == false
-- and StudioModels.place("Nope", workspace, CFrame.new()) == nil
```
Expected: `has=false`, `place=nil` (no error).

---

### Task 3: Round 1 — Entrance canopy + glowing sign (pipeline proof)

Goal: prove the full Blender→export→import→`.rbxmx`→Rojo→code loop on one small standalone piece before touching structure.

**Files:**
- Create: `blender/entrance_sign.py`
- Create (you): `assets/studio/EntranceSign.rbxmx`
- Modify: `src/server/PlotManager.luau` (ground-floor entrance area, around lines 647–670)

- [ ] **Step 1 (me): write `blender/entrance_sign.py`.** A `bpy` script that builds a canopy slab + two posts + a raised sign board with an extruded/emissive "STUDIO" text, sized to the door (canopy ≈ `DOOR_WIDTH+6` = 10 wide, posts ≈ `DOOR_HEIGHT+1` tall), origin centred on the door at Y=0, facing −Y. It selects the objects, joins them into one, and exports to `blender/out/EntranceSign.fbx` via `bpy.ops.export_scene.fbx`. (Concrete first version; we iterate on looks after seeing it.)
- [ ] **Step 2 (you): run it.** Blender → *Scripting* tab → **Open** `blender/entrance_sign.py` → **Run** (▶). The canopy + sign appears; `blender/out/EntranceSign.fbx` is written.
- [ ] **Step 3 (you): import to Studio.** *Avatar/Model* → **3D Importer** → pick `EntranceSign.fbx`. Check scale (should read ~10 studs wide) and that "STUDIO" faces you. Set the sign board's material to **Neon** for the glow.
- [ ] **Step 4 (you): save into the project.** Right-click the imported model → **Save to File** → `assets/studio/EntranceSign.rbxmx`. Also drag a copy into `ReplicatedStorage/Assets/Studio` so it's live now. Rojo keeps the file synced.
- [ ] **Step 5 (me): wire placement.** In `PlotManager.buildOneFloorShell`, on the ground floor (`f == 0`), after the door is built, replace the *procedural canopy + posts + lamps block* (lines ~659–670) with:

```lua
-- Detailed Blender entrance sign if available; else the procedural canopy.
local signCFrame = CFrame.new(base + Vector3.new(0, FLOOR_TOP, -halfD))
if StudioModels.has("EntranceSign") then
	StudioModels.place("EntranceSign", parent, signCFrame, prefix .. "EntranceSign")
else
	-- (existing procedural canopy/posts/lamps block stays here as fallback)
end
```
(Add `local StudioModels = require(script.Parent.StudioModels)` near the top requires.)

- [ ] **Step 6 (me): compile-check** → `rojo build` clean.
- [ ] **Step 7 (me + you): Studio playtest.** Start Play. Verify: the mesh sign sits over the door, glows, correct size/facing; temporarily rename the asset to confirm the procedural canopy returns (fallback); no console errors.
- [ ] **Step 8: iterate** on `entrance_sign.py` looks if needed (repeat 1–4), then this round is a checkpoint.

---

### Task 4: Round 2 — Per-floor facade + roof crown (the big one)

**Files:**
- Create: `blender/facade_module.py`, `blender/roof_crown.py`
- Create (you): `assets/studio/FacadeModule.rbxmx`, `assets/studio/RoofCrown.rbxmx`
- Modify: `src/server/PlotManager.luau` (`buildOneFloorShell`, lines ~601–710, 725–740)

- [ ] **Step 1 (me): write `blender/facade_module.py`.** One floor's exterior shell: 36×32 footprint, 12 tall, with **window openings** on all four sides (matching the current glass positions) and a **door-sized hole** (4×6) centred on the −Y/front face. Includes window frames/mullions + a thin story band + cornice as part of the mesh. Origin at horizontal centre, base at Y=0. Export `blender/out/FacadeModule.fbx`.
- [ ] **Step 2 (me): write `blender/roof_crown.py`.** A detailed roof/parapet cap for a 36×32 top, sitting at the wall top. Export `blender/out/RoofCrown.fbx`.
- [ ] **Step 3 (you): run, import, save** each as `assets/studio/FacadeModule.rbxmx` and `assets/studio/RoofCrown.rbxmx` (+ copies into `ReplicatedStorage/Assets/Studio`). Confirm sizes at import (36×32×12; roof matches).
- [ ] **Step 4 (me): wire the facade + roof with fallback.** In `buildOneFloorShell`, gate the **opaque wall shell** (WallBack, front walls/lintel, corner columns, story band, cornice) behind `StudioModels.has("FacadeModule")`:

```lua
local floorCFrame = CFrame.new(base + Vector3.new(0, slabTop, 0)) -- floor base centre
if StudioModels.has("FacadeModule") then
	StudioModels.place("FacadeModule", parent, floorCFrame, prefix .. "Facade")
	-- Glass panes still placed as Parts (see below); slab/door/balcony/lights/terrace unchanged.
else
	-- (existing WallBack / front walls / columns / storyBand / cornice code stays as fallback)
end
```
Keep the **glass parts** (`glassWall` left/right, upper-floor front glass, door glass) and **slab/door/balcony/lights/rooftop terrace** building in **both** paths — they are never replaced. On the top floor (`f == floorCount - 1`), place `RoofCrown` (fallback: existing `Roof`/`RoofDeck` block) with the same `has()` gate.

- [ ] **Step 5 (me): compile-check** → `rojo build` clean.
- [ ] **Step 6 (me + you): Studio playtest at 1, 2, and 3 floors** (set `houseTier` 0/1/2 via a quick server-side edit): building looks premium; **glass still see-through**; **door walkable**; **interior stations/desks/workers intact**; floors stack correctly; roof crown on top only; rename assets to confirm **fallback** returns the old walls; no errors; smooth at a phone-size view.
- [ ] **Step 7: iterate** on the Blender scripts (window alignment vs. glass parts, no z-fighting/gaps) until it looks right; checkpoint.

---

### Task 5: Round 3 — Corner trim + polish

**Files:**
- Create: `blender/corner_trim.py`
- Create (you): `assets/studio/CornerTrim.rbxmx`
- Modify: `src/server/PlotManager.luau`

- [ ] **Step 1 (me): write `blender/corner_trim.py`** — a decorative corner pillar/trim piece (one corner), placed by code at the 4 corners per floor. Export `blender/out/CornerTrim.fbx`.
- [ ] **Step 2 (you): run, import, save** `assets/studio/CornerTrim.rbxmx` (+ live copy).
- [ ] **Step 3 (me): wire placement** — in `buildOneFloorShell`, when `StudioModels.has("CornerTrim")`, place a clone at each of the 4 corners (`{±halfW, ±halfD}`) with the correct facing; no fallback needed (pure decoration — if missing, simply skip).
- [ ] **Step 4 (me): compile-check** → `rojo build` clean.
- [ ] **Step 5 (me + you): Studio playtest** — corners look good at multiple floors; no clipping; no errors; checkpoint.

---

### Task 6: Final pass

- [ ] **Step 1 (me + you): full playtest** — approach the studio from the plot/lobby; check it reads as premium at 1–3 floors; glass, door, interior, growth, fallback all correct; phone-size view smooth; no console errors.
- [ ] **Step 2 (me): update memory** `development-roadmap.md` — mark M7 Round 1 (building) done + note the Blender→`.rbxmx`→Rojo pipeline for future batches (desks, workers, lobby, animations).
- [ ] **Step 3: decide next batch** (desks/PCs, workers, or lobby props) or move to another milestone.

## Future M7 batch: Map / scenery in Blender (added 2026-07-24, user request)
Turn the decorative lobby/city environment into Blender meshes (roundabout, roads, court, beach, landscaping, signage, props, landmarks) — where Blender pays off most. **Keep code-driven and layered on top:** the 4 runtime-built player plots + studios, spawns, ProximityPrompts, the basketball mechanic, day/night, and collisions. Do it as its own batch, piece by piece (each with the same Blender→`.rbxm`→Rojo→`StudioModels` pipeline + fallback). Trade-off to remember: once scenery is a mesh, editing it means going back to Blender (vs. quick code tweaks today).

---

## Self-Review
- **Spec coverage:** pipeline (Tasks 3–5 loop), Option-A storage (Task 1 + `.rbxmx` saves), facade-per-floor with kept glass/slab/interior (Task 4), roof crown (Task 4), entrance sign as Round-1 proof (Task 3), corner trim (Task 5), fallback safety (Task 2 + every `has()` gate), Rojo wiring + restart (Task 1), detail/reuse stance (Global Constraints), no data changes (none present) — all covered.
- **Placeholders:** none; the one deliberate iteration point (Blender script *looks*) is inherent to art and is explicitly a repeat-until-right loop, not an unspecified step. Luau shown in full.
- **Consistency:** helper API (`has`/`get`/`place`) used identically in Tasks 3–5; dims match the spec + `PlotManager` constants.
