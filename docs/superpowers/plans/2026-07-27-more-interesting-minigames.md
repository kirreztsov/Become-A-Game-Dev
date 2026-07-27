# More Interesting Minigames — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the 3 shallow development minigames with a shared framework hosting 12 tap-friendly minigames (4 per station) that rotate for variety and scale in difficulty with a hidden Studio Level.

**Architecture:** Every minigame is a client "variant" module following one contract, using one of 4 input kinds (mash/timing/sequence/choice). The server owns each round: picks a variant per phase, converts Studio Level → difficulty (0..1), scales per-variant params, generates any needed content (`roundInfo`), and scores the raw input by kind. Difficulty + scoring are pure functions in `GameData` (unit-tested). The quality→cash→subscribers pipeline is unchanged.

**Tech Stack:** Roblox / Luau, Rojo, `TestHarness`/`RunTests` unit tests, `MobileScale`.

**Spec:** `docs/superpowers/specs/2026-07-27-minigames-more-interesting-design.md`

## Global Constraints

- **Mobile-first:** every input is a TAP. No physical-keyboard dependency, no hover, no right-click. On-screen buttons ≥ 44px with spacing. Verify each variant at a 375-wide viewport (scaled by `MobileScale`, `REF_W,REF_H=1000,650`, `MIN_SCALE=0.55`).
- **No economy change:** round score (0..1) feeds `devQuality` exactly as today. Do not touch `TrendMatch.computeCash` or the cash/subscriber formulas.
- `GameData.StartingCash` stays `0`.
- **Colors from `Theme`** (`Theme.Accent`, `.Panel`, `.PanelLight`, `.Text`, `.Success`, `.Gold`, `.Neutral`, `.Line`). Never hardcode brand colors that duplicate Theme.
- **Preserve the seated flow:** minigames render inside a station panel shown only while the player occupies that station's Seat. Do not change seat tracking or the functional Seat/monitor/prompt instances.
- **Rojo new-file caveat:** creating a NEW `.luau` file requires restarting `rojo serve` and reconnecting the Studio plugin before it appears in-game; edits to existing files hot-sync (but hot-sync has been unreliable — verify a change landed by reading the live source via `execute_luau` before trusting a playtest).
- **Reuse existing work:** `CodingGame` → `CodeSprint`, `MapBuildingGame` → `PrecisionPlace`, `TestingGame` → `QAQuiz`. Move + adapt; do not rewrite from scratch.
- Run `./rojo-bin/rojo build default.project.json -o /tmp/mg.rbxl` after each task as a compile check.

## Conventions used by this plan

- **Reference variant:** Task 5 fully codes `CodeSprint` (migrated from `CodingGame`) and establishes the boilerplate every variant reuses: the module shape, a local `corner(inst, r)` helper, `Theme` colors, and calling the injected `report`. Later variant tasks (8–16) give the **complete** distinctive logic (round setup, content rendering, scoring hookup, exact params) and say "follow the CodeSprint boilerplate" for the module skeleton rather than repeating it.
- **Variant contract** (every variant module returns this table):
  ```lua
  local V = { id = "CodeSprint", station = "Coding", inputKind = "mash" }
  function V.init(parent, theme, report) end            -- build hidden UI once
  function V.startRound(difficulty, params, roundInfo) end
  function V.hide() end
  return V
  ```
  `report(value)`: mash → call once per tap (`report()`); timing → call once at tap (`report()`); sequence → call once at resolve (`report(correctCount)`); choice → call once (`report(chosenIndex)`).

## File Structure

```
src/shared/GameData.luau            -- MODIFY: studio level, difficulty, scoring, variant tables, pickVariantId, generateRoundInfo helpers
src/shared/Remotes.luau             -- MODIFY: drop ReportTap/ReportPlacement/ReportChoice, add ReportMinigameInput
src/shared/Tests/RunTests.luau      -- MODIFY: new assertEqual tests
src/server/DevelopmentService.luau  -- MODIFY: generic round runner + single input handler + roundInfo generation
src/client/UI.luau                  -- MODIFY: create 3 MinigameHosts, grow station panel, drop old inits
src/client/Minigames/
  MinigameRegistry.luau             -- CREATE
  MinigameHost.luau                 -- CREATE
  Coding/CodeSprint.luau            -- CREATE (from CodingGame.luau)
  Coding/BugSquash.luau             -- CREATE
  Coding/KeyCombo.luau              -- CREATE
  Coding/CompileCheck.luau          -- CREATE
  MapBuilding/PrecisionPlace.luau   -- CREATE (from MapBuildingGame.luau)
  MapBuilding/BlueprintMemory.luau  -- CREATE
  MapBuilding/TileDrop.luau         -- CREATE
  MapBuilding/PathConnect.luau      -- CREATE
  Testing/BugHunt.luau              -- CREATE
  Testing/QAQuiz.luau               -- CREATE (from TestingGame.luau)
  Testing/PassOrFail.luau           -- CREATE
  Testing/CrashFix.luau             -- CREATE
src/client/CodingGame.luau          -- DELETE (after Task 5)
src/client/MapBuildingGame.luau     -- DELETE (after Task 5)
src/client/TestingGame.luau         -- DELETE (after Task 5)
```

---

## Task 1: Studio Level + difficulty (shared math)

**Files:**
- Modify: `src/shared/GameData.luau`
- Test: `src/shared/Tests/RunTests.luau`

**Interfaces:**
- Produces: `GameData.getStudioLevel(data) -> integer`, `GameData.getDifficulty(studioLevel) -> number 0..1`, constants `StudioLevelPerGames`, `StudioLevelPerSubs`, `StudioLevelMax`, `DifficultyRampLevels`.

- [ ] **Step 1: Write failing tests** in `RunTests.luau` (append before the final `t:summary()`):

```lua
-- Studio level + difficulty
t:assertEqual(GameData.getStudioLevel({ gamesReleased = 0, subscribers = 0 }), 1, "fresh studio is level 1")
t:assertEqual(GameData.getStudioLevel({ gamesReleased = 2, subscribers = 0 }), 2, "2 games -> +1 level")
t:assertEqual(GameData.getStudioLevel({ gamesReleased = 0, subscribers = 100 }), 3, "100 subs -> +2 levels")
t:assertEqual(GameData.getStudioLevel({ gamesReleased = 999, subscribers = 99999 }), GameData.StudioLevelMax, "level clamps at max")
t:assertEqual(GameData.getDifficulty(1), 0, "level 1 -> difficulty 0")
t:assertEqual(GameData.getDifficulty(GameData.DifficultyRampLevels + 1), 1, "ramp end -> difficulty 1")
t:assertEqual(GameData.getDifficulty(9999), 1, "difficulty clamps at 1")
```

- [ ] **Step 2: Run tests, verify they fail** — see `run RunTests` note below (Studio can't run tests from CLI; run via a temporary `execute_luau` that `require`s and runs `RunTests`, or read the failures in Studio Output). Expected: FAIL "attempt to call a nil value (getStudioLevel)".

- [ ] **Step 3: Implement** in `GameData.luau` (near the other formula helpers):

```lua
GameData.StudioLevelPerGames = 2
GameData.StudioLevelPerSubs  = 50
GameData.StudioLevelMax      = 50
GameData.DifficultyRampLevels = 19

function GameData.getStudioLevel(data)
	local lvl = 1
		+ math.floor((data.gamesReleased or 0) / GameData.StudioLevelPerGames)
		+ math.floor((data.subscribers or 0) / GameData.StudioLevelPerSubs)
	return math.min(lvl, GameData.StudioLevelMax)
end

function GameData.getDifficulty(studioLevel)
	return math.clamp((studioLevel - 1) / GameData.DifficultyRampLevels, 0, 1)
end
```

- [ ] **Step 4: Run tests, verify pass.**

- [ ] **Step 5: Commit** — `git commit -m "feat(minigames): studio level + difficulty math"`

**How to run RunTests:** in Studio (Edit), `execute_luau` with:
`local RunTests = require(game.ReplicatedStorage.Shared.Tests.RunTests)` — but `RunTests` runs on require. If it's already required/cached, instead read `src/shared/Tests/RunTests.luau` output by running its body. Simplest reliable path: `execute_luau` a copy that `require`s `GameData` fresh and re-runs the asserts. Note the pass/fail counts printed.

---

## Task 2: Per-kind scoring (shared math)

**Files:**
- Modify: `src/shared/GameData.luau`
- Test: `src/shared/Tests/RunTests.luau`

**Interfaces:**
- Produces: `GameData.scoreMash(count, targetTaps)`, `GameData.scoreTiming(markerPos, zoneCenter, zoneHalfWidth)`, `GameData.scoreSequence(correct, total)`, `GameData.scoreChoice(chosenIndex, correctIndex, wrongScore)` — all return 0..1.
- Consumes: existing `GameData.getMarkerPosition`, `GameData.TestingWrongAnswerScore`.

- [ ] **Step 1: Write failing tests:**

```lua
t:assertEqual(GameData.scoreMash(15, 15), 1, "mash hitting target = 1")
t:assertEqual(GameData.scoreMash(30, 15), 1, "mash over target clamps to 1")
t:assertEqual(GameData.scoreMash(6, 12), 0.5, "mash half target = 0.5")
t:assertEqual(GameData.scoreTiming(0.5, 0.5, 0.15), 1, "timing dead-center = 1")
t:assertEqual(GameData.scoreTiming(0.65, 0.5, 0.15), 0, "timing at zone edge = 0")
t:assertEqual(GameData.scoreTiming(0.9, 0.5, 0.15), 0, "timing outside zone = 0")
t:assertEqual(GameData.scoreSequence(3, 6), 0.5, "sequence 3 of 6 = 0.5")
t:assertEqual(GameData.scoreSequence(0, 0), 0, "sequence 0 of 0 = 0 (no divide error)")
t:assertEqual(GameData.scoreChoice(2, 2, 0.3), 1, "correct choice = 1")
t:assertEqual(GameData.scoreChoice(1, 2, 0.3), 0.3, "wrong choice = wrongScore")
```

- [ ] **Step 2: Run, verify fail.**

- [ ] **Step 3: Implement:**

```lua
function GameData.scoreMash(count, targetTaps)
	return math.clamp(count / targetTaps, 0, 1)
end

function GameData.scoreTiming(markerPos, zoneCenter, zoneHalfWidth)
	local dist = math.abs(markerPos - zoneCenter)
	if dist > zoneHalfWidth then return 0 end
	return 1 - (dist / zoneHalfWidth)
end

function GameData.scoreSequence(correct, total)
	if total <= 0 then return 0 end
	return math.clamp(correct / total, 0, 1)
end

function GameData.scoreChoice(chosenIndex, correctIndex, wrongScore)
	if chosenIndex == correctIndex then return 1 end
	return wrongScore
end
```

- [ ] **Step 4: Run, verify pass.**
- [ ] **Step 5: Commit** — `git commit -m "feat(minigames): per-kind scoring functions"`

---

## Task 3: Variant tables, param scaling, rotation (shared data)

**Files:**
- Modify: `src/shared/GameData.luau`
- Test: `src/shared/Tests/RunTests.luau`

**Interfaces:**
- Produces:
  - `GameData.StationVariantIds = { Coding = {...}, MapBuilding = {...}, Testing = {...} }`
  - `GameData.VariantInputKind[id] -> "mash"|"timing"|"sequence"|"choice"`
  - `GameData.VariantParams[id] = { easy = {...}, hard = {...}, ints = { key=true } }`
  - `GameData.getVariantParams(id, difficulty) -> table` (lerped, integer keys rounded)
  - `GameData.pickVariantId(station, lastId, rng) -> id`
- Consumes: nothing new.

- [ ] **Step 1: Write failing tests:**

```lua
-- param lerp + rounding
GameData.VariantParams.__test = { easy = { a = 0, n = 2 }, hard = { a = 10, n = 8 }, ints = { n = true } }
local p0 = GameData.getVariantParams("__test", 0)
t:assertEqual(p0.a, 0, "difficulty 0 -> easy value")
t:assertEqual(p0.n, 2, "difficulty 0 -> easy int")
local p1 = GameData.getVariantParams("__test", 1)
t:assertEqual(p1.a, 10, "difficulty 1 -> hard value")
t:assertEqual(p1.n, 8, "difficulty 1 -> hard int")
local ph = GameData.getVariantParams("__test", 0.5)
t:assertEqual(ph.a, 5, "midpoint float")
t:assertEqual(ph.n, 5, "midpoint int rounded")
GameData.VariantParams.__test = nil

-- rotation avoids repeats
local ids = GameData.StationVariantIds.Coding
t:assertEqual(#ids, 4, "coding has 4 variants")
-- rng stub returns 0 -> first item of pool; pool excludes lastId
local first = GameData.pickVariantId("Coding", ids[1], function() return 0 end)
t:assertEqual(first ~= ids[1], true, "never repeats lastId when pool > 1")
```

- [ ] **Step 2: Run, verify fail.**

- [ ] **Step 3: Implement** the tables (list ALL 12 ids so later tasks only fill params) and helpers:

```lua
GameData.StationVariantIds = {
	Coding      = { "CodeSprint", "BugSquash", "KeyCombo", "CompileCheck" },
	MapBuilding = { "PrecisionPlace", "BlueprintMemory", "TileDrop", "PathConnect" },
	Testing     = { "BugHunt", "QAQuiz", "PassOrFail", "CrashFix" },
}

GameData.VariantInputKind = {
	CodeSprint = "mash", BugSquash = "mash", KeyCombo = "sequence", CompileCheck = "choice",
	PrecisionPlace = "timing", BlueprintMemory = "sequence", TileDrop = "sequence", PathConnect = "sequence",
	BugHunt = "choice", QAQuiz = "choice", PassOrFail = "sequence", CrashFix = "mash",
}

-- Filled incrementally by each variant task. Values below are the final targets.
GameData.VariantParams = {
	CodeSprint     = { easy = { targetTaps = 12, windowSeconds = 3 },              hard = { targetTaps = 40, windowSeconds = 3 },              ints = { targetTaps = true } },
	BugSquash      = { easy = { targetBugs = 6, spawnInterval = 0.55, windowSeconds = 4 }, hard = { targetBugs = 16, spawnInterval = 0.28, windowSeconds = 4 }, ints = { targetBugs = true } },
	KeyCombo       = { easy = { len = 3, peekSeconds = 2.5, inputSeconds = 6 },    hard = { len = 8, peekSeconds = 0.8, inputSeconds = 5 },    ints = { len = true } },
	CompileCheck   = { easy = { answerSeconds = 10 },                              hard = { answerSeconds = 4 },                               ints = {} },
	PrecisionPlace = { easy = { zoneHalfWidth = 0.18, periodSeconds = 2.2 },       hard = { zoneHalfWidth = 0.05, periodSeconds = 1.0 },       ints = {} },
	BlueprintMemory= { easy = { gridN = 3, patternLen = 3, peekSeconds = 2.5 },    hard = { gridN = 4, patternLen = 8, peekSeconds = 1.0 },    ints = { gridN = true, patternLen = true } },
	TileDrop       = { easy = { pieces = 3, fallSeconds = 2.0 },                   hard = { pieces = 7, fallSeconds = 0.9 },                   ints = { pieces = true } },
	PathConnect    = { easy = { gridN = 4, timeSeconds = 8 },                      hard = { gridN = 6, timeSeconds = 5 },                      ints = { gridN = true } },
	BugHunt        = { easy = { gridN = 3, answerSeconds = 6 },                    hard = { gridN = 5, answerSeconds = 3 },                    ints = { gridN = true } },
	QAQuiz         = { easy = { optionCount = 2, answerSeconds = 12 },             hard = { optionCount = 4, answerSeconds = 5 },              ints = { optionCount = true } },
	PassOrFail     = { easy = { count = 5, flashSeconds = 2.0 },                   hard = { count = 12, flashSeconds = 0.8 },                  ints = { count = true } },
	CrashFix       = { easy = { targetCrashes = 6, spawnInterval = 0.6, windowSeconds = 5 }, hard = { targetCrashes = 18, spawnInterval = 0.25, windowSeconds = 5 }, ints = { targetCrashes = true } },
}

function GameData.getVariantParams(id, difficulty)
	local spec = GameData.VariantParams[id]
	local ints = spec.ints or {}
	local out = {}
	for key, easyVal in pairs(spec.easy) do
		local v = easyVal + (spec.hard[key] - easyVal) * difficulty
		if ints[key] then v = math.floor(v + 0.5) end
		out[key] = v
	end
	return out
end

function GameData.pickVariantId(station, lastId, rng)
	local ids = GameData.StationVariantIds[station]
	local pool = {}
	for _, id in ipairs(ids) do
		if id ~= lastId or #ids == 1 then table.insert(pool, id) end
	end
	return pool[math.floor(rng() * #pool) + 1]
end
```

- [ ] **Step 4: Run, verify pass.**
- [ ] **Step 5: Commit** — `git commit -m "feat(minigames): variant tables, param scaling, rotation"`

---

## Task 4: Remotes swap

**Files:**
- Modify: `src/shared/Remotes.luau`

**Interfaces:**
- Produces: `Remotes.ReportMinigameInput` (RemoteEvent).
- Removes: `Remotes.ReportTap`, `Remotes.ReportPlacement`, `Remotes.ReportChoice`.

- [ ] **Step 1:** In `Remotes.luau` `REMOTE_NAMES`, delete the three lines `"ReportTap"`, `"ReportPlacement"`, `"ReportChoice"` and add `"ReportMinigameInput"` in their place.
- [ ] **Step 2: Compile check** — `./rojo-bin/rojo build default.project.json -o /tmp/mg.rbxl`. Expected: builds. (Server/client still reference old names until Task 7 — that's fine, they're separate files; but do Task 5–7 before playtesting.)
- [ ] **Step 3: Commit** — `git commit -m "feat(minigames): unify report remotes into ReportMinigameInput"`

---

## Task 5: Variant contract + migrate CodeSprint (reference variant)

**Files:**
- Create: `src/client/Minigames/Coding/CodeSprint.luau` (from `src/client/CodingGame.luau`)
- Reference: `src/client/CodingGame.luau` (current IDE-editor UI)

**Interfaces:**
- Produces: `CodeSprint` module implementing the variant contract (`id="CodeSprint"`, `station="Coding"`, `inputKind="mash"`).

- [ ] **Step 1:** Create `CodeSprint.luau` by adapting the current `CodingGame.luau`:
  - Keep the IDE editor UI (title bar, dots, `main.lua`, syntax code, "N lines" counter, WRITE CODE footer bar) verbatim.
  - Change the module header to the contract: add `CodeSprint.id/station/inputKind`.
  - `init(parent, theme, report)` — store `report`; build UI once (as today).
  - `startRound(difficulty, params, roundInfo)` — reset counter; store `params.targetTaps` (for optional progress feel); `container.Visible = true`. Do NOT require Remotes.
  - The WRITE CODE click handler calls `report()` (not `Remotes.ReportTap:FireServer()`).
  - `hide()` — as today.
  - Remove `require(Remotes)`.

  Full module:

```lua
local CodeSprint = { id = "CodeSprint", station = "Coding", inputKind = "mash" }

local container, counterLabel, tapButton
local reportFn
local tapCount, roundActive, targetTaps = 0, false, 15

local EDITOR_BG = Color3.fromRGB(24, 26, 33)
local BAR_BG = Color3.fromRGB(38, 41, 52)
local GUTTER = Color3.fromRGB(120, 128, 148)
local KW = Color3.fromRGB(198, 134, 192)
local FN = Color3.fromRGB(97, 175, 239)
local STR = Color3.fromRGB(152, 195, 121)
local TXT = Color3.fromRGB(210, 216, 230)

local CODE = {
	{ 0, { { KW, "local" }, { TXT, " game = " }, { TXT, "{}" } } },
	{ 0, { { KW, "function" }, { FN, " game.start" }, { TXT, "()" } } },
	{ 1, { { FN, "spawnPlayers" }, { TXT, "()" } } },
	{ 1, { { FN, "loadMap" }, { TXT, "(" }, { STR, "\"lobby\"" }, { TXT, ")" } } },
	{ 1, { { KW, "return" }, { STR, " \"shipped!\"" } } },
	{ 0, { { KW, "end" } } },
}

local function corner(inst, r)
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r); c.Parent = inst; return c
end

function CodeSprint.init(parent, theme, report)
	reportFn = report
	-- [BUILD UI: copy the body of CodingGame.init verbatim, EXCEPT the click
	-- handler fires reportFn() instead of Remotes.ReportTap:FireServer(). Keep
	-- editor/bar/dots/title/counterLabel/code rows/tapButton exactly as-is.]
	-- ... (verbatim from CodingGame.luau) ...
	tapButton.MouseButton1Click:Connect(function()
		if not roundActive then return end
		tapCount += 1
		counterLabel.Text = tapCount == 1 and "1 line" or ("%d lines"):format(tapCount)
		tapButton.Size = UDim2.new(1, -28, 0, 31)
		task.delay(0.06, function()
			if tapButton and tapButton.Parent then tapButton.Size = UDim2.new(1, -20, 0, 34) end
		end)
		reportFn()
	end)
end

function CodeSprint.startRound(difficulty, params, roundInfo)
	tapCount = 0
	targetTaps = params.targetTaps or 15
	roundActive = true
	if counterLabel then counterLabel.Text = "0 lines" end
	container.Visible = true
end

function CodeSprint.hide()
	roundActive = false
	if container then container.Visible = false end
end

return CodeSprint
```

  > When implementing, paste the full UI-building body from `CodingGame.luau` where marked. The only behavioral change is `report` replacing the remote and `params.targetTaps` replacing the constant.

- [ ] **Step 2: Compile check** — `./rojo-bin/rojo build default.project.json -o /tmp/mg.rbxl`. Expected: builds. (New file — a real playtest needs Rojo restart + reconnect, done at Task 7.)
- [ ] **Step 3: Commit** — `git commit -m "feat(minigames): variant contract + migrate CodeSprint"`

---

## Task 6: Migrate PrecisionPlace + QAQuiz to the contract

**Files:**
- Create: `src/client/Minigames/MapBuilding/PrecisionPlace.luau` (from `MapBuildingGame.luau`)
- Create: `src/client/Minigames/Testing/QAQuiz.luau` (from `TestingGame.luau`)

**Interfaces:**
- Produces: `PrecisionPlace` (`station="MapBuilding"`, `inputKind="timing"`), `QAQuiz` (`station="Testing"`, `inputKind="choice"`).

- [ ] **Step 1: PrecisionPlace** — adapt `MapBuildingGame.luau`:
  - `init(parent, theme, report)` — build the track + marker + Place button as today; button calls `report()` (was `Remotes.ReportPlacement:FireServer()`).
  - `startRound(difficulty, params, roundInfo)` — `roundInfo` carries `startTime` and `periodSeconds` from the server (server sends `params.periodSeconds` as the period, and the current server timestamp as `startTime`). Drive the marker with `getMarkerPosition(now - startTime, period)` as today. Use `params.zoneHalfWidth`/`params.periodSeconds` (server also sizes/positions the green zone via `roundInfo.zoneHalfWidth` so client visual matches server scoring — see Task 7 for what the server sends).
  - The green zone highlight width uses `roundInfo.zoneHalfWidth * 2` centered at `MapBuildingZoneCenter`.
  - `hide()` — disconnect the RenderStepped connection, hide container.
- [ ] **Step 2: QAQuiz** — adapt `TestingGame.luau`:
  - `init(parent, theme, report)` — build the prompt label + up to 4 option buttons (today it builds 2; build 4, hide unused). Each button `i` calls `report(i)`.
  - `startRound(difficulty, params, roundInfo)` — `roundInfo` carries `{ prompt, options }` (server-generated, `#options == params.optionCount`). Show `params.optionCount` buttons, hide the rest. Optionally show a countdown using `params.answerSeconds` (visual only).
  - `hide()` — hide container.
- [ ] **Step 3: Compile check** — builds.
- [ ] **Step 4: Commit** — `git commit -m "feat(minigames): migrate PrecisionPlace + QAQuiz"`

---

## Task 7: Registry, Host, generic server runner, UI wiring (end-to-end)

**Files:**
- Create: `src/client/Minigames/MinigameRegistry.luau`
- Create: `src/client/Minigames/MinigameHost.luau`
- Modify: `src/server/DevelopmentService.luau`
- Modify: `src/client/UI.luau`
- Delete: `src/client/CodingGame.luau`, `src/client/MapBuildingGame.luau`, `src/client/TestingGame.luau`

**Interfaces:**
- Consumes: the 3 migrated variants, `GameData` math, `ReportMinigameInput`.
- Produces: a working full dev cycle where each station shows its (currently only registered) variant and scores flow through.

- [ ] **Step 1: MinigameRegistry** — require the variant modules and index them:

```lua
local Coding = script.Parent.Coding
local MapBuilding = script.Parent.MapBuilding
local Testing = script.Parent.Testing

local ALL = {
	require(Coding.CodeSprint),
	require(MapBuilding.PrecisionPlace),
	require(Testing.QAQuiz),
	-- later tasks append: BugSquash, KeyCombo, CompileCheck, BlueprintMemory,
	-- TileDrop, PathConnect, BugHunt, PassOrFail, CrashFix
}

local Registry = { byStation = {}, byId = {} }
for _, v in ipairs(ALL) do
	Registry.byStation[v.station] = Registry.byStation[v.station] or {}
	table.insert(Registry.byStation[v.station], v)
	Registry.byId[v.id] = v
end
function Registry.get(id) return Registry.byId[id] end
function Registry.forStation(station) return Registry.byStation[station] end
return Registry
```

- [ ] **Step 2: MinigameHost** — one per station panel; inits every variant for its station, swaps them on `RoundStarted`:

```lua
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local Registry = require(script.Parent.MinigameRegistry)

local Host = {}
Host.__index = Host

function Host.new(station, panel, theme)
	local self = setmetatable({ station = station, active = nil, variants = {} }, Host)
	for _, v in ipairs(Registry.forStation(station) or {}) do
		v.init(panel, theme, function(value) Remotes.ReportMinigameInput:FireServer(value) end)
		v.hide()
		self.variants[v.id] = v
	end
	return self
end

function Host:show(variantId, difficulty, params, roundInfo)
	if self.active and self.active ~= variantId and self.variants[self.active] then
		self.variants[self.active].hide()
	end
	self.active = variantId
	local v = self.variants[variantId]
	if v then v.startRound(difficulty, params, roundInfo) end
end

function Host:hide()
	if self.active and self.variants[self.active] then self.variants[self.active].hide() end
	self.active = nil
end

return Host
```

- [ ] **Step 3: DevelopmentService** — replace the 3 `ROUND_RUNNERS` and 3 report handlers with the generic runner. Key changes:
  - Delete `runCodingRound`, `runMapBuildingRound`, `runTestingRound`, and the `ROUND_RUNNERS` table.
  - Add `lastVariantByStation = {}` (keyed by userId then station).
  - Add a single `Random.new()` (module-level) for `pickVariantId`.
  - `ReportMinigameInput.OnServerEvent` updates `activeRounds[uid]` by kind:

```lua
Remotes.ReportMinigameInput.OnServerEvent:Connect(function(player, value)
	local round = activeRounds[player.UserId]
	if not round then return end
	if round.kind == "mash" then
		round.count = (round.count or 0) + 1
	elseif round.kind == "timing" and not round.placed then
		round.placed = true
		round.placementTime = Workspace:GetServerTimeNow()
	elseif round.kind == "sequence" and not round.reported then
		round.reported = true
		round.correctCount = tonumber(value) or 0
	elseif round.kind == "choice" and not round.chosen then
		round.chosen = true
		round.chosenIndex = tonumber(value)
	end
end)
```

  - New `runPhase` (replacing the worker-less branch; keep the worker-auto branch unchanged):

```lua
local STATION_FOR_PHASE = { Coding = "Coding", MapBuilding = "MapBuilding", Testing = "Testing" }

local function runPhase(player, data, phase)
	local worker = data.workers[phase]
	if worker.hired then
		-- [unchanged worker-auto branch]
		...
		return score
	end

	Remotes.PhaseStarted:FireClient(player, phase, false)
	waitForPlayerSeated(player, phase)
	if not player.Parent then return 0 end

	local uid = player.UserId
	local station = STATION_FOR_PHASE[phase]
	local difficulty = GameData.getDifficulty(GameData.getStudioLevel(data))
	lastVariantByStation[uid] = lastVariantByStation[uid] or {}
	local variantId = GameData.pickVariantId(station, lastVariantByStation[uid][station], function() return rng:NextNumber() end)
	lastVariantByStation[uid][station] = variantId
	local kind = GameData.VariantInputKind[variantId]
	local params = GameData.getVariantParams(variantId, difficulty)

	local total = 0
	for roundIndex = 1, GameData.RoundsPerPhase do
		if not player.Parent then return 0 end
		local roundInfo = generateRoundInfo(variantId, difficulty, params)
		activeRounds[uid] = { kind = kind, params = params, roundInfo = roundInfo }
		Remotes.RoundStarted:FireClient(player, station, roundIndex, {
			variantId = variantId, difficulty = difficulty, params = params, roundInfo = roundInfo,
		})
		local roundScore = waitAndScore(player, variantId, kind, params, roundInfo)
		total += roundScore
		Remotes.RoundComplete:FireClient(player, phase, roundIndex, roundScore)
	end
	local phaseScore = total / GameData.RoundsPerPhase
	Remotes.PhaseComplete:FireClient(player, phase, phaseScore)
	return phaseScore
end
```

  - `waitAndScore(player, variantId, kind, params, roundInfo)` — waits per kind (reuse the existing timeout loops) then scores:

```lua
local function waitAndScore(player, variantId, kind, params, roundInfo)
	local uid = player.UserId
	if kind == "mash" then
		task.wait(params.windowSeconds)
		local r = activeRounds[uid]; activeRounds[uid] = nil
		local target = params.targetTaps or params.targetBugs or params.targetCrashes
		return r and GameData.scoreMash(r.count or 0, target) or 0
	elseif kind == "timing" then
		local waited = 0
		while waited < GameData.MapBuildingMaxWaitSeconds do
			local r = activeRounds[uid]; if not r or r.placed then break end
			task.wait(0.1); waited += 0.1
		end
		local r = activeRounds[uid]; activeRounds[uid] = nil
		if not r or not r.placed then return 0 end
		local elapsed = r.placementTime - roundInfo.startTime
		local pos = GameData.getMarkerPosition(elapsed, params.periodSeconds)
		return GameData.scoreTiming(pos, GameData.MapBuildingZoneCenter, params.zoneHalfWidth)
	elseif kind == "sequence" then
		local maxWait = roundInfo.maxWait or 12
		local waited = 0
		while waited < maxWait do
			local r = activeRounds[uid]; if not r or r.reported then break end
			task.wait(0.1); waited += 0.1
		end
		local r = activeRounds[uid]; activeRounds[uid] = nil
		if not r or not r.reported then return 0 end
		return GameData.scoreSequence(r.correctCount or 0, roundInfo.total)
	elseif kind == "choice" then
		local waited = 0
		while waited < (params.answerSeconds or GameData.TestingMaxWaitSeconds) do
			local r = activeRounds[uid]; if not r or r.chosen then break end
			task.wait(0.1); waited += 0.1
		end
		local r = activeRounds[uid]; activeRounds[uid] = nil
		if not r or not r.chosen then return 0 end
		return GameData.scoreChoice(r.chosenIndex, roundInfo.correctIndex, GameData.TestingWrongAnswerScore)
	end
	return 0
end
```

  - `generateRoundInfo(variantId, difficulty, params)` — returns per-variant content. For Task 7 only the 3 migrated variants exist:

```lua
local function generateRoundInfo(variantId, difficulty, params)
	if variantId == "PrecisionPlace" then
		return { startTime = Workspace:GetServerTimeNow(), periodSeconds = params.periodSeconds, zoneHalfWidth = params.zoneHalfWidth }
	elseif variantId == "QAQuiz" then
		local q = GameData.TestingQuestions[rng:NextInteger(1, #GameData.TestingQuestions)]
		-- build options list of params.optionCount, always including the correct one (see Task 12 for >2 options)
		local options = { q.options[1], q.options[2] }
		local correctIndex = q.correctIndex
		if rng:NextNumber() < 0.5 then options = { options[2], options[1] }; correctIndex = (correctIndex == 1) and 2 or 1 end
		return { prompt = q.prompt, options = options, correctIndex = correctIndex }
	end
	return {}  -- mash variants need no content
end
```

  > `generateRoundInfo` gains a branch in each later variant task. `waitAndScore`'s `sequence` branch reads `roundInfo.total`, so every sequence variant must set it.

- [ ] **Step 4: UI.luau** — replace the three direct minigame inits with Hosts:
  - Remove `require`s of `CodingGame`/`MapBuildingGame`/`TestingGame` and their `.init` / `hideAllMiniGames` calls.
  - `require(script.Parent.Minigames.MinigameHost)`.
  - After creating `codingPanel`/`mapBuildingPanel`/`testingPanel`, create `local hosts = { Coding = Host.new("Coding", codingPanel, Theme), MapBuilding = Host.new("MapBuilding", mapBuildingPanel, Theme), Testing = Host.new("Testing", testingPanel, Theme) }`.
  - Rewrite the `RoundStarted.OnClientEvent` handler to `hosts[station]:show(info.variantId, info.difficulty, info.params, info.roundInfo)` (the handler currently routes to per-game `startRound`; find it and replace).
  - `hideAllMiniGames` → loop `for _, h in pairs(hosts) do h:hide() end`.
  - Grow `makeStationPanel` size from `UDim2.fromOffset(380, 190)` to `UDim2.fromOffset(420, 300)`.
- [ ] **Step 5: Delete** `src/client/CodingGame.luau`, `MapBuildingGame.luau`, `TestingGame.luau`.
- [ ] **Step 6: Compile check** — `./rojo-bin/rojo build default.project.json -o /tmp/mg.rbxl`. Expected: builds with no references to deleted modules.
- [ ] **Step 7: Integration playtest** — restart `rojo serve`, reconnect the plugin, Play. Run a full dev cycle (Coding → MapBuilding → Testing). Verify each station shows its variant, scoring flows, `DevelopmentComplete` pays out. Verify at desktop AND 375-wide viewport.
- [ ] **Step 8: Commit** — `git commit -m "feat(minigames): host + registry + generic server runner + UI wiring"`

---

## Task 8: Coding — BugSquash (mash)

**Files:**
- Create: `src/client/Minigames/Coding/BugSquash.luau`
- Modify: `src/client/Minigames/MinigameRegistry.luau` (append `require(Coding.BugSquash)`)
- Modify: `src/server/DevelopmentService.luau` (`generateRoundInfo`: BugSquash needs none — mash)

**Interfaces:** `id="BugSquash"`, `station="Coding"`, `inputKind="mash"`. Params (Task 3): `targetBugs`, `spawnInterval`, `windowSeconds`.

**Design:** Over `windowSeconds`, bug (🐛) buttons spawn every `spawnInterval` at random spots in the panel; tapping one squashes it (call `report()`, remove it). Score = squashes / `targetBugs` (handled server-side via `scoreMash` with `target = params.targetBugs`). Follow the CodeSprint boilerplate for module shape + `corner` + Theme.

- [ ] **Step 1: Implement** `BugSquash.luau`:
  - `init(parent, theme, report)` — create a full-panel transparent `container`; store `report`, `theme`.
  - `startRound(difficulty, params, roundInfo)` — clear any leftover bug buttons; `container.Visible = true`; start a spawn loop bound to a round token so it stops on `hide`:

```lua
function BugSquash.startRound(difficulty, params, roundInfo)
	BugSquash.clear()
	container.Visible = true
	local token = {}; activeToken = token
	local elapsed = 0
	task.spawn(function()
		while activeToken == token and elapsed < params.windowSeconds do
			spawnBug(token)             -- see Step 2
			task.wait(params.spawnInterval)
			elapsed += params.spawnInterval
		end
	end)
end
```

  - `spawnBug(token)` — a `TextButton` (🐛, ≥44px) at a random position inside the panel padding; `MouseButton1Click` → if `activeToken == token` then `report()` and `button:Destroy()`. Auto-remove after ~1.5s if not tapped (simulates "spread" — optional visual: briefly spawn a second bug on expiry, capped).
  - `clear()` — destroy all bug buttons; `hide()` — `activeToken = nil`, `clear()`, `container.Visible = false`.
- [ ] **Step 2: Register** — append `require(Coding.BugSquash)` to `MinigameRegistry`'s `ALL`.
- [ ] **Step 3: Compile check.**
- [ ] **Step 4: Playtest** — restart Rojo + reconnect. Force `BugSquash` (temporarily hardcode `pickVariantId` to return `"BugSquash"` for Coding, or raise Studio Level and reroll) and play a Coding phase; verify bugs spawn, tap squashes, score reflects hits. Test on 375-wide. Revert any temporary force.
- [ ] **Step 5: Commit** — `git commit -m "feat(minigames): BugSquash"`

---

## Task 9: Coding — KeyCombo (sequence)

**Files:**
- Create: `src/client/Minigames/Coding/KeyCombo.luau`
- Modify: `MinigameRegistry.luau`, `DevelopmentService.luau` (`generateRoundInfo` branch)

**Interfaces:** `inputKind="sequence"`. Params: `len`, `peekSeconds`, `inputSeconds`.

**Server `generateRoundInfo` branch:**
```lua
elseif variantId == "KeyCombo" then
	local glyphs = { "↑", "↓", "←", "→", "{", "}", ";", "(" }
	local seq = {}
	for i = 1, params.len do seq[i] = glyphs[rng:NextInteger(1, #glyphs)] end
	return { keys = seq, total = params.len, maxWait = params.peekSeconds + params.inputSeconds + 2 }
```

**Design:** Show the `keys` sequence big for `peekSeconds` (a "watch" phase), then hide it and show a keypad of the 8 glyph buttons. The player taps the glyphs in order; count how many are correct **in order** (stop counting on first mistake or count each correct position — use position-wise: index `i` correct if the i-th tap equals `keys[i]`). After `inputSeconds` or when `len` taps are entered, call `report(correctCount)`.

- [ ] **Step 1: Implement** `KeyCombo.luau`:
  - `init` — build container + a hidden "prompt row" (shows the sequence) + a keypad grid of 8 glyph buttons (≥44px). Store `report`.
  - `startRound(difficulty, params, roundInfo)` — store `roundInfo.keys`; reset `entered = {}`; show prompt row with the glyphs; disable keypad; after `params.peekSeconds` hide the prompt and enable the keypad; start an `inputSeconds` timer that on expiry finalizes.
  - Keypad button `g` click → `table.insert(entered, g)`; if `#entered >= #keys` finalize.
  - `finalize()` (guard once) — `correct = 0; for i,k in ipairs(keys) do if entered[i]==k then correct+=1 end end; report(correct)`.
  - `hide()` — cancel timers (token pattern), hide container.
- [ ] **Step 2: Register + generateRoundInfo branch.**
- [ ] **Step 3: Compile check.**
- [ ] **Step 4: Playtest** (force KeyCombo). Verify peek → input → score = correct/len. 375-wide check.
- [ ] **Step 5: Commit** — `git commit -m "feat(minigames): KeyCombo"`

---

## Task 10: Coding — CompileCheck (choice)

**Files:**
- Create: `src/client/Minigames/Coding/CompileCheck.luau`
- Modify: `MinigameRegistry.luau`, `DevelopmentService.luau`, and add `GameData.CompileSnippets` data.

**Interfaces:** `inputKind="choice"`. Params: `answerSeconds`.

**Data (`GameData.luau`):** add a bank of snippet sets, each `{ lines = { good, bad1, bad2 }, correctIsFirst = true }` — store 3 code strings where exactly one compiles. Provide ≥ 8 sets. Example:
```lua
GameData.CompileSnippets = {
	{ good = "local x = 5", bad = { "local x = ", "locl x = 5" } },
	{ good = "print(\"hi\")", bad = { "print(\"hi\"", "prin(\"hi\")" } },
	-- ... ≥ 8 total, mix of subtle (missing paren, typo'd keyword) ...
}
```

**Server `generateRoundInfo` branch:** pick a set, shuffle the 3 lines (good + 2 bad), record which shuffled index is the good one:
```lua
elseif variantId == "CompileCheck" then
	local s = GameData.CompileSnippets[rng:NextInteger(1, #GameData.CompileSnippets)]
	local lines = { s.good, s.bad[1], s.bad[2] }
	-- Fisher–Yates with rng, track where good (originally index 1) lands
	local correctIndex = 1
	for i = #lines, 2, -1 do
		local j = rng:NextInteger(1, i)
		lines[i], lines[j] = lines[j], lines[i]
		if correctIndex == i then correctIndex = j elseif correctIndex == j then correctIndex = i end
	end
	return { lines = lines, correctIndex = correctIndex }
```

**Design:** Show a small prompt ("Which line runs?") and 3 tappable code-line buttons (monospace `Enum.Font.Code`, ≥44px tall). Tapping button `i` calls `report(i)`. Server scores via `scoreChoice`.

- [ ] **Step 1: Implement** `CompileCheck.luau` (init builds 3 line buttons; startRound sets their text from `roundInfo.lines`, resets `answered`; click → `report(i)` once). Follow CodeSprint boilerplate.
- [ ] **Step 2: Add `GameData.CompileSnippets` (≥8 sets), register, add generateRoundInfo branch.**
- [ ] **Step 3: Compile check.**
- [ ] **Step 4: Playtest** (force CompileCheck). Verify correct pick = full score, wrong = `wrongScore`. 375-wide.
- [ ] **Step 5: Commit** — `git commit -m "feat(minigames): CompileCheck"`

---

## Task 11: MapBuilding — BlueprintMemory (sequence)

**Files:** Create `MapBuilding/BlueprintMemory.luau`; modify `MinigameRegistry.luau`, `DevelopmentService.luau`.

**Interfaces:** `inputKind="sequence"`. Params: `gridN`, `patternLen`, `peekSeconds`.

**Server `generateRoundInfo`:**
```lua
elseif variantId == "BlueprintMemory" then
	local cells = params.gridN * params.gridN
	local pattern, used = {}, {}
	while #pattern < math.min(params.patternLen, cells) do
		local c = rng:NextInteger(1, cells)
		if not used[c] then used[c] = true; table.insert(pattern, c) end
	end
	return { gridN = params.gridN, pattern = pattern, total = #pattern, maxWait = params.peekSeconds + 12 }
```

**Design:** Build a `gridN × gridN` grid of square tiles (rebuild if `gridN` changed). Flash the `pattern` tiles lit for `peekSeconds`, then clear. Player taps tiles to reproduce the set; each tap that is in `pattern` and not already counted increments `correct`. When the player has made `patternLen` taps (or a "Done" button), `report(correct)`.

- [ ] **Step 1: Implement** (grid builder keyed by `gridN`; light/clear helpers; tap accounting; token-guarded peek timer). Tiles ≥44px.
- [ ] **Step 2: Register + generateRoundInfo branch.**
- [ ] **Step 3: Compile check.**
- [ ] **Step 4: Playtest** (force). Verify peek → recreate → score = correct/patternLen. 375-wide.
- [ ] **Step 5: Commit** — `git commit -m "feat(minigames): BlueprintMemory"`

---

## Task 12: MapBuilding — TileDrop (sequence) + QAQuiz multi-option content

**Files:** Create `MapBuilding/TileDrop.luau`; modify `MinigameRegistry.luau`, `DevelopmentService.luau`, `GameData.TestingQuestions` (extend for up to 4 options).

**Interfaces:** TileDrop `inputKind="sequence"`. Params: `pieces`, `fallSeconds`.

**Server `generateRoundInfo` (TileDrop):**
```lua
elseif variantId == "TileDrop" then
	return { pieces = params.pieces, fallSeconds = params.fallSeconds, total = params.pieces, maxWait = params.pieces * params.fallSeconds + 3 }
```

**TileDrop design:** `pieces` pieces fall one at a time from the top of the panel over `fallSeconds` each. A target slot sits at the bottom. A "Drop" button (or tapping the piece) releases it; a drop counts as good if the piece is within a tolerance of the slot's x when dropped. Track `goodDrops`; after the last piece, `report(goodDrops)`. Keep it simple: horizontal moving piece + fixed slot is acceptable if vertical animation is hard — the scoring is good/total either way.

**QAQuiz multi-option:** extend `GameData.TestingQuestions` so each question can carry up to 4 options with a `correctIndex`, e.g.:
```lua
{ prompt = "...", options = { "A", "B", "C", "D" }, correctIndex = 3 },
```
Update the `QAQuiz` branch of `generateRoundInfo` to select `params.optionCount` options that always include the correct one plus `optionCount-1` distractors, then shuffle and record `correctIndex` (replaces the 2-option stub from Task 7).

- [ ] **Step 1: Implement TileDrop** (follow boilerplate; token-guarded fall loop).
- [ ] **Step 2: Extend `TestingQuestions` to ≥8 questions with up to 4 options; rewrite the QAQuiz `generateRoundInfo` branch for `optionCount`.**
- [ ] **Step 3: Register TileDrop + its generateRoundInfo branch.**
- [ ] **Step 4: Compile check.**
- [ ] **Step 5: Playtest** — TileDrop (force) AND QAQuiz at high difficulty (4 options). 375-wide.
- [ ] **Step 6: Commit** — `git commit -m "feat(minigames): TileDrop + QAQuiz multi-option"`

---

## Task 13: MapBuilding — PathConnect (sequence)

**Files:** Create `MapBuilding/PathConnect.luau`; modify `MinigameRegistry.luau`, `DevelopmentService.luau`.

**Interfaces:** `inputKind="sequence"`. Params: `gridN`, `timeSeconds`.

**Server `generateRoundInfo`:** pick a start cell (left column) and exit cell (right column) on a `gridN × gridN` grid; compute the shortest Manhattan path length `pathLen = gridN` (straight-ish). Return `{ gridN, startCell, exitCell, total = pathLen, maxWait = timeSeconds + 2 }`. (Obstacles are an optional hard-difficulty extra; omit for v1 to keep scoring simple.)

**Design:** Build the grid; mark start (green) and exit (gold). Player taps adjacent cells to extend a path from start toward exit. Track the count of correctly-connected cells that form a contiguous path from start; `correct = min(connectedTowardExit, total)`. On reaching exit or `timeSeconds` expiry, `report(correct)`. Contiguity check: each newly tapped cell must be orthogonally adjacent to the last path cell; ignore taps that aren't.

- [ ] **Step 1: Implement** (grid + adjacency validation + timer, token-guarded).
- [ ] **Step 2: Register + generateRoundInfo branch.**
- [ ] **Step 3: Compile check.**
- [ ] **Step 4: Playtest** (force). Verify connecting start→exit scores 1, partial path scores partial. 375-wide.
- [ ] **Step 5: Commit** — `git commit -m "feat(minigames): PathConnect"`

---

## Task 14: Testing — BugHunt (choice)

**Files:** Create `Testing/BugHunt.luau`; modify `MinigameRegistry.luau`, `DevelopmentService.luau`.

**Interfaces:** `inputKind="choice"`. Params: `gridN`, `answerSeconds`.

**Server `generateRoundInfo`:**
```lua
elseif variantId == "BugHunt" then
	local cells = params.gridN * params.gridN
	return { gridN = params.gridN, correctIndex = rng:NextInteger(1, cells), answerSeconds = params.answerSeconds }
```

**Design:** A `gridN × gridN` grid of identical tiles (e.g., 🙂), except tile `correctIndex` is subtly "glitched" (slightly different tint / a 🐞). Tapping tile `i` calls `report(i)`. Server scores via `scoreChoice(i, correctIndex, wrongScore)`. Make the glitch subtler at higher difficulty by reducing the tint delta (optional; base version: fixed subtle tint).

- [ ] **Step 1: Implement** (grid keyed by `gridN`; one odd tile; tap → `report(i)` once). Tiles ≥44px.
- [ ] **Step 2: Register + generateRoundInfo branch.**
- [ ] **Step 3: Compile check.**
- [ ] **Step 4: Playtest** (force). Correct tile = 1, wrong = wrongScore. 375-wide.
- [ ] **Step 5: Commit** — `git commit -m "feat(minigames): BugHunt"`

---

## Task 15: Testing — PassOrFail (sequence)

**Files:** Create `Testing/PassOrFail.luau`; modify `MinigameRegistry.luau`, `DevelopmentService.luau`, add `GameData.PassOrFailItems`.

**Interfaces:** `inputKind="sequence"`. Params: `count`, `flashSeconds`.

**Data:** `GameData.PassOrFailItems = { { text = "60 FPS on mobile", ship = true }, { text = "Crashes on launch", ship = false }, ... }` (≥ 12 items).

**Server `generateRoundInfo`:** pick `count` items (with repeats allowed), record the truth array:
```lua
elseif variantId == "PassOrFail" then
	local items, truth = {}, {}
	for i = 1, params.count do
		local it = GameData.PassOrFailItems[rng:NextInteger(1, #GameData.PassOrFailItems)]
		items[i] = it.text; truth[i] = it.ship
	end
	return { items = items, truth = truth, total = params.count, flashSeconds = params.flashSeconds, maxWait = params.count * params.flashSeconds + 3 }
```

**Design:** Show items one at a time (each visible `flashSeconds`), with ✅ Ship and ❌ Cut buttons. Record the player's answer per item; if none before it flips, count as wrong. `correct = Σ (answer[i] == truth[i])`; after the last item, `report(correct)`. The client advances items on a `flashSeconds` timer (token-guarded).

- [ ] **Step 1: Implement** (item label + two big buttons; per-item timer; tally).
- [ ] **Step 2: Add data, register, generateRoundInfo branch.**
- [ ] **Step 3: Compile check.**
- [ ] **Step 4: Playtest** (force). Verify score = correct/count. 375-wide (buttons finger-sized).
- [ ] **Step 5: Commit** — `git commit -m "feat(minigames): PassOrFail"`

---

## Task 16: Testing — CrashFix (mash)

**Files:** Create `Testing/CrashFix.luau`; modify `MinigameRegistry.luau` (generateRoundInfo: none — mash).

**Interfaces:** `inputKind="mash"`. Params: `targetCrashes`, `spawnInterval`, `windowSeconds`.

**Design:** Same spawn/tap structure as BugSquash but themed as crash popups (a small red "⚠ CRASH" card with a close ✕). Over `windowSeconds`, spawn a crash every `spawnInterval`; tapping the ✕ calls `report()` and removes it. Uncaught crashes can linger/stack (visual only). Score = closed / `targetCrashes` via `scoreMash` (server uses `target = params.targetCrashes`).

- [ ] **Step 1: Implement** (reuse the BugSquash spawn-loop pattern; token-guarded).
- [ ] **Step 2: Register.**
- [ ] **Step 3: Compile check.**
- [ ] **Step 4: Playtest** (force). Verify close-taps score. 375-wide.
- [ ] **Step 5: Commit** — `git commit -m "feat(minigames): CrashFix"`

---

## Task 17: Difficulty tuning + full mobile pass + final integration

**Files:** possibly tweak `GameData.VariantParams` / `StudioLevel*` / `DifficultyRampLevels` constants only.

- [ ] **Step 1:** Play full dev cycles at low Studio Level (fresh data) and at a high level (temporarily set `data.gamesReleased`/`subscribers` high via `execute_luau` on the server, then revert). Confirm: forgiving early, genuinely harder late, none impossible. Adjust the easy/hard endpoints as needed.
- [ ] **Step 2:** Confirm rotation shows a different variant per station across successive games and never repeats a station's previous pick.
- [ ] **Step 3: Full mobile pass** — at 375-wide, every variant is readable, all tap targets ≥44px and reachable, no element clipped by the grown panel or `MobileScale`.
- [ ] **Step 4:** Run `RunTests` once more — all asserts pass.
- [ ] **Step 5:** Update memory (`m7`/development-roadmap notes) if the roadmap references minigames. Optional.
- [ ] **Step 6: Commit** — `git commit -m "feat(minigames): difficulty tuning + mobile pass"`

---

## Self-review notes (author)

- **Spec coverage:** all 12 variants (Tasks 5,6,8–16), framework (5–7), Studio Level + difficulty (1,3), scoring (2), rotation (3,7), remote swap (4), mobile (each playtest step + Task 17), panel growth (7). ✅
- **Rounding:** `getVariantParams` rounds integer keys via `ints` table (Task 3). ✅
- **Sequence `total`:** every sequence variant sets `roundInfo.total` (KeyCombo, BlueprintMemory, TileDrop, PathConnect, PassOrFail). `waitAndScore` reads it. ✅
- **Naming consistency:** `pickVariantId`, `getVariantParams`, `VariantInputKind`, `StationVariantIds`, `generateRoundInfo`, `waitAndScore` used identically across tasks. ✅
- **Reuse:** CodeSprint/PrecisionPlace/QAQuiz migrate the existing modules (Tasks 5–6), old files deleted in Task 7. ✅
