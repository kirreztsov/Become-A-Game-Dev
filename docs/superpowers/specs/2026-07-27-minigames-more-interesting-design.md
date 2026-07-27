# More Interesting Minigames — Design Spec

**Goal:** Turn the three shallow development minigames (mash / stop-the-slider / 2-option quiz) into 12 deeper, tap-friendly minigames — 4 per station — that rotate for variety and get harder as the player's studio grows.

**Architecture:** A small shared minigame framework. Every minigame is a self-contained client "variant" module that follows one contract and uses one of **4 input kinds** (mash / timing / sequence / choice). The server owns each round: it picks a variant, converts a hidden **Studio Level** into a **difficulty** (0→1), tells the client, then scores the raw input by its kind. Scoring and difficulty math are pure functions in `GameData` so they can be unit-tested. The existing quality→cash→subscribers pipeline is untouched.

**Tech Stack:** Roblox / Luau, Rojo sync, existing `TestHarness`/`RunTests` unit tests, existing `MobileScale` UI scaler.

## Global Constraints

- **Mobile-playable (first-class):** every input is a TAP. No physical-keyboard dependency, no hover, no right-click. On-screen buttons are ≥ 44px with spacing. The layout must be verified at a 375-wide (phone) viewport, scaled by the existing `MobileScale` module (`REF_W,REF_H = 1000,650`, `MIN_SCALE = 0.55`).
- **No economy rewrite:** round score (0→1) feeds `devQuality` exactly as today (`DevelopmentService` averages phase scores → `TrendMatch.computeCash` → cash + subscribers). No payout formula changes.
- **Launch data:** `GameData.StartingCash` stays `0`.
- **Reuse existing work:** the current `CodingGame` (IDE editor look), `MapBuildingGame` (slider), and `TestingGame` (trivia) become three of the twelve variants — not thrown away.
- **Preserve the seated flow:** minigames still render inside a station panel shown only while the player occupies that station's Seat. Functional Seats / monitors / prompts stay intact.
- **UI colors** come from the shared `Theme` (Accent, Panel, Text, Success, Gold, Neutral…), consistent with the other panels.

---

## 1. The minigame contract

Each variant is a Luau module returning a table with this shape:

```lua
local Variant = {
    id = "CodeSprint",        -- unique string
    station = "Coding",       -- "Coding" | "MapBuilding" | "Testing"
    inputKind = "mash",       -- "mash" | "timing" | "sequence" | "choice"
}

-- Build UI once, into the station panel. `report` is a function the Host
-- supplies; the variant calls it to send input to the server (variants never
-- require Remotes directly).
function Variant.init(parent, theme, report) end

-- Show + configure a round. `difficulty` is 0→1. `params` is the pre-scaled
-- parameter table from the server. `roundInfo` carries per-round data the
-- server generated (e.g. the quiz question, the target pattern, RNG seed).
function Variant.startRound(difficulty, params, roundInfo) end

function Variant.hide() end
```

The variant is responsible only for **presentation + collecting taps**. It does not decide its own score. It calls `report(value)`:

| inputKind | how the variant calls `report` | server interprets |
|---|---|---|
| `mash` | `report()` once per successful tap | counts events in the window (pure speed) |
| `timing` | `report()` once, at the tap moment | stamps server time → marker position |
| `sequence` | `report(correctCount)` once when the round resolves | correct / total — covers **ordered recall** (KeyCombo, BlueprintMemory, PathConnect) *and* **rapid-fire accuracy** (PassOrFail) |
| `choice` | `report(chosenIndex)` once | matches against correct index |

## 2. The Host + Registry

- **`MinigameRegistry`** — maps each station to its ordered list of variant modules, and exposes `getVariant(station, id)` and `idsFor(station)`.
- **`MinigameHost`** — owns one station panel. On `UI.init` it calls `init` on every variant for its station (each builds its hidden UI once). When a `RoundStarted` arrives it calls `hide` on the previous variant and `startRound` on the named one. It provides each variant the `report` function, which fires the unified `ReportMinigameInput` remote. On `RoundComplete`/`PhaseComplete`/panel-close it hides the active variant.

One Host instance per station (Coding, MapBuilding, Testing). `UI.luau` stops wiring `CodingGame`/`MapBuildingGame`/`TestingGame` directly and instead creates three Hosts.

## 3. Studio Level → difficulty (pure, testable)

Added to `GameData`:

```lua
-- Blend games shipped + subscribers into one integer "studio level" (min 1).
-- Constants are tunable; these keep the early game gentle.
GameData.StudioLevelPerGames = 2       -- +1 level per 2 games released
GameData.StudioLevelPerSubs  = 50      -- +1 level per 50 subscribers
GameData.StudioLevelMax      = 50

function GameData.getStudioLevel(data)
    local lvl = 1
        + math.floor((data.gamesReleased or 0) / GameData.StudioLevelPerGames)
        + math.floor((data.subscribers or 0) / GameData.StudioLevelPerSubs)
    return math.min(lvl, GameData.StudioLevelMax)
end

-- Level 1 → 0.0 (easy), reaching 1.0 (max) at DifficultyRampLevels+1.
GameData.DifficultyRampLevels = 19

function GameData.getDifficulty(studioLevel)
    return math.clamp((studioLevel - 1) / GameData.DifficultyRampLevels, 0, 1)
end
```

So a brand-new studio plays at difficulty 0 (very forgiving); around level 20 it caps at 1.0 (toughest tuning). Both functions are unit-tested.

## 4. Difficulty → per-variant parameters

Each variant declares an `easy` and `hard` parameter set; the actual params are `lerp(easy, hard, difficulty)`. A single helper does the blend:

```lua
-- GameData.VariantParams[id] = { easy = {...}, hard = {...} }
function GameData.getVariantParams(id, difficulty)
    local spec = GameData.VariantParams[id]
    local out = {}
    for key, easyVal in pairs(spec.easy) do
        out[key] = easyVal + (spec.hard[key] - easyVal) * difficulty
    end
    return out
end
```

Integer-valued params (`markerCount`, `optionCount`, `patternLen`, `bugCount`, grid sizes, etc.) are rounded when consumed: `math.floor(value + 0.5)`. The variant's param spec lists which keys are integers so the server/variant rounds them consistently.

Examples (exact numbers finalized in the plan; these show the pattern):

| Variant | key params: easy → hard |
|---|---|
| CodeSprint (mash) | `targetTaps` 12 → 40, `windowSeconds` 3 → 3, `comboDecay` 0.6 → 1.4 |
| PrecisionPlace (timing) | `zoneHalfWidth` 0.18 → 0.05, `periodSeconds` 2.2 → 1.0, `markerCount` 1 → 2 |
| BlueprintMemory (sequence) | `patternLen` 3 → 8, `peekSeconds` 2.5 → 0.8 |
| QAQuiz (choice) | `optionCount` 2 → 4, `answerSeconds` 12 → 4 |

## 5. Per-kind scoring (pure, testable)

Added to `GameData` (mirrors today's inline logic, generalized):

```lua
function GameData.scoreMash(count, targetTaps)         -- CodingRound today
    return math.clamp(count / targetTaps, 0, 1)
end

function GameData.scoreTiming(markerPos, zoneCenter, zoneHalfWidth)  -- MapBuilding today
    local dist = math.abs(markerPos - zoneCenter)
    if dist > zoneHalfWidth then return 0 end
    return 1 - (dist / zoneHalfWidth)
end

function GameData.scoreSequence(correct, total)
    if total <= 0 then return 0 end
    return math.clamp(correct / total, 0, 1)
end

function GameData.scoreChoice(chosenIndex, correctIndex, wrongScore)  -- Testing today
    if chosenIndex == correctIndex then return 1 end
    return wrongScore
end
```

`wrongScore` reuses the existing `GameData.TestingWrongAnswerScore` (0.3). A round with no input before timeout scores 0 (same as today).

`markerPos` reuses the existing `GameData.getMarkerPosition(elapsed, period)`.

## 6. Rotation

One variant per **phase** (all 3 rounds of a station use the same variant), chosen at phase start, never repeating the station's previous pick. So each game you develop is a fresh Coding + Map + Testing trio, and successive games cycle through all 12.

```lua
-- rng() returns a float in [0,1) — injected so it can be unit-tested
-- (same pattern as TrendMatch.computeCash's roll function).
function GameData.pickVariantId(station, lastId, rng)
    local ids = GameData.StationVariantIds[station]   -- { "CodeSprint", ... }
    local pool = {}
    for _, id in ipairs(ids) do
        if id ~= lastId or #ids == 1 then table.insert(pool, id) end
    end
    return pool[math.floor(rng() * #pool) + 1]
end
```

The server tracks `lastVariantByStation[userId][station]` for the no-repeat rule.

## 7. The 12 variants

### Coding — "write the code"
1. **CodeSprint** `mash` — reuse current IDE editor; fill a progress bar, combo meter rewards rhythm. *(was `CodingGame`)*
2. **BugSquash** `mash` — 🐛 icons appear on code lines; tap each before it multiplies. Harder: more bugs, faster spread.
3. **KeyCombo** `sequence` — a run of on-screen key buttons flashes (`↑ ↓ { → ;`); tap them back in order. Harder: longer run, shorter peek.
4. **CompileCheck** `choice` — three code lines; tap the one that runs (spot the syntax error). Harder: subtler bug, shorter timer.

### MapBuilding — "build the level"
5. **PrecisionPlace** `timing` — current sweeping slider, deepened. *(was `MapBuildingGame`)* Harder: faster marker, thinner zone, then two markers.
6. **BlueprintMemory** `sequence` — a tile pattern flashes, then recreate it by tapping the same tiles. Harder: bigger pattern, shorter peek.
7. **TileDrop** `timing` — pieces fall one at a time; tap to drop each into its matching slot. Harder: faster falls, more pieces.
8. **PathConnect** `sequence` — tap tiles to draw a path from door to exit before the timer ends. Harder: bigger grid, obstacles, tighter timer.

### Testing — "find the bugs"
9. **BugHunt** `choice` — a grid of tiles, one glitches; tap the odd one out. Harder: more tiles, subtler glitch.
10. **QAQuiz** `choice` — trivia deepened with a timer + streak feedback. *(was `TestingGame`)* Harder: 3–4 options, faster timer.
11. **PassOrFail** `sequence` — features flash by ("ship it?"); tap ✅/❌ quickly and correctly. Reports how many of N you got right. Harder: faster flashes, more features.
12. **CrashFix** `mash` — whack-a-mole: crash popups appear; tap to close them before they pile up. Harder: faster/more crashes.

For `choice`/`sequence` variants that need generated content (quiz question, target pattern, path grid, glitch position), the **server** generates it in `roundInfo` so it stays authoritative, and the variant renders it.

## 8. Remotes change

- **Remove:** `ReportTap`, `ReportPlacement`, `ReportChoice`.
- **Add:** `ReportMinigameInput` — `FireServer(value)`. The server routes it by the active round's `inputKind` (per §1 table). `value` is `nil` for mash/timing, a count for sequence, an index for choice.
- **Unchanged:** `RequestStartDevelopment`, `PhaseStarted`, `RoundStarted` (now also carries `variantId`, `difficulty`, `params`, `roundInfo`), `RoundComplete`, `PhaseComplete`, `DevelopmentComplete`, `SubscribersGained`.

## 9. Server: generic round runner

`DevelopmentService` drops the three hardcoded `ROUND_RUNNERS`. New flow inside `runPhase` (worker-auto path unchanged):

```
data      = PlayerData.get(player)
difficulty = GameData.getDifficulty(GameData.getStudioLevel(data))
variantId  = GameData.pickVariantId(station, lastVariantByStation[uid][station], Random)
lastVariantByStation[uid][station] = variantId
inputKind  = GameData.getVariantInputKind(variantId)
params     = GameData.getVariantParams(variantId, difficulty)

for roundIndex = 1..RoundsPerPhase:
    roundInfo = generateRoundInfo(variantId, difficulty)   -- question/pattern/etc, or {}
    activeRounds[uid] = { kind = inputKind, params = params, roundInfo = roundInfo, ... }
    RoundStarted:FireClient(player, station, roundIndex, { variantId, difficulty, params, roundInfo })
    wait for the kind's completion or timeout    -- reuses today's per-kind wait loops
    score = scoreActiveRound(activeRounds[uid])  -- calls the right GameData.score* fn
    RoundComplete:FireClient(...)
PhaseComplete:FireClient(...)  -- average, as today
```

`ReportMinigameInput.OnServerEvent` updates `activeRounds[uid]` per kind (increment count / stamp time / store count / store index), replacing the three old handlers.

## 10. UI / panel changes

- `makeStationPanel` grows from `380×190` to about `420×300` (centered) so grids (BugHunt, PathConnect, TileDrop) and finger-sized targets fit. All three stations use the same size, so they stay consistent. `MobileScale` shrinks it on phones automatically.
- `UI.init` creates three `MinigameHost`s (one per station panel) instead of calling `CodingGame.init` / `MapBuildingGame.init` / `TestingGame.init`. The seat-tracking that shows/hides each panel is unchanged.

## 11. File structure

```
src/client/Minigames/
  MinigameHost.luau          -- swaps variants into a station panel, provides report()
  MinigameRegistry.luau      -- station -> { variant modules }
  Coding/CodeSprint.luau     -- from CodingGame.luau
  Coding/BugSquash.luau
  Coding/KeyCombo.luau
  Coding/CompileCheck.luau
  MapBuilding/PrecisionPlace.luau  -- from MapBuildingGame.luau
  MapBuilding/BlueprintMemory.luau
  MapBuilding/TileDrop.luau
  MapBuilding/PathConnect.luau
  Testing/BugHunt.luau
  Testing/QAQuiz.luau        -- from TestingGame.luau
  Testing/PassOrFail.luau
  Testing/CrashFix.luau
src/client/CodingGame.luau         -- deleted (moved)
src/client/MapBuildingGame.luau    -- deleted (moved)
src/client/TestingGame.luau        -- deleted (moved)

src/shared/GameData.luau           -- + StudioLevel, difficulty, scoring, variant tables, pickVariantId
src/shared/Remotes.luau            -- swap 3 report remotes for ReportMinigameInput
src/server/DevelopmentService.luau -- generic runner + single input handler
src/client/UI.luau                 -- wire 3 Hosts; grow station panel
src/shared/Tests/RunTests.luau     -- new assertEqual tests
```

## 12. Data flow

```
Studio Level (games + subs)  --GameData.getDifficulty-->  difficulty 0..1
        |                                                        |
 DevelopmentService.runPhase --pickVariantId--> variantId        |
        |                                                        v
        +--> RoundStarted{variantId,difficulty,params,roundInfo} --> MinigameHost
                                                                        |
                                                                 shows Variant.startRound
                                                                        |
                                                     player taps --> report(value)
                                                                        |
                                            ReportMinigameInput --> activeRounds[uid]
                                                                        |
                              round ends --> GameData.score*() --> score 0..1
                                                                        |
                          phase average --> devQuality --> cash + subscribers (unchanged)
```

## 13. Testing

**Unit tests** (`RunTests.luau`, `assertEqual`):
- `getStudioLevel`: 0 games/0 subs → 1; boundaries at the per-games / per-subs thresholds; clamps at `StudioLevelMax`.
- `getDifficulty`: level 1 → 0; level `DifficultyRampLevels+1` → 1; clamps.
- `getVariantParams`: at difficulty 0 returns `easy`, at 1 returns `hard`, at 0.5 the midpoint.
- `scoreMash` / `scoreTiming` / `scoreSequence` / `scoreChoice`: known inputs → known scores (including out-of-zone → 0, wrong choice → `wrongScore`).
- `pickVariantId`: with a stub `rng`, never returns `lastId` when the pool has >1 option; returns the sole option when the station has 1.

**Manual playtest** in Studio, per station, on desktop **and** the 375-wide phone viewport: each variant renders in the panel, is tappable with a finger, reports correctly, and scores flow into a completed dev cycle.

## 14. Build order (each step independently playable)

1. **Framework + math:** contract, `MinigameHost`, `MinigameRegistry`, `GameData` additions (level, difficulty, scoring, `pickVariantId`, param tables), unit tests, `ReportMinigameInput`, generic `DevelopmentService` runner, grow the panel. Move the 3 existing minigames into variants (CodeSprint, PrecisionPlace, QAQuiz) so a full cycle still works end-to-end with rotation of 1 variant per station.
2. **Coding station:** add BugSquash, KeyCombo, CompileCheck → playtest all 4.
3. **MapBuilding station:** add BlueprintMemory, TileDrop, PathConnect → playtest all 4.
4. **Testing station:** add BugHunt, PassOrFail, CrashFix → playtest all 4.
5. **Difficulty tuning + mobile pass:** verify the ramp feels right across Studio Levels and every variant is comfortable on a phone.
