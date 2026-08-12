# Sunday Showdown — Weekend Event (B2) — Design

**Date:** 2026-08-12
**Roadmap item:** B2 (Limited-time event) from `docs/superpowers/plans/2026-08-11-post-v1-roadmap.md`
**Status:** Design approved, spec under review.

## Goal

Add one recurring limited-time event that lifts retention by giving players a
reason to log in on a specific day and a permanent, aspirational reward they can
only earn during the event. The event is **Sunday only** (server UTC). It runs
automatically every week with zero configuration.

Two things make players actually play it:

1. **A live +50% boost** to cash *and* subscribers, active only while the event
   is running — a reason to grind *this* Sunday.
2. **A scarce, collectible reward** — a random "Champion" PC part earned by
   finishing the event quest arc, only obtainable on Sundays, that you keep
   forever and want to collect all 7 of.

## Player-facing behaviour

While it is Sunday (server UTC):

- Everyone gets **+50% cash and +50% subscribers** on released-game earnings.
- A new **🏆 Sunday Showdown** button appears in the left HUD stack. It is hidden
  Monday–Saturday.
- The panel shows a **6-quest arc**, a countdown ("Event ends in Xh"), and the
  player's **Champion-parts collection** (owned / 7).
- Quests are **sequential**: quest 2 unlocks when quest 1 is claimed, and so on.
  Each quest, on claim, pays **scaled cash**.
- Finishing (claiming) all 6 quests grants **one random Champion PC part** the
  player does not already own.

Monday–Saturday: no boost, button hidden, nothing to claim. Progress from a past
Sunday does not carry over — each Sunday is a fresh arc.

## The 6 quests

All six use **"today" deltas** (current stat minus a baseline snapshotted at the
start of the player's Sunday), so a player must play *that Sunday* to make
progress. All six are built only from metrics **every player can always advance
regardless of progression** — release games, gain subscribers, earn cash, release
a trendy hit. (Deliberately excluded: upgrade-PC-parts, hire-workers, and
play-minigames — a maxed player can hit a ceiling on those and the sequential arc
would jam. See "Rejected ideas".)

| # | Quest | Metric (today delta) | Base target |
|---|-------|----------------------|-------------|
| 1 | Release games today | `gamesReleased` | 5 |
| 2 | Gain subscribers today | `subscribers` | 2,000 |
| 3 | Earn cash today | `totalCashEarned` (new counter) | 10,000 |
| 4 | Release more games today | `gamesReleased` | 12 |
| 5 | Release a trendy hit today | `trendyHits` (new counter) | 1 |
| 6 | Final push — earn cash today | `totalCashEarned` | 50,000 |

Base targets are tunable; real numbers get dialed in during playtest.

### Continuous difficulty scaling (no tiers)

Targets and per-quest cash rewards scale **continuously** with the player's
progression — no bucketed tiers. Progression is measured from **subscribers**
(the headline persistent stat) through a smooth, sub-linear curve so targets grow
with the player but stay achievable in a day:

```
scale = 1 + math.log10(1 + subscribers / SUB_REF)      -- SUB_REF ~ 1000, tunable
target      = math.ceil (base       * scale)
rewardCash  = math.floor(baseReward * scale)
```

So a new player (few subs) sees ~"release 5 games"; a strong player sees a much
larger number, each getting a fair personal target from the same formula. The
trendy-hit quest (base 1) scales very slowly and is capped low (≤3) so it never
requires more trend windows than a Sunday reliably offers (trends rotate every
5 minutes — `GameData.TrendRefreshSeconds = 300`).

## The Champion PC part reward (the chase)

Finishing all 6 quests grants **one random Champion part**:

- Roll uniformly among the 7 PC-part categories (CPU, RAM, Storage, Cooling, GPU,
  Monitor, RGB) that the player does **not** already own a Champion version of.
- The granted part's bonus is locked at claim time to **125% of the player's best
  current part bonus**:
  `championBonus = round(1.25 * max over the 7 parts of getPCPartModel(id, level).bonus)`.
  This is always an upgrade beyond the player's shop rig.
- Store it in a new `PlayerData.eventParts` map: `{ [partId] = championBonusPercent }`.
- Champion parts are **permanent** and stack on top of the shop `pcParts` levels
  in the economy (see below). Money-category parts (CPU/RAM/Storage/Cooling) add
  to the cash multiplier; follower-category parts (GPU/Monitor/RGB) add to the
  subs multiplier — same split the shop already uses.
- **Collection:** because the roll excludes parts already owned, each Sunday a
  player wins a *different* part, so the chase is "collect all 7." Once all 7 are
  owned, finishing the arc pays a **scaled cash consolation** instead (the chase
  is complete; boost + quest cash still make Sundays worth playing).

**Balance flag:** Champion parts are a new permanent multiplier layer. Fully
collected (all 7 at 1.25× best) roughly doubles PC power at most. The 1.25 factor
is a single tunable constant; flag for playtest tuning. This does not touch Robux
monetization (it is game-earned, server-authoritative).

## Architecture (mirrors quests + daily challenges)

Same pure-logic + server-authoritative-claim shape as `QuestData`/`ChallengeData`.

### New files

- **`src/shared/EventData.luau`** — pure, unit-tested in RunTests. No side effects.
  - `isEventActive(now)` → is it Sunday (UTC) at `now`.
  - `weekIndex(now)` → integer week id (for per-Sunday rollover; `floor(dayIndex/7)`).
  - `secondsUntilEnd(now)` → seconds left until Sunday ends (for the countdown).
  - `scale(data)` → the continuous progression multiplier from subscribers.
  - `QUESTS` list (the 6 above) + `target(data, i)`, `rewardCash(data, i)`.
  - `progress(data, i)` → today-delta vs `data.eventBaseline`, clamped ≥ 0.
  - `isComplete(data, i)`, `canClaim(data, i)` (sequential: prior quest claimed).
  - `rolloverIfNeeded(data, now)` → if new week: snapshot `eventBaseline` from
    current stats, clear `eventQuestsClaimed`, set `eventClaimedWeek`.
  - `applyQuestClaim(data, i)` → marks claimed, returns quest cash reward.
  - `rollChampionPart(data)` → returns a random un-owned partId + its locked bonus
    (or nil if all 7 owned), and `applyChampionGrant(data, partId, bonus)`.
- **`src/server/EventService.luau`** — `start()` called from `init.server`.
  - Rollover on `PlayerAdded` (waits for data) + a periodic loop for the
    Sat→Sun / Sun→Mon boundary (like `ChallengeService`).
  - `RequestClaimEventQuest` handler: re-validate `canClaim` server-side, grant
    scaled cash, `PlayerData.save`, fire `PlayerStateUpdated`.
  - When quest 6 is claimed: roll + grant the Champion part (or consolation cash),
    persist, fire update. Server-authoritative; no client-supplied amounts.
  - No `loadFailed` guard on claims (game cash, must work in Studio — same lesson
    as quests/challenges).
- **`src/client/EventPanel.luau`** — 🏆 HUD button at **left-stack y offset −278**
  (next free slot below Perks at −226; 52px spacing). Button + claimable badge are
  **shown only when `isEventActive`**. Panel: 6 sequential quest rows with progress
  bars + Claim, the countdown, and a Champion-parts collection strip (7 slots,
  owned lit). Mirrors `ChallengePanel`/`QuestPanel` structure + theme.

### Changed files

- **`src/server/PlayerData.luau`** — add to `defaultData()` + backfill:
  `eventParts = {}`, `eventBaseline = { games = 0, subs = 0, cash = 0, hits = 0 }`,
  `eventClaimedWeek = -1`, `eventQuestsClaimed = {}`, plus the two new lifetime
  counters `totalCashEarned = 0` and `trendyHits = 0`.
- **`src/server/DevelopmentService.luau`** —
  - At the cash grant (~:388) and subs grant (~:398): when `isEventActive(now)`,
    fold a **×1.5 event boost** into the existing multiplier chain.
  - Increment `totalCashEarned` by the cash granted (the lifetime counter).
  - Where `hitBonus` is computed (~:382): when true, increment `trendyHits`.
- **`src/shared/GameData.luau`** — extend `getPCPartsCashMultiplier` and
  `getPCPartsSubsMultiplier` (~:605/:610) to also add `eventParts` bonuses (money
  vs follower split), so Champion parts apply everywhere the shop parts already do.
  Signature gains an optional `eventParts` arg; existing callers pass it.
- **`src/shared/Remotes.luau`** — add `RequestClaimEventQuest`.
- **`src/server/init.server.luau`** — `EventService.start()` (next to
  `QuestService.start()` / `ChallengeService.start()`).

## Data flow

1. Client already receives the full `data` table via `PlayerStateUpdated`.
   `EventPanel` renders all bars/targets/collection purely from `EventData` +
   that `data` — no new per-frame traffic.
2. Claim: client → `RequestClaimEventQuest(i)` → server re-validates via
   `EventData.canClaim`, grants, saves, pushes `PlayerStateUpdated`.
3. Boost + counters + Champion multiplier all live server-side in
   `DevelopmentService`/`GameData`; the client only displays.

## Error handling / edge cases

- **Server time is authoritative** for `isEventActive` and rollover. Client uses
  its own `os.time()` only for the cosmetic countdown; a brief midnight mismatch
  is cosmetic only (same as daily challenges).
- **Prestige resets `gamesReleased` to 0.** Deltas are clamped ≥ 0 by `progress`,
  so a mid-Sunday prestige can only stall a games quest, never break it. Claimed
  quests stay claimed (persisted).
- **`totalCashEarned` / `trendyHits` are monotonic** (only ever increase), so
  their deltas are always valid — unlike spendable `cash`, which is why the new
  lifetime counter is required for the "earn cash" quests.
- **All 7 Champion parts owned** → `rollChampionPart` returns nil → arc pays
  scaled cash instead. No error, chase simply complete.
- **Rollover races** are handled the same way `ChallengeService` handles them
  (rollover on join + boundary loop; claim path re-checks week).

## Testing

- `EventData` gets assertion tests in the existing RunTests harness (mirrors
  `ChallengeData`): `isEventActive` on Sunday vs other days, `weekIndex` rollover,
  `scale` monotonic in subscribers, `progress` delta + clamp, sequential
  `canClaim` gating, `rollChampionPart` excludes owned + returns nil at 7,
  `championBonus` = 1.25 × best.
- In-game Studio playtest: force `isEventActive` true (temporary override), verify
  button appears, bars fill, sequential claim, part grant + collection update,
  economy boost visible. Verification is Rojo build + Studio playtest (no CI).

## Rejected ideas (and why)

- **Upgrade-PC-parts / hire-workers / play-minigames quests** — each has a
  progression ceiling (maxed parts, full worker roster, workers removing the need
  to play minigames). In a sequential arc a ceiling-blocked quest jams the whole
  event. Cut in favour of the four always-advanceable metrics.
- **Fixed 5-tier difficulty buckets** — replaced with the continuous scaling
  formula so the target grows smoothly with the player, not in snap steps.
- **Passive aura / floating pet cosmetic** — rejected by the user as not
  compelling; a collectible functional part with a live boost drives play harder.

## Out of scope (YAGNI)

- No event shop, no multiple reward tiers, no seasonal theming/config — one
  recurring Sunday event, one boost, one collectible chase.
- No changes to passive/idle room income boost (event boost applies to the
  released-game core loop the quests drive). Can revisit if playtest wants it.
