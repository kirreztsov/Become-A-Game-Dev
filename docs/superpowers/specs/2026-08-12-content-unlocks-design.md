# Unlockable Genres & Topics (A1, slice 1) — Design

**Date:** 2026-08-12
**Roadmap item:** A1 (More content to grind toward) from `docs/superpowers/plans/2026-08-11-post-v1-roadmap.md`
**Status:** Design approved, spec under review.

## Goal

Give players a long-tail thing to save for, and make choosing a game's genre and
topic an interesting decision rather than a cosmetic one.

Today there are 4 genres and 4 topics — 16 combinations, all free, all
mechanically identical. This adds 8 more of each (**12 × 12 = 144 combinations**),
where the new ones are **bought** and each grants a **cash bonus** on games that
use it.

## Player-facing behaviour

- The original 4 genres and 4 topics stay **free forever and grant no bonus**, so
  a new player can still make any of the original 16 combinations and nothing is
  taken away from them.
- Every new entry is **locked** until bought. Locked buttons show a padlock and
  the price; clicking one opens the purchase prompt.
- Releasing a game multiplies its **cash** by `1 + genreBonus + topicBonus`.
  Subscribers are deliberately untouched.
- **Cash unlocks roll a live percentage** inside a band. The roll re-rolls on the
  trend cycle and is shown on the button ("🧗 Obby +13%").
- **Robux unlocks are a fixed percentage**, always. Paying buys *certainty*, not
  raw power.

### The ladder

| Tier | Genre | Topic | Cost | Bonus |
|------|-------|-------|------|-------|
| Free | Racing, Horror, Adventure, Simulator | Space, Zombies, Sports, Fantasy | — | — |
| 1 | Obby | Pets | $20,000 | +10–15% |
| 2 | Tycoon | Ninjas | $60,000 | +12–17% |
| 3 | Roleplay | Pirates | $150,000 | +15–20% |
| 4 | Fighting | Robots | $400,000 | +18–23% |
| 5 | Puzzle | Dragons | $1,000,000 | +20–25% |
| 6 | Survival | Superheroes | $2,500,000 | +22–28% |
| — | Battle Royale | Aliens | 99 Robux | +30% fixed |
| — | Anime | Dinosaurs | 199 Robux | +35% fixed |

Icons: 🧗 Obby, 🏭 Tycoon, 🎭 Roleplay, 🥊 Fighting, 🧩 Puzzle, 🏕️ Survival,
⚔️ Battle Royale, 🌸 Anime / 🐶 Pets, 🥷 Ninjas, ⚓ Pirates, 🤖 Robots,
🐉 Dragons, 🦸 Superheroes, 👽 Aliens, 🦖 Dinosaurs.

**Total cash sink: $8,260,000** — roughly 74× the entire PC parts shop
($112,030), so it remains a goal long after the shop is maxed. The cheapest
unlock ($20,000) is reachable early, so there is a near goal as well as far ones.

### The live roll

`TrendsService` already refreshes trends every `TrendRefreshSeconds` (300s). When
it picks new trends it also rolls each cash unlock's current percentage within
its band. The roll is:

- **Global** — identical for every player in the server, exactly like trends.
  This keeps it fair and makes it broadcastable rather than per-player state.
- **Server-owned** — held in `TrendsService`, never sent by the client, and read
  directly by `DevelopmentService` when it computes a payout.
- **Broadcast for display only**, on the existing `TrendsUpdated` remote.

A known and intended consequence: because the roll is visible, players will time
releases for a good roll. That is the same "watch the board, time your release"
loop trends already create.

### Ceilings

- Two maxed cash unlocks on a lucky roll: **+56%**
- Both top Robux unlocks: **+70%**, guaranteed

Both are **additive**, never multiplicative, and sit well under the existing
stack (maxed PC parts alone are ≈2.9×). This is deliberate: the economy was
rebalanced twice in one session for exactly this class of mistake, and an
unbounded content multiplier would undo it.

The fair-advantage line holds: 99 Robux buys reliability at +30%, but a grinder
rolling well on tier 6 reaches +28% per slot and beats it on a good cycle. Only
the 199-Robux pair is strictly ahead, and every cash unlock is permanently
ownable by playing.

## Architecture

Follows the established pattern: pure data and maths in `GameData`
(unit-tested), server owns state and validation, client only renders.

### Changed files

- **`src/shared/GameData.luau`**
  - `Genres` and `Topics` extended to 12 each.
  - New `ContentUnlocks` table keyed by id:
    `{ kind = "genre"|"topic", price?, robuxProductKey?, minBonus, maxBonus, fixedBonus?, icon, order }`.
    Free entries are simply absent from this table.
  - `isContentFree(id)` — true when the id is not in `ContentUnlocks`.
  - `ownsContent(data, id)` — free entries are always owned.
  - `getContentBonus(data, id, rollTable)` — 0 for free/unowned; the fixed bonus
    for Robux entries; the current roll for cash entries.
  - `getReleaseContentMultiplier(data, genre, topic, rollTable)` →
    `1 + genreBonus + topicBonus`.
  - `rollContentBonuses(rng)` → a table of `id -> percentage`, used by
    `TrendsService` each cycle.
  - Two new `Products` entries per kind for the Robux unlocks, shipping with
    `id = 0` ("Coming soon") per the existing convention.
- **`src/server/TrendsService.luau`** — roll the bonus table alongside each trend
  refresh; expose `getContentRolls()`; include the rolls in `TrendsUpdated`.
- **`src/server/DevelopmentService.luau`** — reject a genre/topic the player does
  not own (it already rejects unknown ones), and fold
  `getReleaseContentMultiplier` into the cash grant only.
- **`src/server/ContentService.luau`** (new) — `RequestBuyContent` handler:
  validate the id, that it is a cash unlock, that the player does not already own
  it and can afford it; deduct, mark owned, save, push state.
- **`src/server/MonetizationService.luau`** — four Robux receipt branches (two
  genres, two topics), following the existing `id ~= 0` guard pattern.
- **`src/server/PlayerData.luau`** — `contentOwned = {}` (id → true), plus backfill.
- **`src/client/UI.luau`** — the genre/topic rows become 2×6 grids
  (`UIGridLayout`); locked entries render a padlock and price; owned paid entries
  show their live percentage; clicking a locked entry buys it.
- **`src/shared/Remotes.luau`** — `RequestBuyContent`.
- **`src/shared/Tests/RunTests.luau`** — assertions.

### Data flow

1. `TrendsService` rolls bonuses on each trend refresh and broadcasts them with
   the trends.
2. The client renders each button's lock state from `data.contentOwned` (already
   delivered by `PlayerStateUpdated`) and its live percentage from the broadcast.
3. Buying: client → `RequestBuyContent(id)` → server validates and deducts →
   `PlayerStateUpdated`.
4. Releasing: `DevelopmentService` reads the server's own roll table — never the
   client's — and applies the multiplier to cash.

## Error handling / edge cases

- **Server-authoritative throughout.** The client never sends a price, a bonus or
  a roll. A client claiming a high roll is ignored because the server reads its
  own table.
- **Unowned content is rejected at release**, not silently allowed at 0% — a
  player who somehow submits a locked genre gets the request refused, matching
  how unknown genres are already handled.
- **No `loadFailed` guard on the cash purchase** (game cash, must work in Studio),
  consistent with quests/challenges/event/daily.
- **The Robux unlocks keep** the existing save-before-acknowledge rule in
  `ProcessReceipt`.
- **Buying something already owned** is refused before any deduction.
- **A player mid-release when the roll changes** uses the roll captured at the
  moment the payout is computed. Rolls change every 5 minutes and a release is
  far shorter, so this is not worth locking.
- **Free entries never appear in `ContentUnlocks`**, so they can never be
  accidentally priced or bonused.

## Testing

- Unit assertions: both lists are 12 long with no duplicates; every entry has an
  icon; free entries are free, always owned, and always 0%; each paid entry's
  roll lands inside its band; Robux entries ignore the roll and return their
  fixed value; `getReleaseContentMultiplier` adds the two and returns 1.0 for two
  free picks; the ceiling (two tier-6 max rolls = 1.56, two top Robux = 1.70);
  an unowned paid entry contributes 0.
- Studio playtest: the 2×6 grids render without clipping; a locked entry shows
  its price and buys correctly; cash is deducted exactly once; the percentage on
  a button changes when trends refresh; a released game's payout reflects the
  bonus.

## Out of scope (YAGNI)

- No refunds, no re-rolling on demand, no per-player rolls.
- No bonus to subscribers — cash only, to keep the ceiling legible.
- No bundle discount for buying several unlocks.
- The Robux product IDs are created by the user in Roblox; this ships with
  `id = 0`.

## Known constraint

**Robux purchases cannot be tested while `FRESH_START_NO_SAVING = true`** in
`PlayerData.luau` — the grant is gated on a successful save. The cash unlocks are
fully testable with it on.
