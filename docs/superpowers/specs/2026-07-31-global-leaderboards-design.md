# M9 (Round 1) — Global Leaderboards Design Spec

**Goal:** Turn the 4 in-world beach leaderboards from per-server (only ranks players currently in your server, resets as people leave) into **global, persistent** rankings across every server — each board auto-flipping between a **This Week** view (progress made this week) and an **All-Time** view (grand totals), and showing the local player their own standing.

**Architecture:** A new server module `GlobalLeaderboardService` owns Roblox **OrderedDataStores** (the built-in tool for global rankings) — one all-time store and one week-keyed store per stat. It runs a periodic writer (push each player's numbers) and a periodic reader (pull the top 100 per board into a cache). The existing `LeaderboardService` stops scanning in-server players and renders a **top-10 teaser** from that cache with an auto-flipping This-Week/All-Time header. A new client `LeaderboardPanel` shows the **full scrollable top 100** with stat + period tabs and the player's personal standing. Per-player "this week" progress is tracked as a small accumulator in `PlayerData` that resets when the week index rolls over.

**Tech Stack:** Roblox / Luau, Rojo, `DataStoreService:GetOrderedDataStore`, existing `LeaderboardService` / `PlayerData` / `DevelopmentService` / `PlotManager`, `RunTests` unit tests.

## Global Constraints

- **Studio can't run this.** OrderedDataStores require a published server (API access is off in Studio) and there is no cross-server data in Studio. Everything must **no-op gracefully** in Studio: wrap every DataStore call in `pcall`, and when data is unavailable show a friendly placeholder (`🌍 Global rankings appear in the live game`) — never an error, never a blank crash. Real global behaviour is verified only after publishing.
- **Never break the game on a DataStore failure.** Every read/write is `pcall`-guarded; on failure keep the last-good cached data (or the placeholder) and carry on. A throttled/failed DataStore call must not stall joins, saves, or the render loop.
- **Respect DataStore limits.** Stagger/bound reads and writes so the service stays well under Roblox request budgets (see Data flow). No per-frame DataStore calls.
- **Additive & backward-compatible.** New `PlayerData` fields get safe defaults + migration backfill; existing saves load unchanged. The 4 existing boards, their positions, and the "Go to Leaderboards" teleport button are preserved.
- **No new Robux/monetization surface** — this is a retention/social feature only. `GameData.StartingCash` stays `0`.

## The four stats

Unchanged set; weekly meaning is "gained since the week started", all-time is the grand total.

| Board | All-Time value | This-Week value (gained this week) |
|-------|----------------|------------------------------------|
| ⭐ Top Prestige | `prestigeLevel` | prestige levels gained this week |
| 🏆 Most Subscribers | `subscribers` | subscribers gained this week |
| 💰 Richest | current `cash` | **cash earned** this week (sum of positive gains, not net) |
| 🎮 Most Games | `gamesReleased` | games shipped this week |

Rationale: subs/games/prestige only ever rise, so an all-time-valued weekly board would look identical to all-time — weekly must rank *deltas*. Cash is spendable, so weekly tracks **earned** (positive gains only), and all-time keeps ranking current cash (matches today's "Richest" board).

## Component 1 — Week tracking in PlayerData

- New fields (with defaults + migration backfill):
  - `weekAnchor` (number) — the week index the `weekly` tally belongs to; default = current week index at first load.
  - `weekly` (table) — `{ prestigeLevel = 0, subscribers = 0, cash = 0, gamesReleased = 0 }`; default all zeros.
- `GameData.getWeekIndex(now)` → `math.floor(now / 604800)` (weeks since Unix epoch; `now` = `os.time()` / `DateTimeValue`). Pure, unit-tested.
- `PlayerData.rolloverWeekIfNeeded(data, now)` — if `GameData.getWeekIndex(now) ~= data.weekAnchor`, reset `data.weekly` to zeros and set `data.weekAnchor` to the current index. Called on join (after load) and defensively before each weekly write.
- `PlayerData.addWeekly(data, stat, delta)` — if `delta > 0`, `data.weekly[stat] += delta` (after a rollover check). Called wherever a stat increases.

## Component 2 — Hooking stat increases

At each existing point where a tracked stat rises, also call `PlayerData.addWeekly(data, stat, delta)`:
- **Subscribers** — where subs are credited (DevelopmentService release path / any sub gain).
- **Games** — where `gamesReleased` increments on a successful release.
- **Cash** — where cash is credited from active play + idle income (DevelopmentService payout, PlotManager idle loop, lounge, milestones). Only positive gains count; spending does not decrement the weekly earned tally.
- **Prestige** — where `prestigeLevel` increases on rebirth.

Where a single existing helper already centralizes a credit (e.g. cash), hook it once there rather than at every call site.

## Component 3 — GlobalLeaderboardService (new)

Owns storage, the writer, the reader, and a userId→name cache.

- **Stores** (via `DataStoreService:GetOrderedDataStore(name)`), per stat `S`:
  - All-time: `GetOrderedDataStore("LB_all_" .. S)`
  - Weekly: `GetOrderedDataStore("LB_wk_" .. S .. "_" .. weekIndex)` — the week index in the name makes each new week a fresh empty board automatically; old weeks are simply never read again (no cleanup job).
  - Entry: key = `tostring(userId)`, value = the (floored, non-negative) number.
- **Writer loop** (`task.spawn` + `task.wait(WRITE_SECONDS)`, `WRITE_SECONDS = 60`): for each in-server player, `rolloverWeekIfNeeded`, then `SetAsync` the 4 all-time values and 4 weekly values (each in its own `pcall`). Also flush a player's writes on `PlayerRemoving`.
- **Reader loop** (`task.wait(READ_SECONDS)`, `READ_SECONDS = 45`): for each of the 8 stores, `GetSortedAsync(false, 100)` → read one page (top 100) → build `{ userId, value }` rows → resolve names via the cache → store into `cache[stat][period] = rows`. All in `pcall`; on failure the previous cache stays.
- **Name cache:** `nameCache[userId]`; miss → `Players:GetNameFromUserIdAsync(userId)` in `pcall` (fallback `"Player" .. userId`); cache the result. Prefer names of currently-connected players from `Players`.
- **Public API:**
  - `GlobalLeaderboardService.getRows(stat, period)` → cached `{ {name, value, userId}, ... }` up to **100** rows, or `nil` if unavailable. The world board slices the first 10; the client panel shows the full list.
  - `GlobalLeaderboardService.getSelfStanding(player, stat, period)` → `{ rank = n, value = v }` if the player's userId is within the pulled top-100 rows, else `{ rank = nil, value = v }` where `v` is that player's current live value (from their loaded data). Exact rank beyond top 100 is intentionally not computed (OrderedDataStore has no cheap arbitrary-rank query).
  - `GlobalLeaderboardService.start()` — launches writer + reader loops.
- **Studio / unavailable:** if a probe `SetAsync`/`GetSortedAsync` throws (Studio API off) or a store returns nothing, `getRows` returns `nil` and the board renders the placeholder. No retry storm — just try again next loop tick.

## Component 4 — LeaderboardService display changes

- Keep `build()` geometry (rock, 4 boards, headers, teleport). 
- Remove the in-server player scan; each refresh, for each board `i` (stat `S`):
  - Determine the board's **current period** from a toggle clock: `period = (math.floor(now / FLIP_SECONDS) % 2 == 0) and "week" or "all"`, `FLIP_SECONDS = 10` — so all boards flip together every 10s. Header text reflects it: `🗓️ This Week — <title>` or `🏆 All-Time — <title>`.
  - `rows = GlobalLeaderboardService.getRows(S, period)`. If `nil` → show the placeholder text. Else render the **top 10** as `#rank  name  formattedValue` (reuse each stat's existing `format`).
  - The world boards are one shared SurfaceGui seen by everyone, so they render **only** the top 10 + period header — a per-player "You:" line cannot live on a shared board. The full top 100 and the personal standing live in the client panel (Component 5).
- Refresh cadence stays ~12s (`REFRESH_SECONDS`), independent of the service's 45s data pull (it just re-reads the cache + current toggle).

## Component 5 — Client Leaderboards panel (full top 100, scrollable)

A new client-side popup that shows the complete rankings, opened from the existing "Go to Leaderboards" button (the button now both teleports to the boards and opens this panel; keep it one tap — open the panel, teleport optional).

- **Layout:** a themed panel (reuse `StorePanel`/existing popup styling + `MobileScale`) with:
  - **Stat tabs/picker** across the top — ⭐ Prestige / 🏆 Subscribers / 💰 Richest / 🎮 Games.
  - **Period tabs** — 🗓️ This Week / 🏆 All-Time.
  - A **`ScrollingFrame`** listing the **top 100** rows (`#rank  name  formattedValue`, `AutomaticCanvasSize = Y`, `UIListLayout`), the local player's row highlighted if present.
  - A pinned **"You:" header** above the list: `You: #37 — 1,240` (in top 100) or `You: 1,240 — climb into the top 100!` (below), from `getSelfStanding`.
  - Placeholder state (`🌍 Global rankings appear in the live game`) when rows are `nil` (Studio / unavailable).
- **Data:** client sends `RequestLeaderboardData(stat, period)` on open and on any tab change (debounced); server responds `LeaderboardData(stat, period, rows, selfStanding)` from the service cache (up to 100 rows). No new DataStore reads per request — it's served from the cached pull.

## Data & files

```
src/shared/GameData.luau            -- + getWeekIndex(now); leaderboard stat config (keys, store-name stems)
src/shared/Tests/RunTests.luau      -- + week-index, rollover-reset, addWeekly-positive-only, formatting tests
src/server/PlayerData.luau          -- + weekAnchor/weekly defaults + migration; rolloverWeekIfNeeded; addWeekly
src/server/GlobalLeaderboardService.luau  -- CREATE: OrderedDataStore storage, writer + reader loops, name cache, getRows/getSelfStanding
src/server/LeaderboardService.luau  -- MODIFY: render top-10 teaser from cache, add week/all toggle + period header, drop in-server scan
src/server/DevelopmentService.luau  -- + addWeekly on subs/games/cash gains
src/server/PlotManager.luau         -- + addWeekly on idle cash (+ prestige on rebirth if it lives here)
src/shared/Remotes.luau             -- + "RequestLeaderboardData" + "LeaderboardData"
src/client/LeaderboardPanel.luau    -- CREATE: scrollable top-100 panel (stat + period tabs, "You:" header); opened from Go-to-Leaderboards button
src/server/init.server.luau         -- start GlobalLeaderboardService; wire RequestLeaderboardData -> LeaderboardData from cache
```

## Data flow

```
Stat rises (subs/games/cash/prestige) -> PlayerData.addWeekly(data, stat, delta)   [weekly tally]
Writer loop (60s) + PlayerRemoving  -> rolloverWeekIfNeeded -> SetAsync all-time + weekly stores (pcall each)
Reader loop (45s) -> GetSortedAsync(top 100) x8 -> resolve names -> cache[stat][period]; compute self-standings
Board refresh (12s) -> pick period by 10s flip clock -> getRows(stat, period) -> render top-10 teaser or placeholder
Open panel / change tab -> RequestLeaderboardData(stat, period) -> LeaderboardData(rows<=100, selfStanding) -> scrollable top 100 + "You: #N - value" (or "climb into top 100!")
New week -> week index in weekly store name changes -> fresh empty weekly board; players' weekly tallies reset on next rollover check
```

## Testing

- **Unit (`RunTests.luau`):** `getWeekIndex` (monotonic, changes every 604800s, stable within a week); `rolloverWeekIfNeeded` resets `weekly` to zeros and updates `weekAnchor` only when the index changes; `addWeekly` adds positive deltas and ignores `<= 0`; value formatting/commas for each stat. (All pure — no DataStore.)
- **Studio playtest:** boards build, don't error, and show the `🌍 Global rankings appear in the live game` placeholder (DataStore off); the toggle clock flips headers between This Week / All-Time every ~10s; the Leaderboards panel opens, its stat/period tabs switch, and its top-100 list **scrolls** (showing the placeholder since data is unavailable in Studio); the "Go to Leaderboards" teleport still works; joining/leaving throws no errors from the writer/reader loops.
- **Compile check** after each change: `./rojo-bin/rojo build default.project.json -o /tmp/x.rbxl`.
- **Live (post-publish, user):** across real servers, values populate; weekly board shows this-week gains and resets on the week boundary; all-time accumulates; the personal "You:" line matches.

## Non-goals (YAGNI)

- No exact global rank below the top 100 (OrderedDataStore has no cheap arbitrary-rank query).
- No new physical boards, no per-board manual switch button (auto-flip only), no monetized boosts to ranking.
- No historical weekly archives / "last week's winners" hall (old weekly stores just fade); could be a later add.
- No anti-cheat/validation of stored values beyond flooring to a non-negative integer (values come from server-authoritative PlayerData already).
- The other M9 social features (visit friends' studios, share wins + invite, referral rewards) are separate later rounds, each with its own spec.
