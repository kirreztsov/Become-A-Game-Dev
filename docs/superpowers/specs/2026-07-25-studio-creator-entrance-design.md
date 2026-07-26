# Studio Creator Entrance — Design Spec

**Milestone:** M7 (studio building polish).

**Goal:** Add creator/YouTuber-themed detail props to the player studio's **ground-floor entrance**, that **grow with each upgrade tier** so leveling up visibly turns the storefront into a bigger creator HQ.

## Props by tier (cumulative)
- **Tier 1 (1 floor):** silver **play-button plaque** on the wall by the door; a **camera on a tripod** out front aimed at the entrance.
- **Tier 2 (2 floors):** everything above **+ a studio spotlight** on a stand; an **"ON AIR" light** above the door (the only glowing piece — respects the neon-accent-only rule).
- **Tier 3 (3 floors):** everything above **+ a red carpet** runner to the door; a large **channel banner** over the entrance; the plaque upgrades to **gold**.

## Approach
One Blender model, `StudioEntrance`, containing **all** props. Each prop's parts are named with a tier prefix (`T1_…`, `T2_…`, `T3_…`) plus a prop/colour tag. Placed **once at the ground floor** (`f == 0`) at the entrance apron in front of the door (−Z), facing the street.

The game (`PlotManager`):
1. Places `StudioEntrance` only on the ground floor when `StudioModels.has("StudioEntrance")`.
2. **Removes any part whose tier prefix > the current tier**, so the setup grows as you upgrade.
3. Colours each part by name: plaque silver (T1/T2) or gold (T3), camera/tripod dark, spotlight white/black, ON AIR red (SmoothPlastic, no neon bloom), carpet red, banner = tier accent.
4. Falls back to nothing if the asset is missing (never breaks).

## Constraints
- Ground floor only; does not repeat up the floors.
- Tasteful, not cluttered — props sit on/around the entrance apron, clear of the door path and the side rooms.
- Reuses the Blender→`.rbxm`→Rojo pipeline; `1 unit = 1 stud`, origin at the door base, front −Y → −Z.

## Verification
Studio MCP connection is back, so I place it, screenshot each tier (force `houseTier` 0/1/2), and fine-tune placement/scale/colour myself.

## Out of scope
Interior props; other buildings; per-tier facade shape (already handled separately).
