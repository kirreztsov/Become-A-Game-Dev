# M2 — Dynamic Onboarding Tutorial (Design Spec)

**Milestone:** M2 of the v1.0 launch roadmap (`docs/superpowers/plans/2026-07-23-v1-launch-roadmap.md`).

**Goal:** A friendly, **non-blocking** guide that walks a brand-new player through their first full gameplay loop — from spawning in the lobby to shipping their first game and spending the cash it earns — so a stranger with zero help ships a game, upgrades, and hires a worker within their first few minutes.

**Replaces:** the two removed first-time UIs (the static top-left "Goals" checklist and the multi-page "Welcome, Game Dev!" popup). This is the real onboarding.

---

## Success criteria (Done when…)
- A brand-new player is guided, step by step, to: enter their studio → sit at the New Project PC → pick a trend-matching Genre + Topic and start → play the 3 mini-games → **release their first game** → buy an upgrade → hire a worker.
- The guide **never blocks input** — the player can always walk, look around, and do other things.
- It **auto-starts once** for new players and never re-appears for players who already finished or skipped it (persisted).
- A player can **replay** it any time from a small "?" button.
- No new runtime errors; `rojo build` clean; verified live in Studio.

---

## Locked design decisions
1. **Guidance style:** *Guide, don't block* — a step banner + a world beacon/HUD pulse pointing at the next thing, with input never locked.
2. **Scope:** ends after **first game released + first upgrade bought + first worker hired** (6 guided steps, then a finale).
3. **Trigger/replay:** *first-time only* (saved via a `tutorialDone` flag) **plus a "?" replay button**.

---

## Architecture

One new client module owns the whole experience; the server only persists the done-flag.

### Components
- **`src/client/TutorialGuide.luau` (new)** — the entire tutorial: the step state machine, the bottom-center step banner, the world beacon (Neon pillar + bobbing ⬇ arrow + label), the HUD button pulse, step-completion detection, the Skip link, and the "?" replay button. Exposes:
  - `TutorialGuide.init(player, theme, playerState, hooks)` — builds the UI and starts the state machine. `hooks` carries references the guide needs from `UI.luau` (see Data flow).
  - Internally reacts to `Remotes.PlayerStateUpdated` and a few specific remotes/hooks to advance steps.
- **`src/server/TutorialService.luau` (new, tiny)** — `TutorialService.start()` connects `Remotes.SetTutorialDone.OnServerEvent` and sets `data.tutorialDone = true` for that player (so the save layer persists it). No other logic.

### Edits to existing files
- **`src/shared/Remotes.luau`** — add one `RemoteEvent`: **`SetTutorialDone`** (client → server, fired when the player finishes or skips).
- **`src/server/PlayerData.luau`** — add `tutorialDone = false` to `defaultData`, and backfill it for existing saves (same pattern as other fields). It rides along inside the `data` table already sent by `PlayerStateUpdated`, so the client reads `playerState.tutorialDone` with no extra remote.
- **`src/server/init.server.luau`** — `require` and `TutorialService.start()` alongside the other services.
- **`src/client/UI.luau`** — `require` + `init` `TutorialGuide`, passing the `hooks` table. Minimal, additive.

---

## The step machine

Each step has: **banner text**, a **target** (what the beacon/pulse points at), and a **completion signal**. Steps advance in order. Completion is detected from **deltas** captured when the step begins (not absolute values), so **Replay works for veteran players** — a step completes when the player performs the action *again*, not because they did it long ago.

| # | Banner text | Target / pointer | Completes when |
|---|---|---|---|
| 1 | "Step 1 of 6 — Head to your studio! 🏠" | Pulse the **To Studio** HUD button | player fires `RequestGoToStudio` (hook on the same button click) |
| 2 | "Step 2 of 6 — Sit at the New Project computer 💻" | **World beacon** over the `NewProjectSeat` in the player's plot | `seatedStation == "NewProject"` (via the existing `updateSeatedStation` hook) |
| 3 | "Step 3 of 6 — Pick a Genre + Topic that matches a Trend, then hit Start! 🎯" | (in-panel) banner only | player fires `RequestStartDevelopment` |
| 4 | "Step 4 of 6 — Play the mini-games to build your game! 🎮" | banner only (mini-game panels take the screen) | `Remotes.DevelopmentComplete` fires (first game shipped) |
| 5 | "Step 5 of 6 — Spend your cash on an upgrade! 💰" | banner only | `playerState.houseTier` **or** `playerState.pcTier` increases beyond the step-start baseline |
| 6 | "Step 6 of 6 — Hire your first worker! 👷" | banner only | any `playerState.workers[role].hired` becomes true beyond the step-start baseline |
| ✓ | "🎉 You're all set! Keep releasing hit games and grow your studio!" (auto-dismiss ~5s) | — | after step 6; fires `SetTutorialDone` |

**Notes**
- Steps 1–2 point at concrete places (HUD button, world seat) — that's where the guide is most valuable. Steps 3–6 are banner-only because the relevant UI (the New Project desktop, shop panels) is already on screen once the player is seated.
- The existing "direct to seat" banner/arrow logic in `UI.luau` (`currentPhase`, `hideInstruction`, per-phase arrow) is for mid-development phase routing and is **separate** from this tutorial; the tutorial's own banner lives in `TutorialGuide` and they must not fight (the tutorial banner sits bottom-center; phase routing is unchanged).

---

## Visual details
- **Step banner:** bottom-center card (anchored so it clears the top-center money card and the mini-game panels). On-theme: dark `theme.Panel` background, accent `UIStroke`, rounded corners. Contents: a small step-number pill, the step text, and a muted **"Skip ✕"** link on the right. Built in the HUD; respects the **ZIndexBehavior = Global** rule — no raising a container's ZIndex above its own children (per project memory).
- **World beacon:** a thin translucent **Neon** pillar rising from the target part, a **bobbing ⬇ arrow** (a `TextLabel` in a `BillboardGui`, `AlwaysOnTop`), and a short label ("Sit here!"). Only shown for world-object steps (step 2). Animated with **manual `task.spawn` loops**, never `TweenService` (unreliable in this project, per memory). Cleaned up when the step completes.
- **HUD pulse:** for step 1, a gentle size/stroke pulse on the To Studio button via a manual loop; stops on completion.
- **"?" replay button:** small circular button placed near the middle-left Rebirth button (does not overlap it). Click → restart the state machine at step 1 (re-baselining deltas). Replay does **not** clear `tutorialDone`.

---

## Data flow
1. On join, `PlayerData` provides `tutorialDone` inside `data`; the first `PlayerStateUpdated` hydrates `playerState.tutorialDone` on the client.
2. `TutorialGuide.init` runs during `UI` setup. If `playerState.tutorialDone` is falsy → auto-start at step 1. Otherwise idle (only the "?" replay button is present).
3. `UI.luau` passes a **`hooks`** table so the guide can observe without reaching into UI internals:
   - `hooks.toStudioButton` — the To Studio `TextButton` (for pulse + click detection).
   - `hooks.onSeatedStationChanged(callback)` — lets the guide subscribe to seat changes (called from the existing `updateSeatedStation`).
   - `hooks.getPlotFolder()` — returns the player's plot `Folder` so the guide can find `NewProjectSeat` for the beacon.
   - `hooks.replayAnchor` — optional reference for positioning the "?" button (else absolute-position it near the Rebirth button).
4. Step completion is detected inside `TutorialGuide` by connecting to `Remotes.PlayerStateUpdated`, `Remotes.DevelopmentComplete`, `Remotes.RequestStartDevelopment` (client-fired), and the hooks above.
5. Finishing step 6 **or** clicking Skip → fire `Remotes.SetTutorialDone`, set `playerState.tutorialDone = true` locally, tear down banner/beacon.

---

## Edge cases
- **Seated when tutorial should show:** if the player is mid-development, the tutorial banner stays hidden while seated (HUD hidden) and resumes when they stand up; steps still complete from their signals.
- **Player skips a step's target order** (e.g. buys an upgrade before releasing a game): steps are strictly ordered, so a later action taken early simply won't advance an earlier step. This is acceptable for a first-timer who is being guided; the delta-baseline is re-captured at each step start, so the action still counts when its step becomes active.
- **Replay by a veteran:** all completions are delta-based, so they re-perform each action (make another game, buy another upgrade, hire another worker). Banner copy stays the same.
- **Leaving/rejoining mid-tutorial:** because we only persist a single `tutorialDone` flag (not per-step progress), an unfinished new player will see the tutorial again next join (from step 1). This is intentional and simple — matches "first time only" for anyone who never finished.
- **Character respawn:** the beacon is rebuilt against the current plot on each step-2 entry; the guide re-resolves `NewProjectSeat` via `hooks.getPlotFolder()`.

---

## Testing / verification (no unit tests in this project)
- `./rojo-bin/rojo build default.project.json --output <tmp>` compiles clean.
- Live Studio playtest from a fresh `$0` save: confirm the banner auto-appears at step 1, the To Studio button pulses, the world beacon appears over the New Project desk, and each step advances on the right action through to the finale.
- Confirm `tutorialDone` persists behavior: after finishing, re-entering does not auto-start; the "?" replay button restarts it.
- Confirm input is never blocked at any step.
- Confirm no new console errors (the pre-existing `NewProjectSeat` infinite-yield warning is tracked separately under M8).

---

## Out of scope (deliberately)
- Pointing out shops, money rooms, rebirth, or leaderboards (the "full tour" option was not chosen).
- Per-step save/resume progress (only a single done-flag).
- Voice/animation cinematics.
