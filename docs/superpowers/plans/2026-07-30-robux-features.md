# M8 Robux Revenue Features Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add three fair-advantage Robux items — a VIP+ pass that unlocks a passive-earning lounge, a 2× walk-speed pass, and three cosmetic studio-skin passes with a picker.

**Architecture:** New passes go in `GameData.GamePasses` (all `id = 0`, "coming soon") and flow through the existing `MonetizationService` pipeline unchanged. A new server `LoungeService` credits VIP+ owners standing in a `LoungeZone` each second (server-authoritative, reusing the idle-income credit+push pattern). 2× speed applies on spawn beside the VIP hook. Skins recolor the studio exterior via `PlotManager.applySkin`, persisted per player and chosen from a Store picker.

**Tech Stack:** Roblox / Luau, Rojo, existing `MonetizationService` / `MarketplaceService.ProcessReceipt`, `GameData.getStudioLevel`, `RunTests`.

**Spec:** `docs/superpowers/specs/2026-07-30-robux-features-design.md`

## Global Constraints

- **Fair-advantage, not pay-to-win:** the lounge pays LESS than active play; skins are purely cosmetic (no stat effect).
- **IDs later:** every new pass starts `id = 0` ("coming soon"); nothing may error with `id = 0`.
- **Lounge is server-authoritative, cannot be AFK-broken:** flat rate (NEVER a % of the player's cash), capped, credited server-side only to real VIP+ owners actually in the zone.
- **Skins cosmetic only:** recolor exterior `*Wall*`/`*Roof*`/trim parts; never touch functional parts (seats, monitors, prompts). **Neon** skin uses Neon material only on accent trim.
- **One receipt handler:** extend the existing generic `MonetizationService` handling; do not add a parallel receipt handler.
- `GameData.StartingCash` stays `0`. Mobile: new Store UI follows existing `StorePanel` layout.
- Compile check after each task: `./rojo-bin/rojo build default.project.json -o /tmp/mg.rbxl` (expect "Built project to mg.rbxl"). Non-unit behaviour is verified by Studio playtest.

## File Structure

```
src/shared/GameData.luau            -- MODIFY: 5 new passes; getLoungeRate + constants; StudioSkins
src/shared/Tests/RunTests.luau      -- MODIFY: getLoungeRate tests
src/shared/Remotes.luau             -- MODIFY: add "RequestSetSkin"
src/server/PlayerData.luau          -- MODIFY: activeSkin default + migration
src/server/LoungeService.luau       -- CREATE: 1s zone-earning loop (VIP+ only)
src/server/Lobby.luau               -- MODIFY: build VIP+ Lounge area + LoungeZone
src/server/MonetizationService.luau -- MODIFY: apply Speed2x on spawn
src/server/PlotManager.luau         -- MODIFY: applySkin(player, skinKey) + apply on build
src/server/init.server.luau         -- MODIFY: LoungeService.start(); RequestSetSkin handler
src/client/StorePanel.luau          -- MODIFY: skin "Wear" action + Default option
src/client/UI.luau                  -- MODIFY: "Get VIP+" prompt when non-owner enters lounge
```

---

## Task 1: GameData — passes, lounge rate, skins (+ unit tests)

**Files:** Modify `src/shared/GameData.luau`, `src/shared/Tests/RunTests.luau`

**Interfaces produced:** `GameData.GamePasses.VIPPlus/Speed2x/SkinGold/SkinNeon/SkinMidnight`; `GameData.LoungeRatePerLevel` (8), `GameData.LoungeRateCap` (400), `GameData.getLoungeRate(data) -> number`; `GameData.StudioSkins` (keys: `Default`, `Gold`, `Neon`, `Midnight`). Consumes existing `GameData.getStudioLevel(data)`.

- [ ] **Step 1: Failing tests** — append to `RunTests.luau` before `t:summary()`:
```lua
t:assertEqual(GameData.getLoungeRate({ gamesReleased = 0, subscribers = 0 }), 8, "lounge rate at level 1 = per-level")
t:assertEqual(GameData.getLoungeRate({ gamesReleased = 999, subscribers = 99999 }), 400, "lounge rate clamps to cap")
t:assertEqual(GameData.getLoungeRate({ gamesReleased = 2, subscribers = 0 }) >= 8, true, "lounge rate never below per-level")
```

- [ ] **Step 2:** Add the passes to the `GameData.GamePasses` table (after `Subs2x`):
```lua
	VIPPlus      = { id = 0, order = 5, icon = "\240\159\146\142", name = "VIP+", desc = "Unlocks the VIP+ Lounge -- earn passive cash while you relax." },
	Speed2x      = { id = 0, order = 6, icon = "\240\159\143\131", name = "2x Speed", desc = "Move twice as fast around the world.", walkSpeed = 32 },
	SkinGold     = { id = 0, order = 7, icon = "\240\159\142\168", name = "Gold Studio", desc = "A shiny gold look for your studio.", skin = "Gold" },
	SkinNeon     = { id = 0, order = 8, icon = "\240\159\142\168", name = "Neon Studio", desc = "Dark walls with glowing neon trim.", skin = "Neon" },
	SkinMidnight = { id = 0, order = 9, icon = "\240\159\142\168", name = "Midnight Studio", desc = "A deep midnight-blue look.", skin = "Midnight" },
```

- [ ] **Step 3:** Add lounge rate + skins (near the other `getPass*` helpers):
```lua
GameData.LoungeRatePerLevel = 8
GameData.LoungeRateCap = 400

-- Flat, capped, studio-scaling paycheck for the VIP+ lounge. NEVER a % of the
-- player's cash (so it can't snowball / AFK-break). Tune the two constants so
-- this stays below actively developing games.
function GameData.getLoungeRate(data)
	return math.min(GameData.LoungeRateCap, GameData.LoungeRatePerLevel * GameData.getStudioLevel(data))
end

-- Cosmetic studio-exterior skins. Default = the studio's normal look.
GameData.StudioSkins = {
	Default  = nil,
	Gold     = { wall = Color3.fromRGB(214, 164, 58), wallMat = Enum.Material.Metal, accent = Color3.fromRGB(244, 212, 120) },
	Neon     = { wall = Color3.fromRGB(30, 28, 46), wallMat = Enum.Material.SmoothPlastic, accent = Color3.fromRGB(120, 90, 235), accentMat = Enum.Material.Neon },
	Midnight = { wall = Color3.fromRGB(24, 26, 42), wallMat = Enum.Material.SmoothPlastic, accent = Color3.fromRGB(120, 130, 160) },
}
```
(`StudioSkins.Default = nil` means the key is absent — `applySkin` treats "no entry" as "restore the saved original look".)

- [ ] **Step 4: Run tests, verify pass** (via `execute_luau` re-running the asserts against a fresh `GameData`, as with prior math tasks).
- [ ] **Step 5: Commit** — `git commit -m "feat(robux): GameData passes, lounge rate, studio skins"`

---

## Task 2: Remotes + PlayerData

**Files:** Modify `src/shared/Remotes.luau`, `src/server/PlayerData.luau`

**Interfaces produced:** `Remotes.RequestSetSkin`; `PlayerData` profiles carry `activeSkin` (string, default `"Default"`).

- [ ] **Step 1:** In `Remotes.luau` `REMOTE_NAMES`, add `"RequestSetSkin",` (next to `"RequestSetTutorialDone"`/other Request* entries).
- [ ] **Step 2:** In `PlayerData.luau` default profile (next to `soundMuted = false,`), add:
```lua
		-- Chosen cosmetic studio skin ("Default", "Gold", "Neon", "Midnight").
		activeSkin = "Default",
```
- [ ] **Step 3:** In the migration backfill (next to the `soundMuted` backfill), add:
```lua
			if data.activeSkin == nil then
				data.activeSkin = "Default"
			end
```
- [ ] **Step 4: Compile check** → builds.
- [ ] **Step 5: Commit** — `git commit -m "feat(robux): RequestSetSkin remote + activeSkin persistence"`

---

## Task 3: LoungeService + the lounge zone

**Files:** Create `src/server/LoungeService.luau`; Modify `src/server/Lobby.luau`, `src/server/init.server.luau`

**Interfaces produced:** `LoungeService.start()`. Consumes `GameData.getLoungeRate`, `Remotes.PlayerStateUpdated`, `PlayerData.get`, and a `workspace.Lobby.LoungeZone` Part.

- [ ] **Step 1: Create `src/server/LoungeService.luau`:**
```lua
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local GameData = require(game.ReplicatedStorage.Shared.GameData)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local PlayerData = require(script.Parent.PlayerData)

local LoungeService = {}

local function inZone(pos, zone)
	local o = zone.CFrame:PointToObjectSpace(pos)
	local h = zone.Size / 2
	return math.abs(o.X) <= h.X and math.abs(o.Y) <= h.Y and math.abs(o.Z) <= h.Z
end

function LoungeService.start()
	task.spawn(function()
		while true do
			task.wait(1)
			local lobby = Workspace:FindFirstChild("Lobby")
			local zone = lobby and lobby:FindFirstChild("LoungeZone")
			if zone then
				for _, player in ipairs(Players:GetPlayers()) do
					local data = PlayerData.get(player)
					local char = player.Character
					local root = char and char:FindFirstChild("HumanoidRootPart")
					if data and root and data.passes and data.passes.VIPPlus and inZone(root.Position, zone) then
						data.cash += GameData.getLoungeRate(data)
						Remotes.PlayerStateUpdated:FireClient(player, data)
					end
				end
			end
		end
	end)
end

return LoungeService
```

- [ ] **Step 2: Build the lounge in `Lobby.luau`.** Add a `buildVIPLounge(lobbyFolder)` local function and call it inside `Lobby.build()` (next to `buildPlazaExtras(lobbyFolder)`). It builds a small furnished spot + the invisible earning zone. Use `makePart` (already in Lobby):
```lua
local function buildVIPLounge(lobbyFolder)
	local center = LOBBY_ORIGIN + Vector3.new(-34, 0, 6) -- open plaza spot; nudge in playtest if it overlaps
	makePart("LoungeRug", Vector3.new(16, 0.2, 12), center + Vector3.new(0, FLOOR_TOP + 0.1, 0), Color3.fromRGB(150, 90, 200), Enum.Material.Fabric, lobbyFolder).CanCollide = false
	-- two simple sofas
	for _, sx in ipairs({ -4, 4 }) do
		makePart("LoungeSofa", Vector3.new(4, 1, 2), center + Vector3.new(sx, FLOOR_TOP + 0.6, 3), Color3.fromRGB(90, 70, 130), Enum.Material.Fabric, lobbyFolder)
		makePart("LoungeSofaBack", Vector3.new(4, 1.4, 0.5), center + Vector3.new(sx, FLOOR_TOP + 1.3, 4), Color3.fromRGB(90, 70, 130), Enum.Material.Fabric, lobbyFolder).CanCollide = false
	end
	-- "VIP+ Only" sign
	local signPost = makePart("LoungeSignPost", Vector3.new(0.4, 5, 0.4), center + Vector3.new(0, FLOOR_TOP + 2.5, -5), Color3.fromRGB(60, 50, 80), Enum.Material.Metal, lobbyFolder)
	local sign = makePart("LoungeSign", Vector3.new(7, 2, 0.3), center + Vector3.new(0, FLOOR_TOP + 5, -5), Color3.fromRGB(120, 90, 235), Enum.Material.SmoothPlastic, lobbyFolder)
	sign.CanCollide = false
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.Parent = sign
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundTransparency = 1
	lbl.Text = "\240\159\146\142 VIP+ Lounge"
	lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
	lbl.Font = Enum.Font.FredokaOne
	lbl.TextScaled = true
	lbl.Parent = sg
	-- invisible earning zone
	local zone = makePart("LoungeZone", Vector3.new(16, 10, 12), center + Vector3.new(0, FLOOR_TOP + 5, 0), Color3.fromRGB(120, 90, 235), Enum.Material.SmoothPlastic, lobbyFolder)
	zone.Transparency = 1
	zone.CanCollide = false
end
```
Then add `buildVIPLounge(lobbyFolder)` to `Lobby.build()`.

- [ ] **Step 3:** In `src/server/init.server.luau`, add `LoungeService` to the requires + the start list (next to `MonetizationService.start()`): `local LoungeService = require(script.Parent.LoungeService)` and `LoungeService.start()`.
- [ ] **Step 4: Compile check** → builds.
- [ ] **Step 5: Commit** — `git commit -m "feat(robux): VIP+ lounge zone + earning service"`

**Playtest note:** stand in the lounge; with `data.passes.VIPPlus` temporarily set true (server), cash ticks up ~getLoungeRate/sec only while inside; false → no earning.

---

## Task 4: 2× Speed pass on spawn

**Files:** Modify `src/server/MonetizationService.luau`

**Interfaces:** Consumes `GameData.GamePasses.Speed2x.walkSpeed` (32) and `data.passes.Speed2x`.

- [ ] **Step 1:** Ensure `GameData` is required at the top of `MonetizationService.luau` (add `local GameData = require(game.ReplicatedStorage.Shared.GameData)` if not already present).
- [ ] **Step 2:** In the `onPlayer(player)` function, define an `applySpeed` helper next to `applyIfVIP` and call it in the same two places (`if player.Character then` and inside the `CharacterAdded` handler):
```lua
		local function applySpeed()
			local data = PlayerData.get(player)
			local char = player.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if data and hum and data.passes and data.passes.Speed2x then
				hum.WalkSpeed = GameData.GamePasses.Speed2x.walkSpeed
			end
		end
```
Call `applySpeed()` right after each `applyIfVIP()` call (the immediate one and the one inside `CharacterAdded`, after the `task.wait(0.5)`).

- [ ] **Step 3: Compile check** → builds.
- [ ] **Step 4: Commit** — `git commit -m "feat(robux): 2x speed pass applies on spawn"`

**Playtest note:** with `data.passes.Speed2x` true, respawn → WalkSpeed is 32 (noticeably faster); false → normal 16.

---

## Task 5: Studio skins — apply + RequestSetSkin handler

**Files:** Modify `src/server/PlotManager.luau`, `src/server/init.server.luau`

**Interfaces produced:** `PlotManager.applySkin(player, skinKey)`. Consumes `GameData.StudioSkins`, `plotOfPlayer`, `PlotManager.getPlotFolder`.

- [ ] **Step 1:** Add `applySkin` to `PlotManager.luau` (uses per-part attributes to remember the original look, so `Default` restores exactly with no theme dependency):
```lua
function PlotManager.applySkin(player, skinKey)
	local index = plotOfPlayer[player.UserId]
	if not index then
		return
	end
	local plotFolder = PlotManager.getPlotFolder(index)
	if not plotFolder then
		return
	end
	local skin = GameData.StudioSkins[skinKey] -- nil for "Default"
	for _, d in ipairs(plotFolder:GetDescendants()) do
		if d:IsA("BasePart") and (string.find(d.Name, "Wall") or string.find(d.Name, "Roof")) then
			-- remember the original look once
			if d:GetAttribute("SkinBaseColor") == nil then
				d:SetAttribute("SkinBaseColor", d.Color)
				d:SetAttribute("SkinBaseMat", d.Material.Name)
			end
			local isAccent = string.find(d.Name, "Trim") or string.find(d.Name, "RailCap") or string.find(d.Name, "Lintel")
			if not skin then
				-- Default: restore saved original
				d.Color = d:GetAttribute("SkinBaseColor")
				d.Material = Enum.Material[d:GetAttribute("SkinBaseMat")]
			elseif isAccent and skin.accent then
				d.Color = skin.accent
				d.Material = skin.accentMat or d.Material
			else
				d.Color = skin.wall
				d.Material = skin.wallMat or d.Material
			end
		end
	end
end
```

- [ ] **Step 2:** Apply the saved skin whenever a player's studio building is (re)built. Find the function that builds a player's studio (it calls `buildStudioBuilding(...)` ~line 1406) and, at its end, add:
```lua
	local data = PlayerData.get(player)
	if data then
		PlotManager.applySkin(player, data.activeSkin or "Default")
	end
```
(If `player`/`data` aren't in scope there, fetch the owner of `plotOfPlayer` for that index; the implementer wires the correct variable.)

- [ ] **Step 3:** In `init.server.luau`, add the handler (next to `SetSoundMuted`):
```lua
Remotes.RequestSetSkin.OnServerEvent:Connect(function(player, skinKey)
	local data = PlayerData.get(player)
	if not data then
		return
	end
	if skinKey ~= "Default" then
		if not GameData.StudioSkins[skinKey] then
			return -- unknown skin
		end
		local passKey = "Skin" .. tostring(skinKey) -- "Gold" -> "SkinGold"
		if not (data.passes and data.passes[passKey]) then
			return -- must own the skin pass
		end
	end
	data.activeSkin = skinKey
	PlotManager.applySkin(player, skinKey)
	Remotes.PlayerStateUpdated:FireClient(player, data)
end)
```
(Ensure `GameData` and `PlotManager` are required in `init.server.luau` — they already are.)

- [ ] **Step 4: Compile check** → builds.
- [ ] **Step 5: Commit** — `git commit -m "feat(robux): studio skin apply + set-skin handler"`

**Playtest note:** set `data.passes.SkinGold = true`, fire `RequestSetSkin("Gold")` → studio exterior turns gold; `RequestSetSkin("Default")` → restores normal; functional parts untouched.

---

## Task 6: Store cards for new passes + skin picker + lounge prompt

**Files:** Modify `src/client/StorePanel.luau`, `src/client/UI.luau`

**Interfaces:** Consumes `Remotes.RequestSetSkin`, `GameData.GamePasses` (new entries auto-listed), `playerState.passes`, `playerState.activeSkin`, `workspace.Lobby.LoungeZone`.

- [ ] **Step 1: New passes auto-appear.** `StorePanel.init` already iterates `GameData.GamePasses` (line ~21) and builds a card per entry, so VIP+, 2x Speed, and the three skins show up automatically with a Buy action. Verify by reading — no card-loop change needed for them to appear.

- [ ] **Step 2: Skin "Wear" behaviour.** In the card refresher (the `refreshers[entry.key]` function, ~line 195-228), special-case skin entries (`entry.info.skin ~= nil`): when the player **owns** the skin pass (`playerState.passes[entry.key]`), the action button should read `"Wear"` (or `"Wearing"` + disabled when `playerState.activeSkin == entry.info.skin`) instead of a buy prompt, and its click should fire `Remotes.RequestSetSkin:FireServer(entry.info.skin)` (not the purchase prompt). When not owned, keep the normal Buy action. Read the existing action-button wiring (~line 181-195) and branch on `entry.info.skin` + ownership.

- [ ] **Step 3: Default-look button.** Add one always-available control to revert to the plain look: a small button (e.g. at the top of the list, LayoutOrder 0, or a fixed "Plain look" card) whose click fires `Remotes.RequestSetSkin:FireServer("Default")`. Highlight it when `playerState.activeSkin == "Default"`.

- [ ] **Step 4: "Get VIP+" lounge prompt** in `UI.luau`. Add a hidden banner TextLabel (reuse the existing banner style) and a `RunService.Heartbeat` (throttled to ~4/sec) check: if the local character's `HumanoidRootPart` is inside `workspace.Lobby.LoungeZone` (same box test as LoungeService) **and** `not playerState.passes.VIPPlus`, show "💎 Get VIP+ to earn cash in the lounge!"; otherwise hide it. (Client-side, cosmetic only — the actual earning gate is server-side in LoungeService.)

- [ ] **Step 5: Compile check** → builds.
- [ ] **Step 6: Commit** — `git commit -m "feat(robux): store skin picker + Get VIP+ lounge prompt"`

**Playtest note:** Store shows VIP+/2x Speed/3 skins; owning a skin lets you Wear it and the studio recolors; Default reverts; walking into the lounge without VIP+ shows the prompt.

---

## Task 7: Fill in Robux IDs + full playtest (human-driven)

**Files:** Modify `src/shared/GameData.luau` (the new passes' `id` fields only).

Done by the human in Roblox Creator Dashboard + Studio (controller coordinates; not automatable).

- [ ] **Step 1:** In the Creator Dashboard, create 5 game passes (VIP+, 2x Speed, Gold/Neon/Midnight Studio), copy each numeric ID into the matching `id = 0` in `GameData.GamePasses`.
- [ ] **Step 2:** Playtest each: buy (or grant) VIP+ → lounge pays while inside, below active earning; 2x Speed → faster; each skin → buyable, wearable, studio recolors, choice persists on rejoin; the "Get VIP+" prompt shows for non-owners in the lounge.
- [ ] **Step 3:** Tune `LoungeRatePerLevel` / `LoungeRateCap` if the paycheck feels too strong/weak.
- [ ] **Step 4: Commit** — `git commit -m "feat(robux): fill in game-pass ids + lounge tuning"`.
- [ ] **Step 5:** (Live server) confirm `activeSkin` persists across rejoins and ownership re-verifies on join.

---

## Self-Review

- **Spec coverage:** VIP+ pass + lounge zone + earning (Tasks 1,3); flat capped non-compounding rate (Task 1 `getLoungeRate`, tests); server-authoritative gate (Task 3); 2× speed (Tasks 1,4); 3 skin passes + StudioSkins + apply + picker + persistence (Tasks 1,2,5,6); "Get VIP+" prompt (Task 6); Store cards (Task 6); IDs-later + fill (Task 7). ✅
- **Naming consistency:** pass keys `VIPPlus`/`Speed2x`/`SkinGold`/`SkinNeon`/`SkinMidnight`; skin keys `Gold`/`Neon`/`Midnight`/`Default`; `getLoungeRate`, `applySkin(player, skinKey)`, `RequestSetSkin`, `activeSkin`, `LoungeZone` — used identically across tasks. Pass→skin map is `"Skin"..skinKey`. ✅
- **Safety:** lounge rate flat/capped/never %-of-cash (Task 1); server-only credit to real VIP+ in zone (Task 3); skins touch only `*Wall*`/`*Roof*` parts and remember originals via attributes (Task 5); all ids `0` and non-erroring. ✅
- **No placeholders:** full code for the new module, rate, skins, apply, speed hook, handler, lounge build; precise edits elsewhere. ✅
