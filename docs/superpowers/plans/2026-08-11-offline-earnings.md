# Offline Earnings (B3) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** While a player is logged off, their owned money rooms earn a reduced cash trickle they collect from a "Welcome back" popup on their next join.

**Architecture:** Two pure, unit-tested pieces (a perk cap helper in `PerkData`, the offline-cash formula in `GameData`) drive a server module (`OfflineEarnings`) that computes the pending amount once at join and grants it on Collect (server-authoritative, client value ignored). A small client popup (`OfflineWelcome`) shows the reward. Reuses the existing idle-income rates, perk tree, and `Fx` juice.

**Tech Stack:** Luau, Roblox, Rojo sync, custom `TestHarness` in `src/shared/Tests/RunTests.luau` (the only automated tests; server/client are verified by Studio playtest per project convention).

## Global Constraints

- Offline rate = **50%** of per-second room income. Base cap = **2 hours**. Cap +1h per `p_offline` perk level, max 6 (→ up to 8h).
- Transient boosts excluded from offline cash; prestige multiplier + Cash pass included.
- Cash grant is server-authoritative: server computes pending at join, stores per-session, Collect grants the stored amount and ignores any client-sent value.
- `lastOnline == 0` means "no baseline yet" → never pay out (guards brand-new players and pre-feature saves).
- Pure logic goes in shared modules and is tested in `RunTests`; server/client modules are Studio-tested, not unit-tested. Follow existing file patterns (`ChallengeService`/`ChallengePanel` are the closest siblings).
- Neon/accent colors only for accents (project rule): use `Theme.Accent`/`Theme.Gold`, surfaces stay `Theme.Panel`.

---

### Task 1: Perk cap helper (`p_offline`) — pure, TDD

**Files:**
- Modify: `src/shared/PerkData.luau` (add perk to `PerkData.PERKS`; add `PerkData.offlineCapBonusHours`)
- Test: `src/shared/Tests/RunTests.luau` (before `t:summary()` at line 303)

**Interfaces:**
- Produces: `PerkData.offlineCapBonusHours(data) -> number` (0–6), and a new perk entry `{ id = "p_offline", kind = "offlineCap", value = 1, maxLevel = 6, cost = 1 }`.

- [ ] **Step 1: Write the failing tests**

Add before `t:summary()` (line 303) in `src/shared/Tests/RunTests.luau`:

```lua
-- PerkData: offline cap perk
t:assertEqual(PerkData.offlineCapBonusHours({ perks = {} }), 0, "perk: no offline perk -> 0h bonus")
t:assertEqual(PerkData.offlineCapBonusHours({ perks = { p_offline = 3 } }), 3, "perk: 3 offline levels -> +3h")
t:assertEqual(PerkData.canBuy({ perkPoints = 1, perks = {} }, "p_offline"), true, "perk: offline perk buyable for 1 point")
t:assertEqual(PerkData.isMaxed({ perks = { p_offline = 6 } }, "p_offline"), true, "perk: offline perk maxes at 6")
```

- [ ] **Step 2: Run tests, verify they fail**

Run RunTests in Studio (Edit datamodel) via MCP `execute_luau`:
```lua
require(game.ReplicatedStorage.Shared.Tests.RunTests)
```
Expected: FAIL — `offlineCapBonusHours` is nil / assertion errors.

- [ ] **Step 3: Add the perk entry**

In `src/shared/PerkData.luau`, add to `PerkData.PERKS` (after `p_headstart`):

```lua
	{ id = "p_offline", name = "Deep Sleep", desc = "+1h offline earnings cap", icon = "😴", kind = "offlineCap", value = 1, maxLevel = 6, cost = 1 },
```

- [ ] **Step 4: Add the helper**

In `src/shared/PerkData.luau`, after `PerkData.startCashBonus` (ends ~line 66):

```lua
-- Extra offline-earnings cap hours from Deep Sleep perks (0 if none).
function PerkData.offlineCapBonusHours(data)
	local bonus = 0
	for _, p in ipairs(PerkData.PERKS) do
		if p.kind == "offlineCap" then
			bonus += PerkData.level(data, p.id) * p.value
		end
	end
	return bonus
end
```

- [ ] **Step 5: Run tests, verify they pass**

Re-run `require(...Tests.RunTests)`. Expected: PASS (all four new assertions + the existing suite green). Note: `p_offline` is `kind="offlineCap"`, inert in `cashMult`/`subsMult`/`speedMult`/`startCashBonus`, so existing perk tests stay unchanged.

- [ ] **Step 6: Commit**

```bash
git add src/shared/PerkData.luau src/shared/Tests/RunTests.luau
git commit -m "feat(perks): add Deep Sleep offline-cap perk"
```

---

### Task 2: Offline-cash formula — pure, TDD

**Files:**
- Modify: `src/shared/GameData.luau` (add `GameData.getOfflineCash`)
- Test: `src/shared/Tests/RunTests.luau` (before `t:summary()`)

**Interfaces:**
- Produces: `GameData.getOfflineCash(ratePerSec, elapsedSeconds, capSeconds) -> number` = `floor(ratePerSec * clamp(elapsedSeconds, 0, capSeconds))`.

- [ ] **Step 1: Write the failing tests**

Add before `t:summary()` in `src/shared/Tests/RunTests.luau`:

```lua
-- GameData: offline cash formula (rate/sec, elapsed, cap)
t:assertEqual(GameData.getOfflineCash(10, 100, 7200), 1000, "offline: rate*elapsed under cap")
t:assertEqual(GameData.getOfflineCash(10, 999999, 7200), 72000, "offline: clamped to cap")
t:assertEqual(GameData.getOfflineCash(10, -50, 7200), 0, "offline: negative elapsed -> 0")
t:assertEqual(GameData.getOfflineCash(0, 7200, 7200), 0, "offline: zero rate -> 0")
t:assertEqual(GameData.getOfflineCash(1.5, 10, 7200), 15, "offline: floors fractional cash")
```

- [ ] **Step 2: Run tests, verify they fail**

Run `require(...Tests.RunTests)` in Studio. Expected: FAIL — `getOfflineCash` is nil.

- [ ] **Step 3: Implement the function**

In `src/shared/GameData.luau`, near the other economy helpers (e.g. after `getBaseCash`):

```lua
-- Cash earned while offline: reduced room income (ratePerSec already halved by
-- the caller) over the away time, clamped to [0, capSeconds]. Floored to whole cash.
function GameData.getOfflineCash(ratePerSec, elapsedSeconds, capSeconds)
	local secs = math.clamp(elapsedSeconds or 0, 0, capSeconds or 0)
	return math.floor((ratePerSec or 0) * secs)
end
```

- [ ] **Step 4: Run tests, verify they pass**

Re-run `require(...Tests.RunTests)`. Expected: PASS (5 new assertions + suite green).

- [ ] **Step 5: Commit**

```bash
git add src/shared/GameData.luau src/shared/Tests/RunTests.luau
git commit -m "feat(economy): add pure offline-cash formula"
```

---

### Task 3: Server plumbing — remotes, timestamp, rate accessor, OfflineEarnings module

**Files:**
- Modify: `src/shared/Remotes.luau` (add 2 event names)
- Modify: `src/server/PlayerData.luau` (default + backfill `lastOnline`; stamp it in `save`)
- Modify: `src/server/PlotManager.luau` (add `PlotManager.roomIncomePerSec`)
- Create: `src/server/OfflineEarnings.luau`
- Modify: `src/server/init.server.luau` (require + `.start()`)

**Interfaces:**
- Consumes: `PerkData.offlineCapBonusHours`, `GameData.getOfflineCash`, `GameData.getPrestigeMultiplier(level)`, `GameData.getPassCashMultiplier(data)`, `PlayerData.get`, `PlayerData.save`.
- Produces: `PlotManager.roomIncomePerSec(data) -> number` (Σ per-sec income of owned rooms), `OfflineEarnings.start()`, remotes `OfflineEarningsReady` (server→client: `amount:number, seconds:number`) and `CollectOfflineEarnings` (client→server, no args).

- [ ] **Step 1: Add the two remote names**

In `src/shared/Remotes.luau`, add to `REMOTE_NAMES` (after `"RequestBuyPerk"`, line 53):

```lua
	"OfflineEarningsReady",
	"CollectOfflineEarnings",
```

- [ ] **Step 2: Add `lastOnline` to PlayerData default + backfill**

In `src/server/PlayerData.luau` `defaultData()` (near `prestigeLevel`, ~line 44), add:

```lua
		-- os.time() of the player's last save (for offline earnings). 0 = no
		-- baseline yet, so the first-ever session never pays out.
		lastOnline = 0,
```

In `PlayerData.load` backfill block (after line 123 `data.perks = data.perks or {}`):

```lua
				data.lastOnline = data.lastOnline or 0
```

- [ ] **Step 3: Stamp `lastOnline` on every save**

In `src/server/PlayerData.luau` `PlayerData.save`, right after the `local data = cache[player.UserId]` / `if not data then return false end` guard (after line 207), before the retry loop:

```lua
	-- Freshen the "last seen online" stamp so next join can pay offline earnings
	-- for the gap since this save. (Save runs on autosave, leave, and BindToClose.)
	data.lastOnline = os.time()
```

- [ ] **Step 4: Add the room-income accessor to PlotManager**

In `src/server/PlotManager.luau`, after the `IDLE_RATES` definition (line 2111), add:

```lua
-- Total per-second idle income of the rooms this player owns (before boosts).
-- Single source of truth shared with OfflineEarnings so the two never drift.
function PlotManager.roomIncomePerSec(data)
	local owned = data.roomsOwned or {}
	local rate = 0
	for room, perSec in pairs(IDLE_RATES) do
		if owned[room] then
			rate += perSec
		end
	end
	return rate
end
```

- [ ] **Step 5: Create the OfflineEarnings server module**

Create `src/server/OfflineEarnings.luau`:

```lua
-- Offline earnings (roadmap B3). While a player is away, their owned money rooms
-- earn 50% of their normal per-second income, up to a cap (2h + Deep Sleep perk
-- hours). Computed once at join from the loaded lastOnline stamp; granted on
-- Collect (server-authoritative -- the client's message carries no amount).
local Players = game:GetService("Players")

local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local GameData = require(game.ReplicatedStorage.Shared.GameData)
local PerkData = require(game.ReplicatedStorage.Shared.PerkData)
local PlayerData = require(script.Parent.PlayerData)
local PlotManager = require(script.Parent.PlotManager)

local OFFLINE_FRACTION = 0.5
local BASE_CAP_HOURS = 2

local OfflineEarnings = {}

-- Cash waiting to be collected this session, keyed by UserId. Cleared on Collect.
local pending = {}

local function computeFor(player)
	local data = PlayerData.get(player)
	if not data then
		return 0, 0
	end
	local last = data.lastOnline or 0
	if last <= 0 then
		return 0, 0 -- no baseline (new player / pre-feature save)
	end
	local elapsed = os.time() - last
	local capSeconds = 3600 * (BASE_CAP_HOURS + PerkData.offlineCapBonusHours(data))
	local ratePerSec = PlotManager.roomIncomePerSec(data)
		* OFFLINE_FRACTION
		* GameData.getPrestigeMultiplier(data.prestigeLevel or 0)
		* GameData.getPassCashMultiplier(data)
	local cash = GameData.getOfflineCash(ratePerSec, elapsed, capSeconds)
	return cash, math.clamp(elapsed, 0, capSeconds)
end

function OfflineEarnings.start()
	Remotes.CollectOfflineEarnings.OnServerEvent:Connect(function(player)
		local amount = pending[player.UserId]
		if not amount or amount <= 0 then
			return
		end
		pending[player.UserId] = nil
		local data = PlayerData.get(player)
		if not data then
			return
		end
		data.cash += amount
		PlayerData.save(player)
		Remotes.PlayerStateUpdated:FireClient(player, data)
	end)

	Players.PlayerRemoving:Connect(function(player)
		pending[player.UserId] = nil
	end)

	Players.PlayerAdded:Connect(function(player)
		task.spawn(function()
			-- Wait for this player's data to load (same pattern as ChallengeService).
			for _ = 1, 20 do
				if PlayerData.get(player) then
					break
				end
				task.wait(0.25)
			end
			local cash, seconds = computeFor(player)
			if cash > 0 then
				pending[player.UserId] = cash
				Remotes.OfflineEarningsReady:FireClient(player, cash, seconds)
			end
		end)
	end)
end

return OfflineEarnings
```

- [ ] **Step 6: Wire it into `init.server`**

In `src/server/init.server.luau`, add the require (after line 21 `PerkService`):

```lua
local OfflineEarnings = require(script.OfflineEarnings)
```

and start it (after line 39 `PerkService.start()`):

```lua
OfflineEarnings.start()
```

- [ ] **Step 7: Verify it builds + computes (Studio, Edit datamodel)**

Confirm Rojo synced, then run a simulated compute via MCP `execute_luau` (Edit) to prove the pieces connect (no live Play needed):

```lua
local RS = game:GetService("ReplicatedStorage")
local GameData = require(RS.Shared.GameData)
local PerkData = require(RS.Shared.PerkData)
-- both rooms owned, 1h away, no perks, prestige 0, no pass:
local ratePerSec = (10 + 220/3) * 0.5 -- Arcade 10/s + Merch ~73.3/s, halved
local cap = 3600 * (2 + PerkData.offlineCapBonusHours({perks={}}))
return GameData.getOfflineCash(ratePerSec, 3600, cap) -- ~150600
```
Expected: a positive number (~150600) and no errors. Also confirm `game.ServerScriptService.Server.OfflineEarnings` exists and `require`s clean.

- [ ] **Step 8: Commit**

```bash
git add src/shared/Remotes.luau src/server/PlayerData.luau src/server/PlotManager.luau src/server/OfflineEarnings.luau src/server/init.server.luau
git commit -m "feat(offline): server offline-earnings compute + collect"
```

---

### Task 4: Client "Welcome back" popup

**Files:**
- Create: `src/client/OfflineWelcome.luau`
- Modify: `src/client/UI.luau` (require + init, alongside the other panels)

**Interfaces:**
- Consumes: remote `OfflineEarningsReady(amount, seconds)`, fires `CollectOfflineEarnings`; `Fx.coinBurst(centerX, centerY, n)`, `Fx.popIn(guiObject)`; `Theme` table (`Panel`, `Text`, `TextMuted`, `Accent`, `Gold`, `Line`).
- Produces: `OfflineWelcome.init(player, Theme)`.

- [ ] **Step 1: Create the popup module**

Create `src/client/OfflineWelcome.luau`:

```lua
-- "Welcome back" popup: on join the server may report offline earnings; show a
-- card with the amount + away time and a Collect button. Collect tells the
-- server to grant it (server-authoritative). Reuses the white-card Theme + Fx.
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local Fx = require(script.Parent.Fx)

local OfflineWelcome = {}

local function formatMoney(n)
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

local function formatAway(seconds)
	local h = math.floor(seconds / 3600)
	local m = math.floor((seconds % 3600) / 60)
	if h > 0 then
		return string.format("%dh %dm", h, m)
	end
	return string.format("%dm", m)
end

function OfflineWelcome.init(player, Theme)
	local gui = Instance.new("ScreenGui")
	gui.Name = "OfflineWelcomeGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 60
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local backdrop = Instance.new("TextButton")
	backdrop.Name = "Backdrop"
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
	backdrop.BackgroundTransparency = 0.5
	backdrop.AutoButtonColor = false
	backdrop.Text = ""
	backdrop.Parent = gui

	local card = Instance.new("Frame")
	card.Name = "Card"
	card.Size = UDim2.fromOffset(360, 220)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.BackgroundColor3 = Theme.Panel
	card.Parent = backdrop
	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 16)
	local stroke = Instance.new("UIStroke", card)
	stroke.Color = Theme.Line
	stroke.Thickness = 1

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, -32, 0, 40)
	title.Position = UDim2.fromOffset(16, 18)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 26
	title.TextColor3 = Theme.Text
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "Welcome back! 👋"
	title.Parent = card

	local amount = Instance.new("TextLabel")
	amount.BackgroundTransparency = 1
	amount.Size = UDim2.new(1, -32, 0, 48)
	amount.Position = UDim2.fromOffset(16, 74)
	amount.Font = Enum.Font.GothamBlack
	amount.TextSize = 40
	amount.TextColor3 = Theme.Gold
	amount.TextXAlignment = Enum.TextXAlignment.Left
	amount.Text = "$0"
	amount.Parent = card

	local sub = Instance.new("TextLabel")
	sub.BackgroundTransparency = 1
	sub.Size = UDim2.new(1, -32, 0, 24)
	sub.Position = UDim2.fromOffset(16, 122)
	sub.Font = Enum.Font.Gotham
	sub.TextSize = 16
	sub.TextColor3 = Theme.TextMuted
	sub.TextXAlignment = Enum.TextXAlignment.Left
	sub.Text = "earned while you were away"
	sub.Parent = card

	local collect = Instance.new("TextButton")
	collect.Name = "Collect"
	collect.Size = UDim2.new(1, -32, 0, 44)
	collect.Position = UDim2.new(0, 16, 1, -60)
	collect.BackgroundColor3 = Theme.Accent
	collect.Font = Enum.Font.GothamBold
	collect.TextSize = 20
	collect.TextColor3 = Color3.new(1, 1, 1)
	collect.Text = "Collect"
	collect.AutoButtonColor = true
	collect.Parent = card
	Instance.new("UICorner", collect).CornerRadius = UDim.new(0, 12)

	local claimed = false
	local function claimOnce()
		if claimed then
			return
		end
		claimed = true
		Remotes.CollectOfflineEarnings:FireServer()
	end

	collect.Activated:Connect(function()
		claimOnce()
		local cam = workspace.CurrentCamera
		if cam then
			Fx.coinBurst(cam.ViewportSize.X * 0.5, cam.ViewportSize.Y * 0.5, 12)
		end
		gui.Enabled = false
	end)
	backdrop.Activated:Connect(function()
		-- tapping outside also collects (never lose the reward)
		claimOnce()
		gui.Enabled = false
	end)

	Remotes.OfflineEarningsReady.OnClientEvent:Connect(function(cash, seconds)
		if not cash or cash <= 0 then
			return
		end
		claimed = false
		amount.Text = "$" .. formatMoney(cash)
		sub.Text = "earned while away (" .. formatAway(seconds) .. ")"
		gui.Enabled = true
		Fx.popIn(card)
	end)
end

return OfflineWelcome
```

- [ ] **Step 2: Wire it into `UI.init`**

In `src/client/UI.luau`, add the require near the other panel requires (after line 264 `HomePanel`):

```lua
	local OfflineWelcome = require(script.Parent.OfflineWelcome)
```

and init it alongside the others (after line 1906 `PerkPanel.init(player, Theme, playerState)`):

```lua
	OfflineWelcome.init(player, Theme)
```

- [ ] **Step 3: Verify it builds (Studio)**

Confirm Rojo synced `StarterPlayerScripts.Client.OfflineWelcome`, and that `UI.luau` requires/inits it without error. Since Play-via-MCP does not start reliably here, static + require verification is the automated check; live look is done in Task 5.

- [ ] **Step 4: Commit**

```bash
git add src/client/OfflineWelcome.luau src/client/UI.luau
git commit -m "feat(offline): welcome-back popup + collect UI"
```

---

### Task 5: Playtest + docs

**Files:**
- Create: memory `offline-earnings.md` (+ MEMORY.md pointer) — see memory instructions
- Modify: `docs/superpowers/plans/2026-08-11-post-v1-roadmap.md` (mark B3 done)

- [ ] **Step 1: Simulated end-to-end check (Studio, Edit datamodel)**

Via MCP `execute_luau`, build a synthetic data table with `roomsOwned={Arcade=true,Merch=true}`, `lastOnline = os.time() - 3600`, `prestigeLevel=0`, `perks={}`, and run the same math `computeFor` uses (`PlotManager.roomIncomePerSec` × 0.5 × prestige × pass → `GameData.getOfflineCash`). Confirm: ~150k for 1h; away 5h with no perk clamps to 2h worth; `lastOnline=0` → 0; no rooms owned → 0.

- [ ] **Step 2: Ask the user to click Play in Studio**

Play-via-MCP won't start here (known quirk). Ask the user to press the green Play button and confirm: the popup appears on join if they were away (or fake `lastOnline` a few hours back via the console, then rejoin), the amount reads sensibly, Collect adds cash and closes, and the Perks panel shows "Deep Sleep".

- [ ] **Step 3: Update memory + roadmap**

Write `offline-earnings.md` memory (how it works + files + the `lastOnline==0` guard + 50%/2h+perk balance + `PlotManager.roomIncomePerSec` single-source), add its MEMORY.md pointer, and tick B3 in the post-v1 roadmap plan file.

- [ ] **Step 4: Commit**

```bash
git add -A && git commit -m "docs(offline): mark B3 done + memory"
```

---

## Self-Review

**Spec coverage:** goal ✓ (Tasks 3–4); player-facing popup ✓ (Task 4); balance 50%/2h+perk ✓ (Global Constraints, Tasks 1/3); rate formula w/ prestige+pass, boosts excluded ✓ (Task 3 `computeFor`); data flow stamp/compute/collect ✓ (Task 3); first-join `lastOnline==0` guard ✓ (Tasks 2/3); perk integration ✓ (Task 1); IDLE_RATES single-source accessor ✓ (Task 3 Step 4); RunTests assertions ✓ (Tasks 1–2); edge cases (negative elapsed, zero rate, double-collect via `pending` clear + client `claimed` latch) ✓ (Tasks 2–4); out-of-scope items not built ✓.

**Placeholder scan:** none — every code step has concrete Luau.

**Type consistency:** `PerkData.offlineCapBonusHours(data)` used identically in Task 1 and Task 3. `GameData.getOfflineCash(ratePerSec, elapsedSeconds, capSeconds)` signature matches between Task 2 and Task 3. `PlotManager.roomIncomePerSec(data)` defined Task 3 Step 4, called Task 3 Step 5. Remotes `OfflineEarningsReady(amount, seconds)` / `CollectOfflineEarnings()` fired and handled with matching arg counts across Tasks 3–4.
