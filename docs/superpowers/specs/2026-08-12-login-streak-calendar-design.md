# Login Streak Calendar (B1) — Design

**Date:** 2026-08-12
**Roadmap item:** B1 (Login streak polish) from `docs/superpowers/plans/2026-08-11-post-v1-roadmap.md`
**Status:** Design approved, spec under review.

## Goal

Turn the current daily reward into a real retention hook: a visible 30-day
calendar with milestone prizes, rewards that stay meaningful as the player
grows, and a catch-up path so one missed day does not erase a month.

## What is wrong with the current system

`GameData.DailyRewards` is a **7-entry list that cycles forever** ($100, $300,
2× boost, $800, $2000, 3× boost, $6000). `DailyRewardService.evaluate` grants the
next entry when 20h have passed and resets the streak to 1 when more than 48h
have passed.

Four concrete problems:

1. **Rewards go stale.** $6,000 is a fortune on day one and pocket change after a
   rebirth, so the ladder stops mattering exactly when retention matters most.
2. **Nothing is visible.** The player never sees what is coming, so there is no
   anticipation — the core reason streak calendars work.
3. **One missed day costs everything.** Miss ~2 days and the streak drops to 1.
   For a game aimed at kids who do not control their own screen time, that is
   punishing enough to make people quit rather than come back.
4. **The cycle repeats at 7.** There is no long-term thing to chase.

## Player-facing behaviour

- The daily reward panel becomes a **30-cell calendar grid**. Claimed days show a
  tick, today pulses, future days are dimmed but readable — the player can always
  see what they are working toward.
- **Milestones at day 7, 14 and 30** are rendered larger, with day 30 styled as
  the trophy cell.
- Claiming day 30 **restarts the calendar at day 1** and refreshes the free skip.

### The reward ladder

`GameData.DailyRewards` grows from 7 to **30 entries**. Ordinary days pay cash or
a boost; the three milestones are:

| Day | Reward |
|-----|--------|
| 7 | Large scaled cash + a long 3× boost (15 min) |
| 14 | A Lucky Case spin (`luckySpinsOwned += 1`) |
| 30 | A random **Champion PC part** the player does not own yet |

The day-30 prize reuses the event's Champion system (`EventData.rollChampionPart`
/ `applyChampionGrant`): a random un-owned category, worth 125% of that player's
part in the same category, permanent, folded into the economy multipliers exactly
like an event-won part. It also gives players who cannot make Sundays a second
route into the collection. If all 7 Champion parts are already owned, day 30 pays
the scaled consolation cash instead — the same fallback the event uses.

### Rewards scale with progression

Cash rewards are multiplied by the **same continuous progression scale the event
uses** (`EventData.scale`, a sub-linear curve off subscriber count), so day 12 is
worth roughly the same *relative* amount to a new player and to someone on their
fifth rebirth. Boost and case rewards are not scaled — a 3× boost is a 3× boost.

Base values stay authored in `GameData.DailyRewards`; scaling is applied at grant
time and at display time, from one shared function, so the two cannot disagree.

### Missing a day

1. **The first miss in a calendar is free.** The streak survives and the player is
   told "Streak saved!". Sets `dailySkipUsed = true`.
2. **After that**, the streak is not destroyed immediately — it is held in
   `dailyBrokenStreak` and the player is offered a **Robux streak repair**.
   - Buy it → `dailyStreak` restored from `dailyBrokenStreak`, `dailyBrokenStreak`
     cleared, and the day becomes claimable again.
   - Decline (or claim without repairing) → the streak restarts at 1 and
     `dailyBrokenStreak` clears.
3. `dailySkipUsed` resets when the calendar restarts after day 30.

The 20h claim cooldown and 48h streak-reset window (`DailyClaimCooldownSeconds`,
`DailyStreakResetSeconds`) are unchanged — the free skip and the repair sit on top
of the existing rule rather than replacing it.

## Architecture

Follows the pattern used by quests, challenges and the event: pure logic in a
shared module (unit-tested), server owns granting, client only renders.

### Changed files

- **`src/shared/GameData.luau`**
  - `DailyRewards` extended to 30 entries, with `milestone = true` on 7/14/30.
  - `getDailyReward(streakDay)` no longer wraps modulo-7; it indexes 1..30 and
    clamps at 30.
  - New `getScaledDailyReward(data, streakDay)` → the reward with cash scaled by
    progression; used by both the grant and the display.
  - New `evaluateDailyStreak(data, now)` → pure decision function returning
    `{ available, nextStreak, usedFreeSkip, brokenStreak }`. This is the logic the
    service currently inlines; extracting it makes the skip/repair rules testable.
  - `Products.StreakRepair = { id = 0, ... }` — `0` means "Coming soon" until a
    real Robux product exists, matching the existing convention.
- **`src/server/DailyRewardService.luau`** — uses `evaluateDailyStreak`; grants the
  scaled reward; handles the milestone kinds (`case`, `championPart`); clears
  `dailyBrokenStreak` appropriately.
- **`src/server/MonetizationService.luau`** — one new receipt branch for
  `StreakRepair`: restore `dailyStreak` from `dailyBrokenStreak`, clear it, save.
- **`src/client/DailyRewardPanel.luau`** — becomes the 30-cell calendar; shows the
  "Streak saved!" message and the repair offer.
- **`src/server/PlayerData.luau`** — new fields (defaults + backfill):
  `dailySkipUsed = false`, `dailyBrokenStreak = 0`.
- **`src/shared/Tests/RunTests.luau`** — assertions for the new pure logic.

No new modules: `DailyRewardService` (77 lines) and `DailyRewardPanel` (147 lines)
are both small, so this grows them rather than splitting them.

## Data flow

1. On join, `DailyRewardService.checkForPlayer` calls `evaluateDailyStreak` and
   fires `DailyRewardAvailable` with the day, the scaled reward preview, and
   whether a repair is being offered.
2. The client renders the calendar from the `data` table it already receives.
3. Claim → server re-evaluates, grants, saves, pushes `PlayerStateUpdated`.
4. Repair → a normal Robux product purchase through the existing
   `MonetizationService.ProcessReceipt`.

## Error handling / edge cases

- **Server time is authoritative** for every streak decision; the client only
  displays.
- **Claiming is server-re-validated** — the client never sends a day number or an
  amount.
- **No `loadFailed` guard on the daily claim** (game cash, must work in Studio),
  consistent with quests/challenges/event.
- **The repair is Robux**, so it DOES keep the existing successful-save
  requirement in `ProcessReceipt` — a repair must never be granted if it cannot be
  persisted.
- **All 7 Champion parts owned at day 30** → scaled consolation cash, no error.
- **A player who never misses a day** never sees the skip or repair paths at all.

## Testing

- Unit assertions in RunTests for: 30-entry ladder indexing and clamping at 30;
  milestones landing on 7/14/30; cash scaling monotonic in subscribers and equal
  to the displayed value; `evaluateDailyStreak` across the four cases (on time /
  first miss → free skip / second miss → broken + repair offered / repaired →
  restored); calendar restart clearing `dailySkipUsed`.
- Studio playtest by manipulating `lastDailyClaim` to simulate elapsed days.
- Verification is Rojo build + Studio playtest; there is no CI.

## Out of scope (YAGNI)

- No second currency, no streak leaderboard, no per-day custom art.
- No retroactive claiming of individual missed days — repair restores the streak,
  it does not hand out the skipped days' rewards.
- The Robux product ID itself is created by the user in Roblox; this ships with
  `id = 0` ("Coming soon").

## Known constraint

**Robux purchases cannot be tested while `FRESH_START_NO_SAVING = true`** in
`PlayerData.luau` — the grant is gated on a successful save, which that switch
disables. The repair path must be verified with saving turned back on.
