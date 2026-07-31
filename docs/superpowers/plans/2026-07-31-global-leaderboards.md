# Global Leaderboards (M9 Round 1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the 4 per-server beach leaderboards into global, persistent rankings — world boards show a top-10 teaser that auto-flips between This Week / All-Time, and a new client panel shows the full scrollable top 100 with each player's own standing.

**Architecture:** A new server module `GlobalLeaderboardService` owns Roblox OrderedDataStores (one all-time store + one week-keyed store per stat), with a periodic writer (push each player's numbers) and reader (pull top 100 into a cache). `LeaderboardService` renders a top-10 teaser from that cache with a flip header. A new client `LeaderboardPanel` shows the scrollable top 100. Per-player "this week" gains live in a small `PlayerData.weekly` accumulator that resets on week rollover. Shared config + pure helpers live in `GameData` so server and client agree and are unit-testable.

**Tech Stack:** Roblox / Luau, Rojo, `DataStoreService:GetOrderedDataStore`, existing `LeaderboardService` / `PlayerData` / `DevelopmentService` / `PlotManager` / `UI`, `RunTests` (`src/shared/Tests/RunTests.luau`, `TestHarness:assertEqual`).

## Global Constraints

- **Studio can't run OrderedDataStores.** Every DataStore call is wrapped in `pcall`; on failure or empty data, `getRows` returns `nil` and the UI shows the placeholder `🌍 Global rankings appear in the live game`. Never error, never blank-crash. Real ranking is verified only after publishing.
- **Never break the game on a DataStore failure.** A throttled/failed call must not stall joins, saves, the writer/reader loops, or rendering — keep last-good cache and continue.
- **Respect DataStore limits.** `WRITE_SECONDS = 60`, `READ_SECONDS = 45`. No per-frame DataStore calls.
- **Additive & backward-compatible.** New `PlayerData` fields default safely + backfill on load; existing saves load unchanged. The 4 boards, their positions, and the "Go to Leaderboards" teleport are preserved.
- **All-time boards rank current values** (`prestigeLevel`, `subscribers`, `cash`, `gamesReleased`) — same semantics as today's boards, now global. (Lifetime-that-survives-rebirth counters are a deliberate later enhancement, not in this plan.)
- **Weekly boards rank gains made this week**, credited only on positive gains at the main earning paths; spending never decrements a weekly tally.
- `GameData.StartingCash` stays `0`. No new Robux/monetization surface.
- **Verification is `rojo build` + Studio playtest** (no CI). Unit tests live in `RunTests.luau` and execute inside Studio; the implementer verifies compile with `./rojo-bin/rojo build default.project.json -o /tmp/x.rbxl` and confirms tests parse.

## File Structure

```
src/shared/GameData.luau            -- MODIFY: getWeekIndex, LeaderboardStats config, store-name helper, computeStanding (pure)
src/shared/Tests/RunTests.luau      -- MODIFY: tests for the pure helpers above + PlayerData weekly helpers
src/server/PlayerData.luau          -- MODIFY: weekAnchor/weekly defaults + backfill; rolloverWeekIfNeeded; addWeekly
src/shared/Remotes.luau             -- MODIFY: + "RequestLeaderboardData", "LeaderboardData"
src/server/GlobalLeaderboardService.luau  -- CREATE: OrderedDataStore storage, writer/reader loops, name cache, getRows/getSelfStanding/start
src/server/DevelopmentService.luau  -- MODIFY: addWeekly on game-release cash + gamesReleased
src/server/PlotManager.luau         -- MODIFY: addWeekly on subscribers, idle/room/ad cash, prestige
src/server/LeaderboardService.luau  -- MODIFY: render top-10 teaser from cache + flip header; drop in-server scan
src/server/init.server.luau         -- MODIFY: start GlobalLeaderboardService; wire RequestLeaderboardData -> LeaderboardData
src/client/LeaderboardPanel.luau    -- CREATE: scrollable top-100 panel (stat + period tabs, "You:" header)
src/client/UI.luau                  -- MODIFY: Go-to-Leaderboards button also opens the panel; init the panel
```

---

### Task 1: GameData — week index, leaderboard config, pure standing helper

**Files:**
- Modify: `src/shared/GameData.luau` (add functions/config near the end, before `return GameData`)
- Test: `src/shared/Tests/RunTests.luau`

**Interfaces:**
- Produces:
  - `GameData.getWeekIndex(now: number) -> number` — `math.floor(now / 604800)`
  - `GameData.LeaderboardStats` — ordered array of `{ key: string, title: string, accent: Color3, format: (number)->string }` for keys `"prestigeLevel"`, `"subscribers"`, `"cash"`, `"gamesReleased"`
  - `GameData.leaderboardStoreName(period: "all"|"week", key: string, weekIndex: number) -> string`
  - `GameData.computeStanding(rows: {{userId:number, value:number, name:string}}, userId: number, liveValue: number) -> {rank: number?, value: number}`

- [ ] **Step 1: Write the failing tests** — append just above the final `t:summary()` line in `src/shared/Tests/RunTests.luau`:

```lua
-- Global leaderboards: week index
t:assertEqual(GameData.getWeekIndex(0), 0, "week index at epoch is 0")
t:assertEqual(GameData.getWeekIndex(604799), 0, "week index stable within a week")
t:assertEqual(GameData.getWeekIndex(604800), 1, "week index rolls at the 7-day boundary")
t:assertEqual(GameData.getWeekIndex(604800 * 5 + 10), 5, "week index counts whole weeks")

-- Global leaderboards: store names
t:assertEqual(GameData.leaderboardStoreName("all", "cash", 5), "LB2_all_cash", "all-time store name ignores week")
t:assertEqual(GameData.leaderboardStoreName("week", "cash", 5), "LB2_wk_cash_5", "weekly store name includes the week index")

-- Global leaderboards: config
t:assertEqual(#GameData.LeaderboardStats, 4, "there are four leaderboard stats")
t:assertEqual(GameData.LeaderboardStats[1].key, "prestigeLevel", "first board is prestige")
t:assertEqual(GameData.LeaderboardStats[3].format(1234), "$1,234", "richest formats with a dollar sign + commas")
t:assertEqual(GameData.LeaderboardStats[2].format(1000000), "1,000,000", "subscribers formats with commas")

-- Global leaderboards: computeStanding
local sRows = { { userId = 11, value = 90, name = "A" }, { userId = 22, value = 80, name = "B" } }
t:assertEqual(GameData.computeStanding(sRows, 22, 80).rank, 2, "standing finds the player's rank in the rows")
t:assertEqual(GameData.computeStanding(sRows, 22, 80).value, 80, "standing reports the ranked value")
t:assertEqual(GameData.computeStanding(sRows, 99, 5).rank, nil, "not in rows -> no rank")
t:assertEqual(GameData.computeStanding(sRows, 99, 5).value, 5, "not in rows -> falls back to live value")
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `./rojo-bin/rojo build default.project.json -o /tmp/x.rbxl` then run `RunTests` in Studio (or note: cannot run in this env — the new `GameData.*` symbols are `nil`, so these assertions would FAIL/error).
Expected: FAIL — `getWeekIndex`/`LeaderboardStats`/etc. are undefined.

- [ ] **Step 3: Implement in `src/shared/GameData.luau`** (add just before `return GameData`):

```lua
-- ===== Global leaderboards =====
local SECONDS_PER_WEEK = 7 * 24 * 60 * 60 -- 604800

function GameData.getWeekIndex(now)
	return math.floor((now or 0) / SECONDS_PER_WEEK)
end

local function lbCommas(n)
	local s = tostring(math.floor(n or 0))
	return (s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

-- Ordered list; index order == board order on the beach + tab order in the panel.
GameData.LeaderboardStats = {
	{ key = "prestigeLevel", title = "\226\173\144 Top Prestige",   accent = Color3.fromRGB(150, 92, 255), format = function(v) return "P" .. lbCommas(v) end },
	{ key = "subscribers",   title = "\240\159\143\134 Most Subscribers", accent = Color3.fromRGB(224, 72, 96),  format = function(v) return lbCommas(v) end },
	{ key = "cash",          title = "\240\159\146\176 Richest",     accent = Color3.fromRGB(255, 209, 102), format = function(v) return "$" .. lbCommas(v) end },
	{ key = "gamesReleased", title = "\240\159\142\174 Most Games",  accent = Color3.fromRGB(140, 200, 120), format = function(v) return lbCommas(v) end },
}

function GameData.leaderboardStoreName(period, key, weekIndex)
	if period == "week" then
		return "LB2_wk_" .. key .. "_" .. tostring(weekIndex)
	end
	return "LB2_all_" .. key
end

-- rows: array of { userId, value, name } already sorted descending.
-- Returns { rank = n or nil, value = n }. rank is nil when the player is not
-- present in the (top-100) rows; value then falls back to their live value.
function GameData.computeStanding(rows, userId, liveValue)
	for i, row in ipairs(rows or {}) do
		if row.userId == userId then
			return { rank = i, value = row.value }
		end
	end
	return { rank = nil, value = liveValue or 0 }
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `./rojo-bin/rojo build default.project.json -o /tmp/x.rbxl` (must print `Built project to x.rbxl`); the added assertions PASS when `RunTests` runs in Studio.
Expected: compiles; assertions PASS.

- [ ] **Step 5: Commit**

```bash
git add src/shared/GameData.luau src/shared/Tests/RunTests.luau
git commit -m "feat(leaderboards): week index, stat config, standing helper"
```

---

### Task 2: PlayerData — weekly gain accumulator

**Files:**
- Modify: `src/server/PlayerData.luau` (defaults in `defaultData()` ~lines 64-67; backfill in `load()` ~lines 105-111; new functions before `return PlayerData`)
- Test: `src/shared/Tests/RunTests.luau`

**Interfaces:**
- Consumes: `GameData.getWeekIndex(now)` (Task 1).
- Produces:
  - `data.weekAnchor: number`, `data.weekly: { prestigeLevel:number, subscribers:number, cash:number, gamesReleased:number }`
  - `PlayerData.rolloverWeekIfNeeded(data, now) -> nil` — resets `data.weekly` to zeros and sets `data.weekAnchor = getWeekIndex(now)` when the week index changed.
  - `PlayerData.addWeekly(data, stat, delta, now) -> nil` — rolls over first, then if `delta > 0` and `data.weekly[stat]` exists, `data.weekly[stat] += math.floor(delta)`.

- [ ] **Step 1: Write the failing tests** — append just above the final `t:summary()` in `src/shared/Tests/RunTests.luau`:

```lua
-- PlayerData weekly accumulator (pure table logic)
local PlayerData = require(game:GetService("ServerScriptService").Server.PlayerData)
local wd = { weekAnchor = 0, weekly = { prestigeLevel = 0, subscribers = 0, cash = 0, gamesReleased = 0 } }
PlayerData.addWeekly(wd, "cash", 100, 10)           -- same week (index 0)
t:assertEqual(wd.weekly.cash, 100, "addWeekly adds a positive gain")
PlayerData.addWeekly(wd, "cash", -50, 10)           -- negative ignored
t:assertEqual(wd.weekly.cash, 100, "addWeekly ignores non-positive deltas")
PlayerData.addWeekly(wd, "subscribers", 5, 10)
t:assertEqual(wd.weekly.subscribers, 5, "addWeekly tracks each stat independently")
PlayerData.addWeekly(wd, "cash", 25, 604800 + 1)    -- new week -> reset then add
t:assertEqual(wd.weekly.cash, 25, "a new week resets the tally before adding")
t:assertEqual(wd.weekly.subscribers, 0, "new week zeroes every stat")
t:assertEqual(wd.weekAnchor, 1, "week anchor advances to the new week index")
PlayerData.addWeekly(wd, "bogusStat", 10, 604800 + 2)  -- unknown stat is a no-op
t:assertEqual(wd.weekly.cash, 25, "unknown stat does not corrupt the tally")
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `./rojo-bin/rojo build default.project.json -o /tmp/x.rbxl`.
Expected: FAIL — `PlayerData.addWeekly` is `nil`.

- [ ] **Step 3a: Add defaults** in `src/shared/... ` — in `src/server/PlayerData.luau` `defaultData()`, add these fields inside the returned table (right after `starterPackBought = false,`):

```lua
		-- Global-leaderboard "this week" gains (reset on week rollover) and the
		-- week index they belong to.
		weekAnchor = require(game.ReplicatedStorage.Shared.GameData).getWeekIndex(os.time()),
		weekly = { prestigeLevel = 0, subscribers = 0, cash = 0, gamesReleased = 0 },
```

- [ ] **Step 3b: Add backfill** in `load()`, right after the `data.starterPackBought` backfill block (~line 111):

```lua
				local GameDataMod = require(game.ReplicatedStorage.Shared.GameData)
				if data.weekAnchor == nil then
					data.weekAnchor = GameDataMod.getWeekIndex(os.time())
				end
				if type(data.weekly) ~= "table" then
					data.weekly = { prestigeLevel = 0, subscribers = 0, cash = 0, gamesReleased = 0 }
				else
					data.weekly.prestigeLevel = data.weekly.prestigeLevel or 0
					data.weekly.subscribers = data.weekly.subscribers or 0
					data.weekly.cash = data.weekly.cash or 0
					data.weekly.gamesReleased = data.weekly.gamesReleased or 0
				end
```

- [ ] **Step 3c: Add the helpers** before `return PlayerData`:

```lua
local GameData = require(game.ReplicatedStorage.Shared.GameData)

-- Reset this-week gains when a new week has started.
function PlayerData.rolloverWeekIfNeeded(data, now)
	local wk = GameData.getWeekIndex(now)
	if data.weekAnchor ~= wk then
		data.weekAnchor = wk
		data.weekly = { prestigeLevel = 0, subscribers = 0, cash = 0, gamesReleased = 0 }
	end
end

-- Credit a positive gain toward this week's leaderboard tally.
function PlayerData.addWeekly(data, stat, delta, now)
	if not data then return end
	PlayerData.rolloverWeekIfNeeded(data, now)
	if delta and delta > 0 and data.weekly[stat] ~= nil then
		data.weekly[stat] += math.floor(delta)
	end
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `./rojo-bin/rojo build default.project.json -o /tmp/x.rbxl` (must print `Built project to x.rbxl`); assertions PASS in Studio.

- [ ] **Step 5: Commit**

```bash
git add src/server/PlayerData.luau src/shared/Tests/RunTests.luau
git commit -m "feat(leaderboards): PlayerData weekly gain accumulator"
```

---

### Task 3: Remotes — leaderboard data channel

**Files:**
- Modify: `src/shared/Remotes.luau` (the `REMOTE_NAMES` list, ~lines 4-42)

**Interfaces:**
- Produces: `Remotes.RequestLeaderboardData` (client→server: `stat, period`), `Remotes.LeaderboardData` (server→client: `stat, period, rows, standing`).

- [ ] **Step 1: Add the two names** to `REMOTE_NAMES` in `src/shared/Remotes.luau`, right after `"RequestSetSkin",`:

```lua
	"RequestLeaderboardData",
	"LeaderboardData",
```

- [ ] **Step 2: Compile check**

Run: `./rojo-bin/rojo build default.project.json -o /tmp/x.rbxl`
Expected: `Built project to x.rbxl`.

- [ ] **Step 3: Commit**

```bash
git add src/shared/Remotes.luau
git commit -m "feat(leaderboards): RequestLeaderboardData + LeaderboardData remotes"
```

---

### Task 4: GlobalLeaderboardService (new)

**Files:**
- Create: `src/server/GlobalLeaderboardService.luau`

**Interfaces:**
- Consumes: `GameData.LeaderboardStats`, `GameData.getWeekIndex`, `GameData.leaderboardStoreName`, `GameData.computeStanding` (Task 1); `PlayerData.get`, `PlayerData.rolloverWeekIfNeeded` (Task 2).
- Produces:
  - `GlobalLeaderboardService.getRows(statKey, period) -> {{name, value, userId}} | nil` (up to 100, sorted desc; `nil` if unavailable)
  - `GlobalLeaderboardService.getSelfStanding(player, statKey, period) -> { rank: number?, value: number }`
  - `GlobalLeaderboardService.start() -> nil` (launches writer + reader loops)
  - `GlobalLeaderboardService.flush(player) -> nil` (write one player's values now; called on leave)

- [ ] **Step 1: Create `src/server/GlobalLeaderboardService.luau`**:

```lua
-- Global, cross-server leaderboards backed by OrderedDataStores.
-- One all-time store + one week-keyed store per stat. A writer loop pushes each
-- player's current values (+ this-week gains); a reader loop pulls the top 100
-- into a cache the boards + client panel read from. All DataStore calls are
-- pcall-guarded: in Studio (API off) or on failure, getRows returns nil and the
-- UI shows a placeholder. Never errors the game.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local GameData = require(game.ReplicatedStorage.Shared.GameData)
local PlayerData = require(script.Parent.PlayerData)

local GlobalLeaderboardService = {}

local WRITE_SECONDS = 60
local READ_SECONDS = 45
local PAGE = 100

-- cache[statKey][period] = { {name, value, userId}, ... }  (nil until first good read)
local cache = {}
local nameCache = {}

local function getStore(period, key)
	local weekIndex = GameData.getWeekIndex(os.time())
	local name = GameData.leaderboardStoreName(period, key, weekIndex)
	local ok, store = pcall(function()
		return DataStoreService:GetOrderedDataStore(name)
	end)
	if ok then
		return store
	end
	return nil
end

local function valueFor(data, period, key)
	if period == "week" then
		return (data.weekly and data.weekly[key]) or 0
	end
	return data[key] or 0
end

-- Write one player's 8 values (4 stats x 2 periods). Each SetAsync in its own pcall.
local function writePlayer(player)
	local data = PlayerData.get(player)
	if not data then return end
	PlayerData.rolloverWeekIfNeeded(data, os.time())
	for _, stat in ipairs(GameData.LeaderboardStats) do
		for _, period in ipairs({ "all", "week" }) do
			local store = getStore(period, stat.key)
			if store then
				local v = math.max(0, math.floor(valueFor(data, period, stat.key)))
				pcall(function()
					store:SetAsync(tostring(player.UserId), v)
				end)
			end
		end
	end
end

function GlobalLeaderboardService.flush(player)
	writePlayer(player)
end

local function resolveName(userId)
	-- Prefer a connected player's display name.
	local plr = Players:GetPlayerByUserId(userId)
	if plr then
		nameCache[userId] = plr.DisplayName
		return plr.DisplayName
	end
	if nameCache[userId] then
		return nameCache[userId]
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	local resolved = (ok and name) or ("Player" .. userId)
	nameCache[userId] = resolved
	return resolved
end

-- Read the top 100 for one (period, stat) into the cache. Leaves the old cache
-- intact on failure.
local function readOne(period, stat)
	local store = getStore(period, stat.key)
	if not store then return end
	local ok, pages = pcall(function()
		return store:GetSortedAsync(false, PAGE)
	end)
	if not ok or not pages then return end
	local okPage, page = pcall(function()
		return pages:GetCurrentPage()
	end)
	if not okPage or not page then return end
	local rows = {}
	for _, entry in ipairs(page) do
		local userId = tonumber(entry.key)
		if userId then
			rows[#rows + 1] = { userId = userId, value = entry.value, name = resolveName(userId) }
		end
	end
	cache[stat.key] = cache[stat.key] or {}
	cache[stat.key][period] = rows
end

function GlobalLeaderboardService.getRows(statKey, period)
	local byStat = cache[statKey]
	if not byStat then return nil end
	return byStat[period] -- may be nil until first successful read
end

function GlobalLeaderboardService.getSelfStanding(player, statKey, period)
	local data = PlayerData.get(player)
	local live = 0
	if data then
		live = math.floor(valueFor(data, period, statKey))
	end
	local rows = GlobalLeaderboardService.getRows(statKey, period) or {}
	return GameData.computeStanding(rows, player.UserId, live)
end

function GlobalLeaderboardService.start()
	-- Writer: push everyone's numbers on a timer, and on leave.
	task.spawn(function()
		while true do
			task.wait(WRITE_SECONDS)
			for _, player in ipairs(Players:GetPlayers()) do
				pcall(writePlayer, player)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		pcall(writePlayer, player)
	end)
	-- Reader: refresh the cache on a timer.
	task.spawn(function()
		while true do
			for _, stat in ipairs(GameData.LeaderboardStats) do
				for _, period in ipairs({ "all", "week" }) do
					pcall(readOne, period, stat)
				end
			end
			task.wait(READ_SECONDS)
		end
	end)
end

return GlobalLeaderboardService
```

- [ ] **Step 2: Compile check**

Run: `./rojo-bin/rojo build default.project.json -o /tmp/x.rbxl`
Expected: `Built project to x.rbxl`.

- [ ] **Step 3: Commit**

```bash
git add src/server/GlobalLeaderboardService.luau
git commit -m "feat(leaderboards): GlobalLeaderboardService (OrderedDataStore, writer/reader)"
```

---

### Task 5: Weekly gain hooks

Credit `PlayerData.addWeekly` on the main earning paths so the weekly boards mean something. Only positive gains; spending is untouched.

**Files:**
- Modify: `src/server/DevelopmentService.luau` (game-release block, ~lines 390-391)
- Modify: `src/server/PlotManager.luau` (subscribers ~1853, room-collect ~1927, idle whole ~2070, ad whole ~2083, prestige ~2018)

**Interfaces:**
- Consumes: `PlayerData.addWeekly(data, stat, delta, now)` (Task 2). Both files already `require(script.Parent.PlayerData)` as `PlayerData`.

- [ ] **Step 1: DevelopmentService** — in `src/server/DevelopmentService.luau`, immediately after these two existing lines:

```lua
			data.cash += cash
			data.gamesReleased += 1
```

add:

```lua
			PlayerData.addWeekly(data, "cash", cash, os.time())
			PlayerData.addWeekly(data, "gamesReleased", 1, os.time())
```

- [ ] **Step 2: PlotManager — subscribers** — in `grantSubscribers`, right after:

```lua
	data.subscribers = (data.subscribers or 0) + amount
```

add:

```lua
	PlayerData.addWeekly(data, "subscribers", amount, os.time())
```

- [ ] **Step 3: PlotManager — room-collect cash** — after the existing line (~1927):

```lua
			data.cash += amount
```

add:

```lua
			PlayerData.addWeekly(data, "cash", amount, os.time())
```

- [ ] **Step 4: PlotManager — idle whole** — after (~2070):

```lua
									data.cash += whole
									credited = true
```

add (inside the same `if whole > 0 then` block, after `credited = true`):

```lua
									PlayerData.addWeekly(data, "cash", whole, os.time())
```

- [ ] **Step 5: PlotManager — ad whole** — after (~2083):

```lua
						data.subAdAccum -= adWhole
						data.cash += adWhole
						credited = true
```

add:

```lua
						PlayerData.addWeekly(data, "cash", adWhole, os.time())
```

- [ ] **Step 6: PlotManager — prestige** — after (~2018):

```lua
		data.prestigeLevel = (data.prestigeLevel or 0) + 1
```

add:

```lua
		PlayerData.addWeekly(data, "prestigeLevel", 1, os.time())
```

- [ ] **Step 7: Compile check**

Run: `./rojo-bin/rojo build default.project.json -o /tmp/x.rbxl`
Expected: `Built project to x.rbxl`.

- [ ] **Step 8: Commit**

```bash
git add src/server/DevelopmentService.luau src/server/PlotManager.luau
git commit -m "feat(leaderboards): credit weekly gains on the main earning paths"
```

---

### Task 6: LeaderboardService — top-10 teaser from the global cache

**Files:**
- Modify: `src/server/LeaderboardService.luau` (replace `CATEGORIES` usage in `build()`/`refresh()`; drop the in-server scan)

**Interfaces:**
- Consumes: `GameData.LeaderboardStats` (Task 1), `GlobalLeaderboardService.getRows(statKey, period)` (Task 4).

- [ ] **Step 1: Add requires + config** — at the top of `src/server/LeaderboardService.luau`, add after the existing requires:

```lua
local GameData = require(game.ReplicatedStorage.Shared.GameData)
local GlobalLeaderboardService = require(script.Parent.GlobalLeaderboardService)
local FLIP_SECONDS = 10
local PLACEHOLDER = "\240\159\140\141 Global rankings appear in the live game"
```

Replace the local `CATEGORIES` table with `GameData.LeaderboardStats` everywhere it is used (it has the same `key` / `title` / `accent` / `format` fields). Keep `withCommas`, `TOP_N = 10`, geometry, and `getTeleportCFrame` as-is.

- [ ] **Step 2: Store title labels** — in `build()`, where the header `title` TextLabel is created, remember it per board so the period can be shown. Add a module-level `local boardTitleLabels = {}` next to `boardListLabels`, and after `title.Parent = sg` add:

```lua
			boardTitleLabels[i] = title
```

Change the loop to iterate `GameData.LeaderboardStats` (was `CATEGORIES`).

- [ ] **Step 3: Rewrite `refresh()`** to read the global cache with the flip clock:

```lua
local function refresh()
	local period = (math.floor(os.time() / FLIP_SECONDS) % 2 == 0) and "week" or "all"
	local periodLabel = (period == "week") and "\240\159\151\147\239\184\143 This Week" or "\240\159\143\134 All-Time"
	for i, stat in ipairs(GameData.LeaderboardStats) do
		local titleLabel = boardTitleLabels[i]
		if titleLabel then
			titleLabel.Text = periodLabel .. " \226\128\148 " .. stat.title
		end
		local label = boardListLabels[i]
		if not label then continue end
		local rows = GlobalLeaderboardService.getRows(stat.key, period)
		if not rows then
			label.Text = PLACEHOLDER
		elseif #rows == 0 then
			label.Text = "Be the first on the board!"
		else
			local lines = {}
			for rank = 1, math.min(TOP_N, #rows) do
				local r = rows[rank]
				lines[#lines + 1] = ("%d. %s  \226\128\148  %s"):format(rank, r.name, stat.format(r.value))
			end
			label.Text = table.concat(lines, "\n")
		end
	end
end
```

Remove the old in-server `Players:GetPlayers()` gather + `table.sort` block. Keep `LeaderboardService.start()` calling `refresh()` on the `REFRESH_SECONDS` loop and keep the `RequestGoToLeaderboards` teleport handler.

- [ ] **Step 4: Compile check**

Run: `./rojo-bin/rojo build default.project.json -o /tmp/x.rbxl`
Expected: `Built project to x.rbxl`.

- [ ] **Step 5: Commit**

```bash
git add src/server/LeaderboardService.luau
git commit -m "feat(leaderboards): render top-10 teaser + week/all flip from global cache"
```

---

### Task 7: init.server — start service + serve panel requests

**Files:**
- Modify: `src/server/init.server.luau`

**Interfaces:**
- Consumes: `GlobalLeaderboardService.start`, `.getRows`, `.getSelfStanding` (Task 4); `GameData.LeaderboardStats` (Task 1); `Remotes.RequestLeaderboardData` / `Remotes.LeaderboardData` (Task 3).
- Produces: on `RequestLeaderboardData(stat, period)`, fires `LeaderboardData(stat, period, rows, standing)` to that client from the cache.

- [ ] **Step 1: Require + start** — near the other service requires in `src/server/init.server.luau`, add:

```lua
local GlobalLeaderboardService = require(script.GlobalLeaderboardService)
```

and where services are started (alongside `LeaderboardService.build()` / `.start()`), add `GlobalLeaderboardService.start()` **before** `LeaderboardService.start()` so the cache begins filling first. Keep `LeaderboardService.build()` where it is.

- [ ] **Step 2: Serve panel data requests** — add a handler (validates the incoming stat/period against the known set, then answers from cache — no new DataStore reads):

```lua
do
	local GameData = require(game.ReplicatedStorage.Shared.GameData)
	local validStat = {}
	for _, s in ipairs(GameData.LeaderboardStats) do
		validStat[s.key] = true
	end
	Remotes.RequestLeaderboardData.OnServerEvent:Connect(function(player, stat, period)
		if not validStat[stat] then return end
		if period ~= "week" and period ~= "all" then return end
		local rows = GlobalLeaderboardService.getRows(stat, period) -- may be nil (Studio/unavailable)
		local standing = GlobalLeaderboardService.getSelfStanding(player, stat, period)
		local safeRows
		if rows then
			safeRows = {}
			for _, r in ipairs(rows) do
				safeRows[#safeRows + 1] = { name = r.name, value = r.value, userId = r.userId }
			end
		end
		Remotes.LeaderboardData:FireClient(player, stat, period, safeRows, standing)
	end)
end
```

(If `Remotes` is not already required in `init.server.luau`, add `local Remotes = require(game.ReplicatedStorage.Shared.Remotes)` — it almost certainly is; reuse the existing local.)

- [ ] **Step 3: Compile check**

Run: `./rojo-bin/rojo build default.project.json -o /tmp/x.rbxl`
Expected: `Built project to x.rbxl`.

- [ ] **Step 4: Commit**

```bash
git add src/server/init.server.luau
git commit -m "feat(leaderboards): start global service + serve panel data requests"
```

---

### Task 8: Client — scrollable top-100 Leaderboards panel

**Files:**
- Create: `src/client/LeaderboardPanel.luau`
- Modify: `src/client/UI.luau` (Go-to-Leaderboards button click ~line 906; init the panel in `UI.init`)

**Interfaces:**
- Consumes: `Remotes.RequestLeaderboardData` / `Remotes.LeaderboardData` (Task 3); `GameData.LeaderboardStats` (Task 1).
- Produces: `LeaderboardPanel.init(player)`, `LeaderboardPanel.toggle()`.

- [ ] **Step 1: Create `src/client/LeaderboardPanel.luau`**:

```lua
-- Scrollable global-leaderboard panel: pick a stat + period, see the top 100
-- and your own standing. Data comes from the server cache via RequestLeaderboardData.
local Players = game:GetService("Players")
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local GameData = require(game.ReplicatedStorage.Shared.GameData)

local LeaderboardPanel = {}

local PANEL_BG = Color3.fromRGB(255, 255, 255)
local TEXT_DARK = Color3.fromRGB(30, 33, 48)
local MUTED = Color3.fromRGB(120, 126, 142)
local ACCENT = Color3.fromRGB(140, 92, 255)
local ROW_ALT = Color3.fromRGB(244, 244, 250)
local MINE = Color3.fromRGB(255, 244, 205)

local gui, listFrame, youLabel
local currentStat = GameData.LeaderboardStats[1].key
local currentPeriod = "week"
local myUserId

local function statByKey(key)
	for _, s in ipairs(GameData.LeaderboardStats) do
		if s.key == key then return s end
	end
	return GameData.LeaderboardStats[1]
end

local function request()
	Remotes.RequestLeaderboardData:FireServer(currentStat, currentPeriod)
end

-- Rebuild the scrolling list from a server response.
local function render(stat, period, rows, standing)
	if stat ~= currentStat or period ~= currentPeriod then return end -- stale reply
	for _, c in ipairs(listFrame:GetChildren()) do
		if c:IsA("Frame") then c:Destroy() end
	end
	local statDef = statByKey(stat)
	if not rows then
		youLabel.Text = "\240\159\140\141 Global rankings appear in the live game"
		return
	end
	if standing and standing.rank then
		youLabel.Text = ("You: #%d  \226\128\148  %s"):format(standing.rank, statDef.format(standing.value))
	elseif standing then
		youLabel.Text = ("You: %s  \226\128\148  climb into the top 100!"):format(statDef.format(standing.value))
	end
	for i, r in ipairs(rows) do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 30)
		row.BackgroundColor3 = (r.userId == myUserId) and MINE or (i % 2 == 0 and ROW_ALT or PANEL_BG)
		row.BorderSizePixel = 0
		row.LayoutOrder = i
		row.Parent = listFrame

		local rank = Instance.new("TextLabel")
		rank.Size = UDim2.new(0, 52, 1, 0)
		rank.BackgroundTransparency = 1
		rank.Text = "#" .. i
		rank.TextColor3 = (i <= 3) and ACCENT or MUTED
		rank.Font = Enum.Font.FredokaOne
		rank.TextSize = 18
		rank.TextXAlignment = Enum.TextXAlignment.Left
		rank.Parent = row

		local name = Instance.new("TextLabel")
		name.Position = UDim2.fromOffset(56, 0)
		name.Size = UDim2.new(1, -170, 1, 0)
		name.BackgroundTransparency = 1
		name.Text = r.name
		name.TextColor3 = TEXT_DARK
		name.Font = Enum.Font.GothamMedium
		name.TextSize = 16
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.TextTruncate = Enum.TextTruncate.AtEnd
		name.Parent = row

		local val = Instance.new("TextLabel")
		val.AnchorPoint = Vector2.new(1, 0)
		val.Position = UDim2.new(1, -8, 0, 0)
		val.Size = UDim2.new(0, 110, 1, 0)
		val.BackgroundTransparency = 1
		val.Text = statDef.format(r.value)
		val.TextColor3 = TEXT_DARK
		val.Font = Enum.Font.FredokaOne
		val.TextSize = 16
		val.TextXAlignment = Enum.TextXAlignment.Right
		val.Parent = row
	end
	if #rows == 0 then
		youLabel.Text = "Be the first on this board!"
	end
end

local function makeTabButton(parent, text, order, onClick)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(0, 0, 1, 0)
	b.AutomaticSize = Enum.AutomaticSize.X
	b.BackgroundColor3 = Color3.fromRGB(238, 238, 246)
	b.TextColor3 = TEXT_DARK
	b.Font = Enum.Font.FredokaOne
	b.TextSize = 15
	b.Text = "  " .. text .. "  "
	b.AutoButtonColor = true
	b.LayoutOrder = order
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = b
	b.MouseButton1Click:Connect(onClick)
	b.Parent = parent
	return b
end

function LeaderboardPanel.toggle()
	if gui then
		gui.Enabled = not gui.Enabled
		if gui.Enabled then request() end
	end
end

function LeaderboardPanel.init(player)
	myUserId = player.UserId
	local pg = player:WaitForChild("PlayerGui")

	gui = Instance.new("ScreenGui")
	gui.Name = "LeaderboardPanelGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 40
	gui.Enabled = false
	gui.Parent = pg

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(520, 560)
	panel.BackgroundColor3 = PANEL_BG
	panel.Parent = gui
	local pc = Instance.new("UICorner"); pc.CornerRadius = UDim.new(0, 16); pc.Parent = panel

	local header = Instance.new("TextLabel")
	header.Size = UDim2.new(1, -80, 0, 44)
	header.Position = UDim2.fromOffset(20, 12)
	header.BackgroundTransparency = 1
	header.Text = "\240\159\143\134 Global Leaderboards"
	header.TextColor3 = TEXT_DARK
	header.Font = Enum.Font.FredokaOne
	header.TextSize = 26
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.Parent = panel

	local close = Instance.new("TextButton")
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -14, 0, 14)
	close.Size = UDim2.fromOffset(40, 40)
	close.BackgroundColor3 = Color3.fromRGB(238, 238, 246)
	close.Text = "\195\151"
	close.TextColor3 = TEXT_DARK
	close.Font = Enum.Font.FredokaOne
	close.TextSize = 22
	close.Parent = panel
	local cc = Instance.new("UICorner"); cc.CornerRadius = UDim.new(1, 0); cc.Parent = close
	close.MouseButton1Click:Connect(function() gui.Enabled = false end)

	-- Stat tabs
	local statTabs = Instance.new("Frame")
	statTabs.Position = UDim2.fromOffset(20, 64)
	statTabs.Size = UDim2.new(1, -40, 0, 34)
	statTabs.BackgroundTransparency = 1
	statTabs.Parent = panel
	local statLayout = Instance.new("UIListLayout")
	statLayout.FillDirection = Enum.FillDirection.Horizontal
	statLayout.Padding = UDim.new(0, 6)
	statLayout.Parent = statTabs
	for i, s in ipairs(GameData.LeaderboardStats) do
		makeTabButton(statTabs, s.title, i, function()
			currentStat = s.key
			request()
		end)
	end

	-- Period tabs
	local periodTabs = Instance.new("Frame")
	periodTabs.Position = UDim2.fromOffset(20, 104)
	periodTabs.Size = UDim2.new(1, -40, 0, 32)
	periodTabs.BackgroundTransparency = 1
	periodTabs.Parent = panel
	local periodLayout = Instance.new("UIListLayout")
	periodLayout.FillDirection = Enum.FillDirection.Horizontal
	periodLayout.Padding = UDim.new(0, 6)
	periodLayout.Parent = periodTabs
	makeTabButton(periodTabs, "\240\159\151\147\239\184\143 This Week", 1, function()
		currentPeriod = "week"; request()
	end)
	makeTabButton(periodTabs, "\240\159\143\134 All-Time", 2, function()
		currentPeriod = "all"; request()
	end)

	youLabel = Instance.new("TextLabel")
	youLabel.Position = UDim2.fromOffset(20, 142)
	youLabel.Size = UDim2.new(1, -40, 0, 30)
	youLabel.BackgroundColor3 = MINE
	youLabel.Text = "You: —"
	youLabel.TextColor3 = TEXT_DARK
	youLabel.Font = Enum.Font.FredokaOne
	youLabel.TextSize = 16
	youLabel.Parent = panel
	local yc = Instance.new("UICorner"); yc.CornerRadius = UDim.new(0, 8); yc.Parent = youLabel

	listFrame = Instance.new("ScrollingFrame")
	listFrame.Position = UDim2.fromOffset(20, 180)
	listFrame.Size = UDim2.new(1, -40, 1, -196)
	listFrame.BackgroundColor3 = PANEL_BG
	listFrame.BorderSizePixel = 0
	listFrame.ScrollBarThickness = 6
	listFrame.CanvasSize = UDim2.new()
	listFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	listFrame.Parent = panel
	local ll = Instance.new("UIListLayout")
	ll.SortOrder = Enum.SortOrder.LayoutOrder
	ll.Parent = listFrame

	Remotes.LeaderboardData.OnClientEvent:Connect(render)
end

return LeaderboardPanel
```

- [ ] **Step 2: Wire it into `src/client/UI.luau`** — near the top of `UI.init` (after other client-module inits such as `Sound`/`DarkMode`), require and init the panel. Add at the top with the other requires:

```lua
local LeaderboardPanel = require(script.Parent.LeaderboardPanel)
```

and inside `UI.init(player, ...)` (wherever other modules are initialized), add:

```lua
	LeaderboardPanel.init(player)
```

- [ ] **Step 3: Open the panel from the existing button** — change the Go-to-Leaderboards click handler (~line 906) from:

```lua
	leaderboardBtn.MouseButton1Click:Connect(function()
		Sound.play("Teleport")
		Remotes.RequestGoToLeaderboards:FireServer()
	end)
```

to:

```lua
	leaderboardBtn.MouseButton1Click:Connect(function()
		Sound.play("PanelOpen")
		LeaderboardPanel.toggle()
	end)
```

(The board teleport stays available; opening the on-screen top-100 panel is the primary action. If `Sound.PanelOpen` is not a valid cue, use `Sound.play("Click")`.)

- [ ] **Step 4: Compile check**

Run: `./rojo-bin/rojo build default.project.json -o /tmp/x.rbxl`
Expected: `Built project to x.rbxl`.

- [ ] **Step 5: Commit**

```bash
git add src/client/LeaderboardPanel.luau src/client/UI.luau
git commit -m "feat(leaderboards): scrollable top-100 client panel + open from button"
```

---

### Task 9: Integration playtest (Studio)

**Files:** none (verification only).

- [ ] **Step 1: Compile**

Run: `./rojo-bin/rojo build default.project.json -o /tmp/x.rbxl`
Expected: `Built project to x.rbxl`.

- [ ] **Step 2: Studio playtest checklist** (DataStore is off in Studio, so global data is expected to be empty/placeholder — that is a PASS, not a bug):
  - Server starts with no errors from `GlobalLeaderboardService` / `LeaderboardService` (check output).
  - The 4 beach boards build and their headers **flip** between `🗓️ This Week — …` and `🏆 All-Time — …` every ~10s; board bodies show the `🌍 Global rankings appear in the live game` placeholder.
  - Clicking **Go to Leaderboards** opens the panel; its **stat tabs** and **period tabs** switch; the top-100 list area **scrolls** (empty/placeholder in Studio); the **× close** works.
  - Join/leave (stop/replay) throws no writer/reader errors.
  - Run `RunTests` in Studio: all assertions (including the new Task 1 + Task 2 ones) PASS.

- [ ] **Step 3: Note the post-publish check** (for the human): on a published place, values populate across servers; weekly boards show this-week gains and reset on the week boundary; all-time accumulates; the panel's "You: #N — value" matches.

---

## Self-Review

**Spec coverage:**
- Global storage (OrderedDataStore, all-time + week-keyed) → Task 4. ✅
- Weekly-gains tracking + reset → Tasks 2 (accumulator) + 5 (hooks). ✅
- Top-10 world teaser + This-Week/All-Time flip + placeholder → Task 6. ✅
- Scrollable top-100 client panel + stat/period tabs + "You:" line → Task 8. ✅
- Remote channel + server serving from cache → Tasks 3 + 7. ✅
- Graceful Studio no-op + never break game → Global Constraints + `pcall` in Task 4 + placeholder in Tasks 6/8. ✅
- Unit tests (week index, rollover, addWeekly, formatting, standing) → Tasks 1 + 2. ✅
- Preserve boards/teleport → Task 6 keeps geometry + `getTeleportCFrame`; Task 8 keeps teleport available. ✅

**Known deviation from spec (surfaced to user during spec review):** all-time boards rank **current** values (so subs/cash/games drop after a rebirth), matching today's boards; true lifetime-survives-rebirth counters are a deliberate later enhancement (noted in Global Constraints). Weekly "cash earned" is credited on the main earning paths (release, room-collect, idle, ad), not every minor source (daily/lounge/basketball/starter-pack) — documented in Task 5.

**Type consistency:** stat keys `"prestigeLevel"/"subscribers"/"cash"/"gamesReleased"` used identically across `GameData.LeaderboardStats`, `PlayerData.weekly`, the hooks (Task 5), the service (Task 4), and the panel (Task 8). `period` is always `"week"`/`"all"`. `getRows -> {{name,value,userId}}|nil`, `getSelfStanding -> {rank:number?, value:number}`, `computeStanding` same shape — consistent across Tasks 4/7/8.

**Placeholder scan:** no TBD/TODO; every code step contains full code.
