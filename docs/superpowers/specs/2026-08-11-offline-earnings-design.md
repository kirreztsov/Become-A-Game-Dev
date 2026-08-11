# Offline Earnings (Roadmap B3) — Design

**Date:** 2026-08-11
**Roadmap:** Post-v1 Pre-Public Polish, Phase B (Retention), item B3.
**Status:** Approved design, ready for implementation plan.

## Goal

Give players a reason to come back tomorrow: while they are logged off, their
studio keeps earning a reduced trickle of cash. On their next join they see a
"Welcome back — you earned $X while away" popup and collect it. This ticks the
Ready-to-Launch gate item "at least one come-back-tomorrow hook beyond daily
reward."

## Player-facing behaviour

- Log off with owned money rooms (Arcade / Merch). Come back later.
- On join, a popup appears: **"Welcome back! You earned $12,400 while away (1h 47m)."**
  with a **Collect** button and a coin-burst celebration (reuse `Fx`).
- Pressing Collect adds the cash to the wallet and closes the popup.
- If the player owns no earning rooms, or was away only a few seconds, no popup
  shows (nothing meaningful was earned).

## Balance

- **Offline rate = 50%** of the player's normal per-second room income.
  Active play stays clearly better than being away.
- **Base cap = 2 hours.** Being away longer than the cap still only pays the
  cap's worth — a nudge to return, not an AFK farm.
- **The cap is upgradeable via a new rebirth perk** (`p_offline`, +1h per level),
  so long-term players can extend it. See "Perk integration".

### Rate formula

```
ratePerSec  = 0.5 * Σ IDLE_RATES[room]  (for each room the player owns)
             * prestigeMult             (GameData.getPrestigeMultiplier)
             * passCashMult             (GameData.getPassCashMultiplier — e.g. 2x Cash pass)
capSeconds  = 3600 * (2 + PerkData.offlineCapBonusHours(data))
elapsed     = clamp(os.time() - data.lastOnline, 0, capSeconds)
offlineCash = floor(ratePerSec * elapsed)
```

Notes:
- `IDLE_RATES` (per-second, already in `PlotManager`) is the single source of
  truth for room income; offline reuses it so the two systems can never drift.
- **Transient boosts are intentionally excluded** — a timed Mega Boost would have
  expired while the player was away, so it must not multiply offline cash.
  Prestige multiplier and the permanent Cash pass DO apply (they are permanent,
  matching the active idle loop).
- Rooms the player does not own contribute nothing.

## Data flow

1. **Stamp on save.** Every time `PlayerData.save(player)` runs, and on
   `PlayerRemoving`, write `data.lastOnline = os.time()`. (Save already fires
   periodically and on leave, so this keeps the timestamp fresh.)
2. **Compute on join.** A new server module `OfflineEarnings` listens for a
   player whose data has loaded (mirroring how `ChallengeService` waits for
   data). It reads `data.lastOnline`, computes `offlineCash` with the formula
   above, and — if `offlineCash > 0` — fires a remote to the client with the
   amount and the elapsed seconds. The cash is **not** granted yet; it is granted
   on Collect (server-authoritative).
3. **Collect.** The client Collect button fires `CollectOfflineEarnings`. The
   server grants the pending cash it computed at join, advances `lastOnline` to
   now, saves, and fires `PlayerStateUpdated`.

   To keep this exploit-proof and simple: the server computes the pending amount
   once at join, stores it in a per-session table keyed by player, and Collect
   just grants that stored amount (then clears it). The client-sent value is
   ignored entirely. This avoids any re-derivation drift and any double-collect.

### First-ever join / missing timestamp

If `data.lastOnline` is nil (brand-new player, or an existing save from before
this feature), treat it as "no offline time" — set `lastOnline = os.time()` and
show no popup. Backfill the field in `PlayerData` defaults so it is always
present after the first save.

## Perk integration (extends the A4 perk tree)

Add one perk to `PerkData.PERKS`:

```
{ id = "p_offline", name = "Deep Sleep", desc = "+1h offline earnings cap",
  icon = "😴", kind = "offlineCap", value = 1, maxLevel = 6, cost = 1 }
```

- New pure helper `PerkData.offlineCapBonusHours(data)` = `level("p_offline") * value`
  (0–6 hours), so base 2h + perk = up to 8h.
- `PerkPanel` renders every entry in `PerkData.PERKS` already, so the new perk
  appears in the Perks panel with no UI change.
- `kind = "offlineCap"` is inert in the economy hooks (cashMult/subsMult/etc.),
  so it only affects the offline cap — no accidental economy interaction.
- Unit-test the new helper in `RunTests` alongside the existing perk assertions.

## New / changed pieces

- `PlayerData`: new default `lastOnline = 0` (+ backfill in the loader).
- `PlayerData.save` + `PlayerRemoving` path: stamp `lastOnline = os.time()`.
- `src/server/OfflineEarnings.luau` (new): join compute + pending-store +
  `CollectOfflineEarnings` handler + cash grant + save + `PlayerStateUpdated`.
  Started from `init.server`.
- `src/shared/PerkData.luau`: `p_offline` perk + `offlineCapBonusHours`.
- `Remotes`: `OfflineEarningsReady` (server→client: amount, seconds),
  `CollectOfflineEarnings` (client→server).
- `src/client/OfflineWelcome.luau` (new): the Welcome-back popup (amount +
  elapsed formatted "Xh Ym" + Collect button + `Fx` coin burst). Listens for
  `OfflineEarningsReady`; on Collect fires `CollectOfflineEarnings`. Reuses the
  white-card theme + `MobileScale`-compatible layout like the other panels.
- Expose the offline per-second rate: add a small `PlotManager` accessor (or a
  shared helper) that returns `Σ IDLE_RATES[owned]` so `OfflineEarnings` reads
  the same numbers the idle loop uses, without duplicating the rate table.
- `RunTests`: assertions for `offlineCapBonusHours` and the offline-cash formula
  (rate, cap clamp, zero-when-no-rooms).

## Edge cases

- **Clock going backwards / negative elapsed:** clamped to 0 → no payout.
- **Studio (DataStore off):** `lastOnline` still works via `os.time()`; save
  no-ops on failed load, so it just won't persist that session. The popup and
  Collect still function for playtesting (game cash, like quests/challenges).
- **Owns rooms but rate is 0 after prestige reset of rooms:** `roomsOwned`
  persists through prestige, so rate is preserved; if somehow empty, payout is 0
  and no popup shows.
- **Double-collect:** prevented by the per-session pending-store being cleared on
  Collect; a second Collect finds nothing and no-ops.

## Out of scope (YAGNI)

- No offline earning from active game releases (only the passive room income).
- No offline progress on quests/challenges (those are live-derived).
- No "watch an ad / pay Robux to double offline earnings" — could be a later
  monetization item (Phase D), not now.
