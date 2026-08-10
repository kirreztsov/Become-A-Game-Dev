# PC Install Minigame Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn every PC-part upgrade into a hands-on 3D install: buying reserves the upgrade, a workbench minigame (drag old part out, drag new part into its glowing slot) applies it only on a correct install.

**Architecture:** Server (`PCService`) reserves-on-buy (no charge) and fires `PCInstallStart`; a local client module (`PCInstallGame`) runs the 3D drag-and-snap scene using real `PCVisuals` models; on completion the client fires `PCInstallComplete` and the server re-validates and applies. Pure decision logic lives in `PCService` + a new shared `PCInstall` module so it is unit-testable; the 3D scene is manual-playtested.

**Tech Stack:** Roblox Luau, Rojo (`./rojo-bin/rojo`), existing `TestHarness`/`RunTests` harness run inside Studio, Studio MCP for manual playtest.

## Global Constraints

- `GameData.StartingCash` stays `0`.
- Colored accents use `Enum.Material.SmoothPlastic`, never `Neon` (Neon blooms white in this lighting); the RGB case multi-color look is the pre-approved exception.
- Server-authoritative: the upgrade is applied ONLY by `PCService` after re-validation; the client never grants a part.
- Follow existing patterns: remotes are RemoteEvents auto-created from the `REMOTE_NAMES` list in `src/shared/Remotes.luau`; tests are inline assertions appended to `src/shared/Tests/RunTests.luau` using `TestHarness`.
- Run the test suite in Studio: `execute_luau` (Server datamodel) `require(game.ReplicatedStorage.Shared.Tests.RunTests)` — expect `Tests complete: N passed, 0 failed`.
- Compile check for any change: `./rojo-bin/rojo build default.project.json -o /tmp/pcinstall.rbxl` (expect `Built project`).

---

## File Structure

- `src/shared/Remotes.luau` (modify) — add 3 remote names.
- `src/shared/PCInstall.luau` (create) — bench world anchor, per-part layout table, pure `isWithinSnap`.
- `src/server/PCService.luau` (modify) — pure `reserveDecision`/`applyInstall`; reserve-on-buy + install/cancel/leave wiring; `pendingInstall` table.
- `src/server/Lobby.luau` (modify) — static Assembly Bench landmark prop in the PC Store.
- `src/client/PCInstallGame.luau` (create) — the 3D drag-and-snap minigame.
- `src/client/init.client.luau` (modify) — launch the minigame on `PCInstallStart`, single-instance guard.
- `src/shared/Tests/RunTests.luau` (modify) — inline unit tests for `PCInstall` + `PCService` pure logic.

---

## Task 1: Add install remotes

**Files:**
- Modify: `src/shared/Remotes.luau` (the `REMOTE_NAMES` list, near line 18-22)

**Interfaces:**
- Produces: RemoteEvents `PCInstallStart`, `PCInstallComplete`, `PCInstallCancel` under `ReplicatedStorage.Shared.Remotes` (accessed as `Remotes.PCInstallStart` etc.).

- [ ] **Step 1: Add the three names to the list**

In `src/shared/Remotes.luau`, in the `REMOTE_NAMES` table, add these three entries right after `"PCActionResult",`:

```lua
	"PCInstallStart",
	"PCInstallComplete",
	"PCInstallCancel",
```

- [ ] **Step 2: Compile check**

Run: `./rojo-bin/rojo build default.project.json -o /tmp/pcinstall.rbxl`
Expected: `Built project to ...` with no errors.

- [ ] **Step 3: Commit**

```bash
git add src/shared/Remotes.luau
git commit -m "feat(pc): add install-minigame remotes"
```

---

## Task 2: Shared PCInstall layout + snap helper

**Files:**
- Create: `src/shared/PCInstall.luau`
- Test: `src/shared/Tests/RunTests.luau` (append assertions)

**Interfaces:**
- Produces:
  - `PCInstall.BenchCFrame : CFrame` — world CFrame of the workbench origin (bench top-front-center).
  - `PCInstall.Layout : { [partId:string]: { slot: CFrame, tray: CFrame, camera: CFrame, snap: number, size: number } }` — all CFrames are LOCAL offsets relative to `BenchCFrame`; `snap` is stud radius; `size` is the target model height for `PCVisuals.buildTierDisplay`.
  - `PCInstall.isWithinSnap(dropPos: Vector3, slotPos: Vector3, radius: number) : boolean`
  - `PCInstall.worldSlot(partId) : CFrame`, `PCInstall.worldTray(partId) : CFrame`, `PCInstall.worldCamera(partId) : CFrame` — convenience: `BenchCFrame * Layout[partId].<field>`.
- Consumes: `GameData.PCParts` (list of `{ id = ... }`) to validate coverage in tests.

- [ ] **Step 1: Write the failing tests**

Append to `src/shared/Tests/RunTests.luau` (before the final `t:summary()` line):

```lua
-- PC install minigame: snap + layout coverage
local PCInstall = require(script.Parent.Parent.PCInstall)
t:assertEqual(PCInstall.isWithinSnap(Vector3.new(0, 0, 0), Vector3.new(0, 0, 1), 2), true, "snap: within radius is true")
t:assertEqual(PCInstall.isWithinSnap(Vector3.new(0, 0, 0), Vector3.new(0, 0, 3), 2), false, "snap: beyond radius is false")
t:assertEqual(PCInstall.isWithinSnap(Vector3.new(0, 0, 0), Vector3.new(0, 0, 2), 2), true, "snap: exactly at radius is true")
local missing = {}
for _, p in ipairs(GameData.PCParts) do
	if not PCInstall.Layout[p.id] then
		missing[#missing + 1] = p.id
	end
end
t:assertEqual(#missing, 0, "every PC part has a bench layout entry")
for _, p in ipairs(GameData.PCParts) do
	local e = PCInstall.Layout[p.id]
	if e then
		t:assertEqual(e.snap > 0, true, ("layout %s has a positive snap radius"):format(p.id))
	end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run in Studio (Server): `require(game.ReplicatedStorage.Shared.Tests.RunTests)`
Expected: FAIL/error — `PCInstall` module does not exist yet.

- [ ] **Step 3: Create `src/shared/PCInstall.luau`**

```lua
-- Layout + pure helpers for the PC-install workbench minigame. All Layout
-- CFrames are LOCAL to PCInstall.BenchCFrame; the client multiplies the bench
-- world CFrame by these to place slots, trays and the camera. The 7 parts each
-- get one fixed spot; only the current part's slot glows during a round.
local GameData = require(game.ReplicatedStorage.Shared.GameData)

local PCInstall = {}

-- Workbench origin in the PC Store (bench-top, front-center). Tuned in playtest.
PCInstall.BenchCFrame = CFrame.new(165, 4.6, -12) * CFrame.Angles(0, math.rad(180), 0)

-- Camera sits in front of the bench looking back at the open tower.
local CAM = CFrame.new(Vector3.new(0, 1.6, 6), Vector3.new(0, 1.2, 0))

-- Per-part local offsets. slot = where the part seats; tray = where the new
-- part starts; snap = generous drop radius (studs); size = target model height.
PCInstall.Layout = {
	CPU = { slot = CFrame.new(-1.0, 0.6, -0.4), tray = CFrame.new(-2.6, 0.5, 2.2), camera = CAM, snap = 1.4, size = 1.4 },
	RAM = { slot = CFrame.new(0.6, 0.9, -0.4), tray = CFrame.new(-1.3, 0.5, 2.2), camera = CAM, snap = 1.4, size = 1.8 },
	Storage = { slot = CFrame.new(1.4, 0.4, 0.2), tray = CFrame.new(0.0, 0.5, 2.2), camera = CAM, snap = 1.4, size = 1.6 },
	Cooling = { slot = CFrame.new(-1.0, 1.2, -0.4), tray = CFrame.new(1.3, 0.5, 2.2), camera = CAM, snap = 1.6, size = 2.2 },
	GPU = { slot = CFrame.new(0.2, 0.5, 0.6), tray = CFrame.new(2.6, 0.5, 2.2), camera = CAM, snap = 1.6, size = 1.8 },
	Monitor = { slot = CFrame.new(3.0, 1.2, 0.0), tray = CFrame.new(0.0, 0.5, 2.6), camera = CAM, snap = 1.8, size = 2.4 },
	RGB = { slot = CFrame.new(0.0, 1.4, 0.0), tray = CFrame.new(0.0, 0.5, 3.0), camera = CAM, snap = 2.0, size = 3.0 },
}

function PCInstall.isWithinSnap(dropPos, slotPos, radius)
	return (dropPos - slotPos).Magnitude <= radius
end

function PCInstall.worldSlot(partId)
	return PCInstall.BenchCFrame * PCInstall.Layout[partId].slot
end

function PCInstall.worldTray(partId)
	return PCInstall.BenchCFrame * PCInstall.Layout[partId].tray
end

function PCInstall.worldCamera(partId)
	return PCInstall.BenchCFrame * PCInstall.Layout[partId].camera
end

return PCInstall
```

- [ ] **Step 4: Run tests to verify they pass**

Run in Studio (Server): `require(game.ReplicatedStorage.Shared.Tests.RunTests)`
Expected: the four new lines PASS, `0 failed`.

- [ ] **Step 5: Commit**

```bash
git add src/shared/PCInstall.luau src/shared/Tests/RunTests.luau
git commit -m "feat(pc): shared install-bench layout + snap helper (tested)"
```

---

## Task 3: PCService pure decision logic (reserve + apply)

**Files:**
- Modify: `src/server/PCService.luau` (add pure functions on the `PCService` table, above `PCService.start`)
- Test: `src/shared/Tests/RunTests.luau` (append assertions)

**Interfaces:**
- Consumes: `GameData.getPCPart`, `GameData.getPCPartMaxLevel`, `GameData.getPCPartUpgradeCost`.
- Produces:
  - `PCService.reserveDecision(data, partId, deal) : (ok: boolean, cost: number?, targetLevel: number?)` — pure, no mutation. `deal` is `nil` or `{ partId, discount }`.
  - `PCService.applyInstall(data, pending) : boolean` — re-validates and, on success, mutates `data` (`cash -= pending.cost`, `pcParts[partId] = pending.targetLevel`). `pending` is `{ partId, cost, targetLevel }`.

- [ ] **Step 1: Write the failing tests**

Append to `src/shared/Tests/RunTests.luau` (before `t:summary()`):

```lua
-- PC install minigame: server reserve/apply rules (pure)
local PCService = require(game:GetService("ServerScriptService").Server.PCService)
local cpuCost0 = GameData.getPCPartUpgradeCost("CPU", 0)

local rich = { cash = 1e9, pcParts = {} }
local ok, cost, target = PCService.reserveDecision(rich, "CPU", nil)
t:assertEqual(ok, true, "reserve: rich player can buy CPU")
t:assertEqual(cost, cpuCost0, "reserve: cost is the level-0 upgrade cost")
t:assertEqual(target, 1, "reserve: target level is 1")

local broke = { cash = 0, pcParts = {} }
t:assertEqual((PCService.reserveDecision(broke, "CPU", nil)), false, "reserve: no cash -> false")
t:assertEqual((PCService.reserveDecision(rich, "NotAPart", nil)), false, "reserve: unknown part -> false")

local maxed = { cash = 1e9, pcParts = { CPU = GameData.getPCPartMaxLevel("CPU") } }
t:assertEqual((PCService.reserveDecision(maxed, "CPU", nil)), false, "reserve: maxed part -> false")

local dealed = { cash = 1e9, pcParts = {} }
local _, dcost = PCService.reserveDecision(dealed, "CPU", { partId = "CPU", discount = 0.5 })
t:assertEqual(dcost, math.floor(cpuCost0 * 0.5), "reserve: matching deal halves the cost")

local applyData = { cash = 1e9, pcParts = {} }
local applied = PCService.applyInstall(applyData, { partId = "CPU", cost = cpuCost0, targetLevel = 1 })
t:assertEqual(applied, true, "apply: valid install succeeds")
t:assertEqual(applyData.cash, 1e9 - cpuCost0, "apply: exact cost deducted")
t:assertEqual(applyData.pcParts.CPU, 1, "apply: level set to target")

local staleLevel = { cash = 1e9, pcParts = { CPU = 3 } }
t:assertEqual(PCService.applyInstall(staleLevel, { partId = "CPU", cost = cpuCost0, targetLevel = 1 }), false, "apply: level no longer matches -> false")
t:assertEqual(staleLevel.cash, 1e9, "apply: rejected install does not charge")

local poor = { cash = 1, pcParts = {} }
t:assertEqual(PCService.applyInstall(poor, { partId = "CPU", cost = cpuCost0, targetLevel = 1 }), false, "apply: not enough cash at apply time -> false")
t:assertEqual(poor.pcParts.CPU, nil, "apply: rejected install does not upgrade")
```

- [ ] **Step 2: Run tests to verify they fail**

Run in Studio (Server): `require(game.ReplicatedStorage.Shared.Tests.RunTests)`
Expected: FAIL — `reserveDecision`/`applyInstall` are `nil`.

- [ ] **Step 3: Add the pure functions**

In `src/server/PCService.luau`, add these ABOVE `function PCService.start()`:

```lua
-- Pure buy check. Returns (ok, cost, targetLevel) without mutating `data`.
-- `deal` is nil or { partId = <id>, discount = <fraction> }.
function PCService.reserveDecision(data, partId, deal)
	local part = GameData.getPCPart(partId)
	if not part then
		return false
	end
	local level = (data.pcParts and data.pcParts[partId]) or 0
	if level >= GameData.getPCPartMaxLevel(partId) then
		return false
	end
	local cost = GameData.getPCPartUpgradeCost(partId, level)
	if not cost then
		return false
	end
	if deal and deal.partId == partId then
		cost = math.floor(cost * (1 - deal.discount))
	end
	if (data.cash or 0) < cost then
		return false
	end
	return true, cost, level + 1
end

-- Re-validate a reserved install and, on success, apply it (mutates `data`).
-- `pending` is { partId, cost, targetLevel }. Returns true if applied.
function PCService.applyInstall(data, pending)
	data.pcParts = data.pcParts or {}
	local level = data.pcParts[pending.partId] or 0
	if level ~= pending.targetLevel - 1 then
		return false
	end
	if (data.cash or 0) < pending.cost then
		return false
	end
	data.cash -= pending.cost
	data.pcParts[pending.partId] = pending.targetLevel
	return true
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run in Studio (Server): `require(game.ReplicatedStorage.Shared.Tests.RunTests)`
Expected: all new lines PASS, `0 failed`.

- [ ] **Step 5: Commit**

```bash
git add src/server/PCService.luau src/shared/Tests/RunTests.luau
git commit -m "feat(pc): pure reserve/apply install rules (tested)"
```

---

## Task 4: Wire PCService to reserve-on-buy and apply-on-install

**Files:**
- Modify: `src/server/PCService.luau` (`RequestUpgradePart` handler; add `PCInstallComplete`/`PCInstallCancel` handlers + `pendingInstall` + `PlayerRemoving` cleanup; add requires)

**Interfaces:**
- Consumes: `PCService.reserveDecision`, `PCService.applyInstall` (Task 3); `Remotes.PCInstallStart/Complete/Cancel` (Task 1); `PCVisuals.getVisualTier` (from `src/shared/PCVisuals.luau`).
- Produces: buy now reserves + launches install; upgrade applies only on `PCInstallComplete`.

- [ ] **Step 1: Add requires + pending table**

At the top of `src/server/PCService.luau`, after the existing `local PlayerData = ...` line, add:

```lua
local PCVisuals = require(game.ReplicatedStorage.Shared.PCVisuals)
local Players = game:GetService("Players")
```

Below the `currentDeal` / `DEAL_*` locals, add:

```lua
-- Reserved-but-not-yet-installed upgrades, keyed by Player:
-- { partId = <id>, cost = <number>, targetLevel = <number> }. In-memory only.
local pendingInstall = {}
```

- [ ] **Step 2: Replace the body of the `RequestUpgradePart` handler**

Replace the entire `Remotes.RequestUpgradePart.OnServerEvent:Connect(function(player, partId) ... end)` block with:

```lua
	-- Buy the next model of a part: validate + RESERVE it (no charge yet), then
	-- launch the install minigame. The upgrade is applied on PCInstallComplete.
	Remotes.RequestUpgradePart.OnServerEvent:Connect(function(player, partId)
		local data = PlayerData.get(player)
		if not data then
			return
		end
		data.pcParts = data.pcParts or {}
		if pendingInstall[player] then
			-- an install is already in flight; ignore
			Remotes.PCActionResult:FireClient(player, false)
			return
		end
		local deal = currentDeal[player.UserId]
		local ok, cost, targetLevel = PCService.reserveDecision(data, partId, deal)
		if not ok then
			Remotes.PCActionResult:FireClient(player, false)
			return
		end
		pendingInstall[player] = { partId = partId, cost = cost, targetLevel = targetLevel }
		local currentLevel = targetLevel - 1
		local oldTier = currentLevel > 0 and PCVisuals.getVisualTier(currentLevel) or nil
		local newTier = PCVisuals.getVisualTier(targetLevel)
		Remotes.PCInstallStart:FireClient(player, partId, oldTier, newTier)
	end)
```

- [ ] **Step 3: Add the complete/cancel handlers + cleanup at the end of `PCService.start`**

Immediately before the closing `end` of `function PCService.start()`, add:

```lua
	-- Correct install reported by the client: re-validate and apply.
	Remotes.PCInstallComplete.OnServerEvent:Connect(function(player, partId)
		local data = PlayerData.get(player)
		local pending = pendingInstall[player]
		if not data or not pending or pending.partId ~= partId then
			pendingInstall[player] = nil
			Remotes.PCActionResult:FireClient(player, false)
			return
		end
		local applied = PCService.applyInstall(data, pending)
		pendingInstall[player] = nil
		if not applied then
			Remotes.PCActionResult:FireClient(player, false)
			return
		end
		local RIG_VISUAL_PARTS = { Monitor = true, GPU = true, RGB = true, Cooling = true }
		if RIG_VISUAL_PARTS[partId] then
			local HomeService = require(script.Parent.HomeService)
			HomeService.rebuildHome(player)
		end
		Remotes.PCActionResult:FireClient(player, true)
		Remotes.PlayerStateUpdated:FireClient(player, data)
	end)

	-- Player cancelled or backed out: drop the reservation, nothing charged.
	Remotes.PCInstallCancel.OnServerEvent:Connect(function(player)
		pendingInstall[player] = nil
	end)

	Players.PlayerRemoving:Connect(function(player)
		pendingInstall[player] = nil
		currentDeal[player.UserId] = nil
	end)
```

- [ ] **Step 4: Compile check**

Run: `./rojo-bin/rojo build default.project.json -o /tmp/pcinstall.rbxl`
Expected: `Built project` with no errors.

- [ ] **Step 5: Re-run the unit suite (guards against regressions)**

Run in Studio (Server): `require(game.ReplicatedStorage.Shared.Tests.RunTests)`
Expected: `0 failed`.

- [ ] **Step 6: Commit**

```bash
git add src/server/PCService.luau
git commit -m "feat(pc): reserve-on-buy + apply-on-install wiring"
```

---

## Task 5: Assembly Bench landmark in the PC Store

**Files:**
- Modify: `src/server/Lobby.luau` (add a `buildAssemblyBench` helper and call it where the PC Store is built)

**Interfaces:**
- Consumes: `PCInstall.BenchCFrame` (Task 2) so the visible prop matches where the client builds the interactive rig.
- Produces: a static, anchored, non-interactive `PCAssemblyBench` model in `Workspace.Lobby`.

- [ ] **Step 1: Require PCInstall in Lobby**

Near the other `require` lines at the top of `src/server/Lobby.luau`, add (if not already present):

```lua
local PCInstall = require(game.ReplicatedStorage.Shared.PCInstall)
```

- [ ] **Step 2: Add the bench builder**

Add this helper above the function that builds the PC Store (search for `buildPCWarehouse` / `buildPCStation`; place it just above whichever is called to build the store):

```lua
-- A plain, static workbench that marks where installs happen. The interactive
-- rig (open tower + slots) is built locally on the client during a round; this
-- is just the always-there landmark, seated at PCInstall.BenchCFrame.
local function buildAssemblyBench(parent)
	local model = Instance.new("Model")
	model.Name = "PCAssemblyBench"
	local origin = PCInstall.BenchCFrame

	local top = Instance.new("Part")
	top.Name = "BenchTop"
	top.Anchored = true
	top.Size = Vector3.new(8, 0.4, 4)
	top.CFrame = origin * CFrame.new(0, -0.2, 0)
	top.Color = Color3.fromRGB(120, 90, 60)
	top.Material = Enum.Material.Wood
	top.Parent = model

	for _, x in ipairs({ -3.6, 3.6 }) do
		for _, z in ipairs({ -1.6, 1.6 }) do
			local leg = Instance.new("Part")
			leg.Name = "BenchLeg"
			leg.Anchored = true
			leg.Size = Vector3.new(0.4, 4.2, 0.4)
			leg.CFrame = origin * CFrame.new(x, -2.5, z)
			leg.Color = Color3.fromRGB(70, 70, 78)
			leg.Material = Enum.Material.Metal
			leg.Parent = model
		end
	end

	local mat = Instance.new("Part")
	mat.Name = "BenchMat"
	mat.Anchored = true
	mat.Size = Vector3.new(5, 0.06, 3)
	mat.CFrame = origin * CFrame.new(0, 0.03, 0)
	mat.Color = Color3.fromRGB(30, 32, 40)
	mat.Material = Enum.Material.SmoothPlastic
	mat.Parent = model

	model.Parent = parent
	return model
end
```

- [ ] **Step 3: Call it when building the store**

Find where the PC Store is assembled (the call to the PC warehouse/station builder that receives the `lobbyFolder`). Immediately after that call, add:

```lua
	buildAssemblyBench(lobbyFolder)
```

(Use the same folder variable name used for the other PC-store props in that scope; it is the `Workspace.Lobby` folder.)

- [ ] **Step 4: Compile check**

Run: `./rojo-bin/rojo build default.project.json -o /tmp/pcinstall.rbxl`
Expected: `Built project`.

- [ ] **Step 5: Manual visual check**

Start Play in Studio; confirm a wooden bench with a dark mat exists in the PC Store around `PCInstall.BenchCFrame` and does not clip through a counter or wall. If it overlaps, nudge `PCInstall.BenchCFrame` in `src/shared/PCInstall.luau` and re-check.

- [ ] **Step 6: Commit**

```bash
git add src/server/Lobby.luau src/shared/PCInstall.luau
git commit -m "feat(pc): static Assembly Bench landmark in the PC Store"
```

---

## Task 6: The 3D drag-and-snap minigame (client)

**Files:**
- Create: `src/client/PCInstallGame.luau`

**Interfaces:**
- Consumes: `PCInstall` (Task 2), `PCVisuals` (`buildTierDisplay`, `PAINT`, `TIERED`, `DISPLAY`), `Remotes.PCInstallComplete/Cancel`.
- Produces: `PCInstallGame.run(partId: string, oldTier: number?, newTier: number)` — builds the rig, runs the round, fires `PCInstallComplete` on success or `PCInstallCancel` on back-out, tears everything down. Exposes `PCInstallGame.isActive() : boolean`.

- [ ] **Step 1: Create `src/client/PCInstallGame.luau`**

```lua
-- Local 3D "install the part" minigame. Not replicated: everything is built on
-- the client, framed with a scriptable camera, and torn down when the round
-- ends. Drag the old part out (if any), then drag the new part into its glowing
-- slot; drop within the snap radius and it eases home. Cannot fail.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local PCInstall = require(game.ReplicatedStorage.Shared.PCInstall)
local PCVisuals = require(game.ReplicatedStorage.Shared.PCVisuals)

local PCInstallGame = {}
local active = false

function PCInstallGame.isActive()
	return active
end

local function highlight(model, color)
	local h = Instance.new("Highlight")
	h.FillColor = color
	h.OutlineColor = color
	h.FillTransparency = 0.6
	h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	h.Parent = model
	return h
end

-- A glowing target marker at a world CFrame.
local function makeSlotMarker(cf, size, parent)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.Transparency = 0.5
	p.Size = Vector3.new(size, 0.1, size)
	p.CFrame = cf
	p.Color = Color3.fromRGB(90, 220, 255)
	p.Material = Enum.Material.SmoothPlastic
	p.Parent = parent
	return p
end

-- Build a tier model, anchored non-colliding, pivoted to a world CFrame.
local function buildPart(partId, tier, worldCF)
	local asset = PCVisuals.TIERED[partId]
	local size = (PCInstall.Layout[partId] and PCInstall.Layout[partId].size) or 2.0
	local byWidth = PCVisuals.DISPLAY[partId] and PCVisuals.DISPLAY[partId].byWidth
	local model = PCVisuals.buildTierDisplay(asset, tier, worldCF.Position, size, 0, PCVisuals.PAINT[partId], byWidth)
	if model then
		model:PivotTo(worldCF)
	end
	return model
end

-- Drag `model` on a horizontal plane at height planeY until the mouse/touch is
-- released, then return the drop position. Yields.
local function dragUntilRelease(model, planeY, camera)
	local dropPos
	local released = false

	local function screenToPlane(x, y)
		local ray = camera:ViewportPointToRay(x, y)
		local dy = ray.Direction.Y
		if math.abs(dy) < 1e-4 then
			return model:GetPivot().Position
		end
		local tparam = (planeY - ray.Origin.Y) / dy
		return ray.Origin + ray.Direction * tparam
	end

	local moveConn = UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch then
			local pos = screenToPlane(input.Position.X, input.Position.Y)
			model:PivotTo(CFrame.new(pos.X, planeY, pos.Z))
			dropPos = pos
		end
	end)
	local upConn = UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dropPos = screenToPlane(input.Position.X, input.Position.Y)
			released = true
		end
	end)

	while not released do
		RunService.Heartbeat:Wait()
	end
	moveConn:Disconnect()
	upConn:Disconnect()
	return dropPos or model:GetPivot().Position
end

-- Ease a model to a target CFrame over a few frames.
local function easeTo(model, cf)
	local start = model:GetPivot()
	local steps = 12
	for i = 1, steps do
		model:PivotTo(start:Lerp(cf, i / steps))
		RunService.Heartbeat:Wait()
	end
end

-- Run a single-part round. Returns true if installed.
local function runRound(scene, camera, partId, oldTier, newTier)
	local slotWorld = PCInstall.worldSlot(partId)
	local trayWorld = PCInstall.worldTray(partId)
	local snap = PCInstall.Layout[partId].snap
	local planeY = slotWorld.Position.Y

	local marker = makeSlotMarker(slotWorld, snap * 1.4, scene)

	-- 1. Remove the old part, if any.
	if oldTier then
		local oldModel = buildPart(partId, oldTier, slotWorld)
		if oldModel then
			oldModel.Parent = scene
			highlight(oldModel, Color3.fromRGB(255, 170, 60))
			dragUntilRelease(oldModel, planeY, camera)
			for _, d in ipairs(oldModel:GetDescendants()) do
				if d:IsA("BasePart") then
					d.Transparency = 0.5
				end
			end
			task.wait(0.15)
			oldModel:Destroy()
		end
	end

	-- 2. Insert the new part: drag from the tray until it snaps into the slot.
	local newModel = buildPart(partId, newTier, trayWorld)
	if not newModel then
		return true -- nothing to build (defensive); treat as done
	end
	newModel.Parent = scene
	highlight(newModel, Color3.fromRGB(90, 220, 255))

	while true do
		local drop = dragUntilRelease(newModel, planeY, camera)
		if PCInstall.isWithinSnap(drop, slotWorld.Position, snap) then
			easeTo(newModel, slotWorld)
			marker.Transparency = 1
			task.wait(0.3)
			return true
		else
			easeTo(newModel, trayWorld) -- eases back, try again
		end
	end
end

function PCInstallGame.run(partId, oldTier, newTier)
	if active then
		return
	end
	if not PCInstall.Layout[partId] then
		Remotes.PCInstallCancel:FireServer(partId)
		return
	end
	active = true

	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local camera = workspace.CurrentCamera

	-- hide HUD
	local hidden = {}
	for _, g in ipairs(playerGui:GetChildren()) do
		if g:IsA("ScreenGui") and g.Enabled then
			g.Enabled = false
			hidden[#hidden + 1] = g
		end
	end
	local prevCamType = camera.CameraType
	local prevCamCF = camera.CFrame
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = PCInstall.worldCamera(partId)

	local scene = Instance.new("Folder")
	scene.Name = "PCInstallScene"
	scene.Parent = workspace

	-- Cancel button
	local ui = Instance.new("ScreenGui")
	ui.Name = "PCInstallUI"
	ui.ResetOnSpawn = false
	ui.Parent = playerGui
	local cancelBtn = Instance.new("TextButton")
	cancelBtn.Size = UDim2.fromOffset(120, 44)
	cancelBtn.Position = UDim2.new(0, 20, 1, -64)
	cancelBtn.Text = "Cancel"
	cancelBtn.TextScaled = true
	cancelBtn.BackgroundColor3 = Color3.fromRGB(60, 62, 72)
	cancelBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	cancelBtn.Parent = ui
	local cancelled = false
	cancelBtn.Activated:Connect(function()
		cancelled = true
	end)

	local function cleanup()
		scene:Destroy()
		ui:Destroy()
		camera.CameraType = prevCamType
		camera.CFrame = prevCamCF
		for _, g in ipairs(hidden) do
			g.Enabled = true
		end
		active = false
	end

	task.spawn(function()
		local done = runRound(scene, camera, partId, oldTier, newTier)
		cleanup()
		if cancelled or not done then
			Remotes.PCInstallCancel:FireServer(partId)
		else
			Remotes.PCInstallComplete:FireServer(partId)
		end
	end)
end

return PCInstallGame
```

- [ ] **Step 2: Compile check**

Run: `./rojo-bin/rojo build default.project.json -o /tmp/pcinstall.rbxl`
Expected: `Built project`.

- [ ] **Step 3: Commit**

```bash
git add src/client/PCInstallGame.luau
git commit -m "feat(pc): 3D drag-and-snap install minigame (client)"
```

---

## Task 7: Launch the minigame from the client + end-to-end playtest

**Files:**
- Modify: `src/client/init.client.luau` (connect `PCInstallStart`)

**Interfaces:**
- Consumes: `PCInstallGame.run` (Task 6), `Remotes.PCInstallStart` (Task 1).

- [ ] **Step 1: Require the minigame + connect the launch remote**

In `src/client/init.client.luau`, add near the other client requires:

```lua
local PCInstallGame = require(script.PCInstallGame)
```

(Adjust the path to however sibling client modules are required in this file — match an existing `require(script.<Module>)` line.)

Then, near where other `Remotes.*.OnClientEvent:Connect` handlers are set up, add:

```lua
Remotes.PCInstallStart.OnClientEvent:Connect(function(partId, oldTier, newTier)
	if PCInstallGame.isActive() then
		return
	end
	PCInstallGame.run(partId, oldTier, newTier)
end)
```

(If `Remotes` is not already required in this file, add `local Remotes = require(game.ReplicatedStorage.Shared.Remotes)` with the other requires.)

- [ ] **Step 2: Compile check**

Run: `./rojo-bin/rojo build default.project.json -o /tmp/pcinstall.rbxl`
Expected: `Built project`.

- [ ] **Step 3: End-to-end playtest in Studio (via Studio MCP)**

Start Play. Give the test player cash (inject a Script that sets `PlayerData.get(plr).cash = 999999` and fires `PlayerStateUpdated`, as in prior sessions). Then, for at least CPU (internal), Monitor (external), and RGB (case):

1. Open the PC Store, buy the part.
2. Expect: HUD hides, camera frames the bench, the part's slot glows.
3. If a previous tier existed, drag the old part off; then drag the new part — dropping near the slot snaps it home.
4. Expect on completion: `PCActionResult(true)`, cash reduced by the shown price exactly once, `pcParts[partId]` +1, camera + HUD restored, and the installed tier matches the desk rig / shop shelf.
5. Buy again and press **Cancel** mid-install. Expect: no charge, no level change, camera + HUD restored.
6. Buy at level 0 (first buy of a part). Expect: no old part to remove — a single insert drag.

Fix any slot/tray/camera positions by editing `PCInstall.Layout` / `PCInstall.BenchCFrame` and re-testing (visual tuning only; logic unchanged).

- [ ] **Step 4: Re-run the unit suite**

Run in Studio (Server): `require(game.ReplicatedStorage.Shared.Tests.RunTests)`
Expected: `0 failed`.

- [ ] **Step 5: Commit**

```bash
git add src/client/init.client.luau src/shared/PCInstall.luau
git commit -m "feat(pc): launch install minigame on buy + wire end-to-end"
```

---

## Self-Review Notes

- **Spec coverage:** reserve/apply anti-cheat (Tasks 3-4); shared layout + snap (Task 2); remotes (Task 1); bench landmark (Task 5); 3D drag-snap with old-out/new-in, non-failable, real `PCVisuals` models, scriptable camera, HUD hide/restore, cancel (Task 6); launch + single-instance guard + all-7 + level-0 path (Tasks 6-7); unit + manual testing throughout. All covered.
- **Type consistency:** `reserveDecision(data, partId, deal) -> (ok, cost, targetLevel)` and `applyInstall(data, {partId,cost,targetLevel}) -> bool` are used identically in Task 4. `pendingInstall` entry shape matches `applyInstall`'s `pending`. `PCInstall.Layout[partId]` fields (`slot/tray/camera/snap/size`) are used consistently in Tasks 5-6. `PCInstallGame.run(partId, oldTier, newTier)` / `isActive()` match Task 7's caller.
- **Note for implementer:** `PCInstall.BenchCFrame` and every `Layout` offset are first-guess positions; Task 5 Step 5 and Task 7 Step 3 explicitly tune them in-game. This is visual tuning, not a logic placeholder.
