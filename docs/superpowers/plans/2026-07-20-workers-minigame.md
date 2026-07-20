# Workers + Active Development Mini-Games Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the passive "pick Genre+Topic, watch a bar fill" development cycle with three active, server-verified mini-games (Coding, Map Building, Testing), and let players hire per-phase Workers at the lobby desk to automate phases instead of playing them.

**Architecture:** Server remains fully authoritative — every mini-game's score is computed by the server from server-verified inputs (a server-counted tap total, a server-computed marker position at the server-received click time, a server-known correct answer), never from a client-reported score. The client only renders what the server tells it and reports raw input events (taps, a placement click, a choice index).

**Tech Stack:** Roblox Luau, Rojo (existing project), `Workspace:GetServerTimeNow()` for client/server clock sync in the timing-bar mini-game.

## Global Constraints

- Server is authoritative for all Cash, Worker state, and mini-game scores — the client never computes or reports a final score, only raw inputs (taps, a placement click, a choice).
- Exactly 4 Genres (Racing, Horror, Adventure, Simulator) and 4 Topics (Space, Zombies, Sports, Fantasy) — unchanged from the original BETA.
- Trends Board and its Cash rules are unchanged: exact match = $0 (copy), partial match = 10% chance of 5x, no match = normal. Only what feeds "Base Cash" changes (Dev Quality instead of the old Quality Boost upgrade level).
- Each player has a fully private studio — unchanged.
- The old **Dev Speed** and **Quality Boost** upgrades are removed entirely and must not remain referenced anywhere (dead code, dead RemoteEvents, dead UI).
- Exactly 3 Worker roles: Coding, MapBuilding, Testing — one slot each, no more (an "expansion" for more slots is explicitly out of scope for this plan).
- A hired Worker's phase still takes a short, fixed delay to "work" — never instant.
- Numeric balance values below (round counts, timing windows, costs) are sensible defaults for this project — easy to retune later since they live in `GameData.luau`.

---

## File Structure

```
roblox game/
├── src/
│   ├── shared/
│   │   ├── GameData.luau         (Task 1 — MODIFY: remove old upgrade data, add mini-game/worker data)
│   │   ├── TrendMatch.luau       (Task 2 — MODIFY: qualityBoostLevel -> devQuality)
│   │   ├── Remotes.luau          (Task 3 — MODIFY: new remote list)
│   │   └── Tests/RunTests.luau   (Tasks 1-2 — MODIFY: replace stale assertions)
│   ├── server/
│   │   ├── PlayerData.luau       (Task 4 — MODIFY: new data shape)
│   │   ├── WorkerService.luau    (Task 5 — NEW: hire/upgrade handling)
│   │   ├── DevelopmentService.luau (Task 6 — REWRITE: phase/round engine)
│   │   ├── LobbyBuilder.luau     (Task 7 — MODIFY: add a ProximityPrompt to the desk)
│   │   └── init.server.luau      (Task 8 — MODIFY: swap UpgradeService -> WorkerService)
│   └── client/
│       ├── UI.luau               (Task 9 — REWRITE: remove progress bar/upgrades, add phase routing)
│       ├── CodingGame.luau        (Task 10 — NEW: tap mini-game)
│       ├── MapBuildingGame.luau   (Task 11 — NEW: timing-bar mini-game)
│       ├── TestingGame.luau       (Task 12 — NEW: multiple-choice mini-game)
│       └── WorkersPanel.luau      (Task 13 — NEW: hire/upgrade panel + desk prompt)
```

`CodingGame.luau`/`MapBuildingGame.luau`/`TestingGame.luau`/`WorkersPanel.luau` are siblings of `UI.luau` (all direct children of the same "Client" LocalScript Rojo creates from `init.client.luau`) — from inside `UI.luau`, `script` refers to the UI module itself, so referencing a sibling is `script.Parent.CodingGame`, not `script.CodingGame`.

---

### Task 1: Shared game data — remove old upgrades, add mini-game & worker data

**Files:**
- Modify: `src/shared/GameData.luau`
- Modify: `src/shared/Tests/RunTests.luau`

**Interfaces:**
- Consumes: nothing (pure module)
- Produces:
  - `GameData.Phases: {string}` = `{"Coding", "MapBuilding", "Testing"}`
  - `GameData.RoundsPerPhase: number` = `3`
  - `GameData.CodingRoundSeconds`, `GameData.CodingTargetTaps`
  - `GameData.MapBuildingRoundSeconds`, `GameData.MapBuildingZoneCenter`, `GameData.MapBuildingZoneHalfWidth`, `GameData.MapBuildingMaxWaitSeconds`
  - `GameData.TestingMaxWaitSeconds`, `GameData.TestingWrongAnswerScore`, `GameData.TestingQuestions: {{prompt: string, options: {string}, correctIndex: number}}`
  - `GameData.WorkerHireCost`, `GameData.WorkerUpgradeCostBase`, `GameData.WorkerUpgradeCostGrowth`, `GameData.WorkerBaseScore`, `GameData.WorkerScorePerLevel`, `GameData.WorkerAutoCompleteSeconds`
  - `GameData.getWorkerUpgradeCost(currentLevel: number): number`
  - `GameData.getWorkerScore(level: number): number`
  - `GameData.getBaseCash(devQuality: number): number`
  - `GameData.getMarkerPosition(elapsedSeconds: number, periodSeconds: number): number` — shared by server and client so both compute the timing-bar marker identically
  - Removed: `getDevTime`, `getDevSpeedCost`, `getQualityMultiplier`, `getQualityBoostCost`, `BaseDevTimeSeconds`, `DevSpeedDecayPerLevel`, `DevSpeedCostBase`, `DevSpeedCostGrowth`, `QualityBoostPerLevel`, `QualityBoostCostBase`, `QualityBoostCostGrowth`
  - Kept unchanged: `Genres`, `Topics`, `StartingCash`, `PayoutMultiplier`, `TrendRefreshSeconds`, `TrendBonusChance`, `TrendBonusMultiplier`

- [ ] **Step 1: Write the new GameData.luau**

Replace the full contents of `src/shared/GameData.luau` with:

```lua
local GameData = {}

GameData.Genres = { "Racing", "Horror", "Adventure", "Simulator" }
GameData.Topics = { "Space", "Zombies", "Sports", "Fantasy" }

GameData.StartingCash = 0
GameData.PayoutMultiplier = 10

GameData.TrendRefreshSeconds = 300
GameData.TrendBonusChance = 0.1
GameData.TrendBonusMultiplier = 5

GameData.Phases = { "Coding", "MapBuilding", "Testing" }
GameData.RoundsPerPhase = 3

GameData.CodingRoundSeconds = 3
GameData.CodingTargetTaps = 15

GameData.MapBuildingRoundSeconds = 2
GameData.MapBuildingZoneCenter = 0.5
GameData.MapBuildingZoneHalfWidth = 0.15
GameData.MapBuildingMaxWaitSeconds = 4

GameData.TestingMaxWaitSeconds = 15
GameData.TestingWrongAnswerScore = 0.3
GameData.TestingQuestions = {
	{
		prompt = "A player found a game-breaking bug the night before launch. What do you do?",
		options = { "Ship it anyway, patch later", "Fix it, even if launch slips" },
		correctIndex = 2,
	},
	{
		prompt = "Your loading screen takes 30 seconds. What's the fix?",
		options = { "Add a longer loading bar animation", "Optimize and compress assets" },
		correctIndex = 2,
	},
	{
		prompt = "Players say the tutorial is confusing. What do you do?",
		options = { "Assume they'll figure it out", "Rewrite the tutorial to be clearer" },
		correctIndex = 2,
	},
	{
		prompt = "You added a fun new feature but it lags the game. What now?",
		options = { "Ship it, lag builds character", "Optimize it before shipping" },
		correctIndex = 2,
	},
	{
		prompt = "A tester suggests a great idea outside the original plan. What do you do?",
		options = { "Cram it in right before launch", "Note it for a future update" },
		correctIndex = 2,
	},
}

GameData.WorkerHireCost = 150
GameData.WorkerUpgradeCostBase = 50
GameData.WorkerUpgradeCostGrowth = 1.15
GameData.WorkerBaseScore = 0.5
GameData.WorkerScorePerLevel = 0.05
GameData.WorkerAutoCompleteSeconds = 3

function GameData.getWorkerUpgradeCost(currentLevel)
	return math.floor(GameData.WorkerUpgradeCostBase * (GameData.WorkerUpgradeCostGrowth ^ currentLevel))
end

function GameData.getWorkerScore(level)
	return math.min(1, GameData.WorkerBaseScore + (level * GameData.WorkerScorePerLevel))
end

function GameData.getBaseCash(devQuality)
	return GameData.PayoutMultiplier * devQuality
end

function GameData.getMarkerPosition(elapsedSeconds, periodSeconds)
	local phase01 = (elapsedSeconds % periodSeconds) / periodSeconds

	if phase01 < 0.5 then
		return phase01 * 2
	end

	return 2 - (phase01 * 2)
end

return GameData
```

- [ ] **Step 2: Replace the stale GameData assertions in RunTests.luau**

Open `src/shared/Tests/RunTests.luau`. Replace the block of 9 `GameData.*` assertions right after `local t = TestHarness.new()` (everything from the first `t:assertEqual(GameData.getDevTime...` line through the `t:assertEqual(GameData.getBaseCash(5)...` line — 9 assertions testing the now-removed functions) with:

```lua
t:assertEqual(GameData.getWorkerUpgradeCost(0), 50, "getWorkerUpgradeCost(0) is the base cost")
t:assertEqual(GameData.getWorkerUpgradeCost(1), 57, "getWorkerUpgradeCost(1) grows 15%, floored")
t:assertEqual(GameData.getWorkerScore(0), 0.5, "getWorkerScore(0) is the base score")
t:assertEqual(GameData.getWorkerScore(5), 0.75, "getWorkerScore(5) adds 5% per level")
t:assertEqual(GameData.getWorkerScore(10), 1, "getWorkerScore(10) reaches the 100% cap")
t:assertEqual(GameData.getWorkerScore(20), 1, "getWorkerScore(20) stays capped at 100%")
t:assertEqual(GameData.getBaseCash(0.5), 5, "getBaseCash(0.5) is half the payout multiplier")
t:assertEqual(GameData.getBaseCash(1), 10, "getBaseCash(1) equals the full payout multiplier")
t:assertEqual(GameData.getMarkerPosition(0, 2), 0, "getMarkerPosition(0,...) starts at 0")
t:assertEqual(GameData.getMarkerPosition(0.5, 2), 0.5, "getMarkerPosition at quarter-period is at the midpoint")
t:assertEqual(GameData.getMarkerPosition(1, 2), 1, "getMarkerPosition at half-period is at the far end")
t:assertEqual(GameData.getMarkerPosition(1.5, 2), 0.5, "getMarkerPosition at three-quarter-period is back at the midpoint")
t:assertEqual(GameData.getMarkerPosition(2, 2), 0, "getMarkerPosition at a full period wraps back to 0")
```

Leave the `TrendMatch` assertions below this block untouched for now — Task 2 updates those.

- [ ] **Step 3: Run test to verify it fails, then passes**

In Roblox Studio's command bar:

```
require(game.ReplicatedStorage.Shared.Tests.RunTests)
```

Before Step 1's edit is saved/synced this would error (old functions don't exist as you edit); after both steps are saved and Rojo has synced, re-enter Play mode and run the same line again. Expected: 13 new `PASS:` lines from this task, plus the pre-existing `TrendMatch` assertions still running (they'll still reference the OLD `computeCash` 5th argument name conceptually but numerically still pass, since Task 2 hasn't changed their expected values yet — don't worry if the total count looks off until Task 2 is also done).

- [ ] **Step 4: Commit**

```bash
git add src/shared/GameData.luau src/shared/Tests/RunTests.luau
git commit -m "Replace Dev Speed/Quality Boost data with mini-game and Worker data"
```

---

### Task 2: Trend matching — devQuality instead of qualityBoostLevel

**Files:**
- Modify: `src/shared/TrendMatch.luau`
- Modify: `src/shared/Tests/RunTests.luau`

**Interfaces:**
- Consumes: `GameData.getBaseCash(devQuality)` (Task 1)
- Produces:
  - `TrendMatch.classify(genre, topic, trend1, trend2): "copy" | "partial" | "none"` (unchanged)
  - `TrendMatch.computeCash(genre: string, topic: string, trend1: {...}, trend2: {...}, devQuality: number, randomFn: (() -> number)?): (cash: number, classification: string, hitBonus: boolean)` — 5th parameter renamed/repurposed from `qualityBoostLevel` to `devQuality`

- [ ] **Step 1: Update the failing test**

In `src/shared/Tests/RunTests.luau`, find the `computeCash` assertions (the ones using `trend1`/`trend2` and a 5th numeric argument that used to be `0`). Replace that whole block with:

```lua
local copyCash, copyClass, copyHit = TrendMatch.computeCash("Horror", "Zombies", trend1, trend2, 1, function() return 1 end)
t:assertEqual(copyCash, 0, "copy earns zero cash")
t:assertEqual(copyClass, "copy", "copy is classified as copy")
t:assertEqual(copyHit, false, "copy never hits the trend bonus")

local winCash, winClass, winHit = TrendMatch.computeCash("Horror", "Sports", trend1, trend2, 1, function() return 0.05 end)
t:assertEqual(winCash, GameData.getBaseCash(1) * GameData.TrendBonusMultiplier, "partial match + winning roll gives 5x")
t:assertEqual(winClass, "partial", "winning case is classified as partial")
t:assertEqual(winHit, true, "winning roll reports hitBonus true")

local loseCash, loseClass, loseHit = TrendMatch.computeCash("Horror", "Sports", trend1, trend2, 1, function() return 0.5 end)
t:assertEqual(loseCash, GameData.getBaseCash(1), "partial match + losing roll gives base cash")
t:assertEqual(loseHit, false, "losing roll reports hitBonus false")

local noneCash = TrendMatch.computeCash("Adventure", "Fantasy", trend1, trend2, 1, function() return 0.01 end)
t:assertEqual(noneCash, GameData.getBaseCash(1), "no match always gives base cash regardless of roll")

t:summary()
```

(Note `t:summary()` stays as the last line of the file — if it already appears elsewhere from a prior edit, remove the duplicate and keep only this one at the very end.)

- [ ] **Step 2: Run test to verify it fails**

Re-enter Play mode, command bar:

```
require(game.ReplicatedStorage.Shared.Tests.RunTests)
```

Expected: an error or `FAIL` lines, since `TrendMatch.luau` hasn't been updated yet and its internal call to `GameData.getBaseCash` still expects the old meaning.

- [ ] **Step 3: Update TrendMatch.luau**

In `src/shared/TrendMatch.luau`, find the `computeCash` function signature and body. Change:

```lua
function TrendMatch.computeCash(genre, topic, trend1, trend2, qualityBoostLevel, randomFn)
	randomFn = randomFn or math.random
	local baseCash = GameData.getBaseCash(qualityBoostLevel)
```

to:

```lua
function TrendMatch.computeCash(genre, topic, trend1, trend2, devQuality, randomFn)
	randomFn = randomFn or math.random
	local baseCash = GameData.getBaseCash(devQuality)
```

Nothing else in the file changes — `classify` and the rest of `computeCash`'s body are untouched.

- [ ] **Step 4: Run test to verify it passes**

Re-enter Play mode, run the same command bar line. Expected: all `PASS:` lines (22 total: 13 from Task 1 + 5 `classify` + 9 `computeCash`... recount by actually reading the file once both tasks are done — the important thing is `Tests complete: N passed, 0 failed` with no `FAIL:` lines).

- [ ] **Step 5: Commit**

```bash
git add src/shared/TrendMatch.luau src/shared/Tests/RunTests.luau
git commit -m "TrendMatch: use devQuality instead of the removed Quality Boost upgrade"
```

---

### Task 3: Shared Remotes — new remote list

**Files:**
- Modify: `src/shared/Remotes.luau`

**Interfaces:**
- Consumes: nothing
- Produces: `Remotes.RequestStartDevelopment`, `Remotes.PhaseStarted`, `Remotes.RoundStarted`, `Remotes.ReportTap`, `Remotes.ReportPlacement`, `Remotes.ReportChoice`, `Remotes.RoundComplete`, `Remotes.PhaseComplete`, `Remotes.DevelopmentComplete`, `Remotes.RequestHireWorker`, `Remotes.RequestUpgradeWorker`, `Remotes.WorkerActionResult`, `Remotes.PlayerStateUpdated`, `Remotes.TrendsUpdated` — each a `RemoteEvent`. `RequestBuyUpgrade`/`UpgradeResult` are removed.

- [ ] **Step 1: Update the REMOTE_NAMES list**

In `src/shared/Remotes.luau`, replace the `REMOTE_NAMES` table with:

```lua
local REMOTE_NAMES = {
	"RequestStartDevelopment",
	"PhaseStarted",
	"RoundStarted",
	"ReportTap",
	"ReportPlacement",
	"ReportChoice",
	"RoundComplete",
	"PhaseComplete",
	"DevelopmentComplete",
	"RequestHireWorker",
	"RequestUpgradeWorker",
	"WorkerActionResult",
	"PlayerStateUpdated",
	"TrendsUpdated",
}
```

Nothing else in the file changes — the server-creates/client-waits logic below is unaffected by the list's contents.

- [ ] **Step 2: Manually verify all 14 remotes exist**

In Studio, Play mode, command bar (Server context):

```lua
local names = {
	"RequestStartDevelopment", "PhaseStarted", "RoundStarted", "ReportTap",
	"ReportPlacement", "ReportChoice", "RoundComplete", "PhaseComplete",
	"DevelopmentComplete", "RequestHireWorker", "RequestUpgradeWorker",
	"WorkerActionResult", "PlayerStateUpdated", "TrendsUpdated",
}
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
for _, name in ipairs(names) do
	print(name, Remotes[name].ClassName)
end
```

Expected: 14 lines, each printing `<Name> RemoteEvent` with no errors.

- [ ] **Step 3: Commit**

```bash
git add src/shared/Remotes.luau
git commit -m "Remotes: add mini-game/worker events, remove the old generic upgrade events"
```

---

### Task 4: Player data — new shape (no more upgrade levels, has Workers)

**Files:**
- Modify: `src/server/PlayerData.luau`

**Interfaces:**
- Consumes: nothing new
- Produces: `PlayerData.load`/`.get`/`.save`/`.remove` — same signatures as before, but the data shape returned/cached is now `{cash: number, gamesReleased: number, workers: {Coding: {hired: boolean, level: number}, MapBuilding: {hired: boolean, level: number}, Testing: {hired: boolean, level: number}}}`

- [ ] **Step 1: Update defaultData()**

In `src/server/PlayerData.luau`, replace the `defaultData` function:

```lua
local function defaultData()
	return {
		cash = GameData.StartingCash,
		devSpeedLevel = 0,
		qualityBoostLevel = 0,
		gamesReleased = 0,
	}
end
```

with:

```lua
local function defaultData()
	return {
		cash = GameData.StartingCash,
		gamesReleased = 0,
		workers = {
			Coding = { hired = false, level = 0 },
			MapBuilding = { hired = false, level = 0 },
			Testing = { hired = false, level = 0 },
		},
	}
end
```

Nothing else in the file changes — `load`/`get`/`save`/`remove` and the `failedLoads` safety mechanism operate on whatever table `defaultData()` returns, so they don't need to know its shape.

- [ ] **Step 2: Manually verify the new shape loads correctly**

In Studio, Play mode, command bar (Server context):

```lua
local PlayerData = require(game.ServerScriptService.Server.PlayerData)
local player = game.Players:GetPlayers()[1]
local data = PlayerData.load(player)
print(data.cash, data.gamesReleased)
print(data.workers.Coding.hired, data.workers.Coding.level)
print(data.workers.MapBuilding.hired, data.workers.Testing.level)
```

Expected: `0    0`, then `false    0`, then `false    0` — new players start with nothing hired.

> Note: if you already have saved data from before this change (Cash > 0, or old `devSpeedLevel`/`qualityBoostLevel` fields), that old save will load as-is (missing the new `workers` field) since `PlayerData.load` only calls `defaultData()` for players with NO prior save. If `data.workers` comes back `nil` for your account, either accept starting fresh for this new system (delete the save by publishing under a new DataStore name is overkill for a hobby project — just proceed, Task 6 handles a missing `data.workers` defensively is NOT required, since this is a single-developer testing scenario, not production data migration), or simplest: this is expected and fine for a Studio Play Solo test account — the numbers above assume a fresh account with no prior save.

- [ ] **Step 3: Commit**

```bash
git add src/server/PlayerData.luau
git commit -m "PlayerData: replace Dev Speed/Quality Boost levels with per-role Worker state"
```

---

### Task 5: Worker hire/upgrade service

**Files:**
- Create: `src/server/WorkerService.luau`

**Interfaces:**
- Consumes: `GameData.WorkerHireCost`, `GameData.getWorkerUpgradeCost` (Task 1), `Remotes.RequestHireWorker`, `Remotes.RequestUpgradeWorker`, `Remotes.WorkerActionResult`, `Remotes.PlayerStateUpdated` (Task 3), `PlayerData.get` (Task 4)
- Produces: `WorkerService.start(): ()` — connects both RemoteEvent listeners, call once at server startup

- [ ] **Step 1: Write the implementation**

Create `src/server/WorkerService.luau`:

```lua
local GameData = require(game.ReplicatedStorage.Shared.GameData)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local PlayerData = require(script.Parent.PlayerData)

local WorkerService = {}

function WorkerService.start()
	Remotes.RequestHireWorker.OnServerEvent:Connect(function(player, role)
		local data = PlayerData.get(player)
		if not data or not data.workers[role] then
			return
		end

		local worker = data.workers[role]
		if worker.hired then
			return
		end

		if data.cash < GameData.WorkerHireCost then
			Remotes.WorkerActionResult:FireClient(player, role, "hire", false)
			return
		end

		data.cash -= GameData.WorkerHireCost
		worker.hired = true

		Remotes.WorkerActionResult:FireClient(player, role, "hire", true)
		Remotes.PlayerStateUpdated:FireClient(player, data)
	end)

	Remotes.RequestUpgradeWorker.OnServerEvent:Connect(function(player, role)
		local data = PlayerData.get(player)
		if not data or not data.workers[role] then
			return
		end

		local worker = data.workers[role]
		if not worker.hired then
			return
		end

		local cost = GameData.getWorkerUpgradeCost(worker.level)
		if data.cash < cost then
			Remotes.WorkerActionResult:FireClient(player, role, "upgrade", false)
			return
		end

		data.cash -= cost
		worker.level += 1

		Remotes.WorkerActionResult:FireClient(player, role, "upgrade", true)
		Remotes.PlayerStateUpdated:FireClient(player, data)
	end)
end

return WorkerService
```

Note `data.workers[role]` where `role` is a raw string sent from the client — if it's not one of `"Coding"`/`"MapBuilding"`/`"Testing"` (a modified client sending garbage, or any non-string value), the table lookup simply returns `nil`, so `not data.workers[role]` is true and the handler returns immediately — no crash, no validation function needed.

- [ ] **Step 2: Manually verify hiring and upgrading**

In Studio, Play mode. Command bar (Server context) — set up:

```lua
local PlayerData = require(game.ServerScriptService.Server.PlayerData)
local WorkerService = require(game.ServerScriptService.Server.WorkerService)
local player = game.Players:GetPlayers()[1]
local data = PlayerData.load(player)
data.cash = 500
WorkerService.start()
```

Command bar (Client context) — hire and upgrade:

```lua
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
Remotes.RequestHireWorker:FireServer("Coding")
```

Command bar (Server context) — confirm the hire:

```lua
local PlayerData = require(game.ServerScriptService.Server.PlayerData)
local player = game.Players:GetPlayers()[1]
local data = PlayerData.get(player)
print(data.cash, data.workers.Coding.hired, data.workers.Coding.level)
```

Expected: `350    true    0` (500 - the 150 hire cost).

Command bar (Client context) — upgrade it:

```lua
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
Remotes.RequestUpgradeWorker:FireServer("Coding")
```

Command bar (Server context) — confirm:

```lua
local PlayerData = require(game.ServerScriptService.Server.PlayerData)
local player = game.Players:GetPlayers()[1]
local data = PlayerData.get(player)
print(data.cash, data.workers.Coding.level)
```

Expected: `300    1` (350 - the level-0 upgrade cost of 50).

- [ ] **Step 3: Commit**

```bash
git add src/server/WorkerService.luau
git commit -m "Add WorkerService for hiring and upgrading per-phase Workers"
```

---

### Task 6: Development cycle — server-authoritative phase/round engine

**Files:**
- Create: `src/server/DevelopmentService.luau` (this replaces the entire prior file — same filename, fully new content)

**Interfaces:**
- Consumes: `GameData.Genres`/`Topics`/`Phases`/`RoundsPerPhase`/`CodingRoundSeconds`/`CodingTargetTaps`/`MapBuildingRoundSeconds`/`MapBuildingZoneCenter`/`MapBuildingZoneHalfWidth`/`MapBuildingMaxWaitSeconds`/`TestingMaxWaitSeconds`/`TestingWrongAnswerScore`/`TestingQuestions`/`WorkerAutoCompleteSeconds`/`getWorkerScore`/`getMarkerPosition` (Task 1), `TrendMatch.computeCash` (Task 2), all the Remotes from Task 3, `PlayerData.get` (Task 4), `TrendsService.getCurrent` (already exists, unchanged)
- Produces: `DevelopmentService.start(): ()`, `DevelopmentService.cleanupPlayer(player: Player): ()`

- [ ] **Step 1: Write the implementation**

Replace the full contents of `src/server/DevelopmentService.luau` with:

```lua
local Workspace = game:GetService("Workspace")
local GameData = require(game.ReplicatedStorage.Shared.GameData)
local TrendMatch = require(game.ReplicatedStorage.Shared.TrendMatch)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local PlayerData = require(script.Parent.PlayerData)
local TrendsService = require(script.Parent.TrendsService)

local DevelopmentService = {}

local developing = {}
local activeRounds = {}

local function isValidGenre(genre)
	return table.find(GameData.Genres, genre) ~= nil
end

local function isValidTopic(topic)
	return table.find(GameData.Topics, topic) ~= nil
end

local function runCodingRound(player, roundIndex)
	activeRounds[player.UserId] = { kind = "tap", tapCount = 0 }
	Remotes.RoundStarted:FireClient(player, "Coding", roundIndex, {})
	task.wait(GameData.CodingRoundSeconds)

	local round = activeRounds[player.UserId]
	activeRounds[player.UserId] = nil

	if not round then
		return 0
	end

	return math.clamp(round.tapCount / GameData.CodingTargetTaps, 0, 1)
end

local function runMapBuildingRound(player, roundIndex)
	local startTime = Workspace:GetServerTimeNow()
	activeRounds[player.UserId] = { kind = "timing", placed = false, startTime = startTime }

	Remotes.RoundStarted:FireClient(player, "MapBuilding", roundIndex, {
		startTime = startTime,
		periodSeconds = GameData.MapBuildingRoundSeconds,
	})

	local waited = 0
	while waited < GameData.MapBuildingMaxWaitSeconds do
		local round = activeRounds[player.UserId]
		if not round or round.placed then
			break
		end
		task.wait(0.1)
		waited += 0.1
	end

	local round = activeRounds[player.UserId]
	activeRounds[player.UserId] = nil

	if not round or not round.placed then
		return 0
	end

	local elapsed = round.placementTime - round.startTime
	local markerPosition = GameData.getMarkerPosition(elapsed, GameData.MapBuildingRoundSeconds)
	local distance = math.abs(markerPosition - GameData.MapBuildingZoneCenter)

	if distance > GameData.MapBuildingZoneHalfWidth then
		return 0
	end

	return 1 - (distance / GameData.MapBuildingZoneHalfWidth)
end

local function runTestingRound(player, roundIndex)
	local question = GameData.TestingQuestions[math.random(1, #GameData.TestingQuestions)]
	activeRounds[player.UserId] = { kind = "choice", chosen = false, correctIndex = question.correctIndex }

	Remotes.RoundStarted:FireClient(player, "Testing", roundIndex, {
		prompt = question.prompt,
		options = question.options,
	})

	local waited = 0
	while waited < GameData.TestingMaxWaitSeconds do
		local round = activeRounds[player.UserId]
		if not round or round.chosen then
			break
		end
		task.wait(0.1)
		waited += 0.1
	end

	local round = activeRounds[player.UserId]
	activeRounds[player.UserId] = nil

	if not round or not round.chosen then
		return 0
	end

	if round.chosenIndex == round.correctIndex then
		return 1
	end

	return GameData.TestingWrongAnswerScore
end

local ROUND_RUNNERS = {
	Coding = runCodingRound,
	MapBuilding = runMapBuildingRound,
	Testing = runTestingRound,
}

local function runPhase(player, data, phase)
	local worker = data.workers[phase]

	if worker.hired then
		Remotes.PhaseStarted:FireClient(player, phase, true)
		task.wait(GameData.WorkerAutoCompleteSeconds)
		local score = GameData.getWorkerScore(worker.level)
		Remotes.PhaseComplete:FireClient(player, phase, score)
		return score
	end

	Remotes.PhaseStarted:FireClient(player, phase, false)

	local total = 0
	for roundIndex = 1, GameData.RoundsPerPhase do
		if not player.Parent then
			return 0
		end

		local roundScore = ROUND_RUNNERS[phase](player, roundIndex)
		total += roundScore
		Remotes.RoundComplete:FireClient(player, phase, roundIndex, roundScore)
	end

	local phaseScore = total / GameData.RoundsPerPhase
	Remotes.PhaseComplete:FireClient(player, phase, phaseScore)
	return phaseScore
end

function DevelopmentService.start()
	Remotes.ReportTap.OnServerEvent:Connect(function(player)
		local round = activeRounds[player.UserId]
		if round and round.kind == "tap" then
			round.tapCount += 1
		end
	end)

	Remotes.ReportPlacement.OnServerEvent:Connect(function(player)
		local round = activeRounds[player.UserId]
		if round and round.kind == "timing" and not round.placed then
			round.placed = true
			round.placementTime = Workspace:GetServerTimeNow()
		end
	end)

	Remotes.ReportChoice.OnServerEvent:Connect(function(player, optionIndex)
		local round = activeRounds[player.UserId]
		if round and round.kind == "choice" and not round.chosen then
			round.chosen = true
			round.chosenIndex = optionIndex
		end
	end)

	Remotes.RequestStartDevelopment.OnServerEvent:Connect(function(player, genre, topic)
		if developing[player.UserId] then
			return
		end

		if not isValidGenre(genre) or not isValidTopic(topic) then
			return
		end

		local data = PlayerData.get(player)
		if not data then
			return
		end

		developing[player.UserId] = true

		task.spawn(function()
			local totalQuality = 0

			for _, phase in ipairs(GameData.Phases) do
				if not player.Parent then
					developing[player.UserId] = nil
					return
				end

				totalQuality += runPhase(player, data, phase)
			end

			developing[player.UserId] = nil

			if not player.Parent then
				return
			end

			local devQuality = totalQuality / #GameData.Phases
			local trend1, trend2 = TrendsService.getCurrent()
			local cash, classification, hitBonus = TrendMatch.computeCash(genre, topic, trend1, trend2, devQuality)

			data.cash += cash
			data.gamesReleased += 1

			Remotes.DevelopmentComplete:FireClient(player, cash, classification == "copy", hitBonus)
			Remotes.PlayerStateUpdated:FireClient(player, data)
		end)
	end)
end

function DevelopmentService.cleanupPlayer(player)
	activeRounds[player.UserId] = nil
	developing[player.UserId] = nil
end

return DevelopmentService
```

- [ ] **Step 2: Manually verify a fully-manual development cycle (no Workers hired)**

In Studio, Play mode. Command bar (Server context) — set up and start:

```lua
local PlayerData = require(game.ServerScriptService.Server.PlayerData)
local TrendsService = require(game.ServerScriptService.Server.TrendsService)
local DevelopmentService = require(game.ServerScriptService.Server.DevelopmentService)

local player = game.Players:GetPlayers()[1]
PlayerData.load(player)
TrendsService.start()
DevelopmentService.start()
```

Command bar (Client context) — start developing:

```lua
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
Remotes.RequestStartDevelopment:FireServer("Racing", "Space")
```

Command bar (Client context) — during the Coding phase (within the first ~3 seconds), fire several taps:

```lua
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
for i = 1, 15 do
	Remotes.ReportTap:FireServer()
end
```

Wait for the Map Building phase to start (watch for it — up to ~9 seconds after starting), then fire a placement:

```lua
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
Remotes.ReportPlacement:FireServer()
```

Repeat this 3 times total (once per Map Building round — you'll need to re-run it as each new round starts; timing doesn't need to be exact, any click scores *something*). Then when the Testing phase starts, fire a choice 3 times (once per round):

```lua
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
Remotes.ReportChoice:FireServer(2)
```

After the whole cycle finishes, command bar (Server context):

```lua
local PlayerData = require(game.ServerScriptService.Server.PlayerData)
local player = game.Players:GetPlayers()[1]
print(PlayerData.get(player).cash, PlayerData.get(player).gamesReleased)
```

Expected: `cash` is greater than or equal to `0` (should be well above 0 given full taps and correct Testing answers) and `gamesReleased` is `1`.

- [ ] **Step 3: Manually verify an automated phase (Worker hired)**

Command bar (Server context):

```lua
local PlayerData = require(game.ServerScriptService.Server.PlayerData)
local player = game.Players:GetPlayers()[1]
local data = PlayerData.get(player)
data.workers.Coding.hired = true
data.workers.Coding.level = 5
```

Command bar (Client context):

```lua
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
Remotes.RequestStartDevelopment:FireServer("Horror", "Fantasy")
```

Expected: the Coding phase completes on its own after ~3 seconds with no taps needed (you'll see this in the Output if you print inside a `PhaseComplete` listener, or just note that the whole cycle finishes without you doing anything for the Coding phase specifically — the Map Building and Testing phases still need your manual input as in Step 2, since only Coding has a hired Worker in this test).

- [ ] **Step 4: Commit**

```bash
git add src/server/DevelopmentService.luau
git commit -m "Rewrite DevelopmentService: server-authoritative 3-phase mini-game/Worker engine"
```

---

### Task 7: Lobby — add a Workers ProximityPrompt to the desk

**Files:**
- Modify: `src/server/LobbyBuilder.luau`

**Interfaces:**
- Consumes: nothing new
- Produces: a `ProximityPrompt` named `"WorkersPrompt"` parented to the `MonitorScreen` part

- [ ] **Step 1: Add the ProximityPrompt**

In `src/server/LobbyBuilder.luau`'s `buildDesk` function, right after the line that creates `MonitorScreen` (`local screen = makePart("MonitorScreen", ...)` followed by `screen.CanCollide = false`), add:

```lua
	local workersPrompt = Instance.new("ProximityPrompt")
	workersPrompt.Name = "WorkersPrompt"
	workersPrompt.ActionText = "Manage Workers"
	workersPrompt.ObjectText = "Computer"
	workersPrompt.HoldDuration = 0.5
	workersPrompt.MaxActivationDistance = 10
	workersPrompt.Parent = screen
```

- [ ] **Step 2: Manually verify the prompt appears**

In Studio, Play mode, walk your character up close to the glowing gold monitor screen on the desk. Expected: a "Manage Workers" prompt appears (Roblox's default on-screen ProximityPrompt UI), and holding the interact key (`E` by default) for half a second triggers it (nothing visible happens yet — Task 13 wires up what it opens).

- [ ] **Step 3: Commit**

```bash
git add src/server/LobbyBuilder.luau
git commit -m "Add a Workers ProximityPrompt to the lobby desk's monitor"
```

---

### Task 8: Server bootstrap — swap UpgradeService for WorkerService

**Files:**
- Modify: `src/server/init.server.luau`

**Interfaces:**
- Consumes: `WorkerService.start()` (Task 5), `DevelopmentService.start()`/`cleanupPlayer(player)` (Task 6)
- Produces: nothing new

- [ ] **Step 1: Update the requires and startup calls**

In `src/server/init.server.luau`, replace:

```lua
local UpgradeService = require(script.UpgradeService)
```

with:

```lua
local WorkerService = require(script.WorkerService)
```

and replace:

```lua
UpgradeService.start()
```

with:

```lua
WorkerService.start()
```

- [ ] **Step 2: Add DevelopmentService cleanup on leave**

Still in `src/server/init.server.luau`, find the `Players.PlayerRemoving:Connect(function(player) ... end)` block and add a call to `DevelopmentService.cleanupPlayer` as its first line:

```lua
Players.PlayerRemoving:Connect(function(player)
	DevelopmentService.cleanupPlayer(player)
	PlayerData.save(player)
	PlayerData.remove(player)
end)
```

- [ ] **Step 3: Delete the old UpgradeService file**

`src/server/UpgradeService.luau` is no longer required by anything:

```bash
rm "src/server/UpgradeService.luau"
```

- [ ] **Step 4: Manually verify the server boots cleanly**

In Studio, Play mode (F5). Expected: no errors in the Output window — specifically no "UpgradeService is not a valid member" or similar, confirming the swap is complete and nothing still references the deleted file.

- [ ] **Step 5: Commit**

```bash
git add -A src/server/init.server.luau src/server/UpgradeService.luau
git commit -m "Server bootstrap: replace UpgradeService with WorkerService, clean up rounds on leave"
```

---

### Task 9: Client UI shell — remove the old bar/upgrades, add phase routing

**Files:**
- Create: `src/client/UI.luau` (replaces the entire prior file — same filename, fully new content)

**Interfaces:**
- Consumes: `GameData.Genres`/`Topics`/`RoundsPerPhase` (Task 1), all Remotes from Task 3, `CodingGame`/`MapBuildingGame`/`TestingGame`/`WorkersPanel` modules (Tasks 10-13, — this task creates the calls that will fail to `require` until those files exist; that's expected and fine, since a later task in the same review pass creates them — note this dependency in your report if you implement Task 9 before 10-13)
- Produces: `UI.init(): ()` (unchanged export), plus exposes `UI.Theme`, `UI.addCorner`, `UI.addStroke`, `UI.addGradient`, `UI.addHoverFeedback`, `UI.makeButton` as module-level fields so the mini-game/Workers modules can reuse the same visual style without duplicating the helper functions

- [ ] **Step 1: Write the implementation**

Replace the full contents of `src/client/UI.luau` with:

```lua
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local GameData = require(game.ReplicatedStorage.Shared.GameData)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)

local UI = {}

local selectedGenre = nil
local selectedTopic = nil
local playerState = {
	cash = 0,
	gamesReleased = 0,
	workers = {
		Coding = { hired = false, level = 0 },
		MapBuilding = { hired = false, level = 0 },
		Testing = { hired = false, level = 0 },
	},
}

local Theme = {
	Panel = Color3.fromRGB(36, 27, 54),
	PanelLight = Color3.fromRGB(46, 35, 68),
	Neutral = Color3.fromRGB(46, 36, 66),
	NeutralHover = Color3.fromRGB(58, 46, 82),
	Accent = Color3.fromRGB(140, 92, 255),
	AccentDeep = Color3.fromRGB(108, 66, 214),
	Gold = Color3.fromRGB(255, 209, 102),
	Success = Color3.fromRGB(92, 255, 176),
	Danger = Color3.fromRGB(255, 92, 122),
	Text = Color3.fromRGB(240, 238, 250),
	TextMuted = Color3.fromRGB(178, 168, 205),
}

UI.Theme = Theme

local function addCorner(instance, radius)
	instance.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = instance
	return corner
end

local function addStroke(instance, color, thickness, transparency)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.Transparency = transparency or 0
	stroke.Parent = instance
	return stroke
end

local function addGradient(instance, colorA, colorB, rotation)
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(colorA, colorB)
	gradient.Rotation = rotation or 90
	gradient.Parent = instance
	return gradient
end

local function addHoverFeedback(button, baseColor, hoverColor)
	button.MouseEnter:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.12), { BackgroundColor3 = hoverColor }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.12), { BackgroundColor3 = baseColor }):Play()
	end)
end

local function makeButton(parent, layoutOrder, text, size, textSize)
	local button = Instance.new("TextButton")
	button.Name = text
	button.Text = text
	button.Size = size
	button.LayoutOrder = layoutOrder
	button.BackgroundColor3 = Theme.Neutral
	button.TextColor3 = Theme.Text
	button.Font = Enum.Font.FredokaOne
	button.TextSize = textSize or 18
	button.TextWrapped = true
	button.AutoButtonColor = false
	button.Parent = parent
	addCorner(button, 10)
	addStroke(button, Color3.fromRGB(255, 255, 255), 1, 0.85)
	return button
end

UI.addCorner = addCorner
UI.addStroke = addStroke
UI.addGradient = addGradient
UI.addHoverFeedback = addHoverFeedback
UI.makeButton = makeButton

function UI.init()
	local player = Players.LocalPlayer
	local CodingGame = require(script.Parent.CodingGame)
	local MapBuildingGame = require(script.Parent.MapBuildingGame)
	local TestingGame = require(script.Parent.TestingGame)
	local WorkersPanel = require(script.Parent.WorkersPanel)

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "GameDevTycoonUI"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = player:WaitForChild("PlayerGui")

	local cashPill = Instance.new("Frame")
	cashPill.Name = "CashPill"
	cashPill.Size = UDim2.fromOffset(170, 44)
	cashPill.Position = UDim2.fromOffset(20, 20)
	cashPill.BackgroundColor3 = Theme.Gold
	cashPill.Parent = screenGui
	addCorner(cashPill, 22)
	addStroke(cashPill, Color3.fromRGB(255, 255, 255), 1, 0.7)
	addGradient(cashPill, Color3.fromRGB(255, 224, 148), Color3.fromRGB(255, 191, 71), 90)

	local cashLabel = Instance.new("TextLabel")
	cashLabel.Name = "CashLabel"
	cashLabel.Text = "\240\159\146\176 $0"
	cashLabel.Size = UDim2.fromScale(1, 1)
	cashLabel.BackgroundTransparency = 1
	cashLabel.TextColor3 = Color3.fromRGB(60, 40, 10)
	cashLabel.Font = Enum.Font.FredokaOne
	cashLabel.TextSize = 22
	cashLabel.Parent = cashPill

	local mainFrame = Instance.new("Frame")
	mainFrame.Name = "MainFrame"
	mainFrame.Size = UDim2.fromOffset(460, 560)
	mainFrame.Position = UDim2.fromOffset(20, 80)
	mainFrame.BackgroundColor3 = Theme.Panel
	mainFrame.Parent = screenGui
	addCorner(mainFrame, 18)
	addStroke(mainFrame, Theme.Accent, 2, 0.4)
	addGradient(mainFrame, Theme.PanelLight, Theme.Panel, 90)

	local mainPadding = Instance.new("UIPadding")
	mainPadding.PaddingTop = UDim.new(0, 16)
	mainPadding.PaddingBottom = UDim.new(0, 16)
	mainPadding.PaddingLeft = UDim.new(0, 16)
	mainPadding.PaddingRight = UDim.new(0, 16)
	mainPadding.Parent = mainFrame

	local mainLayout = Instance.new("UIListLayout")
	mainLayout.FillDirection = Enum.FillDirection.Vertical
	mainLayout.Padding = UDim.new(0, 10)
	mainLayout.SortOrder = Enum.SortOrder.LayoutOrder
	mainLayout.Parent = mainFrame

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Text = "\240\159\142\174 Game Studio"
	titleLabel.Size = UDim2.new(1, 0, 0, 32)
	titleLabel.LayoutOrder = 1
	titleLabel.BackgroundTransparency = 1
	titleLabel.TextColor3 = Theme.Text
	titleLabel.Font = Enum.Font.FredokaOne
	titleLabel.TextSize = 26
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = mainFrame

	local trendsCard = Instance.new("Frame")
	trendsCard.Size = UDim2.new(1, 0, 0, 56)
	trendsCard.LayoutOrder = 2
	trendsCard.BackgroundColor3 = Color3.fromRGB(58, 32, 20)
	trendsCard.Parent = mainFrame
	addCorner(trendsCard, 12)
	addStroke(trendsCard, Color3.fromRGB(255, 158, 66), 2, 0.2)
	addGradient(trendsCard, Color3.fromRGB(72, 40, 24), Color3.fromRGB(48, 26, 16), 90)

	local trendsEyebrow = Instance.new("TextLabel")
	trendsEyebrow.Text = "\240\159\148\165 TRENDING NOW"
	trendsEyebrow.Size = UDim2.new(1, -16, 0, 16)
	trendsEyebrow.Position = UDim2.fromOffset(8, 4)
	trendsEyebrow.BackgroundTransparency = 1
	trendsEyebrow.TextColor3 = Color3.fromRGB(255, 158, 66)
	trendsEyebrow.Font = Enum.Font.GothamBold
	trendsEyebrow.TextSize = 12
	trendsEyebrow.TextXAlignment = Enum.TextXAlignment.Left
	trendsEyebrow.Parent = trendsCard

	local trendsLabel = Instance.new("TextLabel")
	trendsLabel.Name = "TrendsLabel"
	trendsLabel.Text = "Loading..."
	trendsLabel.Size = UDim2.new(1, -16, 0, 28)
	trendsLabel.Position = UDim2.fromOffset(8, 22)
	trendsLabel.BackgroundTransparency = 1
	trendsLabel.TextColor3 = Theme.Text
	trendsLabel.Font = Enum.Font.GothamMedium
	trendsLabel.TextSize = 15
	trendsLabel.TextXAlignment = Enum.TextXAlignment.Left
	trendsLabel.TextWrapped = true
	trendsLabel.Parent = trendsCard

	local genreLabel = Instance.new("TextLabel")
	genreLabel.Text = "GENRE"
	genreLabel.Size = UDim2.new(1, 0, 0, 18)
	genreLabel.LayoutOrder = 3
	genreLabel.BackgroundTransparency = 1
	genreLabel.TextColor3 = Theme.TextMuted
	genreLabel.Font = Enum.Font.GothamBold
	genreLabel.TextSize = 12
	genreLabel.TextXAlignment = Enum.TextXAlignment.Left
	genreLabel.Parent = mainFrame

	local genreRow = Instance.new("Frame")
	genreRow.Size = UDim2.new(1, 0, 0, 36)
	genreRow.LayoutOrder = 4
	genreRow.BackgroundTransparency = 1
	genreRow.Parent = mainFrame

	local genreRowLayout = Instance.new("UIListLayout")
	genreRowLayout.FillDirection = Enum.FillDirection.Horizontal
	genreRowLayout.Padding = UDim.new(0, 8)
	genreRowLayout.SortOrder = Enum.SortOrder.LayoutOrder
	genreRowLayout.Parent = genreRow

	local genreButtons = {}
	for i, genre in ipairs(GameData.Genres) do
		local button = makeButton(genreRow, i, genre, UDim2.new(0.25, -6, 1, 0), 15)
		genreButtons[genre] = button
		button.MouseButton1Click:Connect(function()
			selectedGenre = genre
			for name, btn in pairs(genreButtons) do
				btn.BackgroundColor3 = (name == genre) and Theme.Accent or Theme.Neutral
			end
		end)
	end

	local topicLabel = Instance.new("TextLabel")
	topicLabel.Text = "TOPIC"
	topicLabel.Size = UDim2.new(1, 0, 0, 18)
	topicLabel.LayoutOrder = 5
	topicLabel.BackgroundTransparency = 1
	topicLabel.TextColor3 = Theme.TextMuted
	topicLabel.Font = Enum.Font.GothamBold
	topicLabel.TextSize = 12
	topicLabel.TextXAlignment = Enum.TextXAlignment.Left
	topicLabel.Parent = mainFrame

	local topicRow = Instance.new("Frame")
	topicRow.Size = UDim2.new(1, 0, 0, 36)
	topicRow.LayoutOrder = 6
	topicRow.BackgroundTransparency = 1
	topicRow.Parent = mainFrame

	local topicRowLayout = Instance.new("UIListLayout")
	topicRowLayout.FillDirection = Enum.FillDirection.Horizontal
	topicRowLayout.Padding = UDim.new(0, 8)
	topicRowLayout.SortOrder = Enum.SortOrder.LayoutOrder
	topicRowLayout.Parent = topicRow

	local topicButtons = {}
	for i, topic in ipairs(GameData.Topics) do
		local button = makeButton(topicRow, i, topic, UDim2.new(0.25, -6, 1, 0), 15)
		topicButtons[topic] = button
		button.MouseButton1Click:Connect(function()
			selectedTopic = topic
			for name, btn in pairs(topicButtons) do
				btn.BackgroundColor3 = (name == topic) and Theme.Accent or Theme.Neutral
			end
		end)
	end

	local startButton = makeButton(mainFrame, 7, "\240\159\154\128 Start Developing", UDim2.new(1, 0, 0, 48), 20)
	startButton.BackgroundColor3 = Theme.Accent
	addGradient(startButton, Color3.fromRGB(163, 110, 255), Color3.fromRGB(120, 74, 220), 90)
	addHoverFeedback(startButton, Theme.Accent, Theme.AccentDeep)

	local phaseLabel = Instance.new("TextLabel")
	phaseLabel.Text = ""
	phaseLabel.Size = UDim2.new(1, 0, 0, 20)
	phaseLabel.LayoutOrder = 8
	phaseLabel.BackgroundTransparency = 1
	phaseLabel.TextColor3 = Theme.TextMuted
	phaseLabel.Font = Enum.Font.GothamBold
	phaseLabel.TextSize = 13
	phaseLabel.TextXAlignment = Enum.TextXAlignment.Left
	phaseLabel.Parent = mainFrame

	local phaseArea = Instance.new("Frame")
	phaseArea.Name = "PhaseArea"
	phaseArea.Size = UDim2.new(1, 0, 0, 160)
	phaseArea.LayoutOrder = 9
	phaseArea.BackgroundColor3 = Theme.Neutral
	phaseArea.Parent = mainFrame
	addCorner(phaseArea, 12)

	local statusLabel = Instance.new("TextLabel")
	statusLabel.Text = ""
	statusLabel.Size = UDim2.new(1, 0, 0, 24)
	statusLabel.LayoutOrder = 10
	statusLabel.BackgroundTransparency = 1
	statusLabel.TextColor3 = Theme.TextMuted
	statusLabel.Font = Enum.Font.GothamMedium
	statusLabel.TextSize = 15
	statusLabel.TextXAlignment = Enum.TextXAlignment.Left
	statusLabel.Parent = mainFrame

	local workerMessageLabel = Instance.new("TextLabel")
	workerMessageLabel.Name = "WorkerMessage"
	workerMessageLabel.Text = ""
	workerMessageLabel.Size = UDim2.fromScale(1, 1)
	workerMessageLabel.BackgroundTransparency = 1
	workerMessageLabel.TextColor3 = Theme.Text
	workerMessageLabel.Font = Enum.Font.GothamMedium
	workerMessageLabel.TextSize = 16
	workerMessageLabel.TextWrapped = true
	workerMessageLabel.Visible = false
	workerMessageLabel.Parent = phaseArea

	CodingGame.init(phaseArea, Theme)
	MapBuildingGame.init(phaseArea, Theme)
	TestingGame.init(phaseArea, Theme)

	local function hideAllPhaseUI()
		workerMessageLabel.Visible = false
		CodingGame.hide()
		MapBuildingGame.hide()
		TestingGame.hide()
	end

	hideAllPhaseUI()

	local PHASE_DISPLAY_NAMES = {
		Coding = "Coding",
		MapBuilding = "Map Building",
		Testing = "Testing",
	}

	Remotes.PhaseStarted.OnClientEvent:Connect(function(phase, isAutomated)
		hideAllPhaseUI()
		if isAutomated then
			phaseLabel.Text = ("%s \226\128\148 your worker is on it"):format(PHASE_DISPLAY_NAMES[phase])
			workerMessageLabel.Text = ("\240\159\164\150 Your %s worker is working..."):format(PHASE_DISPLAY_NAMES[phase])
			workerMessageLabel.Visible = true
		else
			phaseLabel.Text = PHASE_DISPLAY_NAMES[phase]
		end
	end)

	Remotes.RoundStarted.OnClientEvent:Connect(function(phase, roundIndex, roundData)
		phaseLabel.Text = ("%s \226\128\148 round %d/%d"):format(PHASE_DISPLAY_NAMES[phase], roundIndex, GameData.RoundsPerPhase)
		if phase == "Coding" then
			CodingGame.startRound()
		elseif phase == "MapBuilding" then
			MapBuildingGame.startRound(roundData.startTime, roundData.periodSeconds)
		elseif phase == "Testing" then
			TestingGame.startRound(roundData.prompt, roundData.options)
		end
	end)

	Remotes.RoundComplete.OnClientEvent:Connect(function(phase, roundIndex, score)
		statusLabel.Text = ("Round %d: %d%%"):format(roundIndex, math.floor(score * 100 + 0.5))
		statusLabel.TextColor3 = Theme.TextMuted
	end)

	Remotes.PhaseComplete.OnClientEvent:Connect(function(phase, score)
		hideAllPhaseUI()
		phaseLabel.Text = ("%s complete: %d%%"):format(PHASE_DISPLAY_NAMES[phase], math.floor(score * 100 + 0.5))
	end)

	local developing = false
	local developSequence = 0

	startButton.MouseButton1Click:Connect(function()
		if developing then
			return
		end

		if not selectedGenre or not selectedTopic then
			statusLabel.Text = "Pick a Genre and a Topic first!"
			statusLabel.TextColor3 = Theme.Danger
			return
		end

		developing = true
		developSequence += 1
		local mySequence = developSequence
		statusLabel.Text = ""
		phaseLabel.Text = "Starting..."
		Remotes.RequestStartDevelopment:FireServer(selectedGenre, selectedTopic)

		task.delay(90, function()
			if developing and mySequence == developSequence then
				developing = false
				hideAllPhaseUI()
				phaseLabel.Text = ""
				statusLabel.Text = "Something went wrong -- try again."
				statusLabel.TextColor3 = Theme.Danger
			end
		end)
	end)

	Remotes.DevelopmentComplete.OnClientEvent:Connect(function(cash, wasCopy, hitBonus)
		developing = false
		hideAllPhaseUI()
		phaseLabel.Text = ""

		if wasCopy then
			statusLabel.Text = "That was a copy! Earned $0."
			statusLabel.TextColor3 = Theme.Danger
		elseif hitBonus then
			statusLabel.Text = ("\240\159\148\165 TRENDY HIT! Earned $%d!"):format(cash)
			statusLabel.TextColor3 = Theme.Success
		else
			statusLabel.Text = ("Released! Earned $%d."):format(cash)
			statusLabel.TextColor3 = Theme.Gold
		end
	end)

	Remotes.PlayerStateUpdated.OnClientEvent:Connect(function(data)
		playerState.cash = data.cash
		playerState.gamesReleased = data.gamesReleased
		playerState.workers = data.workers
		cashLabel.Text = ("\240\159\146\176 $%d"):format(playerState.cash)
	end)

	Remotes.TrendsUpdated.OnClientEvent:Connect(function(trend1, trend2)
		trendsLabel.Text = ("%s + %s    %s + %s"):format(
			trend1.genre, trend1.topic, trend2.genre, trend2.topic
		)
	end)

	WorkersPanel.init(player, Theme, playerState)
end

return UI
```

Note the 90-second safety timeout on the Start button: worst case is all 3 phases played manually (Coding 3×3s=9s, Map Building 3×4s=12s, Testing 3×15s=45s ≈ 66s total) — 90 seconds gives comfortable headroom. The `developSequence` generation-counter guard is the same pattern used previously in this project to stop a stale timeout from misfiring during a later, healthy cycle.

- [ ] **Step 2: Commit**

This task's code `require`s modules that don't exist yet (Tasks 10-13) — that's expected. Commit anyway; the review for this task should focus on the UI shell logic itself (phase/round routing, the safety timeout, remote wiring), not on running it in Studio yet (that only becomes possible once Tasks 10-13 land).

```bash
git add src/client/UI.luau
git commit -m "Rewrite UI shell: remove progress bar/upgrades, add phase/round routing"
```

---

### Task 10: Coding mini-game (tap challenge)

**Files:**
- Create: `src/client/CodingGame.luau`

**Interfaces:**
- Consumes: `Remotes.ReportTap` (Task 3)
- Produces: `CodingGame.init(parent: Frame, theme: table): ()`, `CodingGame.startRound(): ()`, `CodingGame.hide(): ()`

- [ ] **Step 1: Write the implementation**

Create `src/client/CodingGame.luau`:

```lua
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)

local CodingGame = {}

local container
local counterLabel
local tapCount = 0
local roundActive = false

function CodingGame.init(parent, theme)
	container = Instance.new("Frame")
	container.Name = "CodingGame"
	container.Size = UDim2.fromScale(1, 1)
	container.BackgroundTransparency = 1
	container.Visible = false
	container.Parent = parent

	counterLabel = Instance.new("TextLabel")
	counterLabel.Size = UDim2.new(1, 0, 0, 28)
	counterLabel.Position = UDim2.fromOffset(0, 8)
	counterLabel.BackgroundTransparency = 1
	counterLabel.Text = "Taps: 0"
	counterLabel.Font = Enum.Font.FredokaOne
	counterLabel.TextSize = 20
	counterLabel.TextColor3 = theme.Text
	counterLabel.Parent = container

	local tapButton = Instance.new("TextButton")
	tapButton.Size = UDim2.fromOffset(140, 90)
	tapButton.Position = UDim2.new(0.5, -70, 0, 48)
	tapButton.BackgroundColor3 = theme.Accent
	tapButton.Text = "\240\159\146\187 TAP!"
	tapButton.Font = Enum.Font.FredokaOne
	tapButton.TextSize = 22
	tapButton.TextColor3 = theme.Text
	tapButton.AutoButtonColor = false
	tapButton.BorderSizePixel = 0
	tapButton.Parent = container

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = tapButton

	tapButton.MouseButton1Click:Connect(function()
		if not roundActive then
			return
		end
		tapCount += 1
		counterLabel.Text = ("Taps: %d"):format(tapCount)
		Remotes.ReportTap:FireServer()
	end)
end

function CodingGame.startRound()
	tapCount = 0
	roundActive = true
	counterLabel.Text = "Taps: 0"
	container.Visible = true
end

function CodingGame.hide()
	roundActive = false
	if container then
		container.Visible = false
	end
end

return CodingGame
```

- [ ] **Step 2: Manually verify (once Tasks 9-13 all land together, per Task 14's playtest)**

This module has no standalone Studio playtest step of its own — Task 14's end-to-end playtest is where the full client (Tasks 9-13) gets exercised together, since `UI.luau` (Task 9) is what actually calls `CodingGame.init`/`startRound`. For this task's own gate, verify by code-reading: `roundActive` starts `false` so stray clicks before a round begins are ignored; `startRound` resets `tapCount` to 0 and shows the container; `hide` sets `roundActive = false` so a click during the brief window between phases can't sneak in an extra counted tap.

- [ ] **Step 3: Commit**

```bash
git add src/client/CodingGame.luau
git commit -m "Add Coding mini-game (tap challenge) client module"
```

---

### Task 11: Map Building mini-game (timing bar)

**Files:**
- Create: `src/client/MapBuildingGame.luau`

**Interfaces:**
- Consumes: `GameData.getMarkerPosition`/`MapBuildingZoneCenter`/`MapBuildingZoneHalfWidth` (Task 1), `Remotes.ReportPlacement` (Task 3)
- Produces: `MapBuildingGame.init(parent: Frame, theme: table): ()`, `MapBuildingGame.startRound(startTime: number, periodSeconds: number): ()`, `MapBuildingGame.hide(): ()`

- [ ] **Step 1: Write the implementation**

Create `src/client/MapBuildingGame.luau`:

```lua
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local GameData = require(game.ReplicatedStorage.Shared.GameData)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)

local MapBuildingGame = {}

local container
local marker
local placeButton
local renderConnection
local roundStartTime
local roundPeriod
local placed = false

function MapBuildingGame.init(parent, theme)
	container = Instance.new("Frame")
	container.Name = "MapBuildingGame"
	container.Size = UDim2.fromScale(1, 1)
	container.BackgroundTransparency = 1
	container.Visible = false
	container.Parent = parent

	local track = Instance.new("Frame")
	track.Size = UDim2.new(1, -32, 0, 24)
	track.Position = UDim2.new(0, 16, 0, 40)
	track.BackgroundColor3 = theme.Panel
	track.BorderSizePixel = 0
	track.Parent = container

	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = UDim.new(0, 12)
	trackCorner.Parent = track

	local zoneWidthScale = GameData.MapBuildingZoneHalfWidth * 2
	local zoneHighlight = Instance.new("Frame")
	zoneHighlight.Size = UDim2.new(zoneWidthScale, 0, 1, 0)
	zoneHighlight.Position = UDim2.new(GameData.MapBuildingZoneCenter - GameData.MapBuildingZoneHalfWidth, 0, 0, 0)
	zoneHighlight.BackgroundColor3 = theme.Success
	zoneHighlight.BackgroundTransparency = 0.5
	zoneHighlight.BorderSizePixel = 0
	zoneHighlight.Parent = track

	marker = Instance.new("Frame")
	marker.Size = UDim2.fromOffset(6, 32)
	marker.AnchorPoint = Vector2.new(0.5, 0.5)
	marker.Position = UDim2.new(0, 0, 0.5, 0)
	marker.BackgroundColor3 = theme.Gold
	marker.BorderSizePixel = 0
	marker.Parent = track

	placeButton = Instance.new("TextButton")
	placeButton.Size = UDim2.new(1, -32, 0, 40)
	placeButton.Position = UDim2.new(0, 16, 0, 84)
	placeButton.BackgroundColor3 = theme.Accent
	placeButton.Text = "\240\159\147\141 Place It!"
	placeButton.Font = Enum.Font.FredokaOne
	placeButton.TextSize = 18
	placeButton.TextColor3 = theme.Text
	placeButton.AutoButtonColor = false
	placeButton.BorderSizePixel = 0
	placeButton.Parent = container

	local placeCorner = Instance.new("UICorner")
	placeCorner.CornerRadius = UDim.new(0, 10)
	placeCorner.Parent = placeButton

	placeButton.MouseButton1Click:Connect(function()
		if placed then
			return
		end
		placed = true
		Remotes.ReportPlacement:FireServer()
	end)
end

function MapBuildingGame.startRound(startTime, periodSeconds)
	roundStartTime = startTime
	roundPeriod = periodSeconds
	placed = false
	container.Visible = true

	if renderConnection then
		renderConnection:Disconnect()
	end

	renderConnection = RunService.RenderStepped:Connect(function()
		local elapsed = Workspace:GetServerTimeNow() - roundStartTime
		local position = GameData.getMarkerPosition(elapsed, roundPeriod)
		marker.Position = UDim2.new(position, 0, 0.5, 0)
	end)
end

function MapBuildingGame.hide()
	if renderConnection then
		renderConnection:Disconnect()
		renderConnection = nil
	end
	if container then
		container.Visible = false
	end
end

return MapBuildingGame
```

- [ ] **Step 2: Verify by code reading**

Confirm `marker.Position` is driven every frame by `GameData.getMarkerPosition` — the exact same function the server uses to score a placement — so what the player sees matches what the server will judge (purely visual/cosmetic on the client; the server never trusts this rendering, only the click timestamp it receives). Confirm `hide()` disconnects `renderConnection` so no `RenderStepped` connection leaks once the round ends or a phase completes early.

- [ ] **Step 3: Commit**

```bash
git add src/client/MapBuildingGame.luau
git commit -m "Add Map Building mini-game (timing bar) client module"
```

---

### Task 12: Testing mini-game (multiple choice)

**Files:**
- Create: `src/client/TestingGame.luau`

**Interfaces:**
- Consumes: `Remotes.ReportChoice` (Task 3)
- Produces: `TestingGame.init(parent: Frame, theme: table): ()`, `TestingGame.startRound(prompt: string, options: {string}): ()`, `TestingGame.hide(): ()`

- [ ] **Step 1: Write the implementation**

Create `src/client/TestingGame.luau`:

```lua
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)

local TestingGame = {}

local container
local promptLabel
local optionButtons = {}
local answered = false

function TestingGame.init(parent, theme)
	container = Instance.new("Frame")
	container.Name = "TestingGame"
	container.Size = UDim2.fromScale(1, 1)
	container.BackgroundTransparency = 1
	container.Visible = false
	container.Parent = parent

	promptLabel = Instance.new("TextLabel")
	promptLabel.Size = UDim2.new(1, -24, 0, 60)
	promptLabel.Position = UDim2.fromOffset(12, 8)
	promptLabel.BackgroundTransparency = 1
	promptLabel.Text = ""
	promptLabel.Font = Enum.Font.GothamMedium
	promptLabel.TextSize = 15
	promptLabel.TextWrapped = true
	promptLabel.TextColor3 = theme.Text
	promptLabel.Parent = container

	for i = 1, 2 do
		local button = Instance.new("TextButton")
		button.Size = UDim2.new(1, -24, 0, 36)
		button.Position = UDim2.fromOffset(12, 70 + (i - 1) * 44)
		button.BackgroundColor3 = theme.Neutral
		button.Text = ""
		button.Font = Enum.Font.GothamMedium
		button.TextSize = 14
		button.TextWrapped = true
		button.TextColor3 = theme.Text
		button.AutoButtonColor = false
		button.BorderSizePixel = 0
		button.Parent = container

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10)
		corner.Parent = button

		button.MouseButton1Click:Connect(function()
			if answered then
				return
			end
			answered = true
			Remotes.ReportChoice:FireServer(i)
		end)

		optionButtons[i] = button
	end
end

function TestingGame.startRound(prompt, options)
	answered = false
	promptLabel.Text = prompt
	for i, button in ipairs(optionButtons) do
		button.Text = options[i] or ""
	end
	container.Visible = true
end

function TestingGame.hide()
	if container then
		container.Visible = false
	end
end

return TestingGame
```

- [ ] **Step 2: Verify by code reading**

Confirm each option button's click handler captures its own loop-local `i` (1 or 2) correctly (Luau's `for i = 1, 2 do local button = ...; button.MouseButton1Click:Connect(function() ... i ... end) end` — each iteration's `i` is a fresh local, so the closures don't all end up sharing the final value of `i`). Confirm `answered` blocks a second click in the same round from firing a second `ReportChoice`.

- [ ] **Step 3: Commit**

```bash
git add src/client/TestingGame.luau
git commit -m "Add Testing mini-game (multiple choice) client module"
```

---

### Task 13: Workers panel + desk prompt wiring

**Files:**
- Create: `src/client/WorkersPanel.luau`

**Interfaces:**
- Consumes: `GameData.Phases`/`WorkerHireCost`/`getWorkerUpgradeCost` (Task 1), `Remotes.RequestHireWorker`/`RequestUpgradeWorker`/`WorkerActionResult`/`PlayerStateUpdated` (Task 3), the `"WorkersPrompt"` ProximityPrompt (Task 7)
- Produces: `WorkersPanel.init(player: Player, theme: table, playerState: table): ()`

- [ ] **Step 1: Write the implementation**

Create `src/client/WorkersPanel.luau`:

```lua
local ProximityPromptService = game:GetService("ProximityPromptService")
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local GameData = require(game.ReplicatedStorage.Shared.GameData)

local WorkersPanel = {}

local ROLE_DISPLAY_NAMES = {
	Coding = "\226\154\161 Coding",
	MapBuilding = "\240\159\151\186\239\184\143 Map Building",
	Testing = "\226\156\168 Testing",
}

function WorkersPanel.init(player, theme, playerState)
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "WorkersPanelGui"
	screenGui.ResetOnSpawn = false
	screenGui.Enabled = false
	screenGui.Parent = player:WaitForChild("PlayerGui")

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromOffset(360, 320)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.BackgroundColor3 = theme.Panel
	frame.BorderSizePixel = 0
	frame.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 18)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = theme.Accent
	stroke.Thickness = 2
	stroke.Transparency = 0.4
	stroke.Parent = frame

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 16)
	padding.PaddingBottom = UDim.new(0, 16)
	padding.PaddingLeft = UDim.new(0, 16)
	padding.PaddingRight = UDim.new(0, 16)
	padding.Parent = frame

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = frame

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Text = "\240\159\145\183 Workers"
	titleLabel.Size = UDim2.new(1, 0, 0, 30)
	titleLabel.LayoutOrder = 1
	titleLabel.BackgroundTransparency = 1
	titleLabel.TextColor3 = theme.Text
	titleLabel.Font = Enum.Font.FredokaOne
	titleLabel.TextSize = 24
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = frame

	local roleRows = {}

	for i, role in ipairs(GameData.Phases) do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 60)
		row.LayoutOrder = i + 1
		row.BackgroundColor3 = theme.Neutral
		row.BorderSizePixel = 0
		row.Parent = frame

		local rowCorner = Instance.new("UICorner")
		rowCorner.CornerRadius = UDim.new(0, 10)
		rowCorner.Parent = row

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Text = ROLE_DISPLAY_NAMES[role]
		nameLabel.Size = UDim2.new(0.5, 0, 1, 0)
		nameLabel.Position = UDim2.fromOffset(10, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.TextColor3 = theme.Text
		nameLabel.Font = Enum.Font.FredokaOne
		nameLabel.TextSize = 16
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Parent = row

		local actionButton = Instance.new("TextButton")
		actionButton.Size = UDim2.new(0.42, 0, 0, 40)
		actionButton.Position = UDim2.new(0.56, 0, 0.5, -20)
		actionButton.BackgroundColor3 = theme.Accent
		actionButton.TextColor3 = theme.Text
		actionButton.Font = Enum.Font.FredokaOne
		actionButton.TextSize = 14
		actionButton.TextWrapped = true
		actionButton.AutoButtonColor = false
		actionButton.BorderSizePixel = 0
		actionButton.Parent = row

		local actionCorner = Instance.new("UICorner")
		actionCorner.CornerRadius = UDim.new(0, 8)
		actionCorner.Parent = actionButton

		actionButton.MouseButton1Click:Connect(function()
			local worker = playerState.workers[role]
			if worker.hired then
				Remotes.RequestUpgradeWorker:FireServer(role)
			else
				Remotes.RequestHireWorker:FireServer(role)
			end
		end)

		roleRows[role] = actionButton
	end

	local statusLabel = Instance.new("TextLabel")
	statusLabel.Text = ""
	statusLabel.Size = UDim2.new(1, 0, 0, 20)
	statusLabel.LayoutOrder = 9
	statusLabel.BackgroundTransparency = 1
	statusLabel.TextColor3 = theme.Danger
	statusLabel.Font = Enum.Font.GothamMedium
	statusLabel.TextSize = 13
	statusLabel.TextXAlignment = Enum.TextXAlignment.Left
	statusLabel.Parent = frame

	local closeButton = Instance.new("TextButton")
	closeButton.Text = "Close"
	closeButton.Size = UDim2.new(1, 0, 0, 32)
	closeButton.LayoutOrder = 10
	closeButton.BackgroundColor3 = theme.Neutral
	closeButton.TextColor3 = theme.Text
	closeButton.Font = Enum.Font.FredokaOne
	closeButton.TextSize = 16
	closeButton.AutoButtonColor = false
	closeButton.BorderSizePixel = 0
	closeButton.Parent = frame

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 10)
	closeCorner.Parent = closeButton

	closeButton.MouseButton1Click:Connect(function()
		screenGui.Enabled = false
	end)

	local function refresh()
		for role, actionButton in pairs(roleRows) do
			local worker = playerState.workers[role]
			if worker.hired then
				actionButton.Text = ("Upgrade\nLv%d \194\183 $%d"):format(worker.level, GameData.getWorkerUpgradeCost(worker.level))
			else
				actionButton.Text = ("Hire\n$%d"):format(GameData.WorkerHireCost)
			end
		end
	end

	refresh()

	Remotes.PlayerStateUpdated.OnClientEvent:Connect(function()
		statusLabel.Text = ""
		refresh()
	end)

	Remotes.WorkerActionResult.OnClientEvent:Connect(function(role, action, success)
		if not success then
			statusLabel.Text = ("Not enough cash to %s the %s worker!"):format(action, role)
		end
	end)

	ProximityPromptService.PromptTriggered:Connect(function(prompt, triggeringPlayer)
		if triggeringPlayer == player and prompt.Name == "WorkersPrompt" then
			screenGui.Enabled = true
			statusLabel.Text = ""
			refresh()
		end
	end)
end

return WorkersPanel
```

This relies on `UI.luau` (Task 9) registering its own `Remotes.PlayerStateUpdated` listener (which updates `playerState.workers` to the freshly-received table) *before* calling `WorkersPanel.init(...)` — confirm this ordering holds in the final `UI.luau` (the `Remotes.PlayerStateUpdated.OnClientEvent:Connect(...)` block appears above the `WorkersPanel.init(player, Theme, playerState)` line), since Roblox fires multiple listeners on the same event in the order they were connected — otherwise this module's `refresh()` would read one-event-stale worker data.

- [ ] **Step 2: Verify by code reading**

Confirm `playerState.workers[role]` is read fresh inside `refresh()` and inside the click handler (not cached at `init` time), so it reflects whatever `UI.luau`'s `PlayerStateUpdated` handler most recently assigned to `playerState.workers`.

- [ ] **Step 3: Commit**

```bash
git add src/client/WorkersPanel.luau
git commit -m "Add Workers panel UI, opened via the lobby desk's ProximityPrompt"
```

---

### Task 14: End-to-end integration playtest

**Files:** none (verification only)

**Interfaces:** none — this task exercises everything from Tasks 1-13 together

- [ ] **Step 1: Full manual-play loop**

In Studio, Play Solo (F5). Checklist:

- Pick a Genre and Topic, hit Start Developing
- Coding phase appears with a tap counter and TAP! button — tap rapidly for ~3 seconds across 3 rounds, see round scores appear between rounds
- Map Building phase appears with a moving marker and a green zone — click "Place It!" near the marker's center a few times across 3 rounds
- Testing phase appears with a question and 2 options — pick one each round across 3 rounds
- After all 3 phases, a final Released/TRENDY HIT/Copy message appears with a Cash amount, and the Cash pill updates
- Repeat 2-3 times, confirm Cash accumulates

- [ ] **Step 2: Worker hire/upgrade loop**

- Walk to the desk, confirm the "Manage Workers" prompt appears near the monitor and holding E opens the Workers panel
- Hire the Coding worker (needs $150 — develop a few cycles first if needed), confirm Cash drops and the button changes to "Upgrade"
- Start a new development cycle — confirm the Coding phase now shows "Your Coding worker is working..." instead of the tap mini-game, and completes on its own after a few seconds
- Upgrade the Coding worker once, confirm cash drops by the shown cost and the button's level increments
- Close the panel, confirm it can be reopened via the prompt

- [ ] **Step 3: Trend copy/partial/none check**

Note the 2 Genre+Topic pairs on the Trends Board. Play a cycle matching one exactly — confirm "That was a copy! Earned $0." regardless of how well the mini-games went. Play a cycle matching only the Genre or only the Topic of a trend a few times — confirm you occasionally see "TRENDY HIT!" (roughly 1 in 10 tries).

- [ ] **Step 4: Persistence check**

Stop Play mode, start it again — confirm Cash and any hired/upgraded Workers are exactly as they were.

- [ ] **Step 5: Commit the plan as complete**

```bash
git add -A
git commit -m "Complete Workers + active development mini-games" --allow-empty
```
