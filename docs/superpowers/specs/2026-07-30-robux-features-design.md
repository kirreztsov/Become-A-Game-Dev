# M8 — More Robux Revenue Features Design Spec

**Goal:** Add three fair-advantage Robux items — a **VIP+ pass** unlocking an **earning lounge** (a zone that pays steady, safely-capped passive cash), a **2× walk-speed pass**, and three **individual cosmetic studio-skin passes** with a picker.

**Architecture:** New passes are added to `GameData.GamePasses` (all `id = 0`, "coming soon", until real IDs exist) and flow through the existing `MonetizationService` receipt/ownership pipeline unchanged. A small new server `LoungeService` owns a lounge zone and credits VIP+ owners inside it each second (server-authoritative, reusing the idle-income cash-credit + `PlayerStateUpdated` push pattern). The 2× speed pass applies on spawn beside the existing VIP hook. Skins recolor the player's studio exterior parts via a new `PlotManager.applySkin`; the active skin persists per player and is chosen from a picker in the Store.

**Tech Stack:** Roblox / Luau, Rojo, existing `MonetizationService` / `MarketplaceService.ProcessReceipt`, `GameData.getStudioLevel`, `RunTests` unit tests.

## Global Constraints

- **Fair-advantage, not pay-to-win** (project rule): paid items let payers progress faster or look different, never gate content. The lounge pays *less than active play*; skins are purely cosmetic.
- **IDs later:** every new pass starts `id = 0` and shows as "coming soon" / unavailable to buy until the real Roblox game-pass IDs are created and filled in — identical to the existing passes. Nothing may error with `id = 0`.
- **Lounge is server-authoritative and cannot be AFK-broken:** the server decides who is in the zone and pays only real VIP+ owners; the payout is a **flat rate (never a % of the player's cash)**, capped, and tuned below active earning, so it adds up linearly like a salary and never snowballs.
- **Skins are cosmetic only** — no stat/gameplay effect; they only recolor the studio exterior. The **Neon** skin uses Neon material **only as accent trim** (project's Neon-accent-only rule), never whole walls.
- **Don't disturb existing monetization:** there is exactly one `MarketplaceService.ProcessReceipt` (in `MonetizationService`); new items extend the existing generic pass/ownership handling, not a parallel system.
- **Mobile:** new Store cards + the skin picker follow existing `StorePanel` layout and scale via `MobileScale`; tap targets ≥ 44px.
- `GameData.StartingCash` stays `0`.

## Feature 1 — VIP+ pass + earning lounge

**Pass:** `GameData.GamePasses.VIPPlus = { id = 0, order = 5, icon = "💎", name = "VIP+", desc = "Unlocks the VIP+ Lounge — earn passive cash while you relax.", ... }`. Owning it is the only gate for lounge earnings. (VIP+ grants no cash multiplier itself; its value is the lounge.)

**The zone:** `Lobby.luau` builds a **VIP+ Lounge** area in the plaza — a small furnished spot (rug, a couple lounge chairs/sofa, a "💎 VIP+ Only" sign) with an invisible **zone Part** (`LoungeZone`, `CanCollide=false`, `Transparency=1`) marking the earning region. Anyone can walk in; only VIP+ owners earn.

**Earning model (`LoungeService.luau`, new server module):**
- A 1-second loop (`task.wait(1)` or a Heartbeat accumulator). Each tick, for every player whose `HumanoidRootPart` is inside `LoungeZone`'s box:
  - If `data.passes.VIPPlus` → `data.cash += GameData.getLoungeRate(data)` then `Remotes.PlayerStateUpdated:FireClient(player, data)` (same credit+push as idle income).
  - If not a VIP+ owner → pay nothing (the client shows a "Get VIP+" prompt; see below).
- **Rate:** `GameData.getLoungeRate(data) = math.min(GameData.LoungeRateCap, GameData.LoungeRatePerLevel * GameData.getStudioLevel(data))`, in cash/second. Starting values: `LoungeRatePerLevel = 8`, `LoungeRateCap = 400`. So a new studio earns ~8/sec, scaling to a 400/sec cap — flat, linear, capped. The flat rate is credited **as-is** (cash multipliers like 2x Cash do **not** stack onto it, keeping it predictable and bounded). Tune the two constants in playtest so lounge income stays clearly below actively developing games.
- **Zone check:** box test against `LoungeZone` (position ± size/2) — server-side, so it can't be spoofed. A player who leaves stops earning.

**"Get VIP+" prompt:** client-side, when the local player (who does **not** own VIP+) enters the lounge zone, show a small banner/prompt inviting them to open the Store and buy VIP+. Owning it removes the prompt.

## Feature 2 — 2× Speed pass

**Pass:** `GameData.GamePasses.Speed2x = { id = 0, order = 6, icon = "🏃", name = "2x Speed", desc = "Move twice as fast around the world.", walkSpeed = 32 }`.

**Applied on spawn:** in `MonetizationService`'s per-player / `CharacterAdded` flow (the same place VIP cosmetic is applied), if `data.passes.Speed2x` then set the character's `Humanoid.WalkSpeed = GameData.GamePasses.Speed2x.walkSpeed` (32; default is 16). Re-applied on every respawn. Independent of Faster Workers (that pass affects worker build speed, not the player).

## Feature 3 — Studio skins

**Passes (one per skin):** `SkinGold`, `SkinNeon`, `SkinMidnight` in `GameData.GamePasses` (all `id = 0`), e.g. `SkinGold = { id = 0, order = 7, icon = "🎨", name = "Gold Studio", desc = "A shiny gold look for your studio.", skin = "Gold" }`. Owning a skin pass unlocks selecting it.

**Skin definitions:** `GameData.StudioSkins` maps a skin key to the exterior colours/materials:
```lua
GameData.StudioSkins = {
    Default  = nil, -- keep the studio's normal look
    Gold     = { wall = Color3.fromRGB(214,164,58), wallMat = Enum.Material.Metal,
                 trim = Color3.fromRGB(244,212,120) },
    Neon     = { wall = Color3.fromRGB(30,28,46), wallMat = Enum.Material.SmoothPlastic,
                 accent = Color3.fromRGB(120,90,235), accentMat = Enum.Material.Neon }, -- Neon only on accent trim
    Midnight = { wall = Color3.fromRGB(24,26,42), wallMat = Enum.Material.SmoothPlastic,
                 trim = Color3.fromRGB(120,130,160) },
}
```

**Persist + apply:**
- `PlayerData`: add `activeSkin = "Default"` (+ migration backfill).
- `PlotManager.applySkin(player, skinKey)` — finds the player's plot folder and recolours exterior parts whose name contains `"Wall"` or `"Roof"` to the skin's `wall`/`wallMat`; accent/trim-named parts (e.g. `RoofRailCap`, `Roof`) to `trim`/`accent`. `"Default"` re-applies the studio's normal colours (rebuild the shell, or restore stored defaults). Cosmetic only — never touches functional parts (seats, monitors, prompts).
- Called (a) when a plot's studio is built (apply `data.activeSkin`), and (b) on skin change.
- **Change flow:** new remote `RequestSetSkin` (client → server, `skinKey`). Server validates the player owns that skin pass (or it's `"Default"`), sets `data.activeSkin`, calls `applySkin`, pushes `PlayerStateUpdated`.

**Picker (client):** a small **Skins** section in `StorePanel` — a button per skin. Owned skins select (fire `RequestSetSkin`); unowned skins prompt the purchase. The active one is highlighted. `Default` is always available/free.

## Data & files

```
src/shared/GameData.luau     -- + VIPPlus/Speed2x/SkinGold/SkinNeon/SkinMidnight passes;
                                getLoungeRate + LoungeRatePerLevel/LoungeRateCap; StudioSkins
src/shared/Tests/RunTests.luau -- + getLoungeRate tests (scales, caps, >= 0)
src/shared/Remotes.luau      -- + "RequestSetSkin"
src/server/PlayerData.luau   -- + activeSkin default + migration
src/server/LoungeService.luau -- CREATE: zone earning loop (VIP+ only)
src/server/MonetizationService.luau -- + apply Speed2x on spawn
src/server/PlotManager.luau  -- + applySkin(player, skinKey); apply activeSkin on build
src/server/init.server.luau  -- start LoungeService; handle RequestSetSkin (or route to PlotManager)
src/server/Lobby.luau        -- build the VIP+ Lounge area + LoungeZone part
src/client/StorePanel.luau   -- new pass cards + Skins picker
src/client/<lounge prompt>   -- "Get VIP+" prompt when a non-owner enters the zone
                                (in UI.luau or a small client module)
```

## Data flow

```
Buy VIP+  → ProcessReceipt/ownership (existing) → data.passes.VIPPlus = true
Stand in lounge → LoungeService (1s loop): in-zone AND VIPPlus? → data.cash += getLoungeRate(data) → PlayerStateUpdated
Buy 2x Speed → data.passes.Speed2x → on spawn Humanoid.WalkSpeed = 32
Buy a skin → data.passes.SkinX = true → picker → RequestSetSkin → validate owned → data.activeSkin → PlotManager.applySkin → PlayerStateUpdated
```

## Testing

- **Unit (`RunTests.luau`):** `getLoungeRate` — level 1 gives `LoungeRatePerLevel`; a high level clamps to `LoungeRateCap`; result is a non-negative number; never depends on `data.cash` (no compounding).
- **Studio playtest:** stand in the lounge with/without VIP+ (temporarily flip `data.passes.VIPPlus` server-side to test) → cash ticks only when owned and only while inside; leaving stops it; rate is clearly below a game-dev payout. 2× speed doubles movement on spawn. Skin picker recolours the studio exterior (and only the exterior), persists the choice, and `Default` restores the normal look. No errors with all IDs `0`.
- Compile check after each change: `./rojo-bin/rojo build default.project.json -o /tmp/x.rbxl`.

## Non-goals (YAGNI)

- No physical wall/teleport gating the lounge — earning is gated by ownership, not a barrier.
- Lounge income does not stack the cash multipliers (kept flat/predictable).
- No skin previews-before-buy, no per-part custom colours — three fixed skins + Default only.
- VIP+ adds no cash multiplier or cosmetic beyond lounge access (keeps it distinct from VIP).
