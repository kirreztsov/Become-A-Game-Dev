# Workers + Active Development Mini-Games — Design Spec

## Overview

Replaces the passive "pick Genre+Topic, watch a bar fill" development cycle
with an active one: making a game is now three short mini-games (Coding, Map
Building, Testing). Separately, players can hire one Worker per phase at a
desk in the lobby; a hired Worker auto-completes their phase instead of the
player playing it, so a fully-staffed studio can run the whole cycle
hands-free except for picking Genre+Topic.

This replaces the "Upgrades" section of the original BETA spec
(`2026-07-20-game-dev-tycoon-design.md`) — **Dev Speed** and **Quality
Boost** are removed entirely. Everything else from that spec (Trends Board,
Cash rules, solo private studio, endless loop) is unchanged.

## Updated Core Loop

1. Player picks a **Genre** + a **Topic** (unchanged, always manual).
2. Player presses **"Start Developing"**.
3. Three phases run in a fixed order: **Coding → Map Building → Testing**.
   For each phase:
   - If the player has hired a Worker for that phase, it **auto-completes**
     after a short fixed delay (representing the worker "at work"), scored
     by that Worker's own upgrade level.
   - Otherwise, the player plays that phase's mini-game themselves, scored
     by their actual performance.
4. Each phase produces a **Phase Score** from 0.0 to 1.0. **Dev Quality** =
   the average of the three Phase Scores.
5. The game "releases": Cash is computed exactly as before — compare
   Genre+Topic against the Trends Board (exact match = copy = $0, partial
   match = 10% chance of 5x, no match = normal) — except **Base Cash is now
   `PayoutMultiplier × Dev Quality`** instead of being driven by the old
   Quality Boost upgrade level.
6. Repeat indefinitely, same as before.

## The Three Mini-Games

Each is genuinely **server-authoritative** — the server computes the Phase
Score itself from server-verified inputs, never from a client-reported
number. This matches this project's existing rule that the client only
requests actions and displays server-decided outcomes; it's what stops a
modified client from just claiming a perfect score.

### Coding — tap challenge

- The server opens a fixed-length round window (a few seconds) and starts
  counting.
- The client fires a lightweight "tap" event each time the player taps a
  button; the client renders its own tap counter for feedback, but that
  displayed count is cosmetic only.
- The **server** counts taps that arrive within its round window (with a
  sane per-tap minimum spacing to ignore inhuman/scripted tap floods) and
  computes the Phase Score from its own count against a target tap count.

### Map Building — timing bar

- The server picks a round start time and a marker motion (a marker
  oscillating back and forth over a track at a fixed speed) — this makes
  "where the marker is" a pure function of elapsed server time that both
  sides can independently compute.
- The client animates the same marker motion locally for the player to
  watch and react to (using the same fixed motion parameters), and sends a
  single "I'm placing it now" event when the player clicks/taps.
- The **server** computes where the marker actually was at the moment its
  own clock received that event, and scores based on distance from the
  center of the target zone (closer to center = higher score, outside the
  zone entirely = 0).

### Testing — multiple choice

- The server picks a question and its two options from a small fixed pool
  (defined server-side, or shared data with the correct answer withheld
  from what's sent to the client) and sends only the question text and
  option text to the client — never which one is correct.
- The client displays the two options; the player picks one; the client
  reports which option index was chosen.
- The **server** compares that against its own record of the correct
  option and scores the round accordingly (a wrong pick still gives partial
  credit, not zero — this is meant to feel forgiving, not punishing).

Each mini-game runs for a small, fixed number of rounds (a few), and the
Phase Score is the average across those rounds — one lucky or unlucky round
shouldn't swing the whole phase.

## Workers

- There are exactly **3 job slots**, one per phase: Coding, Map Building,
  Testing. (Unlocking additional slots/phases beyond these 3 — an
  "expansion" — is a real idea for later, explicitly out of scope for this
  pass, the same way extra Genres/Topics were deferred earlier.)
- Workers are hired and upgraded at the **desk in the lobby** — walking up
  and interacting with it opens a Workers panel (separate from the main
  floating gameplay UI) showing all 3 roles, whether each is hired, its
  current level, and hire/upgrade costs.
- Hiring a role costs Cash (a flat cost, same for all 3 roles) and is a
  one-time purchase per role.
- Once hired, a Worker has its own upgrade track (own cost curve, same
  shape as the old per-level upgrade costs) that raises the Phase Score it
  contributes when it auto-completes its phase — so an un-upgraded Worker
  does its job passably, and upgrading it makes it noticeably better,
  mirroring how a player who's good at the mini-game already scores higher
  without any Worker at all.
- A phase handled by a Worker still takes a short, fixed amount of time
  (not instant) — the UI shows something like "Your Coding Worker is
  working..." during that delay, so automating a phase still has some
  pacing to it rather than feeling free.

## Removed From the Original BETA

- `GameData.getDevTime`, `getDevSpeedCost`, `DevSpeedDecayPerLevel`,
  `DevSpeedCostBase`/`Growth`, `getQualityMultiplier`, `getQualityBoostCost`,
  `QualityBoostPerLevel`, `QualityBoostCostBase`/`Growth`, and the
  `getBaseCash(qualityBoostLevel)` signature (Base Cash is now a function of
  Dev Quality, not an upgrade level).
- `UpgradeService`'s `DevSpeed`/`QualityBoost` handling, and the client's
  Dev Speed/Quality Boost upgrade buttons.
- The single continuous progress bar UI for the whole development cycle
  (replaced by the three-phase mini-game/auto-complete sequence).
- `playerState.devSpeedLevel`/`qualityBoostLevel` (replaced by per-worker
  hired/level state, see below).

## Data Shape Changes

`PlayerData`'s per-player table changes from
`{cash, devSpeedLevel, qualityBoostLevel, gamesReleased}` to:

```
{
  cash: number,
  gamesReleased: number,
  workers: {
    Coding: { hired: boolean, level: number },
    MapBuilding: { hired: boolean, level: number },
    Testing: { hired: boolean, level: number },
  },
}
```

## Out of Scope for This Pass

- Additional job slots / an "expansion" system beyond the base 3 workers.
- Visible Worker NPC characters in the lobby (workers are represented by
  their effect on the development cycle and their entry in the Workers
  panel, not a physical character model).
- The per-player house system (a separate, upcoming project — explicitly
  sequenced after this one).
- General visual polish beyond what's needed to build the above (the lobby
  size increase already happened as a quick standalone fix).
