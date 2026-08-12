# Login Streak Calendar (B1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the repeating 7-day daily reward with a visible 30-day calendar whose rewards scale with the player's progression, with milestone prizes at days 7/14/30 and a free-skip-then-Robux-repair catch-up path.

**Architecture:** Pure decision logic and the reward ladder live in `GameData` (unit-tested in RunTests). `DailyRewardService` owns granting; `MonetizationService` gains one receipt branch for the repair; `DailyRewardPanel` becomes the calendar grid. The day-30 Champion PC part reuses the already-tested `EventData.rollChampionPart` / `applyChampionGrant`.

**Tech Stack:** Roblox Luau, Rojo sync, Studio playtest (no CI). Pure logic asserted via `src/shared/Tests/RunTests.luau`.

## Global Constraints

- **Verification** is `rojo build` + Studio playtest; pure logic is asserted in `src/shared/Tests/RunTests.luau`. There is no CI runner.
- **Server time is authoritative.** Every streak decision uses the server's `os.time()`. The client only displays.
- **Claiming is server-re-validated.** The client sends no day number and no amount.
- **No `loadFailed` guard on the daily claim** — it is game cash and must work in Studio, consistent with quests/challenges/event.
- **The Robux repair KEEPS the successful-save requirement** in `ProcessReceipt`. A paid repair must never be acknowledged if it cannot be persisted.
- **New Robux products ship with `id = 0`** ("Coming soon") until the user creates the real product, matching the existing `GameData.Products` convention.
- **Only cash amounts scale** with progression. Boost multipliers, boost durations and case spins are authored values and are never scaled.
- **The calendar is 30 days.** Milestones are days 7, 14 and 30. Claiming day 30 restarts at day 1 and clears the free skip.
- **Emoji** are written as escaped byte sequences in this codebase (e.g. `"\240\159\142\129"`), matching `DailyRewardService`/`DailyRewardPanel`.

---

### Task 1: The 30-day ladder + pure streak logic in GameData

Everything else consumes this. All of it is pure and unit-tested.

**Files:**
- Modify: `src/shared/GameData.luau` (replace `DailyRewards` ~757-765 and `getDailyReward` ~768-773; extend `describeDailyReward` ~776-781; add two new functions; add `Products.StreakRepair`)
- Modify: `src/shared/Tests/RunTests.luau` (add assertions immediately before the final `t:summary()`)

**Interfaces:**
- Consumes: `GameData.DailyClaimCooldownSeconds` (20h), `GameData.DailyStreakResetSeconds` (48h), `EventData.scale(data)` (existing, from the event feature).
- Produces (used by later tasks):
  - `GameData.DailyCalendarDays` = `30`
  - `GameData.DailyRewards` — 30 entries, each `{ kind, amount?, mult?, dur?, spins?, milestone? }`
  - `GameData.getDailyReward(streakDay) -> reward, index` (clamped 1..30)
  - `GameData.getScaledDailyReward(data, streakDay) -> reward` (a copy; `amount` scaled)
  - `GameData.describeDailyReward(reward) -> string`
  - `GameData.evaluateDailyStreak(data, now) -> { available, nextStreak, usedFreeSkip, repairOffered, brokenStreak, calendarRestart }`
  - `GameData.Products.StreakRepair = { id = 0, ... }`

- [ ] **Step 1: Write the failing tests** — in `src/shared/Tests/RunTests.luau`, immediately before the final `t:summary()` line:

```lua
-- Daily login calendar (B1): 30-day ladder, scaling, and streak decisions
t:assertEqual(GameData.DailyCalendarDays, 30, "daily: calendar is 30 days")
t:assertEqual(#GameData.DailyRewards, 30, "daily: ladder has 30 entries")
t:assertEqual(GameData.DailyRewards[7].milestone, true, "daily: day 7 is a milestone")
t:assertEqual(GameData.DailyRewards[14].milestone, true, "daily: day 14 is a milestone")
t:assertEqual(GameData.DailyRewards[30].milestone, true, "daily: day 30 is a milestone")
t:assertEqual(GameData.DailyRewards[14].kind, "case", "daily: day 14 grants a case spin")
t:assertEqual(GameData.DailyRewards[30].kind, "champion", "daily: day 30 grants a champion part")
t:assertEqual(GameData.DailyRewards[7].amount ~= nil and GameData.DailyRewards[7].mult ~= nil, true, "daily: day 7 grants cash AND a boost")

-- indexing no longer wraps every 7 days; it clamps at 30
local _, i1 = GameData.getDailyReward(1)
t:assertEqual(i1, 1, "daily: day 1 indexes entry 1")
local _, i8 = GameData.getDailyReward(8)
t:assertEqual(i8, 8, "daily: day 8 indexes entry 8 (no 7-day wrap)")
local _, i30 = GameData.getDailyReward(30)
t:assertEqual(i30, 30, "daily: day 30 indexes entry 30")
local _, i99 = GameData.getDailyReward(99)
t:assertEqual(i99, 30, "daily: past the end clamps to entry 30")
local _, i0 = GameData.getDailyReward(0)
t:assertEqual(i0, 1, "daily: day 0 clamps up to entry 1")

-- cash scales with progression; boosts and spins never do
local freshP = { subscribers = 0 }
local bigP = { subscribers = 100000 }
local base5 = GameData.DailyRewards[5].amount
t:assertEqual(GameData.getScaledDailyReward(freshP, 5).amount, base5, "daily: a fresh player gets the base amount")
t:assertEqual(GameData.getScaledDailyReward(bigP, 5).amount > base5, true, "daily: a big player gets more")
t:assertEqual(GameData.getScaledDailyReward(bigP, 3).mult, GameData.DailyRewards[3].mult, "daily: boost multiplier is never scaled")
t:assertEqual(GameData.getScaledDailyReward(bigP, 3).dur, GameData.DailyRewards[3].dur, "daily: boost duration is never scaled")
t:assertEqual(GameData.getScaledDailyReward(bigP, 14).spins, GameData.DailyRewards[14].spins, "daily: case spins are never scaled")
t:assertEqual(GameData.getScaledDailyReward(bigP, 5) ~= GameData.DailyRewards[5], true, "daily: scaling returns a copy, not the shared entry")
t:assertEqual(GameData.DailyRewards[5].amount, base5, "daily: scaling never mutates the authored ladder")

-- descriptions
t:assertEqual(GameData.describeDailyReward({ kind = "cash", amount = 500 }), "$500", "daily: cash description")
t:assertEqual(GameData.describeDailyReward({ kind = "case", spins = 1 }):find("Lucky") ~= nil, true, "daily: case description mentions Lucky")
t:assertEqual(GameData.describeDailyReward({ kind = "champion" }):find("Champion") ~= nil, true, "daily: champion description mentions Champion")

-- streak decisions. COOLDOWN = 20h, RESET = 48h
local DAY = 24 * 3600
local RESET = GameData.DailyStreakResetSeconds

-- brand new player: claimable immediately, day 1
local newbie = { lastDailyClaim = 0, dailyStreak = 0 }
local rNew = GameData.evaluateDailyStreak(newbie, 1000000)
t:assertEqual(rNew.available, true, "daily: a new player can claim at once")
t:assertEqual(rNew.nextStreak, 1, "daily: a new player is on day 1")

-- claimed 4h ago: not claimable yet
local tooSoon = { lastDailyClaim = 1000000, dailyStreak = 3 }
t:assertEqual(GameData.evaluateDailyStreak(tooSoon, 1000000 + 4 * 3600).available, false, "daily: cannot claim inside the cooldown")

-- claimed 25h ago (inside the reset window): streak continues
local onTime = { lastDailyClaim = 1000000, dailyStreak = 3 }
local rOn = GameData.evaluateDailyStreak(onTime, 1000000 + 25 * 3600)
t:assertEqual(rOn.available, true, "daily: claimable after the cooldown")
t:assertEqual(rOn.nextStreak, 4, "daily: an on-time return advances the streak")
t:assertEqual(rOn.usedFreeSkip, false, "daily: an on-time return uses no free skip")
t:assertEqual(rOn.repairOffered, false, "daily: an on-time return offers no repair")

-- missed (past the reset window) with the free skip available: streak survives
local missedOnce = { lastDailyClaim = 1000000, dailyStreak = 12, dailySkipUsed = false }
local rMiss = GameData.evaluateDailyStreak(missedOnce, 1000000 + RESET + DAY)
t:assertEqual(rMiss.nextStreak, 13, "daily: the free skip keeps the streak going")
t:assertEqual(rMiss.usedFreeSkip, true, "daily: the free skip is reported as used")
t:assertEqual(rMiss.repairOffered, false, "daily: no repair needed while the skip is available")
t:assertEqual(missedOnce.dailySkipUsed, false, "daily: evaluate is pure and does not mutate")

-- missed again with the skip already spent: streak held for repair
local missedTwice = { lastDailyClaim = 1000000, dailyStreak = 12, dailySkipUsed = true }
local rBroke = GameData.evaluateDailyStreak(missedTwice, 1000000 + RESET + DAY)
t:assertEqual(rBroke.nextStreak, 1, "daily: a second miss drops to day 1")
t:assertEqual(rBroke.repairOffered, true, "daily: a second miss offers the repair")
t:assertEqual(rBroke.brokenStreak, 12, "daily: the lost streak is reported so it can be repaired")

-- a streak already awaiting repair keeps offering it
local awaiting = { lastDailyClaim = 1000000, dailyStreak = 1, dailySkipUsed = true, dailyBrokenStreak = 20 }
local rAwait = GameData.evaluateDailyStreak(awaiting, 1000000 + 25 * 3600)
t:assertEqual(rAwait.repairOffered, true, "daily: a pending repair is still offered")
t:assertEqual(rAwait.brokenStreak, 20, "daily: the pending repair remembers the streak")

-- finishing day 30 restarts the calendar
local finished = { lastDailyClaim = 1000000, dailyStreak = 30, dailySkipUsed = true }
local rWrap = GameData.evaluateDailyStreak(finished, 1000000 + 25 * 3600)
t:assertEqual(rWrap.nextStreak, 1, "daily: after day 30 the calendar restarts at 1")
t:assertEqual(rWrap.calendarRestart, true, "daily: the restart is reported so the free skip can reset")

-- the repair product exists, unconfigured
t:assertEqual(GameData.Products.StreakRepair ~= nil, true, "daily: a StreakRepair product exists")
t:assertEqual(GameData.Products.StreakRepair.id, 0, "daily: StreakRepair ships as 'coming soon' (id 0)")
```

- [ ] **Step 2: Run the tests to verify they fail**

Sync with Rojo, then run `src/shared/Tests/RunTests.luau` in Studio (Edit mode, the way the harness is normally executed). Expected: FAILs on `DailyCalendarDays` (nil), the 30-entry count (currently 7), `getScaledDailyReward` (nil), `evaluateDailyStreak` (nil) and `Products.StreakRepair` (nil).

> Note: in Edit mode `RunTests` currently HANGS partway through at `require(PCService)` → `Remotes:WaitForChild`. If that happens, verify these assertions instead by requiring `GameData` directly in a scratch script and running the same checks — the daily logic has no `Remotes` dependency.

- [ ] **Step 3: Replace `GameData.DailyRewards` and `getDailyReward`** — replace the existing table and function (currently ~757-773) with:

```lua
-- A 30-day login calendar. Ordinary days pay cash or a boost; days 7, 14 and 30
-- are milestones. `amount` is a BASE value -- it gets scaled to the player's
-- progression by getScaledDailyReward, so day 12 is worth about the same
-- relative amount to a new player and to someone on their fifth rebirth.
-- Boost multipliers/durations and case spins are authored values and never scale.
GameData.DailyCalendarDays = 30
GameData.DailyRewards = {
	{ kind = "cash", amount = 100 },
	{ kind = "cash", amount = 300 },
	{ kind = "boost", mult = 2, dur = 300 },
	{ kind = "cash", amount = 800 },
	{ kind = "cash", amount = 1500 },
	{ kind = "boost", mult = 2, dur = 600 },
	-- Day 7 milestone: cash AND a long boost.
	{ kind = "cash", amount = 5000, mult = 3, dur = 900, milestone = true },
	{ kind = "cash", amount = 2500 },
	{ kind = "cash", amount = 3500 },
	{ kind = "boost", mult = 2, dur = 900 },
	{ kind = "cash", amount = 5000 },
	{ kind = "cash", amount = 6500 },
	{ kind = "boost", mult = 3, dur = 600 },
	-- Day 14 milestone: a Lucky Case spin.
	{ kind = "case", spins = 1, milestone = true },
	{ kind = "cash", amount = 9000 },
	{ kind = "cash", amount = 11000 },
	{ kind = "boost", mult = 3, dur = 900 },
	{ kind = "cash", amount = 14000 },
	{ kind = "cash", amount = 17000 },
	{ kind = "boost", mult = 3, dur = 900 },
	{ kind = "cash", amount = 21000 },
	{ kind = "cash", amount = 25000 },
	{ kind = "boost", mult = 3, dur = 1200 },
	{ kind = "cash", amount = 30000 },
	{ kind = "cash", amount = 36000 },
	{ kind = "boost", mult = 3, dur = 1200 },
	{ kind = "cash", amount = 43000 },
	{ kind = "cash", amount = 50000 },
	{ kind = "boost", mult = 3, dur = 1200 },
	-- Day 30 grand prize: a random Champion PC part (see DailyRewardService).
	{ kind = "champion", milestone = true },
}

-- The authored reward for a calendar day. Clamps into 1..30 rather than wrapping
-- (the calendar restarts by resetting the streak, not by indexing past the end).
function GameData.getDailyReward(streakDay)
	local idx = math.clamp(math.floor(streakDay or 1), 1, #GameData.DailyRewards)
	return GameData.DailyRewards[idx], idx
end

-- The reward as the player will actually receive it: a COPY with `amount` scaled
-- to their progression. Used by both the grant and the on-screen preview, so the
-- two can never disagree. Never mutates the authored ladder.
function GameData.getScaledDailyReward(data, streakDay)
	local EventData = require(game.ReplicatedStorage.Shared.EventData)
	local base = GameData.getDailyReward(streakDay)
	local copy = {}
	for k, v in pairs(base) do
		copy[k] = v
	end
	if copy.amount then
		copy.amount = math.floor(copy.amount * EventData.scale(data))
	end
	return copy
end
```

- [ ] **Step 4: Extend `describeDailyReward`** — replace the existing function (~776-781) with:

```lua
-- Short human label for a reward (client popup + calendar cells).
function GameData.describeDailyReward(reward)
	if reward.kind == "champion" then
		return "\240\159\143\134 Champion Part!"
	end
	if reward.kind == "case" then
		return ("\240\159\142\129 %d Lucky Spin"):format(reward.spins or 1)
	end
	if reward.kind == "boost" then
		return ("%gx cash \194\183 %dm"):format(reward.mult, math.floor(reward.dur / 60))
	end
	-- Cash, optionally with a boost attached (the day 7 milestone).
	if reward.mult then
		return ("$%d + %gx \194\183 %dm"):format(reward.amount, reward.mult, math.floor(reward.dur / 60))
	end
	return ("$%d"):format(reward.amount)
end
```

- [ ] **Step 5: Add `evaluateDailyStreak`** — immediately after `describeDailyReward`:

```lua
-- Decides, from the player's data alone, whether a daily reward is claimable and
-- which calendar day it would be. PURE: it reports what should change but never
-- mutates `data` -- DailyRewardService applies the results.
--
-- Returns a table:
--   available       claimable right now (cooldown elapsed)
--   nextStreak      the calendar day this claim would be (1..30)
--   usedFreeSkip    true if a missed day was forgiven by the one free skip
--   repairOffered   true if the streak is broken and a Robux repair applies
--   brokenStreak    the streak being held for repair (0 when none)
--   calendarRestart true when the previous claim finished day 30
function GameData.evaluateDailyStreak(data, now)
	local last = data.lastDailyClaim or 0
	local prev = data.dailyStreak or 0
	local pending = data.dailyBrokenStreak or 0
	local elapsed = now - last
	local available = (last == 0) or (elapsed >= GameData.DailyClaimCooldownSeconds)

	local result = {
		available = available,
		nextStreak = 1,
		usedFreeSkip = false,
		repairOffered = false,
		brokenStreak = 0,
		calendarRestart = false,
	}

	-- A streak already awaiting repair keeps offering it; until it is bought the
	-- player is on day 1.
	if pending > 0 then
		result.repairOffered = true
		result.brokenStreak = pending
		return result
	end

	if last == 0 then
		return result -- first ever claim: day 1
	end

	if elapsed > GameData.DailyStreakResetSeconds then
		-- They missed. The first miss per calendar is forgiven.
		if not data.dailySkipUsed then
			result.usedFreeSkip = true
			result.nextStreak = prev + 1
		else
			result.repairOffered = true
			result.brokenStreak = prev
			result.nextStreak = 1
		end
	else
		result.nextStreak = prev + 1
	end

	-- Finishing day 30 restarts the calendar (and refreshes the free skip).
	if result.nextStreak > GameData.DailyCalendarDays then
		result.nextStreak = 1
		result.calendarRestart = true
	end

	return result
end
```

- [ ] **Step 6: Add the repair product** — in `GameData.Products`, add a third entry after `MegaBoost`:

```lua
	StreakRepair = { id = 0, order = 3, icon = "\240\159\148\167", name = "Streak Repair", desc = "Broke your login streak? Put it back and carry on where you left off.", repair = true },
```

- [ ] **Step 7: Run the tests to verify they pass**

Run `RunTests.luau` (or the scratch-script fallback from Step 2). Expected: every new `daily:` assertion PASSES and all pre-existing assertions still pass.

- [ ] **Step 8: Commit**

```bash
git add src/shared/GameData.luau src/shared/Tests/RunTests.luau
git commit -m "feat(daily): 30-day login calendar ladder + pure streak logic"
```

---

### Task 2: PlayerData fields

**Files:**
- Modify: `src/server/PlayerData.luau` (`defaultData()` — add beside the existing `lastDailyClaim`/`dailyStreak` fields; backfill block — add after the existing `data.dailyStreak = data.dailyStreak or 0` line)

**Interfaces:**
- Produces: on every `data` table — `dailySkipUsed = false`, `dailyBrokenStreak = 0`.

- [ ] **Step 1: Add the fields to `defaultData()`** — find the existing daily-reward lines (`lastDailyClaim = 0,` and `dailyStreak = 0,`) and add immediately after them:

```lua
		-- Login calendar (see GameData.evaluateDailyStreak): whether this
		-- calendar's one free missed day has been used, and a streak being held
		-- for a Robux repair (0 = none).
		dailySkipUsed = false,
		dailyBrokenStreak = 0,
```

- [ ] **Step 2: Add the backfill** — in the existing-save backfill block, immediately after `data.dailyStreak = data.dailyStreak or 0`:

```lua
				if data.dailySkipUsed == nil then
					data.dailySkipUsed = false
				end
				data.dailyBrokenStreak = data.dailyBrokenStreak or 0
```

- [ ] **Step 3: Verify** — re-read both edited regions: the table literal is still valid Lua (commas correct) and both fields appear in defaults AND backfill. Rojo sync and confirm the Studio server boots with no errors.

- [ ] **Step 4: Commit**

```bash
git add src/server/PlayerData.luau
git commit -m "feat(daily): PlayerData free-skip + broken-streak fields"
```

---

### Task 3: DailyRewardService — scaled rewards, milestones, skip/repair

**Files:**
- Modify: `src/server/DailyRewardService.luau` (replace the local `evaluate` at lines 20-33, `checkForPlayer` at 37-47, and the claim handler inside `start()` at 50-74)

**Interfaces:**
- Consumes: `GameData.evaluateDailyStreak`, `GameData.getScaledDailyReward`, `GameData.describeDailyReward`, `GameData.applyBoost` (existing), `EventData.rollChampionPart` / `applyChampionGrant` / `consolationCash` (existing, from the event feature).
- Produces: `DailyRewardAvailable:FireClient(player, streakDay, rewardDesc, repairOffered, brokenStreak)` — two new trailing arguments the client reads in Task 5. `DailyRewardClaimed:FireClient(player, streakDay, rewardDesc)` is unchanged.

- [ ] **Step 1: Add the EventData require** — at the top of the file, after the `GameData` require:

```lua
local EventData = require(game.ReplicatedStorage.Shared.EventData)
```

- [ ] **Step 2: Delete the local `evaluate` function** (lines 20-33, from the `-- Is a reward claimable right now` comment through its closing `end`). Its logic now lives in `GameData.evaluateDailyStreak` so it can be unit-tested.

- [ ] **Step 3: Add a grant helper** — immediately after `nowSeconds()`:

```lua
-- Applies one calendar reward to `data`. The reward must already be scaled (see
-- GameData.getScaledDailyReward). Returns a description of what was actually
-- granted, which can differ from the ladder entry: the day-30 Champion part
-- falls back to consolation cash once all 7 are collected.
local function grantReward(data, reward)
	if reward.kind == "champion" then
		local partId, bonus = EventData.rollChampionPart(data)
		if partId then
			EventData.applyChampionGrant(data, partId, bonus)
			return ("\240\159\143\134 Champion %s!"):format(partId)
		end
		local consolation = EventData.consolationCash(data)
		data.cash += consolation
		return ("$%d"):format(consolation)
	end

	if reward.spins then
		data.luckySpinsOwned = (data.luckySpinsOwned or 0) + reward.spins
	end
	if reward.amount then
		data.cash += reward.amount
	end
	if reward.mult then
		-- Shared rule: only the duration stacks; the multiplier takes the higher
		-- value (never the sum).
		GameData.applyBoost(data, reward.mult, reward.dur, "\240\159\142\129", "Daily Boost", workspace:GetServerTimeNow())
	end
	return GameData.describeDailyReward(reward)
end
```

- [ ] **Step 4: Replace `checkForPlayer`** (lines 37-47) with:

```lua
-- Tell a player whether a daily reward is waiting (called after their data
-- loads on join). Also tells them when a broken streak can be repaired.
function DailyRewardService.checkForPlayer(player)
	local data = PlayerData.get(player)
	if not data then
		return
	end
	local decision = GameData.evaluateDailyStreak(data, nowSeconds())
	if decision.available or decision.repairOffered then
		local reward = GameData.getScaledDailyReward(data, decision.nextStreak)
		Remotes.DailyRewardAvailable:FireClient(
			player,
			decision.nextStreak,
			GameData.describeDailyReward(reward),
			decision.repairOffered,
			decision.brokenStreak
		)
	end
end
```

- [ ] **Step 5: Replace the claim handler** — the whole `Remotes.RequestClaimDaily.OnServerEvent:Connect(...)` body inside `start()` (lines 50-74):

```lua
	Remotes.RequestClaimDaily.OnServerEvent:Connect(function(player)
		local data = PlayerData.get(player)
		if not data then
			return
		end
		local decision = GameData.evaluateDailyStreak(data, nowSeconds())
		if not decision.available then
			return -- not claimable yet (or a double-fire); ignore
		end

		local reward = GameData.getScaledDailyReward(data, decision.nextStreak)
		data.lastDailyClaim = nowSeconds()
		data.dailyStreak = decision.nextStreak

		-- Apply the streak bookkeeping the pure evaluation reported.
		if decision.usedFreeSkip then
			data.dailySkipUsed = true
		end
		if decision.calendarRestart then
			data.dailySkipUsed = false -- a fresh calendar gets a fresh free skip
		end
		-- Claiming without repairing accepts the loss and clears the offer.
		data.dailyBrokenStreak = 0

		local grantedDesc = grantReward(data, reward)

		Remotes.PlayerStateUpdated:FireClient(player, data)
		Remotes.DailyRewardClaimed:FireClient(player, decision.nextStreak, grantedDesc)
	end)
```

- [ ] **Step 6: Verify by re-reading** — confirm: the old local `evaluate` is gone with no remaining callers; `grantReward` is defined above `start()`; `data.cash += reward.amount` appears exactly once; the boost branch still uses `applyBoost`. Rojo sync; confirm the Studio server boots clean. (Behaviour is exercised in Task 6.)

- [ ] **Step 7: Commit**

```bash
git add src/server/DailyRewardService.luau
git commit -m "feat(daily): grant scaled rewards, milestones, and free-skip bookkeeping"
```

---

### Task 4: MonetizationService — the Robux streak repair

**Files:**
- Modify: `src/server/MonetizationService.luau` (add a branch in the `ProcessReceipt` product chain, after the `MegaBoost` branch ~148-152)

**Interfaces:**
- Consumes: `GameData.Products.StreakRepair` (Task 1), `data.dailyBrokenStreak` (Task 2).
- Produces: nothing new — it mutates `data.dailyStreak` / `data.dailyBrokenStreak` through the existing receipt flow.

- [ ] **Step 1: Add the receipt branch** — immediately after the `MegaBoost` branch (which ends with `handled = true`) and before the closing `end` of that if-chain:

```lua
		elseif id ~= 0 and id == GameData.Products.StreakRepair.id then
			-- Put the held streak back. Nothing to repair means nothing to sell,
			-- so leave `handled` false and let Roblox retry rather than taking
			-- money for a no-op.
			local broken = data.dailyBrokenStreak or 0
			if broken > 0 then
				data.dailyStreak = broken
				data.dailyBrokenStreak = 0
				handled = true
			end
```

> The existing save-before-acknowledge logic below this chain already covers the repair: if the save fails, Roblox re-delivers rather than the player losing a paid repair. Do NOT add a separate save here.

- [ ] **Step 2: Verify by re-reading** — confirm the branch sits inside the same if-chain (it starts with `elseif`), that `handled` is only set when `broken > 0`, and that nothing else in `ProcessReceipt` changed. Rojo sync; Studio server boots clean.

- [ ] **Step 3: Commit**

```bash
git add src/server/MonetizationService.luau
git commit -m "feat(daily): Robux streak repair restores a held login streak"
```

---

### Task 5: DailyRewardPanel — the 30-day calendar

**Files:**
- Modify: `src/client/DailyRewardPanel.luau` (replace the 7-pip row at lines 65-85, enlarge the card at line 29, move the reward label at line 89, add a repair button after line 108, replace `showFor` at 110-126, and extend the `DailyRewardAvailable` handler at 137-139)

**Interfaces:**
- Consumes: `Remotes.DailyRewardAvailable(streakDay, rewardDesc, repairOffered, brokenStreak)` (Task 3), `GameData.getDailyReward` / `describeDailyReward` / `DailyCalendarDays` (Task 1), `Remotes.RequestClaimDaily` (existing), `MarketplaceService:PromptProductPurchase` + `GameData.Products.StreakRepair` (Task 1).
- Produces: `DailyRewardPanel.init(player, theme)` — signature unchanged.

- [ ] **Step 1: Add requires** — at the top of the file, after the existing `Sound` require:

```lua
local MarketplaceService = game:GetService("MarketplaceService")
local GameData = require(game.ReplicatedStorage.Shared.GameData)
```

- [ ] **Step 2: Enlarge the card** — replace line 29 (`card.Size = UDim2.fromOffset(360, 280)`) with:

```lua
	card.Size = UDim2.fromOffset(470, 470) -- taller: it now holds a 30-cell grid
```

- [ ] **Step 3: Replace the 7-pip row with a 30-cell grid** — replace lines 65-85 (from the `-- 7 day-pips` comment through the `end` of the pip loop) with:

```lua
	-- A 30-cell calendar: 6 columns x 5 rows. Each cell shows its day number,
	-- with milestones (7/14/30) drawn larger and gold-ringed.
	local GRID_COLS, CELL, GAP = 6, 62, 6
	local gridRows = math.ceil(GameData.DailyCalendarDays / GRID_COLS)
	local gridHeight = gridRows * CELL + (gridRows - 1) * GAP
	local grid = Instance.new("Frame")
	grid.Name = "Calendar"
	grid.Size = UDim2.fromOffset(GRID_COLS * CELL + (GRID_COLS - 1) * GAP, gridHeight)
	grid.Position = UDim2.new(0.5, 0, 0, 88)
	grid.AnchorPoint = Vector2.new(0.5, 0)
	grid.BackgroundTransparency = 1
	grid.Parent = card

	local cells = {}
	for day = 1, GameData.DailyCalendarDays do
		local reward = GameData.getDailyReward(day)
		local col = (day - 1) % GRID_COLS
		local row = math.floor((day - 1) / GRID_COLS)

		local cell = Instance.new("TextLabel")
		cell.Name = "Day" .. day
		cell.Size = UDim2.fromOffset(CELL, CELL)
		cell.Position = UDim2.fromOffset(col * (CELL + GAP), row * (CELL + GAP))
		cell.BackgroundColor3 = theme.Neutral
		cell.Text = tostring(day)
		cell.TextColor3 = theme.TextMuted
		cell.Font = Enum.Font.FredokaOne
		cell.TextSize = reward.milestone and 20 or 15
		cell.TextYAlignment = Enum.TextYAlignment.Top
		cell.Parent = grid
		corner(cell, 10)

		-- Milestone days get a gold ring so the chase is visible at a glance.
		if reward.milestone then
			local ring = Instance.new("UIStroke")
			ring.Color = theme.Gold
			ring.Thickness = 2
			ring.Transparency = 0.15
			ring.Parent = cell
		end

		-- Small reward hint under the day number.
		local hint = Instance.new("TextLabel")
		hint.Name = "Hint"
		hint.Size = UDim2.new(1, -6, 0, 26)
		hint.Position = UDim2.fromOffset(3, CELL - 28)
		hint.BackgroundTransparency = 1
		hint.Text = GameData.describeDailyReward(reward)
		hint.TextColor3 = theme.TextMuted
		hint.Font = Enum.Font.GothamMedium
		hint.TextSize = 9
		hint.TextWrapped = true
		hint.Parent = cell

		cells[day] = { cell = cell, hint = hint }
	end
```

- [ ] **Step 4: Move the reward label below the grid** — replace line 89 (`rewardLabel.Position = UDim2.fromOffset(20, 132)`) with:

```lua
	rewardLabel.Position = UDim2.fromOffset(20, 88 + gridHeight + 10)
```

- [ ] **Step 5: Add the repair button** — immediately after `corner(claim, 12)` (line 108):

```lua
	-- Shown only when a broken streak can be bought back.
	local repairBtn = Instance.new("TextButton")
	repairBtn.Name = "Repair"
	repairBtn.Size = UDim2.fromOffset(240, 36)
	repairBtn.Position = UDim2.new(0.5, 0, 1, -80)
	repairBtn.AnchorPoint = Vector2.new(0.5, 1)
	repairBtn.BackgroundColor3 = theme.Gold
	repairBtn.TextColor3 = Color3.fromRGB(60, 40, 10)
	repairBtn.Font = Enum.Font.FredokaOne
	repairBtn.TextSize = 16
	repairBtn.Text = "\240\159\148\167 Repair streak"
	repairBtn.Visible = false
	repairBtn.Parent = card
	corner(repairBtn, 10)

	repairBtn.MouseButton1Click:Connect(function()
		local product = GameData.Products.StreakRepair
		if not product or product.id == 0 then
			repairBtn.Text = "Coming soon!"
			return
		end
		MarketplaceService:PromptProductPurchase(player, product.id)
	end)
```

- [ ] **Step 6: Replace `showFor`** (lines 110-126) with:

```lua
	local function showFor(streakDay, rewardDesc, repairOffered, brokenStreak)
		if repairOffered and (brokenStreak or 0) > 0 then
			streakLabel.Text = ("Streak broken at day %d!"):format(brokenStreak)
			repairBtn.Visible = true
			repairBtn.Text = "\240\159\148\167 Repair streak"
		else
			streakLabel.Text = ("Day %d of %d"):format(streakDay, GameData.DailyCalendarDays)
			repairBtn.Visible = false
		end
		rewardLabel.Text = rewardDesc

		-- Past days are ticked off, today is highlighted, the rest stay dim.
		for day, entry in pairs(cells) do
			if day < streakDay then
				entry.cell.BackgroundColor3 = theme.Success
				entry.cell.TextColor3 = Color3.fromRGB(255, 255, 255)
				entry.hint.Text = "\226\156\133"
			elseif day == streakDay then
				entry.cell.BackgroundColor3 = theme.Gold
				entry.cell.TextColor3 = Color3.fromRGB(60, 40, 10)
			else
				entry.cell.BackgroundColor3 = theme.Neutral
				entry.cell.TextColor3 = theme.TextMuted
			end
		end

		claim.Text = "Claim!"
		claim.Active = true
		screenGui.Enabled = true
	end
```

- [ ] **Step 7: Pass the new arguments through** — replace the `DailyRewardAvailable` handler (lines 137-139) with:

```lua
	Remotes.DailyRewardAvailable.OnClientEvent:Connect(function(streakDay, rewardDesc, repairOffered, brokenStreak)
		showFor(streakDay, rewardDesc, repairOffered, brokenStreak)
	end)
```

- [ ] **Step 8: Verify by re-reading** — confirm: `GameData` and `MarketplaceService` are required at module scope; `cells` and `gridHeight` are defined before `showFor` and the reward label use them; the reward label and buttons sit below the grid and inside the 470px-tall card; a `nil` `repairOffered` (an older server) takes the normal branch. Rojo sync; confirm the client loads with no errors.

- [ ] **Step 9: Commit**

```bash
git add src/client/DailyRewardPanel.luau
git commit -m "feat(daily): 30-cell login calendar with milestones and repair button"
```

---

### Task 6: Studio playtest verification

**Files:** none (verification only).

- [ ] **Step 1: Confirm the pure logic is green.** Run `RunTests.luau` (or the Task 1 Step 2 fallback). Expected: all `daily:` assertions pass.

- [ ] **Step 2: See the calendar.** Start Play. The daily popup should appear on join showing **Day 1 of 30**, a 6×5 grid with reward hints, gold rings on days 7/14/30, and no repair button. Claim it: cash arrives, the popup closes, day 1 turns green.

- [ ] **Step 3: Walk the calendar.** Module state is sandboxed per execution, so drive this from a Script injected into the real server VM:

```lua
local SSS = game:GetService("ServerScriptService")
local old = SSS:FindFirstChild("__DailyProbe") if old then old:Destroy() end
local s = Instance.new("Script")
s.Name = "__DailyProbe"
s.Source = [[
local Players = game:GetService("Players")
local SSS = game:GetService("ServerScriptService")
local PlayerData = require(SSS.Server.PlayerData)
local DailyRewardService = require(SSS.Server.DailyRewardService)
local p = Players:GetPlayers()[1]
local d = PlayerData.get(p)
d.dailyStreak = 6
d.dailyBrokenStreak = 0
d.lastDailyClaim = os.time() - 25 * 3600  -- yesterday
DailyRewardService.checkForPlayer(p)      -- should offer day 7 (milestone)
]]
s.Parent = SSS
```

Confirm the popup shows **Day 7 of 30**, that cell is highlighted, and the reward reads cash **plus** a boost. Claim and confirm both land (cash rises and the boost timer appears in the HUD).

- [ ] **Step 4: Check the other milestones.** Repeat Step 3 with `d.dailyStreak = 13` (claim → day 14 grants a Lucky Spin; confirm the owned-spin count rises) and `d.dailyStreak = 29` (claim → day 30 grants a **Champion part**; confirm a new part lights up in the event panel's Champion strip and the PC-parts multipliers rise).

- [ ] **Step 5: Check the free skip.** Set `d.dailyStreak = 10`, `d.dailySkipUsed = false`, `d.lastDailyClaim = os.time() - 72 * 3600` (3 days ago, past the 48h reset). Re-check: the streak must still advance to **day 11**, not reset. After claiming, confirm `d.dailySkipUsed` is now `true`.

- [ ] **Step 6: Check the repair offer.** Set `d.dailyStreak = 20`, `d.dailySkipUsed = true`, `d.dailyBrokenStreak = 0`, `d.lastDailyClaim = os.time() - 72 * 3600`. Re-check: the popup must read "Streak broken at day 20!" and show the repair button. Click it — with `id = 0` it must say "Coming soon!" and prompt no purchase.

- [ ] **Step 7: Check the calendar restart.** Set `d.dailyStreak = 30`, `d.dailySkipUsed = true`, `d.lastDailyClaim = os.time() - 25 * 3600`. Claim: the day must become **1** and `d.dailySkipUsed` must be back to `false`.

- [ ] **Step 8: Clean up.** Destroy the `__DailyProbe` script. It is runtime-only and never in source, so there is nothing to revert in git.

---

## Self-Review

**Spec coverage:**
- 30-cell calendar grid, claimed/today/future states → Task 5. ✓
- Milestones at 7/14/30 rendered larger with gold rings → Tasks 1 (data) + 5 (render). ✓
- Day 7 cash + long boost; day 14 Lucky Case; day 30 Champion part with consolation fallback → Task 1 (ladder) + Task 3 (`grantReward`). ✓
- Cash scales with progression, from one shared function used by grant and display → Task 1 `getScaledDailyReward`, used in Task 3 for both the preview and the grant. ✓
- Boosts/spins never scale → Task 1, asserted. ✓
- `getDailyReward` clamps 1..30 instead of wrapping modulo-7 → Task 1, asserted. ✓
- One free skip per calendar, then a held streak + Robux repair → Task 1 `evaluateDailyStreak`, Task 3 bookkeeping, Task 4 receipt, Task 5 button. ✓
- Free skip resets on calendar restart → Task 1 (`calendarRestart`) + Task 3. ✓
- New PlayerData fields with backfill → Task 2. ✓
- Repair keeps the save-before-acknowledge rule → Task 4 (explicitly does not add its own save). ✓
- `StreakRepair` ships with `id = 0` → Task 1 Step 6, asserted. ✓
- Server-authoritative, client sends no amounts → Task 3 (claim re-evaluates; the client fires a bare `RequestClaimDaily`). ✓
- No `loadFailed` guard on the daily claim → Task 3 (none added). ✓
- Unit tests for ladder, scaling and all four streak cases → Task 1. ✓
- Studio playtest → Task 6. ✓

**Placeholder scan:** No TBD/TODO/"add error handling"/"similar to Task N". Every code step carries complete code. ✓

**Type consistency:** `evaluateDailyStreak` returns the same six field names in Task 1 (definition), Task 3 (`decision.available/nextStreak/usedFreeSkip/repairOffered/brokenStreak/calendarRestart`) and Task 1's assertions. Reward entries use `kind/amount/mult/dur/spins/milestone` consistently across Tasks 1, 3 and 5. `DailyRewardAvailable` gains exactly two trailing arguments, fired in Task 3 and consumed in Task 5 in matching order. `dailySkipUsed`/`dailyBrokenStreak` are spelled identically in Tasks 1–6. `GameData.DailyCalendarDays` is used in Tasks 1 and 5. `gridHeight` is defined in Task 5 Step 3 and used in Step 4. ✓
