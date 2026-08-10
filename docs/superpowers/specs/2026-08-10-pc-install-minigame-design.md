# PC Install Minigame — Design Spec

**Date:** 2026-08-10
**Goal:** Make upgrading a PC part a hands-on 3D step: after buying a part, the player goes to a workbench in the PC Store, drags the old part out, and drags the new part into its glowing slot. Only a completed install applies the upgrade.

## Summary

Today buying a part is instant: `RequestUpgradePart` → server checks cash + level → deducts cash, bumps `pcParts[id]`, fires `PCActionResult(true)` + `PlayerStateUpdated`.

This feature inserts a required "install" step between paying and getting the upgrade. Buying now *reserves* the upgrade (no charge) and launches a local 3D minigame at a workbench. Only when the client reports a correct install does the server apply the upgrade. Quitting mid-install charges nothing.

The minigame is drag-and-drop with generous snapping, per-player and local (other players don't see it), using the real tiered part models via `PCVisuals`, so the part installed is exactly the one that later appears on the desk rig and shop shelf.

## Scope

- All **7** parts use the same workbench: GPU, Monitor, RGB (case), CPU, RAM, Storage, Cooling.
- Each part has **one** fixed home spot on the bench. Only the spot for the current part glows.
- A round is at most **two drags**: remove the old part (if one exists), then insert the new part.
- **Non-failable.** Wrong drops don't snap; the part eases back to the tray. The round ends when the new part is seated.
- Level 0 → 1 (first buy) has no old part to remove — the round is a single insert drag.

Out of scope (YAGNI): scoring/star ratings, timers, cosmetic rewards, multiplayer-visible installs, physics collisions, cable-routing or screw sub-steps.

## Flow (data + anti-cheat)

1. Player fires the buy prompt → `RequestUpgradePart(partId)` (unchanged remote).
2. `PCService` validates: part exists, not maxed, `cash >= cost`. On success it stores
   `pendingInstall[player] = { partId, cost, targetLevel }` and fires
   `PCInstallStart(partId, oldTier, newTier)` to that client. **No cash is deducted yet.**
   - `oldTier` / `newTier` are visual tiers from `PCVisuals.getVisualTier(level)` for the
     current and next level (so the client shows the correct models; may be equal).
   - If validation fails, fire `PCActionResult(false)` as today (no pending install).
   - If a pending install already exists for that player, ignore the new request (return busy
     via `PCActionResult(false)`).
3. Client runs the minigame (see below).
4. On a correct install the client fires `PCInstallComplete(partId)`.
5. `PCService` handles `PCInstallComplete`: look up `pendingInstall[player]`; verify it exists,
   the `partId` matches, and the buy is *still* valid (`cash >= cost`, level still
   `targetLevel - 1`). If valid: `cash -= cost`, `pcParts[partId] = targetLevel`, clear pending,
   run the existing post-upgrade side effects (rig/home rebuild triggers), fire
   `PCActionResult(true)` + `PlayerStateUpdated(data)`. If invalid: clear pending, fire
   `PCActionResult(false)`.
6. `PCInstallCancel(partId)` or the player leaving clears `pendingInstall[player]`; nothing is
   charged, no upgrade applied.

`pendingInstall` is an in-memory table keyed by `Player`, cleared on `PlayerRemoving`. It never
persists.

## The minigame (client)

- **Landmark:** `Lobby.luau` builds a static, non-interactive **Assembly Bench** prop in the PC
  Store near the buy counter, so players see where installs happen.
- **Interactive rig:** on `PCInstallStart`, `PCInstallGame.luau` builds the interactive scene
  *locally* (not replicated): an open tower with the motherboard and marked slots, a parts tray,
  and slot highlights. It sets a scriptable camera framing the bench and hides the HUD
  ScreenGuis; both are restored on finish/cancel.
- **Spots:** `PCInstall.luau` (shared) holds, per partId, the slot's local CFrame, the tray
  spawn CFrame, the camera pose, and the snap radius. The bench's world CFrame anchors these.
  Spot intent per part: CPU = socket; RAM = RAM slot; Storage = M.2; Cooling = on the CPU;
  GPU = PCIe slot; Monitor = a stand beside the tower; RGB (case) = a "drop the build into the
  new case" pad.
- **Round:**
  1. If `oldTier` is present (level ≥ 1), the old-tier model sits in the slot. The player drags
     it to a recycle tray; it fades out.
  2. The new-tier model sits on the parts tray. The player drags it; released within the slot's
     snap radius, it eases into the exact slot CFrame with a click sound + glow pulse.
- **Controls:** press-and-hold a draggable part; a ray from the cursor/touch onto a horizontal
  plane at bench height gives the drag point; on release, snap if within radius, else ease back
  to the tray. Snap radius is generous for touch.
- **Models:** `PCVisuals.buildTierDisplay(asset, tier, ...)` with the part's paint fn supplies
  both the old and new part models, sized to the slot.
- **Completion:** when the new part is seated, wait a short beat, tear down the rig, restore
  camera + HUD, fire `PCInstallComplete(partId)`.
- **Cancel:** a Cancel/back button (and the minigame's own guard if the round can't start) tears
  down and fires `PCInstallCancel(partId)`.

## Files

- `src/shared/Remotes.luau` — add remote names `PCInstallStart`, `PCInstallComplete`,
  `PCInstallCancel` (all RemoteEvents, created by the existing name-list loop).
- `src/shared/PCInstall.luau` *(new)* — per-part bench layout table + a pure `isWithinSnap(dropPos,
  slotPos, radius)` helper. No Roblox-instance side effects beyond CFrame math, so it is unit
  testable.
- `src/server/PCService.luau` — reserve-on-buy, `PCInstallComplete` apply handler,
  `PCInstallCancel`/leave cleanup, `pendingInstall` table.
- `src/server/Lobby.luau` — static Assembly Bench landmark prop in the PC Store.
- `src/client/PCInstallGame.luau` *(new)* — the 3D drag minigame (build rig, camera, input,
  snap, complete/cancel).
- `src/client/init.client.luau` — on `PCInstallStart`, launch `PCInstallGame`; ensure only one
  install runs at a time.

## Testing

- **Unit (`src/shared/Tests`)**, following the existing test style:
  - `PCInstall.luau`: `isWithinSnap` true/false around the radius boundary; every partId in
    `GameData.PCParts` has a layout entry (no missing spots).
  - Reserve/apply/validate rules of `PCService`: buying reserves without charging; a valid
    `PCInstallComplete` deducts exactly `cost` and sets level to `targetLevel`; an install that
    no longer validates (not enough cash, level changed, no pending) applies nothing; cancel/leave
    clears the pending entry. (Extract the pure decision logic so it can be tested without live
    RemoteEvents.)
- **Manual playtest** in Studio (driven via the Studio MCP as in prior sessions): buy each of the
  7 parts, confirm the correct slot glows, the old part removes and the new part snaps, the
  upgrade applies once on completion, cancel/leave charges nothing, and the installed tier matches
  the desk rig + shop shelf.

## Constraints (carried from the project)

- `GameData.StartingCash` stays `0`.
- Colored accents use `SmoothPlastic`, not `Neon` (Neon blooms to white in this lighting); the RGB
  case's multi-color look is the existing approved exception.
- Server-authoritative: the upgrade is only ever applied by `PCService` after re-validation; the
  client never grants the part.
