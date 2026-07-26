# M2 Onboarding Tutorial Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A friendly, non-blocking onboarding tutorial that guides a brand-new player through their first full loop — enter studio → sit at New Project PC → pick a trend-matching Genre+Topic & start → play the mini-games → release first game → buy an upgrade → hire a worker — then congratulates them.

**Architecture:** One new client module (`TutorialGuide.luau`) owns the whole experience: a bottom-center step banner, a world beacon over the New Project desk, a pulse on the "To Studio" button, step-completion detection from existing remotes/state, a Skip link, and a "?" replay button. The server only persists a `tutorialDone` flag. `UI.luau` passes a small `hooks` table so the guide can observe the To Studio button, seat changes, and the player's plot folder without reaching into UI internals.

**Tech Stack:** Roblox Luau, Rojo sync (`./rojo-bin/rojo serve default.project.json --port 34872`), RemoteEvents. **No automated test framework** — verification is `./rojo-bin/rojo build` (compile) + live Studio playtest via the Studio MCP.

## Global Constraints
- **Non-blocking:** the tutorial must NEVER disable player input or lock controls.
- **Animations:** use manual `task.spawn`/`task.wait` loops for all motion (beacon bob, button pulse). Do NOT use `TweenService` — it is unreliable in this project.
- **ZIndex:** the HUD uses `ZIndexBehavior = Global`; never raise a container Frame's `ZIndex` above its own children (it hides them). Use separate ScreenGuis + `DisplayOrder` for layering.
- **Emoji in strings:** write emoji as literal UTF-8 characters in `.luau` files (Rojo preserves them) — e.g. `"🏠"`.
- **Exact step count/order/copy:** 6 steps then a finale, in this order and with this copy:
  1. `Step 1 of 6 — Head to your studio! 🏠`
  2. `Step 2 of 6 — Sit at the New Project computer! 💻`
  3. `Step 3 of 6 — Pick a Genre + Topic that matches a Trend, then hit Start! 🎯`
  4. `Step 4 of 6 — Play the mini-games to build your game! 🎮`
  5. `Step 5 of 6 — Spend your cash on an upgrade (PC or a new floor)! 💰`
  6. `Step 6 of 6 — Hire your first worker! 👷`
  - Finale: `🎉 You're all set! Keep releasing hit games and grow your studio!`
- **Completion by delta:** each step's completion compares against a baseline captured when the step *starts* (so Replay works for veterans).
- **Commits:** this repo isn't committed as part of the normal flow; the commit step in each task is OPTIONAL — only commit if the user asks. Never commit on `main` without branching first.

---

## File structure

- **Create `src/server/TutorialService.luau`** — one responsibility: on `SetTutorialDone`, set `data.tutorialDone = true`.
- **Create `src/client/TutorialGuide.luau`** — the entire tutorial (banner, beacon, pulse, step machine, replay, skip).
- **Modify `src/shared/Remotes.luau`** — add the `SetTutorialDone` RemoteEvent to the event list.
- **Modify `src/server/PlayerData.luau`** — add `tutorialDone = false` default + backfill.
- **Modify `src/server/init.server.luau`** — require + start `TutorialService`.
- **Modify `src/client/UI.luau`** — require `TutorialGuide`, add a seated-station listener registry, and call `TutorialGuide.init` with a `hooks` table.

---

### Task 1: Persistence plumbing (done-flag saves)

**Files:**
- Create: `src/server/TutorialService.luau`
- Modify: `src/shared/Remotes.luau`
- Modify: `src/server/PlayerData.luau`
- Modify: `src/server/init.server.luau`

**Interfaces:**
- Produces: `Remotes.SetTutorialDone` (RemoteEvent, client→server, no args); `PlayerData` default field `tutorialDone: boolean`; `TutorialService.start()`.

- [ ] **Step 1: Add the RemoteEvent**

In `src/shared/Remotes.luau`, find the list of event names (the strings the module creates RemoteEvents from) and add `"SetTutorialDone"` to it, following the exact pattern already used for names like `"RequestClaimDaily"`. (Open the file; the events are declared in one table/loop — add the new name there.)

- [ ] **Step 2: Add the data field + backfill**

In `src/server/PlayerData.luau`, add `tutorialDone = false` to the `defaultData` table, and add a backfill line next to the other backfills so existing saves get it:

```lua
-- in defaultData = { ... }
tutorialDone = false,
```
```lua
-- in the backfill section (where other fields are defaulted for loaded saves)
if data.tutorialDone == nil then
    data.tutorialDone = false
end
```

- [ ] **Step 3: Create the service**

Create `src/server/TutorialService.luau`:

```lua
-- Persists the onboarding tutorial's "done" flag. The client drives the whole
-- tutorial; the server just records that the player finished (or skipped) it so
-- it never auto-starts again.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerData = require(script.Parent.PlayerData)

local TutorialService = {}

function TutorialService.start()
	Remotes.SetTutorialDone.OnServerEvent:Connect(function(player)
		local data = PlayerData.get(player)
		if data then
			data.tutorialDone = true
		end
	end)
end

return TutorialService
```

- [ ] **Step 4: Wire it into the server bootstrap**

In `src/server/init.server.luau`, follow the existing pattern for services (e.g. how `DailyRewardService` is required and started). Add a require alongside the others:

```lua
local TutorialService = require(script.TutorialService)
```
and a start call alongside the others:
```lua
TutorialService.start()
```

- [ ] **Step 5: Compile-check**

Run: `./rojo-bin/rojo build default.project.json --output /tmp/m2check.rbxl`
Expected: `Built project to /tmp/m2check.rbxl` with no errors.

- [ ] **Step 6: Live-verify the flag round-trips**

With Rojo synced and a fresh Play session, run this in the Studio MCP (Server datamodel) to confirm the field exists and the remote flips it:
```lua
local PlayerData = require(game.ServerScriptService.Server.PlayerData)
local p = game.Players:GetPlayers()[1]
local d = PlayerData.get(p)
local before = d.tutorialDone
game.ReplicatedStorage.Shared.Remotes.SetTutorialDone:FireServer() -- (or fire from client)
return ("tutorialDone before=%s"):format(tostring(before))
```
Expected: `tutorialDone before=false` (the default for a fresh player). (Note: `require` may hit a stale module cache in Studio; if so, verify instead by reading the client's `PlayerStateUpdated` payload in Task 2.)

- [ ] **Step 7 (optional): Commit**

```bash
git add src/shared/Remotes.luau src/server/PlayerData.luau src/server/TutorialService.luau src/server/init.server.luau
git commit -m "feat(m2): persist onboarding tutorialDone flag"
```

---

### Task 2: TutorialGuide module + UI integration (the full tutorial)

**Files:**
- Create: `src/client/TutorialGuide.luau`
- Modify: `src/client/UI.luau` (require at ~line 137; seated-station registry around `updateSeatedStation` at ~line 1346; `hooks` + init call after `WorkerHub.init` at ~line 1634)

**Interfaces:**
- Consumes: `Remotes.SetTutorialDone`, `Remotes.PlayerStateUpdated` (payload includes `tutorialDone`, `gamesReleased`, `houseTier`, `pcTier`, `workers`), `Remotes.PhaseStarted`, `Remotes.DevelopmentComplete`.
- Consumes from `hooks`: `hooks.toStudioButton: TextButton`, `hooks.onSeatedStationChanged(cb: (station: string?) -> ())`, `hooks.getPlotFolder(): Folder?`.
- Produces: `TutorialGuide.init(player, theme, playerState, hooks)`.

- [ ] **Step 1: Create the full TutorialGuide module**

Create `src/client/TutorialGuide.luau`:

```lua
-- Dynamic onboarding tutorial (M2). A friendly, NON-BLOCKING guide that walks a
-- brand-new player through their first full loop and then congratulates them.
-- Input is never locked. All motion uses manual loops (TweenService is
-- unreliable in this project). Step completion is detected from deltas captured
-- when each step starts, so Replay works for veteran players too.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local TutorialGuide = {}

local STEP_TEXT = {
	"Step 1 of 6 — Head to your studio! 🏠",
	"Step 2 of 6 — Sit at the New Project computer! 💻",
	"Step 3 of 6 — Pick a Genre + Topic that matches a Trend, then hit Start! 🎯",
	"Step 4 of 6 — Play the mini-games to build your game! 🎮",
	"Step 5 of 6 — Spend your cash on an upgrade (PC or a new floor)! 💰",
	"Step 6 of 6 — Hire your first worker! 👷",
}
local FINALE_TEXT = "🎉 You're all set! Keep releasing hit games and grow your studio!"

function TutorialGuide.init(player, theme, playerState, hooks)
	hooks = hooks or {}
	local currentStep = 0 -- 0 = idle; 1..6 = active; goes to 0 after finale
	local baseline = { games = 0, houseTier = 0, pcTier = 0, workersHired = 0 }
	local beacon = nil
	local beaconGen = 0
	local pulseGen = 0

	local gui = Instance.new("ScreenGui")
	gui.Name = "TutorialGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 15
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Bottom-center step banner.
	local banner = Instance.new("Frame")
	banner.Name = "Banner"
	banner.Size = UDim2.fromOffset(580, 66)
	banner.AnchorPoint = Vector2.new(0.5, 1)
	banner.Position = UDim2.new(0.5, 0, 1, -28)
	banner.BackgroundColor3 = theme.Panel
	banner.Visible = false
	banner.Parent = gui
	local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(0, 14); bc.Parent = banner
	local bs = Instance.new("UIStroke"); bs.Color = theme.Accent; bs.Thickness = 2; bs.Transparency = 0.25; bs.Parent = banner

	local bannerText = Instance.new("TextLabel")
	bannerText.Name = "Text"
	bannerText.Size = UDim2.new(1, -110, 1, -12)
	bannerText.Position = UDim2.fromOffset(20, 6)
	bannerText.BackgroundTransparency = 1
	bannerText.TextXAlignment = Enum.TextXAlignment.Left
	bannerText.TextWrapped = true
	bannerText.TextColor3 = theme.Text
	bannerText.Font = Enum.Font.FredokaOne
	bannerText.TextSize = 19
	bannerText.Parent = banner

	local skip = Instance.new("TextButton")
	skip.Name = "Skip"
	skip.Size = UDim2.fromOffset(78, 30)
	skip.AnchorPoint = Vector2.new(1, 0.5)
	skip.Position = UDim2.new(1, -14, 0.5, 0)
	skip.BackgroundTransparency = 1
	skip.Text = "Skip ✕"
	skip.TextColor3 = theme.TextMuted
	skip.Font = Enum.Font.GothamMedium
	skip.TextSize = 15
	skip.Parent = banner

	-- "?" replay button, just below the middle-left Rebirth button.
	local replay = Instance.new("TextButton")
	replay.Name = "ReplayTutorial"
	replay.Size = UDim2.fromOffset(40, 40)
	replay.AnchorPoint = Vector2.new(0, 0.5)
	replay.Position = UDim2.new(0, 24, 0.5, 74)
	replay.BackgroundColor3 = theme.Accent
	replay.Text = "?"
	replay.TextColor3 = Color3.fromRGB(255, 255, 255)
	replay.Font = Enum.Font.FredokaOne
	replay.TextSize = 22
	replay.Parent = gui
	local rc = Instance.new("UICorner"); rc.CornerRadius = UDim.new(1, 0); rc.Parent = replay

	-- ---- pointing helpers (pulse + beacon) --------------------------------
	local function stopPulse()
		pulseGen += 1 -- invalidates any running pulse loop; it restores state itself
	end

	local function startPulse(button)
		if not button then return end
		pulseGen += 1
		local myGen = pulseGen
		local orig = button.BackgroundTransparency
		task.spawn(function()
			while myGen == pulseGen and button.Parent do
				for _, t in ipairs({ 0, 0.4, 0 }) do
					if myGen ~= pulseGen then break end
					button.BackgroundTransparency = t
					task.wait(0.35)
				end
			end
			if button.Parent then
				button.BackgroundTransparency = orig
			end
		end)
	end

	local function hideBeacon()
		beaconGen += 1
		if beacon then
			beacon:Destroy()
			beacon = nil
		end
	end

	local function showSeatBeacon()
		hideBeacon()
		local plot = hooks.getPlotFolder and hooks.getPlotFolder()
		if not plot then return end
		local seat = plot:FindFirstChild("NewProjectSeat", true)
		if not seat then return end
		beaconGen += 1
		local myGen = beaconGen

		local model = Instance.new("Model")
		model.Name = "TutorialBeacon"

		local pillar = Instance.new("Part")
		pillar.Name = "Pillar"
		pillar.Size = Vector3.new(0.6, 10, 0.6)
		pillar.Anchored = true
		pillar.CanCollide = false
		pillar.CanQuery = false
		pillar.Material = Enum.Material.Neon
		pillar.Color = theme.Accent
		pillar.Transparency = 0.35
		pillar.CFrame = seat.CFrame * CFrame.new(0, 6, 0)
		pillar.Parent = model

		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.fromOffset(130, 96)
		bb.StudsOffsetWorldSpace = Vector3.new(0, 7, 0)
		bb.AlwaysOnTop = true
		bb.Adornee = seat
		bb.Parent = model
		local arrow = Instance.new("TextLabel")
		arrow.Size = UDim2.fromScale(1, 0.6)
		arrow.BackgroundTransparency = 1
		arrow.Text = "⬇"
		arrow.TextColor3 = theme.Accent
		arrow.Font = Enum.Font.FredokaOne
		arrow.TextScaled = true
		arrow.Parent = bb
		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.fromScale(1, 0.4)
		lbl.Position = UDim2.fromScale(0, 0.6)
		lbl.BackgroundTransparency = 1
		lbl.Text = "Sit here!"
		lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
		lbl.TextStrokeTransparency = 0.3
		lbl.Font = Enum.Font.FredokaOne
		lbl.TextScaled = true
		lbl.Parent = bb

		model.Parent = workspace
		beacon = model

		task.spawn(function()
			local t = 0
			while myGen == beaconGen and model.Parent do
				t += 0.1
				bb.StudsOffsetWorldSpace = Vector3.new(0, 7 + math.sin(t * 3) * 0.6, 0)
				task.wait(0.05)
			end
		end)
	end

	-- ---- step machine -----------------------------------------------------
	local function captureBaseline()
		local hired = 0
		if playerState.workers then
			for _, w in pairs(playerState.workers) do
				if w.hired then hired += 1 end
			end
		end
		baseline = {
			games = playerState.gamesReleased or 0,
			houseTier = playerState.houseTier or 0,
			pcTier = playerState.pcTier or 0,
			workersHired = hired,
		}
	end

	local setStep -- forward declare
	local function finish(showFinale)
		currentStep = 0
		stopPulse()
		hideBeacon()
		if showFinale then
			bannerText.Text = FINALE_TEXT
			skip.Visible = false
			banner.Visible = true
			task.delay(5, function()
				if currentStep == 0 then
					banner.Visible = false
				end
			end)
		else
			banner.Visible = false
		end
		if not playerState.tutorialDone then
			playerState.tutorialDone = true
			Remotes.SetTutorialDone:FireServer()
		end
	end

	function setStep(n)
		currentStep = n
		stopPulse()
		hideBeacon()
		captureBaseline()
		bannerText.Text = STEP_TEXT[n]
		skip.Visible = true
		banner.Visible = true
		if n == 1 then
			startPulse(hooks.toStudioButton)
		elseif n == 2 then
			showSeatBeacon()
		end
	end

	local function advance()
		if currentStep < 1 then return end
		if currentStep >= #STEP_TEXT then
			finish(true)
		else
			setStep(currentStep + 1)
		end
	end

	local function startTutorial()
		setStep(1)
	end

	-- ---- wiring -----------------------------------------------------------
	skip.MouseButton1Click:Connect(function()
		finish(false)
	end)
	replay.MouseButton1Click:Connect(function()
		startTutorial()
	end)

	if hooks.toStudioButton then
		hooks.toStudioButton.MouseButton1Click:Connect(function()
			if currentStep == 1 then advance() end
		end)
	end

	if hooks.onSeatedStationChanged then
		hooks.onSeatedStationChanged(function(station)
			if currentStep == 2 and station == "NewProject" then
				advance()
			end
		end)
	end

	Remotes.PhaseStarted.OnClientEvent:Connect(function()
		if currentStep == 3 then advance() end
	end)

	Remotes.DevelopmentComplete.OnClientEvent:Connect(function()
		if currentStep == 4 then advance() end
	end)

	local autoStartChecked = false
	Remotes.PlayerStateUpdated.OnClientEvent:Connect(function(data)
		playerState.tutorialDone = data.tutorialDone
		if not autoStartChecked then
			autoStartChecked = true
			if not data.tutorialDone then
				startTutorial()
			end
			return
		end
		if currentStep == 5 then
			if (data.houseTier or 0) > baseline.houseTier or (data.pcTier or 0) > baseline.pcTier then
				advance()
			end
		elseif currentStep == 6 then
			local hired = 0
			if data.workers then
				for _, w in pairs(data.workers) do
					if w.hired then hired += 1 end
				end
			end
			if hired > baseline.workersHired then
				advance()
			end
		end
	end)
end

return TutorialGuide
```

- [ ] **Step 2: Require the module in UI.luau**

In `src/client/UI.luau`, after the `WorkerHub` require (line ~137), add:
```lua
	local TutorialGuide = require(script.Parent.TutorialGuide)
```

- [ ] **Step 3: Add the seated-station listener registry in UI.luau**

In `src/client/UI.luau`, immediately before `local function updateSeatedStation()` (line ~1346) add:
```lua
	local seatedStationListeners = {}
```
Then inside `updateSeatedStation`, right after the line `seatedStation = newStation`, add:
```lua
		for _, cb in ipairs(seatedStationListeners) do
			task.spawn(cb, seatedStation)
		end
```

- [ ] **Step 4: Init TutorialGuide with hooks in UI.luau**

In `src/client/UI.luau`, after `WorkerHub.init(player, Theme)` (line ~1634) add:
```lua
	TutorialGuide.init(player, Theme, playerState, {
		toStudioButton = toStudioBtn,
		onSeatedStationChanged = function(cb)
			table.insert(seatedStationListeners, cb)
		end,
		getPlotFolder = function()
			return plotFolder
		end,
	})
```
(`toStudioBtn` and `plotFolder` are locals already in scope in this function — `toStudioBtn` at line ~748, `plotFolder` at line ~1422.)

- [ ] **Step 5: Compile-check**

Run: `./rojo-bin/rojo build default.project.json --output /tmp/m2check.rbxl`
Expected: `Built project to /tmp/m2check.rbxl` with no errors.

- [ ] **Step 6: Live playtest the full flow**

With Rojo synced, start a fresh Play session (Studio MCP `start_stop_play`). Verify, in order:
1. On spawn, the bottom-center banner shows **"Step 1 of 6 — Head to your studio! 🏠"** and the **To Studio** button is pulsing. Input is not locked (you can walk).
2. Click **To Studio** → banner advances to **Step 2**, and a glowing Neon beacon with a bobbing ⬇ "Sit here!" appears over the New Project desk.
3. Sit at the New Project desk → banner advances to **Step 3**.
4. Pick a Genre + Topic and press Start → banner advances to **Step 4** once phases begin.
5. Finish the mini-games so the game releases → banner advances to **Step 5**.
6. Buy a PC or floor upgrade → banner advances to **Step 6**.
7. Hire a worker → banner shows the **🎉 finale** and disappears after ~5s.
8. Confirm `SetTutorialDone` fired (Server MCP): the player's `data.tutorialDone` is now `true`.
9. Re-enter (stop/start Play) → the banner does **not** auto-appear. Click the **"?"** button → it restarts at Step 1.

Use the Studio MCP `screen_capture` to confirm the banner + beacon render on-theme.

- [ ] **Step 7 (optional): Commit**

```bash
git add src/client/TutorialGuide.luau src/client/UI.luau
git commit -m "feat(m2): dynamic onboarding tutorial (banner, beacon, steps, replay)"
```

---

## Self-Review notes (author)
- **Spec coverage:** persistence (Task 1) covers `tutorialDone` + `SetTutorialDone`; Task 2 covers all 6 steps, finale, non-blocking banner, world beacon (step 2), HUD pulse (step 1), Skip, "?" replay, auto-start-once, and delta-based detection. All spec sections mapped.
- **Signals verified against code:** `seatedStation == "NewProject"` (STATION_NAMES includes it), `PhaseStarted`/`DevelopmentComplete`/`PlayerStateUpdated` exist in Remotes, `toStudioBtn` (line ~748) and `plotFolder` (line ~1422) are in scope at the init site.
- **Type consistency:** `hooks` keys (`toStudioButton`, `onSeatedStationChanged`, `getPlotFolder`) match between the UI init call (Task 2 Step 4) and the module (Task 2 Step 1).
- **No TweenService**, manual loops with generation counters for pulse/beacon; emoji as literal UTF-8.
