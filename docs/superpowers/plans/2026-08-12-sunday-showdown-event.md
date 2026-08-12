# Sunday Showdown — Weekend Event (B2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a recurring Sunday-only event: a +50% cash & subs boost, a 6-quest arc whose targets scale continuously with the player, and a final random "Champion" PC part (125% of the player's best part) collectible across weeks.

**Architecture:** Same pure-logic + server-authoritative-claim shape as the existing quests/daily-challenges. All math lives in a pure `EventData` module (unit-tested in RunTests). The server (`EventService`) snapshots a per-Sunday baseline, validates claims, and grants rewards; the client (`EventPanel`) renders bars from the `data` table it already receives. The Champion-part bonus folds into the existing PC-parts economy multipliers.

**Tech Stack:** Roblox Luau, Rojo sync, Studio playtest (no CI). Tests run via `src/shared/Tests/RunTests.luau` in a live Studio datamodel.

## Global Constraints

- **Verification** is `rojo build` + Studio playtest; pure logic is asserted in `src/shared/Tests/RunTests.luau`. There is no CI runner.
- **Claims are server-authoritative.** The client never sends amounts; the server re-validates via `EventData` before granting.
- **No `loadFailed` guard on claims** — this is game cash, not Robux; claiming must work in Studio (DataStore is off there). Same lesson as quests/challenges.
- **Sunday = server UTC.** The Unix epoch (day 0) is a Thursday, so `math.floor(now/86400) % 7 == 3` is Sunday. This is the single source of truth for "is the event active".
- **Emoji** in Luau string literals are written directly (e.g. `"🏆"`), matching `ChallengeData`/`ChallengePanel`.
- **Champion parts must never touch Robux monetization** — they are game-earned only.
- New HUD button goes at left-stack **y offset −278** (the next free 52px slot below Perks at −226).

---

### Task 1: `EventData` pure module + unit tests

The heart of the feature: all event math with zero side effects. Everything else consumes this.

**Files:**
- Create: `src/shared/EventData.luau`
- Modify: `src/shared/Tests/RunTests.luau` (add assertions before `t:summary()` at line 316)
- Test: `src/shared/Tests/RunTests.luau`

**Interfaces:**
- Consumes: `GameData.PCParts`, `GameData.getPCPart(id)`, `GameData.getPCPartModel(id, level)` (already exist).
- Produces (used by later tasks):
  - `EventData.isEventActive(now: number) -> boolean`
  - `EventData.dayIndex(now) -> number`
  - `EventData.secondsUntilEnd(now) -> number`
  - `EventData.scale(data) -> number`
  - `EventData.QUESTS` (array of 6 `{ id, title, desc, icon, stat, base, rewardBase, cap? }`)
  - `EventData.target(data, i) -> number`
  - `EventData.rewardCash(data, i) -> number`
  - `EventData.progress(data, i) -> number`
  - `EventData.isComplete(data, i) -> boolean`
  - `EventData.isClaimed(data, i) -> boolean`
  - `EventData.canClaim(data, i) -> boolean`  (sequential)
  - `EventData.rolloverIfNeeded(data, dayIndex) -> boolean`
  - `EventData.applyQuestClaim(data, i) -> { cash: number, final: boolean } | nil`
  - `EventData.bestPartBonus(data) -> number`
  - `EventData.rollChampionPart(data, rng?) -> (partId: string?, bonus: number?)`
  - `EventData.applyChampionGrant(data, partId, bonus)`
  - `EventData.consolationCash(data) -> number`
  - `EventData.list(data) -> array` and `EventData.championList(data) -> array` (client render)
  - `EventData.championCount(data) -> number`
  - `EventData.claimableCount(data) -> number`

- [ ] **Step 1: Write `src/shared/EventData.luau`**

```lua
-- Sunday Showdown weekend event (roadmap B2). Active only on Sunday (server
-- UTC). A 6-quest arc whose targets scale continuously with the player's
-- progression; finishing all 6 grants a random "Champion" PC part worth 125% of
-- the player's best part. Progress is TODAY's gain vs a baseline snapshotted at
-- the start of the player's Sunday. All math here is pure (no side effects) so
-- the client renders from the same data it gets via PlayerStateUpdated, and the
-- server (EventService) owns baseline + claims. Tested in RunTests.
local GameData = require(script.Parent.GameData)

local EventData = {}

EventData.DAY_SECONDS = 86400
EventData.EVENT_DOW = 3 -- Unix day 0 is a Thursday, so day%7==3 is Sunday.
EventData.SUB_REF = 1000 -- progression scale reference (tunable)
EventData.CHAMPION_FACTOR = 1.25 -- a Champion part = 125% of your best part
EventData.MIN_CHAMPION_BONUS = 0.15 -- floor so a fresh winner still gets value

-- The 6 sequential quests. stat is one of "games"/"subs"/"cash"/"hits", all
-- monotonic-within-a-day counters so today's progress = current - baseline.
-- base = target at scale 1; rewardBase = cash reward at scale 1. cap (optional)
-- clamps the scaled target (used to keep the trendy-hit quest reachable).
EventData.QUESTS = {
	{ id = "e1_games", title = "Get Building", desc = "Release %d games today", icon = "🎮", stat = "games", base = 5, rewardBase = 3000 },
	{ id = "e2_subs", title = "Go Viral", desc = "Gain %d subscribers today", icon = "⭐", stat = "subs", base = 2000, rewardBase = 4000 },
	{ id = "e3_cash", title = "Cash In", desc = "Earn $%d today", icon = "💰", stat = "cash", base = 10000, rewardBase = 5000 },
	{ id = "e4_games", title = "Studio Grind", desc = "Release %d more games today", icon = "🎮", stat = "games", base = 12, rewardBase = 7000 },
	{ id = "e5_hits", title = "Chase the Trend", desc = "Release %d trendy hit(s) today", icon = "🔥", stat = "hits", base = 1, rewardBase = 9000, cap = 3 },
	{ id = "e6_cash", title = "Final Push", desc = "Earn $%d today", icon = "🏆", stat = "cash", base = 50000, rewardBase = 15000 },
}

function EventData.dayIndex(now)
	return math.floor((now or 0) / EventData.DAY_SECONDS)
end

-- True only on Sunday (server UTC).
function EventData.isEventActive(now)
	return EventData.dayIndex(now) % 7 == EventData.EVENT_DOW
end

-- Seconds until the current day ends (the "event ends in" countdown; only
-- meaningful while active).
function EventData.secondsUntilEnd(now)
	now = now or 0
	return EventData.DAY_SECONDS - (now % EventData.DAY_SECONDS)
end

-- Smooth, sub-linear progression multiplier from subscriber count. scale(0 subs)
-- == 1 and rises slowly (+1 per 10x subs past SUB_REF), so quest targets grow
-- with the player but stay achievable in a day. No bucketed tiers.
function EventData.scale(data)
	local subs = (data and data.subscribers) or 0
	return 1 + math.log(1 + subs / EventData.SUB_REF, 10)
end

function EventData.target(data, i)
	local q = EventData.QUESTS[i]
	if not q then return 0 end
	local t = math.ceil(q.base * EventData.scale(data))
	if q.cap then
		t = math.min(q.cap, t)
	end
	return t
end

function EventData.rewardCash(data, i)
	local q = EventData.QUESTS[i]
	if not q then return 0 end
	return math.floor(q.rewardBase * EventData.scale(data))
end

local function statCurrent(data, stat)
	if stat == "games" then
		return data.gamesReleased or 0
	elseif stat == "subs" then
		return data.subscribers or 0
	elseif stat == "cash" then
		return data.totalCashEarned or 0
	elseif stat == "hits" then
		return data.trendyHits or 0
	end
	return 0
end

-- Today's progress toward quest i: (current stat - baseline), clamped
-- [0, target]. Baseline lives in data.eventBaseline (set on rollover).
function EventData.progress(data, i)
	local q = EventData.QUESTS[i]
	if not q then return 0 end
	local base = (data.eventBaseline or {})[q.stat] or 0
	local gained = statCurrent(data, q.stat) - base
	return math.clamp(gained, 0, EventData.target(data, i))
end

function EventData.isComplete(data, i)
	return EventData.progress(data, i) >= EventData.target(data, i)
end

function EventData.isClaimed(data, i)
	return (data.eventQuestsClaimed or {})[i] == true
end

-- Sequential: quest i is claimable only if it is complete, unclaimed, and its
-- predecessor (if any) is already claimed. Time-gating (Sunday-only) is enforced
-- by the server; this stays pure and time-independent.
function EventData.canClaim(data, i)
	if i < 1 or i > #EventData.QUESTS then
		return false
	end
	if EventData.isClaimed(data, i) then
		return false
	end
	if i > 1 and not EventData.isClaimed(data, i - 1) then
		return false
	end
	return EventData.isComplete(data, i)
end

-- Start a fresh Sunday arc when the stored event day is stale: snapshot the
-- baseline stats and clear this arc's claims. Keyed on dayIndex (like the daily
-- challenges); harmless on non-Sundays since the arc is inactive then. Returns
-- true if it changed anything. Server-authoritative; the client only reads.
function EventData.rolloverIfNeeded(data, dayIndex)
	if data.eventDay == dayIndex then
		return false
	end
	data.eventDay = dayIndex
	data.eventBaseline = {
		games = data.gamesReleased or 0,
		subs = data.subscribers or 0,
		cash = data.totalCashEarned or 0,
		hits = data.trendyHits or 0,
	}
	data.eventQuestsClaimed = {}
	return true
end

-- Mark quest i claimed and return its cash reward + whether it was the final
-- quest (the caller then rolls a Champion part). Pure: mutates
-- eventQuestsClaimed only; caller grants + saves. nil if not claimable.
function EventData.applyQuestClaim(data, i)
	if not EventData.canClaim(data, i) then
		return nil
	end
	data.eventQuestsClaimed = data.eventQuestsClaimed or {}
	data.eventQuestsClaimed[i] = true
	return { cash = EventData.rewardCash(data, i), final = (i == #EventData.QUESTS) }
end

-- The bonus of the player's single best-equipped shop part (max over all 7).
function EventData.bestPartBonus(data)
	local pcParts = (data and data.pcParts) or {}
	local best = 0
	for _, p in ipairs(GameData.PCParts) do
		local model = GameData.getPCPartModel(p.id, pcParts[p.id] or 0)
		if model and model.bonus > best then
			best = model.bonus
		end
	end
	return best
end

local function round2(x)
	return math.floor(x * 100 + 0.5) / 100
end

-- Roll a random PC-part category the player has NOT yet won a Champion of, and
-- the locked bonus for it (125% of their best current part, floored to a
-- meaningful minimum). Returns (nil, nil) when all 7 are already collected.
-- rng(n) -> integer in [1, n]; defaults to math.random for live play.
function EventData.rollChampionPart(data, rng)
	rng = rng or math.random
	local owned = data.eventParts or {}
	local pool = {}
	for _, p in ipairs(GameData.PCParts) do
		if owned[p.id] == nil then
			pool[#pool + 1] = p.id
		end
	end
	if #pool == 0 then
		return nil, nil
	end
	local partId = pool[rng(#pool)]
	local bonus = math.max(EventData.MIN_CHAMPION_BONUS, round2(EventData.CHAMPION_FACTOR * EventData.bestPartBonus(data)))
	return partId, bonus
end

function EventData.applyChampionGrant(data, partId, bonus)
	data.eventParts = data.eventParts or {}
	data.eventParts[partId] = bonus
end

-- Consolation cash when the final quest is finished but all 7 Champion parts are
-- already collected (the chase is complete).
function EventData.consolationCash(data)
	return math.floor(20000 * EventData.scale(data))
end

-- Client render: the 6 quests with progress/targets/flags/reward.
function EventData.list(data)
	local out = {}
	for i, q in ipairs(EventData.QUESTS) do
		local target = EventData.target(data, i)
		local done = EventData.isComplete(data, i)
		local claimed = EventData.isClaimed(data, i)
		local locked = (i > 1) and not EventData.isClaimed(data, i - 1)
		out[i] = {
			index = i,
			title = q.title,
			desc = string.format(q.desc, target),
			icon = q.icon,
			progress = EventData.progress(data, i),
			target = target,
			done = done,
			claimed = claimed,
			locked = locked,
			claimable = EventData.canClaim(data, i),
			rewardCash = EventData.rewardCash(data, i),
		}
	end
	return out
end

-- Client render: the 7-part Champion collection strip.
function EventData.championList(data)
	local owned = (data and data.eventParts) or {}
	local out = {}
	for _, p in ipairs(GameData.PCParts) do
		out[#out + 1] = {
			id = p.id,
			icon = p.icon,
			name = p.name,
			owned = owned[p.id] ~= nil,
			bonus = owned[p.id],
		}
	end
	return out
end

function EventData.championCount(data)
	local n = 0
	for _ in pairs((data and data.eventParts) or {}) do
		n += 1
	end
	return n
end

function EventData.claimableCount(data)
	local n = 0
	for i = 1, #EventData.QUESTS do
		if EventData.canClaim(data, i) then
			n += 1
		end
	end
	return n
end

return EventData
```

- [ ] **Step 2: Add assertions in `src/shared/Tests/RunTests.luau` immediately before `t:summary()` (line 316)**

```lua
-- EventData: Sunday gating, scaling, sequential claims, champion roll
local EventData = require(script.Parent.Parent.EventData)

-- Sunday detection (Unix day 0 = Thursday; day 3 = Sunday)
t:assertEqual(EventData.isEventActive(0), false, "event: epoch (Thursday) is not active")
t:assertEqual(EventData.isEventActive(2 * 86400), false, "event: Saturday is not active")
t:assertEqual(EventData.isEventActive(3 * 86400), true, "event: Sunday IS active")
t:assertEqual(EventData.isEventActive(3 * 86400 + 5000), true, "event: still Sunday later in the day")
t:assertEqual(EventData.isEventActive(4 * 86400), false, "event: Monday is not active")
t:assertEqual(EventData.isEventActive(10 * 86400), true, "event: a later Sunday is active")
t:assertEqual(EventData.secondsUntilEnd(3 * 86400 + 100), 86300, "event: seconds until day ends")

-- Scaling is continuous and monotonic in subscribers
t:assertEqual(math.abs(EventData.scale({ subscribers = 0 }) - 1) < 1e-9, true, "event: scale at 0 subs is 1")
t:assertEqual(EventData.scale({ subscribers = 50000 }) > EventData.scale({ subscribers = 0 }), true, "event: scale rises with subs")
t:assertEqual(EventData.target({ subscribers = 50000 }, 1) >= EventData.target({ subscribers = 0 }, 1), true, "event: target scales up with subs")
t:assertEqual(EventData.target({ subscribers = 0 }, 1), 5, "event: quest 1 base target is 5 at scale 1")
t:assertEqual(EventData.target({ subscribers = 1e9 }, 5), 3, "event: trendy-hit target is capped at 3")

-- Rollover snapshots baseline + clears claims; progress is today's delta
local ed = { gamesReleased = 4, subscribers = 100, totalCashEarned = 500, trendyHits = 2, eventDay = -1 }
t:assertEqual(EventData.rolloverIfNeeded(ed, 3), true, "event: rollover on stale day")
t:assertEqual(ed.eventDay, 3, "event: rollover sets the day")
t:assertEqual(ed.eventBaseline.games, 4, "event: baseline snapshots games")
t:assertEqual(ed.eventBaseline.cash, 500, "event: baseline snapshots totalCashEarned")
t:assertEqual(EventData.rolloverIfNeeded(ed, 3), false, "event: no rollover on same day")
t:assertEqual(EventData.progress(ed, 1), 0, "event: 0 progress right after baseline")
ed.gamesReleased = 6 -- released 2 today
t:assertEqual(EventData.progress(ed, 1), 2, "event: progress = today's delta")

-- Sequential claiming: quest 2 locked until quest 1 claimed
ed.gamesReleased = ed.eventBaseline.games + EventData.target(ed, 1) -- complete quest 1
t:assertEqual(EventData.canClaim(ed, 1), true, "event: quest 1 complete -> claimable")
ed.subscribers = ed.eventBaseline.subs + EventData.target(ed, 2) -- also complete quest 2
t:assertEqual(EventData.canClaim(ed, 2), false, "event: quest 2 locked until quest 1 claimed")
local r1 = EventData.applyQuestClaim(ed, 1)
t:assertEqual(r1 ~= nil and r1.final, false, "event: quest 1 claim is not final")
t:assertEqual(EventData.isClaimed(ed, 1), true, "event: quest 1 marked claimed")
t:assertEqual(EventData.canClaim(ed, 1), false, "event: cannot claim quest 1 twice")
t:assertEqual(EventData.canClaim(ed, 2), true, "event: quest 2 unlocks after quest 1")

-- Final quest reports final = true
local edF = { eventDay = 3, eventBaseline = { games = 0, subs = 0, cash = 0, hits = 0 }, eventQuestsClaimed = { [1]=true,[2]=true,[3]=true,[4]=true,[5]=true }, totalCashEarned = 0, subscribers = 0 }
edF.totalCashEarned = EventData.target(edF, 6)
local r6 = EventData.applyQuestClaim(edF, 6)
t:assertEqual(r6 ~= nil and r6.final, true, "event: quest 6 claim is final")

-- Champion part roll: locked bonus = 1.25 * best part, excludes owned, nil at 7
local champData = { pcParts = { CPU = 5 }, eventParts = {} } -- CPU lvl 5 bonus 0.65
t:assertEqual(math.abs(EventData.bestPartBonus(champData) - 0.65) < 1e-9, true, "event: best part bonus reads the top model")
local pid, pbonus = EventData.rollChampionPart(champData, function() return 1 end)
t:assertEqual(pid ~= nil, true, "event: rolls a part when some are unowned")
t:assertEqual(math.abs(pbonus - 0.81) < 1e-9, true, "event: champion bonus = round2(1.25*0.65)=0.81")
EventData.applyChampionGrant(champData, pid, pbonus)
t:assertEqual(champData.eventParts[pid], pbonus, "event: grant stores the bonus")
-- Fill all 7, then rolling returns nil
for _, p in ipairs(GameData.PCParts) do champData.eventParts[p.id] = 0.5 end
local nilId = EventData.rollChampionPart(champData, function() return 1 end)
t:assertEqual(nilId, nil, "event: nil when all 7 champion parts owned")
-- Minimum bonus floor for a fresh winner (no parts)
local _, freshBonus = EventData.rollChampionPart({ pcParts = {}, eventParts = {} }, function() return 1 end)
t:assertEqual(math.abs(freshBonus - EventData.MIN_CHAMPION_BONUS) < 1e-9, true, "event: fresh winner gets the minimum bonus floor")
```

- [ ] **Step 3: Run the test suite to verify it passes**

In Studio (Rojo synced), run `src/shared/Tests/RunTests.luau` (the existing way the harness is executed). Expected: all EventData assertions PASS, summary reports 0 failures. If `require` of `EventData` errors, confirm the file is at `src/shared/EventData.luau` so it maps to `ReplicatedStorage.Shared.EventData`.

- [ ] **Step 4: Commit**

```bash
git add src/shared/EventData.luau src/shared/Tests/RunTests.luau
git commit -m "feat(event): EventData pure module + unit tests (Sunday Showdown B2)"
```

---

### Task 2: PlayerData fields (defaults + backfill + counters)

Add the event fields and the two new lifetime counters so every player has them.

**Files:**
- Modify: `src/server/PlayerData.luau` (defaults `defaultData()` ~line 93–96; backfill ~line 154)

**Interfaces:**
- Produces: on every `data` table — `eventParts = {}`, `eventBaseline = { games, subs, cash, hits }`, `eventDay = -1`, `eventQuestsClaimed = {}`, `totalCashEarned = 0`, `trendyHits = 0`.

- [ ] **Step 1: Add fields to `defaultData()`** — insert just before the closing `homeItems = {},` line (after the `weekly = {...}` line, ~line 93). Insert:

```lua
		-- Sunday Showdown event (see EventData): the day index the current arc's
		-- baseline belongs to, the stat snapshot taken at that Sunday's start,
		-- which quests are claimed, and the permanently-collected Champion parts
		-- (partId -> bonus). -1 forces a fresh roll. Plus two lifetime counters
		-- the event's cash/trendy quests measure deltas from.
		eventDay = -1,
		eventBaseline = { games = 0, subs = 0, cash = 0, hits = 0 },
		eventQuestsClaimed = {},
		eventParts = {},
		totalCashEarned = 0,
		trendyHits = 0,
```

- [ ] **Step 2: Add backfill** — in the existing-save backfill block, immediately after the challenge backfill (`data.challengeClaimed = data.challengeClaimed or {}`, ~line 154), insert:

```lua
				if data.eventDay == nil then
					data.eventDay = -1
				end
				data.eventBaseline = data.eventBaseline or { games = 0, subs = 0, cash = 0, hits = 0 }
				data.eventQuestsClaimed = data.eventQuestsClaimed or {}
				data.eventParts = data.eventParts or {}
				data.totalCashEarned = data.totalCashEarned or 0
				data.trendyHits = data.trendyHits or 0
```

- [ ] **Step 3: Verify sync** — save; confirm Rojo shows the file synced and Studio server starts with no errors. Full behaviour is verified in Task 7; here just confirm no syntax error on sync.

- [ ] **Step 4: Commit**

```bash
git add src/server/PlayerData.luau
git commit -m "feat(event): PlayerData event fields + lifetime cash/trendy counters"
```

---

### Task 3: Fold Champion parts into the PC-parts economy multipliers

Champion parts add their bonus on top of the shop `pcParts` levels, in the same money/followers split.

**Files:**
- Modify: `src/shared/GameData.luau` (`_pcPartsMultiplier` ~590; `getPCPartsCashMultiplier` ~605; `getPCPartsSubsMultiplier` ~610)
- Test: `src/shared/Tests/RunTests.luau`

**Interfaces:**
- Consumes: `data.eventParts` (from Task 2).
- Produces: `GameData.getPCPartsCashMultiplier(pcParts, eventParts)` and `GameData.getPCPartsSubsMultiplier(pcParts, eventParts)` — `eventParts` optional; nil behaves exactly as today. `_pcPartById` (already defined at ~561) is reused.

- [ ] **Step 1: Add a failing test** — in `RunTests.luau`, before `t:summary()`:

```lua
-- Champion parts fold into the PC-parts multipliers (money vs followers split)
local baseCash = GameData.getPCPartsCashMultiplier({ CPU = 0 })
t:assertEqual(math.abs(GameData.getPCPartsCashMultiplier({ CPU = 0 }, { CPU = 0.5 }) - (baseCash + 0.5)) < 1e-9, true, "champion: CPU (money) adds to cash multiplier")
t:assertEqual(math.abs(GameData.getPCPartsSubsMultiplier({ GPU = 0 }, { CPU = 0.5 }) - GameData.getPCPartsSubsMultiplier({ GPU = 0 })) < 1e-9, true, "champion: a money part does NOT touch the subs multiplier")
t:assertEqual(math.abs(GameData.getPCPartsSubsMultiplier({ GPU = 0 }, { GPU = 0.4 }) - (GameData.getPCPartsSubsMultiplier({ GPU = 0 }) + 0.4)) < 1e-9, true, "champion: GPU (followers) adds to subs multiplier")
t:assertEqual(GameData.getPCPartsCashMultiplier({ CPU = 0 }, nil), baseCash, "champion: nil eventParts behaves as before")
```

- [ ] **Step 2: Run to verify it fails**

Run `RunTests.luau`. Expected: FAIL — the current `getPCPartsCashMultiplier` ignores a second argument, so the `+0.5` assertions fail.

- [ ] **Step 3: Implement** — replace the three functions (`_pcPartsMultiplier` and the two public wrappers, lines ~590–612) with:

```lua
local function _pcPartsMultiplier(pcParts, kind, eventParts)
	pcParts = pcParts or {}
	local m = 1
	for _, p in ipairs(GameData.PCParts) do
		if p.kind == kind then
			local model = p.models[(pcParts[p.id] or 0) + 1]
			if model then
				m += model.bonus
			end
		end
	end
	-- Champion parts (event reward): a permanent bonus per part, added on top of
	-- the shop level, in the same money/followers split.
	if eventParts then
		for id, bonus in pairs(eventParts) do
			local p = _pcPartById[id]
			if p and p.kind == kind then
				m += bonus
			end
		end
	end
	return m
end

-- Cash-per-game multiplier from the money categories (CPU/RAM/Storage/Cooling),
-- plus any Champion (event) parts in those categories.
function GameData.getPCPartsCashMultiplier(pcParts, eventParts)
	return _pcPartsMultiplier(pcParts, "money", eventParts)
end

-- Subscribers-per-release multiplier from the follower categories
-- (GPU/Monitor/RGB), plus any Champion (event) parts in those categories.
function GameData.getPCPartsSubsMultiplier(pcParts, eventParts)
	return _pcPartsMultiplier(pcParts, "followers", eventParts)
end
```

- [ ] **Step 4: Run to verify it passes**

Run `RunTests.luau`. Expected: PASS (new champion assertions green; all prior assertions still green).

- [ ] **Step 5: Commit**

```bash
git add src/shared/GameData.luau src/shared/Tests/RunTests.luau
git commit -m "feat(event): fold Champion parts into PC-parts cash/subs multipliers"
```

---

### Task 4: DevelopmentService — event boost + counters + pass eventParts

Apply the +50% Sunday boost, feed the two lifetime counters, and thread `data.eventParts` into the multipliers.

**Files:**
- Modify: `src/server/DevelopmentService.luau` (require block top of file; release grant lines 388–398)

**Interfaces:**
- Consumes: `EventData.isEventActive` (Task 1), `data.eventParts` (Task 2), the extended multipliers (Task 3).
- Produces: increments `data.totalCashEarned` and `data.trendyHits`; applies ×1.5 to released-game cash & subs on Sundays.

- [ ] **Step 1: Require `EventData`** — at the top of `DevelopmentService.luau`, alongside the other `require` lines, add:

```lua
local EventData = require(game.ReplicatedStorage.Shared.EventData)
```

- [ ] **Step 2: Replace lines 388–398.** The current block is:

```lua
				cash = math.floor(cash * GameData.getPCPartsCashMultiplier(data.pcParts) * GameData.getFloorMultiplier(data.houseTier) * GameData.getBoostMultiplier(data, Workspace:GetServerTimeNow()) * GameData.getSubscriberMultiplier(data.subscribers) * GameData.getPrestigeMultiplier(data.prestigeLevel) * GameData.getPassCashMultiplier(data) * PerkData.cashMult(data))

				data.cash += cash
				data.gamesReleased += 1
				PlayerData.addWeekly(data, "cash", cash, os.time())
				PlayerData.addWeekly(data, "gamesReleased", 1, os.time())

				-- Releasing a game grows your channel: more subscribers for a better
				-- game, with a big bonus when it matched a trend. This can cross a
				-- Play Button milestone (bonus cash + a trophy in the studio).
				local subsGained = math.floor(GameData.getSubsForRelease(devQuality, hitBonus) * GameData.getPassSubsMultiplier(data) * GameData.getPCPartsSubsMultiplier(data.pcParts) * PerkData.subsMult(data))
```

Replace it with (adds `eventBoost`, the two counters, and threads `data.eventParts`):

```lua
				local eventNow = os.time()
				local eventBoost = EventData.isEventActive(eventNow) and 1.5 or 1
				cash = math.floor(cash * GameData.getPCPartsCashMultiplier(data.pcParts, data.eventParts) * GameData.getFloorMultiplier(data.houseTier) * GameData.getBoostMultiplier(data, Workspace:GetServerTimeNow()) * GameData.getSubscriberMultiplier(data.subscribers) * GameData.getPrestigeMultiplier(data.prestigeLevel) * GameData.getPassCashMultiplier(data) * PerkData.cashMult(data) * eventBoost)

				data.cash += cash
				data.gamesReleased += 1
				-- Lifetime cash-earned (monotonic) — the event's cash quests delta from this.
				data.totalCashEarned = (data.totalCashEarned or 0) + cash
				-- Trendy-hit counter (monotonic) — the event's trendy-hit quest delta from this.
				if hitBonus then
					data.trendyHits = (data.trendyHits or 0) + 1
				end
				PlayerData.addWeekly(data, "cash", cash, os.time())
				PlayerData.addWeekly(data, "gamesReleased", 1, os.time())

				-- Releasing a game grows your channel: more subscribers for a better
				-- game, with a big bonus when it matched a trend. This can cross a
				-- Play Button milestone (bonus cash + a trophy in the studio).
				local subsGained = math.floor(GameData.getSubsForRelease(devQuality, hitBonus) * GameData.getPassSubsMultiplier(data) * GameData.getPCPartsSubsMultiplier(data.pcParts, data.eventParts) * PerkData.subsMult(data) * eventBoost)
```

> Confirm you did not end up with a duplicated `data.cash += cash` or `local subsGained` line after the replacement.

- [ ] **Step 3: Verify sync + no error** — Rojo sync; start the Studio server; release a game and confirm no runtime error (full behaviour verified in Task 7).

- [ ] **Step 4: Commit**

```bash
git add src/server/DevelopmentService.luau
git commit -m "feat(event): Sunday +50% boost, lifetime cash/trendy counters, thread eventParts"
```

---

### Task 5: `EventService` + Remote + server wiring

Server owns rollover (per-Sunday baseline) and the sequential, Sunday-gated claim that grants quest cash and — on the final quest — a random Champion part.

**Files:**
- Create: `src/server/EventService.luau`
- Modify: `src/shared/Remotes.luau` (add `"RequestClaimEventQuest"` to `REMOTE_NAMES`, after `"RequestClaimChallenge"` line 52)
- Modify: `src/server/init.server.luau` (require ~20; start ~39)

**Interfaces:**
- Consumes: `EventData` (Task 1), `PlayerData` (`get`/`save`), `Remotes.RequestClaimEventQuest`, `Remotes.PlayerStateUpdated`.
- Produces: `EventService.start()`.

- [ ] **Step 1: Add the remote** — in `src/shared/Remotes.luau`, add a line after `"RequestClaimChallenge",` (line 52):

```lua
	"RequestClaimEventQuest",
```

- [ ] **Step 2: Write `src/server/EventService.luau`**

```lua
-- Server side of the Sunday Showdown event (roadmap B2). Mirrors
-- ChallengeService: roll each player onto the current Sunday arc (snapshot the
-- baseline + clear claims) on join and across the day boundary, and handle a
-- sequential CLAIM. Claims are Sunday-gated (server-authoritative) and re-check
-- completion via EventData. Finishing the final quest grants a random Champion
-- PC part (or scaled consolation cash when all 7 are already collected).
local Players = game:GetService("Players")

local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local EventData = require(game.ReplicatedStorage.Shared.EventData)
local PlayerData = require(script.Parent.PlayerData)

local EventService = {}

-- Roll a player onto today's arc if their stored event day is stale; push an
-- update if so.
local function rollover(player)
	local data = PlayerData.get(player)
	if not data then
		return
	end
	if EventData.rolloverIfNeeded(data, EventData.dayIndex(os.time())) then
		Remotes.PlayerStateUpdated:FireClient(player, data)
	end
end

function EventService.start()
	Remotes.RequestClaimEventQuest.OnServerEvent:Connect(function(player, index)
		if type(index) ~= "number" then
			return
		end
		local data = PlayerData.get(player)
		if not data then
			return
		end
		local now = os.time()
		-- The event only exists on Sundays; reject any off-day claim.
		if not EventData.isEventActive(now) then
			return
		end
		-- Make sure we're on today's arc before validating a claim.
		EventData.rolloverIfNeeded(data, EventData.dayIndex(now))
		local result = EventData.applyQuestClaim(data, index)
		if not result then
			return -- not complete, locked, already claimed, or bad index
		end
		if result.cash then
			data.cash += result.cash
			data.totalCashEarned = (data.totalCashEarned or 0) + result.cash
		end
		-- Finishing the final quest grants a random un-owned Champion part, or
		-- scaled consolation cash if the player has already collected all 7.
		if result.final then
			local partId, bonus = EventData.rollChampionPart(data)
			if partId then
				EventData.applyChampionGrant(data, partId, bonus)
			else
				local consolation = EventData.consolationCash(data)
				data.cash += consolation
				data.totalCashEarned = (data.totalCashEarned or 0) + consolation
			end
		end
		PlayerData.save(player)
		Remotes.PlayerStateUpdated:FireClient(player, data)
	end)

	-- Roll over on join (once the player's data has loaded).
	Players.PlayerAdded:Connect(function(player)
		task.spawn(function()
			for _ = 1, 20 do
				if PlayerData.get(player) then
					break
				end
				task.wait(0.5)
			end
			rollover(player)
		end)
	end)
	for _, p in ipairs(Players:GetPlayers()) do
		task.spawn(function()
			rollover(p)
		end)
	end

	-- Catch the day boundary for players who stay online across midnight.
	task.spawn(function()
		while true do
			task.wait(30)
			for _, p in ipairs(Players:GetPlayers()) do
				rollover(p)
			end
		end
	end)
end

return EventService
```

- [ ] **Step 3: Wire into `init.server.luau`** — add the require after `local ChallengeService = require(script.ChallengeService)` (line 20):

```lua
local EventService = require(script.EventService)
```

and add the start call after `ChallengeService.start()` (line 39):

```lua
EventService.start()
```

- [ ] **Step 4: Verify sync + server starts** — Rojo sync; start Studio server; confirm no error on boot and that `RequestClaimEventQuest` exists under `ReplicatedStorage/Remotes`. Full claim flow is verified in Task 7.

- [ ] **Step 5: Commit**

```bash
git add src/server/EventService.luau src/shared/Remotes.luau src/server/init.server.luau
git commit -m "feat(event): EventService (rollover + Sunday-gated sequential claim + champion grant)"
```

---

### Task 6: `EventPanel` client UI + wiring

The 🏆 HUD button (visible only on Sundays) opens a panel with the 6 sequential quest bars, an "ends in" countdown, and the 7-slot Champion collection.

**Files:**
- Create: `src/client/EventPanel.luau`
- Modify: `src/client/UI.luau` (require ~258; init ~1907)

**Interfaces:**
- Consumes: `EventData` (Task 1), `Remotes.RequestClaimEventQuest`, `Remotes.PlayerStateUpdated`, the shared `theme` table + `playerState` passed to `.init` (fields used: `theme.Panel`, `theme.PanelLight`, `theme.Text`, `theme.TextMuted`, `theme.Gold`, `theme.Neutral`, `theme.Success` — same set `ChallengePanel` uses).
- Produces: `EventPanel.init(player, theme, playerState)`.

- [ ] **Step 1: Write `src/client/EventPanel.luau`**

```lua
-- Sunday Showdown event UI. A 🏆 HUD button (shown only on Sundays, with a
-- claimable badge) opens a panel with the 6 sequential quest bars, an "event
-- ends in" countdown, and the 7-slot Champion-parts collection. Progress is
-- computed client-side from the player's own data via the shared EventData;
-- claiming is server-authoritative and Sunday-gated.
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local EventData = require(game.ReplicatedStorage.Shared.EventData)

local EventPanel = {}

local function corner(inst, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = inst
end

local function short(n)
	if n >= 1e6 then
		return (string.format("%.1f", n / 1e6):gsub("%.0$", "")) .. "M"
	elseif n >= 1e3 then
		return (string.format("%.1f", n / 1e3):gsub("%.0$", "")) .. "K"
	end
	return tostring(math.floor(n))
end

local function fmtCountdown(secs)
	local h = math.floor(secs / 3600)
	local m = math.floor((secs % 3600) / 60)
	return string.format("Event ends in %dh %dm", h, m)
end

function EventPanel.init(player, theme, playerState)
	local ACCENT = Color3.fromRGB(240, 180, 70) -- gold, distinct from the other panels

	local state = {}
	if playerState then
		for k, v in pairs(playerState) do
			state[k] = v
		end
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "EventGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 22
	gui.Parent = player:WaitForChild("PlayerGui")

	-- 🏆 HUD button (left stack, below Perks). Visible only while the event runs.
	local openBtn = Instance.new("TextButton")
	openBtn.Name = "EventButton"
	openBtn.Size = UDim2.fromOffset(178, 48)
	openBtn.AnchorPoint = Vector2.new(0, 0.5)
	openBtn.Position = UDim2.new(0, 16, 0.5, -278)
	openBtn.BackgroundColor3 = Color3.fromRGB(232, 168, 56)
	openBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	openBtn.Font = Enum.Font.FredokaOne
	openBtn.TextSize = 18
	openBtn.Text = "🏆 Showdown"
	openBtn.AutoButtonColor = true
	openBtn.Visible = false
	openBtn.Parent = gui
	corner(openBtn, 12)
	local obStroke = Instance.new("UIStroke")
	obStroke.Color = Color3.fromRGB(255, 255, 255)
	obStroke.Thickness = 1
	obStroke.Transparency = 0.6
	obStroke.Parent = openBtn

	local badge = Instance.new("TextLabel")
	badge.Name = "Badge"
	badge.Size = UDim2.fromOffset(24, 24)
	badge.AnchorPoint = Vector2.new(1, 0)
	badge.Position = UDim2.new(1, 4, 0, -6)
	badge.BackgroundColor3 = Color3.fromRGB(230, 70, 70)
	badge.TextColor3 = Color3.fromRGB(255, 255, 255)
	badge.Font = Enum.Font.FredokaOne
	badge.TextSize = 14
	badge.Text = "0"
	badge.Visible = false
	badge.Parent = openBtn
	corner(badge, 12)

	local backdrop = Instance.new("Frame")
	backdrop.Name = "Backdrop"
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	backdrop.BackgroundTransparency = 0.5
	backdrop.BorderSizePixel = 0
	backdrop.Visible = false
	backdrop.Parent = gui

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Size = UDim2.fromOffset(560, 470)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.BackgroundColor3 = theme.Panel
	panel.Parent = backdrop
	corner(panel, 18)
	local pStroke = Instance.new("UIStroke")
	pStroke.Color = ACCENT
	pStroke.Thickness = 2.5
	pStroke.Transparency = 0.2
	pStroke.Parent = panel

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 46)
	title.Position = UDim2.fromOffset(0, 14)
	title.BackgroundTransparency = 1
	title.Text = "🏆 Sunday Showdown"
	title.TextColor3 = theme.Gold
	title.Font = Enum.Font.FredokaOne
	title.TextSize = 26
	title.Parent = panel

	local countdown = Instance.new("TextLabel")
	countdown.Size = UDim2.new(1, -40, 0, 20)
	countdown.Position = UDim2.fromOffset(20, 54)
	countdown.BackgroundTransparency = 1
	countdown.Text = ""
	countdown.TextColor3 = theme.TextMuted
	countdown.Font = Enum.Font.GothamMedium
	countdown.TextSize = 13
	countdown.Parent = panel

	local close = Instance.new("TextButton")
	close.Size = UDim2.fromOffset(34, 34)
	close.Position = UDim2.new(1, -12, 0, 12)
	close.AnchorPoint = Vector2.new(1, 0)
	close.BackgroundTransparency = 1
	close.Text = "×"
	close.TextColor3 = theme.TextMuted
	close.Font = Enum.Font.GothamBold
	close.TextSize = 26
	close.Parent = panel

	local list = Instance.new("ScrollingFrame")
	list.Size = UDim2.new(1, -32, 1, -166)
	list.Position = UDim2.fromOffset(16, 84)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	-- Champion collection strip along the bottom (7 slots).
	local collectionTitle = Instance.new("TextLabel")
	collectionTitle.Size = UDim2.new(1, -32, 0, 18)
	collectionTitle.Position = UDim2.new(0, 16, 1, -74)
	collectionTitle.AnchorPoint = Vector2.new(0, 0)
	collectionTitle.BackgroundTransparency = 1
	collectionTitle.TextXAlignment = Enum.TextXAlignment.Left
	collectionTitle.Text = "Champion Parts"
	collectionTitle.TextColor3 = theme.Text
	collectionTitle.Font = Enum.Font.FredokaOne
	collectionTitle.TextSize = 15
	collectionTitle.Parent = panel

	local strip = Instance.new("Frame")
	strip.Size = UDim2.new(1, -32, 0, 44)
	strip.Position = UDim2.new(0, 16, 1, -52)
	strip.BackgroundTransparency = 1
	strip.Parent = panel
	local stripLayout = Instance.new("UIListLayout")
	stripLayout.FillDirection = Enum.FillDirection.Horizontal
	stripLayout.Padding = UDim.new(0, 8)
	stripLayout.SortOrder = Enum.SortOrder.LayoutOrder
	stripLayout.Parent = strip

	local function buildQuestCard(entry)
		local card = Instance.new("Frame")
		card.Name = "Q" .. entry.index
		card.Size = UDim2.new(1, -6, 0, 86)
		card.LayoutOrder = entry.index
		card.BackgroundColor3 = theme.PanelLight or theme.Panel
		card.Parent = list
		corner(card, 12)

		local icon = Instance.new("TextLabel")
		icon.Size = UDim2.fromOffset(48, 48)
		icon.Position = UDim2.fromOffset(14, 12)
		icon.BackgroundTransparency = 1
		icon.Text = entry.icon
		icon.TextSize = 34
		icon.Font = Enum.Font.FredokaOne
		icon.Parent = card

		local name = Instance.new("TextLabel")
		name.Size = UDim2.new(1, -240, 0, 22)
		name.Position = UDim2.fromOffset(72, 12)
		name.BackgroundTransparency = 1
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.Text = entry.index .. ". " .. entry.title
		name.TextColor3 = theme.Text
		name.Font = Enum.Font.FredokaOne
		name.TextSize = 18
		name.Parent = card

		local desc = Instance.new("TextLabel")
		desc.Size = UDim2.new(1, -240, 0, 18)
		desc.Position = UDim2.fromOffset(72, 34)
		desc.BackgroundTransparency = 1
		desc.TextXAlignment = Enum.TextXAlignment.Left
		desc.Text = entry.desc
		desc.TextColor3 = theme.TextMuted
		desc.Font = Enum.Font.GothamMedium
		desc.TextSize = 12
		desc.Parent = card

		local track = Instance.new("Frame")
		track.Size = UDim2.new(1, -252, 0, 14)
		track.Position = UDim2.fromOffset(72, 58)
		track.BackgroundColor3 = theme.Neutral or Color3.fromRGB(210, 214, 222)
		track.BorderSizePixel = 0
		track.Parent = card
		corner(track, 7)
		local fill = Instance.new("Frame")
		fill.Size = UDim2.fromScale(entry.target > 0 and math.clamp(entry.progress / entry.target, 0, 1) or 0, 1)
		fill.BackgroundColor3 = ACCENT
		fill.BorderSizePixel = 0
		fill.Parent = track
		corner(fill, 7)
		local barLabel = Instance.new("TextLabel")
		barLabel.Size = UDim2.fromScale(1, 1)
		barLabel.BackgroundTransparency = 1
		barLabel.Text = short(entry.progress) .. " / " .. short(entry.target)
		barLabel.TextColor3 = Color3.fromRGB(60, 62, 72)
		barLabel.Font = Enum.Font.GothamBold
		barLabel.TextSize = 11
		barLabel.Parent = track

		local reward = Instance.new("TextLabel")
		reward.Size = UDim2.fromOffset(150, 18)
		reward.Position = UDim2.new(1, -16, 0, 12)
		reward.AnchorPoint = Vector2.new(1, 0)
		reward.BackgroundTransparency = 1
		reward.TextXAlignment = Enum.TextXAlignment.Right
		reward.Text = "+$" .. short(entry.rewardCash)
		reward.TextColor3 = theme.Gold
		reward.Font = Enum.Font.FredokaOne
		reward.TextSize = 15
		reward.Parent = card

		local action = Instance.new("TextButton")
		action.Size = UDim2.fromOffset(130, 40)
		action.Position = UDim2.new(1, -16, 1, -12)
		action.AnchorPoint = Vector2.new(1, 1)
		action.Font = Enum.Font.FredokaOne
		action.TextSize = 16
		action.TextColor3 = Color3.fromRGB(255, 255, 255)
		action.Parent = card
		corner(action, 10)

		if entry.claimed then
			action.Text = "Claimed ✅"
			action.BackgroundColor3 = theme.Neutral or Color3.fromRGB(180, 184, 192)
			action.AutoButtonColor = false
			action.Active = false
		elseif entry.claimable then
			action.Text = "CLAIM"
			action.BackgroundColor3 = theme.Success or Color3.fromRGB(90, 190, 120)
			action.AutoButtonColor = true
			action.Active = true
			action.MouseButton1Click:Connect(function()
				Remotes.RequestClaimEventQuest:FireServer(entry.index)
			end)
		elseif entry.locked then
			action.Text = "Locked 🔒"
			action.BackgroundColor3 = theme.Neutral or Color3.fromRGB(180, 184, 192)
			action.AutoButtonColor = false
			action.Active = false
		else
			action.Text = "In progress"
			action.BackgroundColor3 = theme.Neutral or Color3.fromRGB(180, 184, 192)
			action.AutoButtonColor = false
			action.Active = false
		end
	end

	local function buildChampionSlot(entry, order)
		local slot = Instance.new("TextLabel")
		slot.Name = entry.id
		slot.Size = UDim2.fromOffset(44, 44)
		slot.LayoutOrder = order
		slot.BackgroundColor3 = entry.owned and ACCENT or (theme.Neutral or Color3.fromRGB(210, 214, 222))
		slot.Text = entry.owned and entry.icon or "❔"
		slot.TextSize = 24
		slot.Font = Enum.Font.FredokaOne
		slot.TextColor3 = Color3.fromRGB(255, 255, 255)
		slot.Parent = strip
		corner(slot, 10)
	end

	local function rebuild()
		local now = os.time()
		local active = EventData.isEventActive(now)
		openBtn.Visible = active
		if not active then
			backdrop.Visible = false
			badge.Visible = false
			return
		end

		for _, ch in ipairs(list:GetChildren()) do
			if ch:IsA("Frame") then
				ch:Destroy()
			end
		end
		for _, entry in ipairs(EventData.list(state)) do
			buildQuestCard(entry)
		end

		for _, ch in ipairs(strip:GetChildren()) do
			if ch:IsA("TextLabel") then
				ch:Destroy()
			end
		end
		for i, entry in ipairs(EventData.championList(state)) do
			buildChampionSlot(entry, i)
		end
		collectionTitle.Text = "Champion Parts  (" .. EventData.championCount(state) .. "/7)"

		local claimable = EventData.claimableCount(state)
		badge.Text = tostring(claimable)
		badge.Visible = claimable > 0
	end
	rebuild()

	openBtn.MouseButton1Click:Connect(function()
		rebuild()
		countdown.Text = fmtCountdown(EventData.secondsUntilEnd(os.time()))
		backdrop.Visible = true
	end)
	close.MouseButton1Click:Connect(function()
		backdrop.Visible = false
	end)

	Remotes.PlayerStateUpdated.OnClientEvent:Connect(function(data)
		for k, v in pairs(data) do
			state[k] = v
		end
		rebuild()
	end)

	-- Keep the badge + countdown fresh and catch the Sunday start/end boundary.
	task.spawn(function()
		while true do
			task.wait(20)
			rebuild()
			if backdrop.Visible then
				countdown.Text = fmtCountdown(EventData.secondsUntilEnd(os.time()))
			end
		end
	end)
end

return EventPanel
```

- [ ] **Step 2: Wire into `UI.luau`** — add the require after `local PerkPanel = require(script.Parent.PerkPanel)` (line 258):

```lua
	local EventPanel = require(script.Parent.EventPanel)
```

and add the init call after `PerkPanel.init(player, Theme, playerState)` (line 1907):

```lua
	EventPanel.init(player, Theme, playerState)
```

- [ ] **Step 3: Verify sync** — Rojo sync; confirm the client loads with no error. Because most days are not Sunday, the button will be hidden by default — that is correct. Behaviour is exercised in Task 7 with a forced-active override.

- [ ] **Step 4: Commit**

```bash
git add src/client/EventPanel.luau src/client/UI.luau
git commit -m "feat(event): EventPanel HUD (Sunday-only button, quest bars, champion collection)"
```

---

### Task 7: Studio playtest verification

Exercise the whole feature in a running Studio session, including forcing the event active (today may not be Sunday).

**Files:** none (verification only; the Step 1 override is reverted in Step 6).

- [ ] **Step 1: Force the event active for testing** — temporarily make `EventData.isEventActive` return true so the arc runs on any day. In `src/shared/EventData.luau`, add a temporary first line inside `isEventActive`: `return true` **(removed in Step 6)**. Rojo sync.

- [ ] **Step 2: Start the Studio server + play.** Confirm on join: no console errors, the 🏆 Showdown button appears in the left HUD stack below Perks (no overlap with the Perks button at −226), and opening it shows 6 quest cards with the first unlocked ("In progress"/"CLAIM") and the rest "Locked 🔒", plus the "Champion Parts (0/7)" strip and the countdown.

- [ ] **Step 3: Complete and claim sequentially.** Release games / grow subs / earn cash to complete quest 1; confirm its bar fills and CLAIM works (cash granted, card flips to "Claimed ✅", quest 2 unlocks). Confirm a locked quest's button is inert. Verify the +50% boost by comparing a release payout with the override on vs off (toggle Step 1's `return true`).

- [ ] **Step 4: Finish the arc → Champion part.** Complete all 6 quests (temporarily lower the `base` values in `EventData.QUESTS` to reach quest 6 quickly, then restore them in Step 6). On claiming quest 6, confirm a random Champion part lights up in the collection strip (count → 1/7) and that the player's cash/subs earn rate visibly increases (the part's bonus folded into the economy). Force a new arc (bump `data.eventDay` via the command bar, or wait for the 30s rollover after changing the local clock) and confirm the next Champion part is a *different* category.

- [ ] **Step 5: Off-day gate.** Remove the Step 1 override so `isEventActive` returns false today, and confirm the button hides and a manually-fired `RequestClaimEventQuest` (via the command bar) grants nothing (server rejects off-Sunday).

- [ ] **Step 6: Remove the test override + restore any tweaked numbers.** Delete the temporary `return true` from `isEventActive` and restore any `base` values changed for testing. Rojo sync; re-run `RunTests.luau` to confirm all assertions still pass.

- [ ] **Step 7: Commit any cleanup** (only if the override/numbers were committed at some point)

```bash
git add -A
git commit -m "chore(event): remove test override, restore tuned targets"
```

---

## Self-Review

**Spec coverage:**
- Sunday-only + auto-detect → Task 1 `isEventActive` (epoch-Thursday math), gated in Task 5 (claims) + Task 6 (button visibility). ✓
- +50% cash & subs live boost → Task 4 (`eventBoost` on both grants). ✓
- 6 sequential quests, today-delta, always-advanceable metrics → Task 1 `QUESTS` (games/subs/cash/hits) + sequential `canClaim`. ✓
- Continuous scaling (no tiers) → Task 1 `scale` + `target`/`rewardCash`. ✓
- Two new counters (`totalCashEarned`, `trendyHits`) → Task 2 (fields) + Task 4 (increments). ✓
- Random Champion part = 125% of best, collect all 7, consolation at 7 → Task 1 (`rollChampionPart`/`bestPartBonus`/`consolationCash`) + Task 3 (economy fold) + Task 5 (grant). ✓
- 🏆 HUD at y −278, hidden off-Sunday, quest bars + collection + countdown → Task 6. ✓
- Server-authoritative claims, no loadFailed guard → Task 5. ✓
- Pure-logic unit tests → Tasks 1 & 3 assertions in RunTests. ✓
- Studio playtest verification → Task 7. ✓

**Placeholder scan:** No TBD/TODO/"add error handling"/"similar to". All code blocks complete. ✓

**Type consistency:** `data.eventParts` (map partId→bonus), `eventBaseline` keys `{games,subs,cash,hits}`, `eventQuestsClaimed` (index→bool), `eventDay` (number). `applyQuestClaim` returns `{cash, final}`. `getPCPartsCashMultiplier(pcParts, eventParts)` / `getPCPartsSubsMultiplier(pcParts, eventParts)` signatures match between Task 3 (definition) and Task 4 (call sites). `RequestClaimEventQuest` fired with an integer index in Task 6, validated as `number` in Task 5. Field names identical across Tasks 1/2/4/5/6. ✓
