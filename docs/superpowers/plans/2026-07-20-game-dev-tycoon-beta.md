# Game Dev Tycoon (BETA) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a playable BETA of the solo Game Dev Tycoon — pick a Genre+Topic, develop it, get paid based on the live Trends Board, buy upgrades, repeat forever.

**Architecture:** Server-authoritative Roblox experience synced via Rojo. Pure game-math (costs, timers, trend matching) lives in `ReplicatedStorage.Shared` as dependency-free Luau modules so it can be unit-tested from Studio's command bar without touching any Roblox service. All Cash/DataStore/timer decisions are made on the server and pushed to clients over RemoteEvents; the client only renders state and sends requests.

**Tech Stack:** Roblox Luau, Rojo 7.7.0 (already installed at `rojo-bin/rojo`, project already synced), Roblox DataStoreService.

## Global Constraints

- Server is authoritative for all Cash, upgrade levels, and trend outcomes — the client never computes a final result, only requests actions and displays what the server sends back.
- Each player has a fully private studio; no shared economy, leaderboard, or visiting other players' studios (out of scope for this plan).
- Exactly 4 Genres (Racing, Horror, Adventure, Simulator) and 4 Topics (Space, Zombies, Sports, Fantasy) for BETA — more can be added later by extending the shared data lists, no other code changes needed.
- The loop is endless — there is no win condition, final boss, or scripted ending.
- Both upgrade tracks (Dev Speed, Quality Boost) are uncapped — infinite levels, cost grows each level so it self-balances instead of hitting a hard ceiling.
- Trends Board is shared per-server (not per-player): 2 randomly rolled Genre+Topic pairs, re-rolled every 300 seconds for everyone at once.
- Trend outcome rules: exact match (Genre AND Topic) of a trending pair = Cash **0** (copy). Partial match (Genre OR Topic, not both) = 10% chance of **5x** Cash, otherwise normal Cash. No match = normal Cash.
- The player always develops every game themselves — no hired staff/workers that produce games automatically (out of scope, confirmed by user).
- Numeric balance values (below) are sensible defaults chosen for this plan — easy to retune later since they all live in one file (`GameData.luau`).

---

## File Structure

```
roblox game/
├── src/
│   ├── shared/
│   │   ├── GameData.luau         (Task 1 — constants + pure formulas)
│   │   ├── TrendMatch.luau       (Task 2 — pure trend classification + cash calc)
│   │   ├── Remotes.luau          (Task 3 — RemoteEvent bootstrap, shared by client+server)
│   │   └── Tests/
│   │       ├── TestHarness.luau  (Task 1 — tiny assert-and-print test runner)
│   │       └── RunTests.luau     (Task 1/2 — requires + runs all shared module tests)
│   ├── server/
│   │   ├── PlayerData.luau       (Task 4 — DataStore load/get/save/remove)
│   │   ├── TrendsService.luau    (Task 5 — trend state + 5-min refresh loop)
│   │   ├── DevelopmentService.luau (Task 6 — start/complete a development cycle)
│   │   ├── UpgradeService.luau   (Task 7 — buy-upgrade handling)
│   │   └── init.server.luau      (Task 8 — wires all services + player join/leave)
│   └── client/
│       ├── UI.luau               (Tasks 9-11 — the whole UI, built incrementally)
│       └── init.client.luau      (Task 9 — bootstraps UI.init())
```

Each shared module has one job: `GameData` is pure numbers/lists, `TrendMatch` is the copy/partial/none + roll logic, `Remotes` just wires up communication. Server files are split by responsibility (data, trends, development, upgrades) so each can be worked on and tested independently. Client UI is one file for BETA since the whole screen is one cohesive piece — splitting it further can happen later if it grows unwieldy.

---

### Task 1: Shared game data & formulas

**Files:**
- Create: `src/shared/GameData.luau`
- Create: `src/shared/Tests/TestHarness.luau`
- Create: `src/shared/Tests/RunTests.luau`

**Interfaces:**
- Consumes: nothing (pure module, no dependencies)
- Produces:
  - `GameData.Genres: {string}` = `{"Racing", "Horror", "Adventure", "Simulator"}`
  - `GameData.Topics: {string}` = `{"Space", "Zombies", "Sports", "Fantasy"}`
  - `GameData.StartingCash: number` = `0`
  - `GameData.TrendRefreshSeconds: number` = `300`
  - `GameData.TrendBonusChance: number` = `0.1`
  - `GameData.TrendBonusMultiplier: number` = `5`
  - `GameData.getDevTime(devSpeedLevel: number): number`
  - `GameData.getDevSpeedCost(currentLevel: number): number`
  - `GameData.getQualityMultiplier(qualityBoostLevel: number): number`
  - `GameData.getQualityBoostCost(currentLevel: number): number`
  - `GameData.getBaseCash(qualityBoostLevel: number): number`
  - `TestHarness.new(): TestHarness` with `:assertEqual(actual, expected, message)` and `:summary()`

- [ ] **Step 1: Remove the placeholder file left by `rojo init`**

`rojo init` scaffolded a `src/shared/Hello.luau` placeholder that nothing in this plan uses. Delete it:

```bash
rm "src/shared/Hello.luau"
```

- [ ] **Step 2: Write the failing test**

Create `src/shared/Tests/TestHarness.luau`:

```lua
local TestHarness = {}
TestHarness.__index = TestHarness

function TestHarness.new()
	return setmetatable({ passed = 0, failed = 0 }, TestHarness)
end

function TestHarness:assertEqual(actual, expected, message)
	if actual == expected then
		self.passed += 1
		print(("PASS: %s"):format(message))
	else
		self.failed += 1
		warn(("FAIL: %s -- expected %s, got %s"):format(message, tostring(expected), tostring(actual)))
	end
end

function TestHarness:summary()
	print(("Tests complete: %d passed, %d failed"):format(self.passed, self.failed))
end

return TestHarness
```

Create `src/shared/Tests/RunTests.luau`:

```lua
local GameData = require(script.Parent.Parent.GameData)
local TestHarness = require(script.TestHarness)

local t = TestHarness.new()

t:assertEqual(GameData.getDevTime(0), 30, "getDevTime(0) is the base time")
t:assertEqual(GameData.getDevTime(1), 30 * 0.95, "getDevTime(1) applies one decay step")
t:assertEqual(GameData.getDevSpeedCost(0), 10, "getDevSpeedCost(0) is the base cost")
t:assertEqual(GameData.getDevSpeedCost(1), 11, "getDevSpeedCost(1) grows 15%, floored")
t:assertEqual(GameData.getQualityMultiplier(0), 1, "getQualityMultiplier(0) is 1x")
t:assertEqual(GameData.getQualityMultiplier(5), 1.5, "getQualityMultiplier(5) is +50%")
t:assertEqual(GameData.getQualityBoostCost(0), 15, "getQualityBoostCost(0) is the base cost")
t:assertEqual(GameData.getBaseCash(0), 10, "getBaseCash(0) equals the payout multiplier")
t:assertEqual(GameData.getBaseCash(5), 15, "getBaseCash(5) scales with quality multiplier")

t:summary()
```

- [ ] **Step 3: Run test to verify it fails**

In Roblox Studio, make sure `rojo serve` (already running) is connected, then open the command bar at the bottom and run:

```
require(game.ReplicatedStorage.Shared.Tests.RunTests)
```

Expected: an error like `attempt to call a nil value` or `GameData is not a valid member` in the Output window — because `GameData.luau` doesn't exist yet.

- [ ] **Step 4: Write minimal implementation**

Create `src/shared/GameData.luau`:

```lua
local GameData = {}

GameData.Genres = { "Racing", "Horror", "Adventure", "Simulator" }
GameData.Topics = { "Space", "Zombies", "Sports", "Fantasy" }

GameData.StartingCash = 0

GameData.BaseDevTimeSeconds = 30
GameData.DevSpeedDecayPerLevel = 0.95
GameData.DevSpeedCostBase = 10
GameData.DevSpeedCostGrowth = 1.15

GameData.QualityBoostPerLevel = 0.1
GameData.QualityBoostCostBase = 15
GameData.QualityBoostCostGrowth = 1.15

GameData.PayoutMultiplier = 10

GameData.TrendRefreshSeconds = 300
GameData.TrendBonusChance = 0.1
GameData.TrendBonusMultiplier = 5

function GameData.getDevTime(devSpeedLevel)
	return GameData.BaseDevTimeSeconds * (GameData.DevSpeedDecayPerLevel ^ devSpeedLevel)
end

function GameData.getDevSpeedCost(currentLevel)
	return math.floor(GameData.DevSpeedCostBase * (GameData.DevSpeedCostGrowth ^ currentLevel))
end

function GameData.getQualityMultiplier(qualityBoostLevel)
	return 1 + (qualityBoostLevel * GameData.QualityBoostPerLevel)
end

function GameData.getQualityBoostCost(currentLevel)
	return math.floor(GameData.QualityBoostCostBase * (GameData.QualityBoostCostGrowth ^ currentLevel))
end

function GameData.getBaseCash(qualityBoostLevel)
	return GameData.PayoutMultiplier * GameData.getQualityMultiplier(qualityBoostLevel)
end

return GameData
```

- [ ] **Step 5: Run test to verify it passes**

Run the same command bar line again:

```
require(game.ReplicatedStorage.Shared.Tests.RunTests)
```

Expected output in the Output window: 9 `PASS:` lines, then `Tests complete: 9 passed, 0 failed`.

> Note: the command bar caches `require` results. If you edit `GameData.luau` and want to re-run tests in the same Play/Edit session, stop and start Play mode again (or use `require(game.ReplicatedStorage.Shared.Tests.RunTests, true)` is not valid Luau — just re-enter Play mode) so the module is freshly required.

- [ ] **Step 6: Commit**

```bash
git add src/shared/Hello.luau src/shared/GameData.luau src/shared/Tests/TestHarness.luau src/shared/Tests/RunTests.luau
git commit -m "Add GameData module with balance formulas and a Studio test harness"
```

---

### Task 2: Trend matching logic

**Files:**
- Create: `src/shared/TrendMatch.luau`
- Modify: `src/shared/Tests/RunTests.luau`

**Interfaces:**
- Consumes: `GameData.getBaseCash`, `GameData.TrendBonusChance`, `GameData.TrendBonusMultiplier` (from Task 1)
- Produces:
  - `TrendMatch.classify(genre: string, topic: string, trend1: {genre: string, topic: string}, trend2: {genre: string, topic: string}): "copy" | "partial" | "none"`
  - `TrendMatch.computeCash(genre: string, topic: string, trend1: {...}, trend2: {...}, qualityBoostLevel: number, randomFn: (() -> number)?): (cash: number, classification: string, hitBonus: boolean)`

- [ ] **Step 1: Write the failing test**

Append to the end of `src/shared/Tests/RunTests.luau` (before the final `t:summary()` line — move `t:summary()` to stay last):

```lua
local TrendMatch = require(script.Parent.Parent.TrendMatch)

local trend1 = { genre = "Horror", topic = "Zombies" }
local trend2 = { genre = "Racing", topic = "Space" }

t:assertEqual(TrendMatch.classify("Horror", "Zombies", trend1, trend2), "copy", "exact match on trend1 is a copy")
t:assertEqual(TrendMatch.classify("Racing", "Space", trend1, trend2), "copy", "exact match on trend2 is a copy")
t:assertEqual(TrendMatch.classify("Horror", "Sports", trend1, trend2), "partial", "matching only genre is partial")
t:assertEqual(TrendMatch.classify("Adventure", "Zombies", trend1, trend2), "partial", "matching only topic is partial")
t:assertEqual(TrendMatch.classify("Adventure", "Fantasy", trend1, trend2), "none", "matching neither is none")

local copyCash, copyClass, copyHit = TrendMatch.computeCash("Horror", "Zombies", trend1, trend2, 0, function() return 1 end)
t:assertEqual(copyCash, 0, "copy earns zero cash")
t:assertEqual(copyClass, "copy", "copy is classified as copy")
t:assertEqual(copyHit, false, "copy never hits the trend bonus")

local winCash, winClass, winHit = TrendMatch.computeCash("Horror", "Sports", trend1, trend2, 0, function() return 0.05 end)
t:assertEqual(winCash, GameData.getBaseCash(0) * GameData.TrendBonusMultiplier, "partial match + winning roll gives 5x")
t:assertEqual(winClass, "partial", "winning case is classified as partial")
t:assertEqual(winHit, true, "winning roll reports hitBonus true")

local loseCash, loseClass, loseHit = TrendMatch.computeCash("Horror", "Sports", trend1, trend2, 0, function() return 0.5 end)
t:assertEqual(loseCash, GameData.getBaseCash(0), "partial match + losing roll gives base cash")
t:assertEqual(loseHit, false, "losing roll reports hitBonus false")

local noneCash = TrendMatch.computeCash("Adventure", "Fantasy", trend1, trend2, 0, function() return 0.01 end)
t:assertEqual(noneCash, GameData.getBaseCash(0), "no match always gives base cash regardless of roll")
```

- [ ] **Step 2: Run test to verify it fails**

Re-enter Play mode in Studio (so `require` re-runs fresh), open the command bar, run:

```
require(game.ReplicatedStorage.Shared.Tests.RunTests)
```

Expected: an error resolving `TrendMatch` (module doesn't exist yet) in the Output window.

- [ ] **Step 3: Write minimal implementation**

Create `src/shared/TrendMatch.luau`:

```lua
local GameData = require(script.Parent.GameData)

local TrendMatch = {}

local function isExactMatch(genre, topic, trend)
	return genre == trend.genre and topic == trend.topic
end

local function isPartialMatch(genre, topic, trend)
	local genreMatches = genre == trend.genre
	local topicMatches = topic == trend.topic
	return genreMatches ~= topicMatches
end

function TrendMatch.classify(genre, topic, trend1, trend2)
	if isExactMatch(genre, topic, trend1) or isExactMatch(genre, topic, trend2) then
		return "copy"
	end

	if isPartialMatch(genre, topic, trend1) or isPartialMatch(genre, topic, trend2) then
		return "partial"
	end

	return "none"
end

function TrendMatch.computeCash(genre, topic, trend1, trend2, qualityBoostLevel, randomFn)
	randomFn = randomFn or math.random
	local baseCash = GameData.getBaseCash(qualityBoostLevel)
	local classification = TrendMatch.classify(genre, topic, trend1, trend2)

	if classification == "copy" then
		return 0, classification, false
	end

	if classification == "partial" then
		if randomFn() <= GameData.TrendBonusChance then
			return baseCash * GameData.TrendBonusMultiplier, classification, true
		end
		return baseCash, classification, false
	end

	return baseCash, classification, false
end

return TrendMatch
```

- [ ] **Step 4: Run test to verify it passes**

Re-enter Play mode, run the same command bar line:

```
require(game.ReplicatedStorage.Shared.Tests.RunTests)
```

Expected: all `PASS:` lines (23 total across both modules), then `Tests complete: 23 passed, 0 failed`.

- [ ] **Step 5: Commit**

```bash
git add src/shared/TrendMatch.luau src/shared/Tests/RunTests.luau
git commit -m "Add TrendMatch module for copy/partial/none classification and cash rolls"
```

---

### Task 3: Shared RemoteEvents bootstrap

**Files:**
- Create: `src/shared/Remotes.luau`

**Interfaces:**
- Consumes: nothing
- Produces: `Remotes.RequestStartDevelopment`, `Remotes.DevelopmentComplete`, `Remotes.RequestBuyUpgrade`, `Remotes.UpgradeResult`, `Remotes.TrendsUpdated`, `Remotes.PlayerStateUpdated` — each a `RemoteEvent` instance, available identically whether required from server or client code.

This module has no game logic to unit test (it only creates/finds Roblox instances), so it's verified by manual playtest instead of the automated harness.

- [ ] **Step 1: Write the implementation**

Create `src/shared/Remotes.luau`:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local REMOTE_NAMES = {
	"RequestStartDevelopment",
	"DevelopmentComplete",
	"RequestBuyUpgrade",
	"UpgradeResult",
	"TrendsUpdated",
	"PlayerStateUpdated",
}

local Remotes = {}

local folder
if RunService:IsServer() then
	folder = Instance.new("Folder")
	folder.Name = "Remotes"
	folder.Parent = ReplicatedStorage

	for _, name in ipairs(REMOTE_NAMES) do
		local event = Instance.new("RemoteEvent")
		event.Name = name
		event.Parent = folder
	end
else
	folder = ReplicatedStorage:WaitForChild("Remotes")
end

for _, name in ipairs(REMOTE_NAMES) do
	Remotes[name] = folder:WaitForChild(name)
end

return Remotes
```

- [ ] **Step 2: Manually verify it loads on the server**

In Studio, enter Play mode (F5), open the command bar, set its context dropdown to **Server**, and run:

```
print(require(game.ReplicatedStorage.Shared.Remotes).RequestStartDevelopment.ClassName)
```

Expected: prints `RemoteEvent` with no errors.

- [ ] **Step 3: Manually verify it loads on the client**

With Play mode still running, switch the command bar's context dropdown to **Client**, and run the same line:

```
print(require(game.ReplicatedStorage.Shared.Remotes).RequestStartDevelopment.ClassName)
```

Expected: prints `RemoteEvent` — confirming the client sees the same instances the server created, not a second copy.

- [ ] **Step 4: Commit**

```bash
git add src/shared/Remotes.luau
git commit -m "Add shared Remotes bootstrap for client/server communication"
```

---

### Task 4: Player data persistence

**Files:**
- Create: `src/server/PlayerData.luau`

**Interfaces:**
- Consumes: `GameData.StartingCash` (Task 1)
- Produces:
  - `PlayerData.load(player: Player): {cash: number, devSpeedLevel: number, qualityBoostLevel: number, gamesReleased: number}`
  - `PlayerData.get(player: Player): {cash: number, devSpeedLevel: number, qualityBoostLevel: number, gamesReleased: number}`
  - `PlayerData.save(player: Player): ()`
  - `PlayerData.remove(player: Player): ()`

- [ ] **Step 1: Enable Studio's API access so DataStore calls work while testing**

In Roblox Studio: **Home tab → Game Settings → Security → toggle "Enable Studio Access to API Services" ON → Save**. Without this, every `GetAsync`/`SetAsync` call below will fail silently into the `pcall` fallback and nothing will ever actually persist.

- [ ] **Step 2: Write the implementation**

Create `src/server/PlayerData.luau`:

```lua
local DataStoreService = game:GetService("DataStoreService")
local GameData = require(game.ReplicatedStorage.Shared.GameData)

local playerStore = DataStoreService:GetDataStore("PlayerData_v1")

local PlayerData = {}
local cache = {}

local function defaultData()
	return {
		cash = GameData.StartingCash,
		devSpeedLevel = 0,
		qualityBoostLevel = 0,
		gamesReleased = 0,
	}
end

function PlayerData.load(player)
	local success, data = pcall(function()
		return playerStore:GetAsync("Player_" .. player.UserId)
	end)

	if success and data then
		cache[player.UserId] = data
	else
		cache[player.UserId] = defaultData()
	end

	return cache[player.UserId]
end

function PlayerData.get(player)
	return cache[player.UserId]
end

function PlayerData.save(player)
	local data = cache[player.UserId]
	if not data then
		return
	end

	local success, err = pcall(function()
		playerStore:SetAsync("Player_" .. player.UserId, data)
	end)

	if not success then
		warn(("Failed to save data for %s: %s"):format(player.Name, tostring(err)))
	end
end

function PlayerData.remove(player)
	cache[player.UserId] = nil
end

return PlayerData
```

- [ ] **Step 3: Manually verify load/save round-trips**

In Studio, enter Play mode (F5, Play Solo — this uses your own account's UserId for real DataStore reads/writes). Open the command bar, set context to **Server**, and run:

```lua
local PlayerData = require(game.ServerScriptService.Server.PlayerData)
local player = game.Players:GetPlayers()[1]
local data = PlayerData.load(player)
print(data.cash, data.devSpeedLevel)
data.cash = 42
PlayerData.save(player)
```

Expected: prints `0	0` (starting values) with no warnings in Output.

- [ ] **Step 4: Verify the save actually persisted**

Stop Play mode, start Play mode again (F5), command bar (Server context):

```lua
local PlayerData = require(game.ServerScriptService.Server.PlayerData)
local player = game.Players:GetPlayers()[1]
local data = PlayerData.load(player)
print(data.cash)
```

Expected: prints `42` — confirming the value saved in Step 3 actually persisted across sessions.

- [ ] **Step 5: Commit**

```bash
git add src/server/PlayerData.luau
git commit -m "Add PlayerData module for DataStore-backed player persistence"
```

---

### Task 5: Trends Board service

**Files:**
- Create: `src/server/TrendsService.luau`

**Interfaces:**
- Consumes: `GameData.Genres`, `GameData.Topics`, `GameData.TrendRefreshSeconds` (Task 1), `Remotes.TrendsUpdated` (Task 3)
- Produces:
  - `TrendsService.start(): ()` — begins the refresh loop, call once at server startup
  - `TrendsService.getCurrent(): (trend1: {genre: string, topic: string}, trend2: {genre: string, topic: string})`
  - `TrendsService.sendCurrentTo(player: Player): ()` — fires `TrendsUpdated` to just one player (used when they join mid-cycle)

- [ ] **Step 1: Write the implementation**

Create `src/server/TrendsService.luau`:

```lua
local GameData = require(game.ReplicatedStorage.Shared.GameData)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)

local TrendsService = {}

local currentTrend1
local currentTrend2

local function rollTrend()
	return {
		genre = GameData.Genres[math.random(1, #GameData.Genres)],
		topic = GameData.Topics[math.random(1, #GameData.Topics)],
	}
end

local function refresh()
	currentTrend1 = rollTrend()
	currentTrend2 = rollTrend()
	Remotes.TrendsUpdated:FireAllClients(currentTrend1, currentTrend2)
end

function TrendsService.start()
	refresh()
	task.spawn(function()
		while true do
			task.wait(GameData.TrendRefreshSeconds)
			refresh()
		end
	end)
end

function TrendsService.getCurrent()
	return currentTrend1, currentTrend2
end

function TrendsService.sendCurrentTo(player)
	Remotes.TrendsUpdated:FireClient(player, currentTrend1, currentTrend2)
end

return TrendsService
```

- [ ] **Step 2: Manually verify trends roll and broadcast**

In Studio, enter Play mode (F5), command bar (Server context):

```lua
local TrendsService = require(game.ServerScriptService.Server.TrendsService)
TrendsService.start()
local trend1, trend2 = TrendsService.getCurrent()
print(trend1.genre, trend1.topic, trend2.genre, trend2.topic)
```

Expected: prints two random Genre/Topic pairs (any combination is valid, e.g. `Simulator Zombies Racing Fantasy`), no errors.

- [ ] **Step 3: Manually verify the 5-minute refresh (using a shortened interval)**

Temporarily edit `src/shared/GameData.luau`, changing `GameData.TrendRefreshSeconds = 300` to `GameData.TrendRefreshSeconds = 10`, save. In Studio, re-enter Play mode, run the same Step 2 script, then wait ~12 seconds and run `local t1, t2 = TrendsService.getCurrent(); print(t1.genre, t1.topic)` again — expect the values to have changed. Once confirmed, change `TrendRefreshSeconds` back to `300` and save.

- [ ] **Step 4: Commit**

```bash
git add src/server/TrendsService.luau
git commit -m "Add TrendsService for the shared 5-minute Trends Board"
```

---

### Task 6: Development cycle

**Files:**
- Create: `src/server/DevelopmentService.luau`

**Interfaces:**
- Consumes: `GameData.Genres`, `GameData.Topics`, `GameData.getDevTime` (Task 1), `TrendMatch.computeCash` (Task 2), `Remotes.RequestStartDevelopment`, `Remotes.DevelopmentComplete`, `Remotes.PlayerStateUpdated` (Task 3), `PlayerData.get`, `PlayerData.save` (Task 4), `TrendsService.getCurrent` (Task 5)
- Produces: `DevelopmentService.start(): ()` — connects the RemoteEvent listener, call once at server startup

- [ ] **Step 1: Write the implementation**

Create `src/server/DevelopmentService.luau`:

```lua
local GameData = require(game.ReplicatedStorage.Shared.GameData)
local TrendMatch = require(game.ReplicatedStorage.Shared.TrendMatch)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local PlayerData = require(script.Parent.PlayerData)
local TrendsService = require(script.Parent.TrendsService)

local DevelopmentService = {}

local developing = {}

local function isValidGenre(genre)
	return table.find(GameData.Genres, genre) ~= nil
end

local function isValidTopic(topic)
	return table.find(GameData.Topics, topic) ~= nil
end

function DevelopmentService.start()
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
		local devTime = GameData.getDevTime(data.devSpeedLevel)

		task.delay(devTime, function()
			developing[player.UserId] = nil

			if not player.Parent then
				return
			end

			local trend1, trend2 = TrendsService.getCurrent()
			local cash, classification, hitBonus = TrendMatch.computeCash(
				genre,
				topic,
				trend1,
				trend2,
				data.qualityBoostLevel
			)

			data.cash += cash
			data.gamesReleased += 1

			Remotes.DevelopmentComplete:FireClient(player, cash, classification == "copy", hitBonus)
			Remotes.PlayerStateUpdated:FireClient(player, data)
		end)
	end)
end

return DevelopmentService
```

- [ ] **Step 2: Manually verify a full development cycle**

In Studio, temporarily lower the timer for a fast test: edit `src/shared/GameData.luau`, change `GameData.BaseDevTimeSeconds = 30` to `GameData.BaseDevTimeSeconds = 3`, save. Enter Play mode (F5).

`RemoteEvent:FireServer` only works when called from client-side code, so this test needs two command bar calls in two different contexts — set the command bar's context dropdown to **Server** first and run:

```lua
local TrendsService = require(game.ServerScriptService.Server.TrendsService)
local DevelopmentService = require(game.ServerScriptService.Server.DevelopmentService)
local PlayerData = require(game.ServerScriptService.Server.PlayerData)

local player = game.Players:GetPlayers()[1]
PlayerData.load(player)
TrendsService.start()
DevelopmentService.start()
```

Now switch the command bar's context dropdown to **Client** and run:

```lua
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
Remotes.RequestStartDevelopment:FireServer("Racing", "Space")
```

Wait 4 seconds, switch the command bar's context dropdown back to **Server**, then run:

```lua
local PlayerData = require(game.ServerScriptService.Server.PlayerData)
local player = game.Players:GetPlayers()[1]
print(PlayerData.get(player).cash, PlayerData.get(player).gamesReleased)
```

Expected: `cash` is greater than `0` (or exactly `0` if a "copy" was rolled — rare with random trends) and `gamesReleased` is `1`.

Once confirmed, change `BaseDevTimeSeconds` back to `30` in `src/shared/GameData.luau` and save.

- [ ] **Step 3: Commit**

```bash
git add src/server/DevelopmentService.luau
git commit -m "Add DevelopmentService for the develop-and-release cycle"
```

---

### Task 7: Upgrade purchases

**Files:**
- Create: `src/server/UpgradeService.luau`

**Interfaces:**
- Consumes: `GameData.getDevSpeedCost`, `GameData.getQualityBoostCost` (Task 1), `Remotes.RequestBuyUpgrade`, `Remotes.UpgradeResult`, `Remotes.PlayerStateUpdated` (Task 3), `PlayerData.get` (Task 4)
- Produces: `UpgradeService.start(): ()` — connects the RemoteEvent listener, call once at server startup

- [ ] **Step 1: Write the implementation**

Create `src/server/UpgradeService.luau`:

```lua
local GameData = require(game.ReplicatedStorage.Shared.GameData)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local PlayerData = require(script.Parent.PlayerData)

local UpgradeService = {}

local UPGRADE_HANDLERS = {
	DevSpeed = {
		getLevel = function(data) return data.devSpeedLevel end,
		getCost = GameData.getDevSpeedCost,
		applyLevel = function(data) data.devSpeedLevel += 1 end,
	},
	QualityBoost = {
		getLevel = function(data) return data.qualityBoostLevel end,
		getCost = GameData.getQualityBoostCost,
		applyLevel = function(data) data.qualityBoostLevel += 1 end,
	},
}

function UpgradeService.start()
	Remotes.RequestBuyUpgrade.OnServerEvent:Connect(function(player, upgradeType)
		local handler = UPGRADE_HANDLERS[upgradeType]
		if not handler then
			return
		end

		local data = PlayerData.get(player)
		if not data then
			return
		end

		local cost = handler.getCost(handler.getLevel(data))

		if data.cash < cost then
			Remotes.UpgradeResult:FireClient(player, upgradeType, false)
			return
		end

		data.cash -= cost
		handler.applyLevel(data)

		Remotes.UpgradeResult:FireClient(player, upgradeType, true)
		Remotes.PlayerStateUpdated:FireClient(player, data)
	end)
end

return UpgradeService
```

- [ ] **Step 2: Manually verify an upgrade purchase**

In Studio, enter Play mode (F5). As in Task 6, `FireServer` needs to be called from client-side code, so set the command bar's context dropdown to **Server** first and run:

```lua
local PlayerData = require(game.ServerScriptService.Server.PlayerData)
local UpgradeService = require(game.ServerScriptService.Server.UpgradeService)

local player = game.Players:GetPlayers()[1]
local data = PlayerData.load(player)
data.cash = 100
UpgradeService.start()
```

Now switch the command bar's context dropdown to **Client** and run:

```lua
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
Remotes.RequestBuyUpgrade:FireServer("DevSpeed")
```

Switch the command bar's context dropdown back to **Server**, then run:

```lua
local PlayerData = require(game.ServerScriptService.Server.PlayerData)
local player = game.Players:GetPlayers()[1]
local data = PlayerData.get(player)
print(data.cash, data.devSpeedLevel)
```

Expected: `cash` is `90` (100 - the level-0 cost of 10) and `devSpeedLevel` is `1`.

- [ ] **Step 3: Commit**

```bash
git add src/server/UpgradeService.luau
git commit -m "Add UpgradeService for buying Dev Speed and Quality Boost levels"
```

---

### Task 8: Server bootstrap

**Files:**
- Create: `src/server/init.server.luau`
- Modify: `src/server/init.server.luau` (delete the old placeholder file Rojo generated at init, replacing its contents)

**Interfaces:**
- Consumes: `PlayerData.load/save/remove` (Task 4), `TrendsService.start/sendCurrentTo` (Task 5), `DevelopmentService.start` (Task 6), `UpgradeService.start` (Task 7), `Remotes.PlayerStateUpdated` (Task 3)
- Produces: nothing (this is the entry point — nothing else requires it)

- [ ] **Step 1: Write the implementation**

Replace the contents of `src/server/init.server.luau` with:

```lua
local Players = game:GetService("Players")
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local PlayerData = require(script.PlayerData)
local TrendsService = require(script.TrendsService)
local DevelopmentService = require(script.DevelopmentService)
local UpgradeService = require(script.UpgradeService)

TrendsService.start()
DevelopmentService.start()
UpgradeService.start()

local AUTOSAVE_INTERVAL_SECONDS = 120

Players.PlayerAdded:Connect(function(player)
	local data = PlayerData.load(player)
	Remotes.PlayerStateUpdated:FireClient(player, data)
	TrendsService.sendCurrentTo(player)
end)

Players.PlayerRemoving:Connect(function(player)
	PlayerData.save(player)
	PlayerData.remove(player)
end)

task.spawn(function()
	while true do
		task.wait(AUTOSAVE_INTERVAL_SECONDS)
		for _, player in ipairs(Players:GetPlayers()) do
			PlayerData.save(player)
		end
	end
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		PlayerData.save(player)
	end
end)
```

- [ ] **Step 2: Manually verify the whole server boots cleanly**

In Studio, enter Play mode (F5). Expected: no errors in the Output window, and the Output shows no warnings about missing `Remotes` or DataStore failures (assuming Step 1 of Task 4 was done).

- [ ] **Step 3: Manually verify join/leave persistence end-to-end**

With Play mode running (Play Solo), command bar (Server context):

```lua
local PlayerData = require(game.ServerScriptService.Server.PlayerData)
local player = game.Players:GetPlayers()[1]
PlayerData.get(player).cash = 77
```

Stop Play mode (this triggers `PlayerRemoving` → `PlayerData.save`). Start Play mode again, command bar (Server context):

```lua
local PlayerData = require(game.ServerScriptService.Server.PlayerData)
local player = game.Players:GetPlayers()[1]
print(PlayerData.get(player).cash)
```

Expected: prints `77` — confirming `PlayerAdded` loaded the saved value automatically this time, with no manual `PlayerData.load` call needed.

- [ ] **Step 4: Commit**

```bash
git add src/server/init.server.luau
git commit -m "Wire up server bootstrap: player join/leave, autosave, and service startup"
```

---

### Task 9: Client UI shell — Genre/Topic picker, Start button, progress bar

**Files:**
- Create: `src/client/UI.luau`
- Create: `src/client/init.client.luau` (replacing Rojo's placeholder)

**Interfaces:**
- Consumes: `GameData.Genres`, `GameData.Topics`, `GameData.getDevTime` (Task 1), `Remotes.RequestStartDevelopment`, `Remotes.DevelopmentComplete` (Task 3)
- Produces: `UI.init(): ()` — builds the whole screen and wires all remote listeners; later tasks (10, 11) add to this same module rather than creating new ones, since it's one cohesive screen for BETA

- [ ] **Step 1: Write the implementation**

Create `src/client/UI.luau`:

```lua
local Players = game:GetService("Players")
local GameData = require(game.ReplicatedStorage.Shared.GameData)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)

local UI = {}

local selectedGenre = nil
local selectedTopic = nil
local currentDevSpeedLevel = 0

local function makeButton(parent, layoutOrder, text, position, size)
	local button = Instance.new("TextButton")
	button.Name = text
	button.Text = text
	button.Position = position
	button.Size = size
	button.LayoutOrder = layoutOrder
	button.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.Parent = parent
	return button
end

function UI.init()
	local player = Players.LocalPlayer
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "GameDevTycoonUI"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = player:WaitForChild("PlayerGui")

	local mainFrame = Instance.new("Frame")
	mainFrame.Name = "MainFrame"
	mainFrame.Size = UDim2.fromOffset(420, 360)
	mainFrame.Position = UDim2.fromScale(0.02, 0.1)
	mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	mainFrame.Parent = screenGui

	local genreLabel = Instance.new("TextLabel")
	genreLabel.Text = "Genre:"
	genreLabel.Size = UDim2.fromOffset(400, 24)
	genreLabel.Position = UDim2.fromOffset(10, 10)
	genreLabel.BackgroundTransparency = 1
	genreLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	genreLabel.Parent = mainFrame

	local genreButtons = {}
	for i, genre in ipairs(GameData.Genres) do
		local button = makeButton(mainFrame, i, genre, UDim2.fromOffset(10 + (i - 1) * 100, 36), UDim2.fromOffset(95, 30))
		genreButtons[genre] = button
		button.MouseButton1Click:Connect(function()
			selectedGenre = genre
			for name, btn in pairs(genreButtons) do
				btn.BackgroundColor3 = (name == genre) and Color3.fromRGB(90, 140, 90) or Color3.fromRGB(60, 60, 70)
			end
		end)
	end

	local topicLabel = Instance.new("TextLabel")
	topicLabel.Text = "Topic:"
	topicLabel.Size = UDim2.fromOffset(400, 24)
	topicLabel.Position = UDim2.fromOffset(10, 76)
	topicLabel.BackgroundTransparency = 1
	topicLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	topicLabel.Parent = mainFrame

	local topicButtons = {}
	for i, topic in ipairs(GameData.Topics) do
		local button = makeButton(mainFrame, i, topic, UDim2.fromOffset(10 + (i - 1) * 100, 102), UDim2.fromOffset(95, 30))
		topicButtons[topic] = button
		button.MouseButton1Click:Connect(function()
			selectedTopic = topic
			for name, btn in pairs(topicButtons) do
				btn.BackgroundColor3 = (name == topic) and Color3.fromRGB(90, 140, 90) or Color3.fromRGB(60, 60, 70)
			end
		end)
	end

	local startButton = makeButton(mainFrame, 100, "Start Developing", UDim2.fromOffset(10, 150), UDim2.fromOffset(190, 36))

	local progressBackground = Instance.new("Frame")
	progressBackground.Size = UDim2.fromOffset(390, 20)
	progressBackground.Position = UDim2.fromOffset(10, 196)
	progressBackground.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
	progressBackground.Parent = mainFrame

	local progressBar = Instance.new("Frame")
	progressBar.Size = UDim2.fromScale(0, 1)
	progressBar.BackgroundColor3 = Color3.fromRGB(90, 140, 90)
	progressBar.Parent = progressBackground

	local statusLabel = Instance.new("TextLabel")
	statusLabel.Text = ""
	statusLabel.Size = UDim2.fromOffset(400, 24)
	statusLabel.Position = UDim2.fromOffset(10, 222)
	statusLabel.BackgroundTransparency = 1
	statusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	statusLabel.Parent = mainFrame

	local developing = false

	startButton.MouseButton1Click:Connect(function()
		if developing then
			return
		end

		if not selectedGenre or not selectedTopic then
			statusLabel.Text = "Pick a Genre and a Topic first!"
			return
		end

		developing = true
		statusLabel.Text = "Developing..."
		Remotes.RequestStartDevelopment:FireServer(selectedGenre, selectedTopic)

		local devTime = GameData.getDevTime(currentDevSpeedLevel)
		local startClock = os.clock()

		local connection
		connection = game:GetService("RunService").RenderStepped:Connect(function()
			local elapsed = os.clock() - startClock
			local fraction = math.clamp(elapsed / devTime, 0, 1)
			progressBar.Size = UDim2.fromScale(fraction, 1)

			if not developing then
				connection:Disconnect()
			end
		end)
	end)

	Remotes.DevelopmentComplete.OnClientEvent:Connect(function(cash, wasCopy, hitBonus)
		developing = false
		progressBar.Size = UDim2.fromScale(0, 1)

		if wasCopy then
			statusLabel.Text = "That was a copy! Earned $0."
		elseif hitBonus then
			statusLabel.Text = ("TRENDY HIT! Earned $%d!"):format(cash)
		else
			statusLabel.Text = ("Released! Earned $%d."):format(cash)
		end
	end)
end

return UI
```

Create `src/client/init.client.luau`:

```lua
require(script.UI).init()
```

- [ ] **Step 2: Manually verify the picker, timer, and release feedback**

In Studio, enter Play mode (F5, Play Solo). Expected: a dark panel appears top-left with 4 Genre buttons, 4 Topic buttons, a "Start Developing" button, and a progress bar. Click a Genre and a Topic (they highlight green), click "Start Developing" — the progress bar should fill smoothly over ~30 seconds (the default `BaseDevTimeSeconds`), then the status label should show either "Released! Earned $X." or "TRENDY HIT!" or "That was a copy!".

- [ ] **Step 3: Commit**

```bash
git add src/client/UI.luau src/client/init.client.luau
git commit -m "Add client UI shell: genre/topic picker, start button, progress bar"
```

---

### Task 10: Client UI — Cash display and Trends Board

**Files:**
- Modify: `src/client/UI.luau`

**Interfaces:**
- Consumes: `Remotes.PlayerStateUpdated`, `Remotes.TrendsUpdated` (Task 3)
- Produces: nothing new exported — extends `UI.init()` from Task 9 with more UI elements and listeners

- [ ] **Step 1: Write the implementation**

In `src/client/UI.luau`, add a `cashLabel` and `trendsLabel`, and track the latest known state so Task 11's cost labels can read it too. Insert this right after the `mainFrame` is created (after the line `mainFrame.Parent = screenGui`), and before the `genreLabel` block:

```lua
	local cashLabel = Instance.new("TextLabel")
	cashLabel.Name = "CashLabel"
	cashLabel.Text = "Cash: $0"
	cashLabel.Size = UDim2.fromOffset(200, 24)
	cashLabel.Position = UDim2.fromOffset(210, 10)
	cashLabel.BackgroundTransparency = 1
	cashLabel.TextColor3 = Color3.fromRGB(255, 220, 120)
	cashLabel.Parent = screenGui

	local trendsLabel = Instance.new("TextLabel")
	trendsLabel.Name = "TrendsLabel"
	trendsLabel.Text = "Trends: loading..."
	trendsLabel.Size = UDim2.fromOffset(400, 40)
	trendsLabel.Position = UDim2.fromOffset(10, 320)
	trendsLabel.BackgroundTransparency = 1
	trendsLabel.TextColor3 = Color3.fromRGB(200, 200, 255)
	trendsLabel.Parent = mainFrame
```

Note `mainFrame.Size` needs to grow to fit the trends label — change the existing line:

```lua
	mainFrame.Size = UDim2.fromOffset(420, 360)
```

to:

```lua
	mainFrame.Size = UDim2.fromOffset(420, 400)
```

Then, replace the line `local currentDevSpeedLevel = 0` near the top of the module with a small shared state table (Task 11 will read from it too):

```lua
local playerState = {
	cash = 0,
	devSpeedLevel = 0,
	qualityBoostLevel = 0,
	gamesReleased = 0,
}
```

And everywhere the old code referenced `currentDevSpeedLevel`, use `playerState.devSpeedLevel` instead — update the line inside `startButton.MouseButton1Click`:

```lua
		local devTime = GameData.getDevTime(playerState.devSpeedLevel)
```

Finally, add these two listeners at the end of `UI.init()`, right after the existing `Remotes.DevelopmentComplete.OnClientEvent:Connect(...)` block:

```lua
	Remotes.PlayerStateUpdated.OnClientEvent:Connect(function(data)
		playerState.cash = data.cash
		playerState.devSpeedLevel = data.devSpeedLevel
		playerState.qualityBoostLevel = data.qualityBoostLevel
		playerState.gamesReleased = data.gamesReleased
		cashLabel.Text = ("Cash: $%d"):format(playerState.cash)
	end)

	Remotes.TrendsUpdated.OnClientEvent:Connect(function(trend1, trend2)
		trendsLabel.Text = ("Trends: %s+%s and %s+%s"):format(
			trend1.genre, trend1.topic, trend2.genre, trend2.topic
		)
	end)
```

- [ ] **Step 2: Manually verify Cash and Trends update live**

In Studio, enter Play mode (F5, Play Solo). Expected: "Cash: $0" appears top area, and "Trends: ..." shows two Genre+Topic pairs immediately (fired via `TrendsService.sendCurrentTo` on join). Develop a game — after it completes, the Cash label should update to reflect the new total (matching the amount shown in the status label from Task 9).

- [ ] **Step 3: Commit**

```bash
git add src/client/UI.luau
git commit -m "Add Cash display and live Trends Board to client UI"
```

---

### Task 11: Client UI — Upgrade shop panel

**Files:**
- Modify: `src/client/UI.luau`

**Interfaces:**
- Consumes: `GameData.getDevSpeedCost`, `GameData.getQualityBoostCost` (Task 1), `Remotes.RequestBuyUpgrade`, `Remotes.UpgradeResult` (Task 3), `playerState` (Task 10)
- Produces: nothing new exported — completes `UI.init()` for BETA

- [ ] **Step 1: Write the implementation**

In `src/client/UI.luau`, add the upgrade shop UI right before the closing `end` of `UI.init()` (after the `Remotes.TrendsUpdated.OnClientEvent:Connect(...)` block added in Task 10):

```lua
	local devSpeedButton = makeButton(mainFrame, 200, "Upgrade Dev Speed", UDim2.fromOffset(210, 150), UDim2.fromOffset(190, 36))
	local qualityBoostButton = makeButton(mainFrame, 201, "Upgrade Quality", UDim2.fromOffset(210, 192), UDim2.fromOffset(190, 36))

	local function refreshUpgradeButtons()
		devSpeedButton.Text = ("Upgrade Dev Speed ($%d)"):format(GameData.getDevSpeedCost(playerState.devSpeedLevel))
		qualityBoostButton.Text = ("Upgrade Quality ($%d)"):format(GameData.getQualityBoostCost(playerState.qualityBoostLevel))
	end

	refreshUpgradeButtons()

	devSpeedButton.MouseButton1Click:Connect(function()
		Remotes.RequestBuyUpgrade:FireServer("DevSpeed")
	end)

	qualityBoostButton.MouseButton1Click:Connect(function()
		Remotes.RequestBuyUpgrade:FireServer("QualityBoost")
	end)

	Remotes.UpgradeResult.OnClientEvent:Connect(function(upgradeType, success)
		if not success then
			statusLabel.Text = ("Not enough cash to upgrade %s!"):format(upgradeType)
		end
	end)
```

Then update the `Remotes.PlayerStateUpdated.OnClientEvent` listener from Task 10 to also refresh the upgrade button labels whenever state changes — change it to:

```lua
	Remotes.PlayerStateUpdated.OnClientEvent:Connect(function(data)
		playerState.cash = data.cash
		playerState.devSpeedLevel = data.devSpeedLevel
		playerState.qualityBoostLevel = data.qualityBoostLevel
		playerState.gamesReleased = data.gamesReleased
		cashLabel.Text = ("Cash: $%d"):format(playerState.cash)
		refreshUpgradeButtons()
	end)
```

Since `refreshUpgradeButtons` and `devSpeedButton`/`qualityBoostButton` are defined further down in the function than this listener, move the whole `Remotes.PlayerStateUpdated.OnClientEvent:Connect(...)` block (and the `Remotes.TrendsUpdated...` block right after it) to just *after* the new upgrade-shop code above, so `refreshUpgradeButtons` exists before it's referenced.

- [ ] **Step 2: Manually verify upgrades work end-to-end**

In Studio, enter Play mode (F5, Play Solo). Expected: two more buttons appear ("Upgrade Dev Speed ($10)", "Upgrade Quality ($15)"). Develop a few games until Cash ≥ 10, click "Upgrade Dev Speed" — the button label should update to a higher cost (e.g. "$11") and Cash should drop by 10. Develop another game — it should take slightly less time than 30 seconds (confirming `playerState.devSpeedLevel` is being used by the progress bar timer from Task 9).

- [ ] **Step 3: Commit**

```bash
git add src/client/UI.luau
git commit -m "Add upgrade shop panel to client UI"
```

---

### Task 12: End-to-end integration playtest

**Files:** none (verification only)

**Interfaces:** none — this task exercises everything from Tasks 1–11 together

- [ ] **Step 1: Fresh-account full loop playtest**

In Studio, enter Play mode (F5, Play Solo). Run through this checklist:

- Trends Board shows two Genre+Topic pairs immediately on join
- Pick a Genre and Topic, click Start Developing — progress bar fills over ~30 seconds
- On completion, status label shows Released/TRENDY HIT/Copy appropriately, and Cash updates to match
- Repeat 3-4 times, confirm Cash accumulates correctly (add up the amounts shown)
- Buy a Dev Speed upgrade, confirm Cash drops by the shown cost and the next development cycle is faster
- Buy a Quality Boost upgrade, confirm Cash drops by the shown cost and the next non-trend release earns more Cash than before
- Try to buy an upgrade with insufficient Cash — confirm the status label shows "Not enough cash"
- Stop Play mode, start it again — confirm Cash and upgrade levels are exactly what they were when you stopped (DataStore persistence working)

- [ ] **Step 2: Verify trend copy/partial/none behavior directly**

Note the two Genre+Topic pairs shown on the Trends Board. Develop a game using the **exact same Genre and Topic** as one of them — confirm the result is "That was a copy! Earned $0." Then develop a game matching **only the Genre** (different Topic) of a trend — over a few attempts, confirm you sometimes see "TRENDY HIT!" (roughly 1 in 10 tries) and otherwise a normal release.

- [ ] **Step 3: Commit the plan as complete**

```bash
git add -A
git commit -m "Complete Game Dev Tycoon BETA: full develop-earn-upgrade loop with Trends Board" --allow-empty
```
