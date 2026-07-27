# Studio Per-Tier Houses — Design Spec

**Milestone:** M7 (studio building).

**Goal:** Each upgrade tier is a **distinct, more beautiful, physically bigger** studio — its own Blender model, not a recolor. Level 1 humble → Level 2 nicer/bigger → Level 3 gold-carved luxury. Stays walkable and grows with upgrades.

## Per-tier vision
| Level | Tier | Width | Floors | Look |
|-------|------|-------|--------|------|
| 1 | 0 | ~36 | 1 | **Humble** — plain walls, small simple windows, a basic door, minimal trim, modest colors. A scrappy starter studio. |
| 2 | 1 | ~48 | 2 | **Proper studio** — bigger framed windows, awnings, an entrance canopy, trim bands, balconies + detailed flower boxes. Clean and nice. |
| 3 | 2 | ~60 | 3 | **Luxury HQ** — fluted columns/pilasters with **gold carvings**, gold capitals + moldings, a **crest/emblem over the door**, arched windows, a layered **gold cornice**, grand steps + red carpet. Purple/cream + gold. |

## Width system — DROPPED (2026-07-25 decision)
Physical width-per-tier was investigated and rejected: `BUILDING_HALF_W` is used in ~25 places including **live per-plot runtime code** (edge clamps etc.), so making it tier-based risks bugs on a working studio for little visual gain. Footprint stays fixed (48 wide). The "bigger" feel comes instead from **more floors** + **grander facade design** per tier (tall columns, big cornice on L3). The distinct models carry the whole "unique + beautiful per tier" goal.

## Facade models (one per tier)
- Three Blender models: `StudioL1`, `StudioL2`, `StudioL3`, picked by tier (extends the existing per-tier facade picker). Each auto-scaled to that tier's width via `targetWidth`.
- All use the **same part-name convention** so the existing code paints them: `Body / Accent / Trim / Win / Planter / Stem / Center / FlowerA|B|C`, plus new **`Gold`** parts for Level 3 carvings/moldings/crest.
- Fallback: if a tier's model is missing, fall back to the base facade (never breaks).

## Keep
- Walkable interior, per-floor growth, the creator entrance props (camera/plaque/spotlight/etc.), and detailed multi-species flowers on Levels 2–3.

## Build order (one tier at a time, verify each in Studio myself)
1. **Width system** — tier-based half-width threaded through; confirm the building + rooms + landscaping resize per tier with no overlap.
2. **Level 1** — humble `StudioL1` model + wire tier 0.
3. **Level 2** — `StudioL2` (detailed) + wire tier 1.
4. **Level 3** — `StudioL3` (gold luxury) + wire tier 2.

## Constraints
- Blender→`.rbxm`→Rojo pipeline; `1 unit = 1 stud`; origin at door base; front −Y → −Z.
- Gold = a colour, not Neon (respects the neon-accent-only rule).
- Verification = Studio playtest; I force each tier and screenshot to confirm.

## Out of scope
Interior/station redesign; other buildings; audio.
