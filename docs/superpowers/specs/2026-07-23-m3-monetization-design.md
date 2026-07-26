# M3 — Monetization (Fair Advantage) — Design Spec

**Milestone:** M3 of the v1.0 launch roadmap (`docs/superpowers/plans/2026-07-23-v1-launch-roadmap.md`).

**Goal:** Add fair-advantage monetization — 4 game passes and 2 dev products — all server-validated, clearly presented, and balanced so paying gives a real edge but F2P stays fully viable.

**Monetization stance:** Between standard and heavy. Paying players progress faster / flex; free players reach everything, just slower.

---

## Success criteria (Done when…)
- All 4 passes and both products work end-to-end (prompt → grant → effect), server-validated.
- A **💎 Store** HUD button opens a panel listing every pass (with **Owned ✓** state) and product with clear effects.
- Effects apply everywhere they should (game releases, idle rooms, subs, worker speed) and stack in a bounded way.
- F2P remains viable; nothing is purchase-gated.
- `rojo build` clean; verified in Studio by **simulating ownership** (real Robux purchases can't be tested in Studio).

---

## The lineup

### Game passes (permanent; `MarketplaceService` game-pass API)
| Key | Name | Effect | Value |
|---|---|---|---|
| `Cash2x` | 2× Cash | Multiplies ALL earned cash | ×2 |
| `VIP` | VIP | +25% cash + gold cosmetic + "VIP" nametag | ×1.25 cash |
| `FasterWorkers` | Faster Workers | Worker phase speed multiplier (stacks on rarity speed) | ×1.5 |
| `Subs2x` | 2× Subscribers | Doubles subscribers gained per release | ×2 |

`Cash2x` and `VIP` **stack multiplicatively** on cash (both owned = ×2.5), on top of the existing PC / floor / boost / subscriber / prestige multipliers. This is the intended ceiling — bounded and F2P-reachable.

### Dev products (`MarketplaceService` developer-product API + `ProcessReceipt`)
| Key | Name | Effect | One-time? |
|---|---|---|---|
| `StarterPack` | Starter Pack | Grant $500 cash + a 2× cash boost for 10 min + a guaranteed **Rare** worker | Yes (hidden once bought) |
| `MegaBoost` | Mega Boost | 3× cash boost for 15 min (stacks with the boost timer) | No (repeatable) |

Existing **Lucky Crate** products (x1/x5/x10 spin bundles) stay exactly as they are — their grant logic just moves under the centralized receipt handler.

---

## Architecture

`MarketplaceService.ProcessReceipt` is a **single global callback** — today `WorkerCaseService` owns it. M3 centralizes it so nothing competes for it.

### New files
- **`src/server/MonetizationService.luau`** — owns:
  - The single `MarketplaceService.ProcessReceipt`, dispatching by `receiptInfo.ProductId`:
    - matches `GameData.LuckyCaseProducts[id]` → `WorkerCaseService.grantLuckySpins(data, n)`
    - matches `GameData.Products.StarterPack.id` → grant the Starter Pack bundle (once; sets `data.starterPackBought`)
    - matches `GameData.Products.MegaBoost.id` → `GameData.applyBoost(data, 3, 900, "💎", "Mega Boost", now)`
    - else → `Enum.ProductPurchaseDecision.NotProcessedYet`
  - Game-pass ownership: on join, for each pass with a real id (`> 0`), `pcall(UserOwnsGamePassAsync)` → set `data.passes[key] = true`; apply VIP cosmetic/tag if owned.
  - `MarketplaceService.PromptGamePassPurchaseFinished` (server): on `wasPurchased`, resolve the pass key from the id, set `data.passes[key] = true`, apply effects (VIP cosmetic), `PlayerStateUpdated:FireClient`.
  - `MonetizationService.start()`.
- **`src/client/StorePanel.luau`** — the **💎 Store** HUD button (top-left corner, where the old Goals checklist was) + a Store panel (own `ScreenGui`, `DisplayOrder = 20`): a card per pass and product. Passes show **Owned ✓** (from `playerState.passes[key]`) or a **Get** button → `MarketplaceService:PromptGamePassPurchase(player, id)`. Products show a **Buy** button → `MarketplaceService:PromptProductPurchase(player, id)`. Items with `id == 0` (not yet created) render **"Coming soon"** disabled. Starter Pack hides when `playerState.starterPackBought`. Refreshes on `PlayerStateUpdated`.

### Edited files
- **`src/shared/GameData.luau`** — add:
  - `GameData.GamePasses = { Cash2x = {id=0, name, desc, cashMult=2}, VIP = {id=0, name, desc, cashMult=1.25}, FasterWorkers = {id=0, name, desc, workerSpeedMult=1.5}, Subs2x = {id=0, name, desc, subsMult=2} }`
  - `GameData.Products = { StarterPack = {id=0, name, desc, cash=500, boostMult=2, boostDur=600, worker="Rare"}, MegaBoost = {id=0, name, desc, boostMult=3, boostDur=900} }`
  - Helpers (keep effect sites to one-liners):
    - `GameData.getPassCashMultiplier(data)` → `1 * (Cash2x?×2) * (VIP?×1.25)`
    - `GameData.getPassWorkerSpeedMultiplier(data)` → `FasterWorkers? 1.5 : 1`
    - `GameData.getPassSubsMultiplier(data)` → `Subs2x? 2 : 1`
    - `GameData.applyBoost(data, mult, dur, icon, label, now)` → the stack-or-set boost logic (extracted so DailyReward/shop/MegaBoost/StarterPack all share it).
- **`src/server/PlayerData.luau`** — add defaults + backfill: `passes = {}`, `starterPackBought = false`.
- **`src/server/WorkerCaseService.luau`** — remove its `ProcessReceipt` assignment; expose `WorkerCaseService.grantLuckySpins(data, n)` and `WorkerCaseService.grantWorker(player, data, rarity)` (wraps the existing `applyRoll` + `PlotManager.refreshWorkerNPCs(player)`).
- **`src/server/DevelopmentService.luau`** — in the release cash calc (currently multiplies by PC/floor/boost/sub/prestige) add `* GameData.getPassCashMultiplier(data)`; multiply `subsGained` by `GameData.getPassSubsMultiplier(data)`; in `runPhase` worker branch, `speed = GameData.getRaritySpeed(worker.rarity) * GameData.getPassWorkerSpeedMultiplier(data)`.
- **`src/server/PlotManager.luau`** — in the idle loop, apply `GameData.getPassCashMultiplier(data)` to room income and ad-revenue credited each tick (so 2× Cash / VIP cover passive income too).
- **`src/server/init.server.luau`** — `require` + `MonetizationService.start()` **after** `WorkerCaseService.start()`.
- **`src/client/UI.luau`** — `require` + `init` `StorePanel` (pass `player, Theme, playerState`); ensure `playerState.passes` / `playerState.starterPackBought` hydrate from `PlayerStateUpdated`.

---

## Data flow
1. Join → `PlayerData` provides `passes` + `starterPackBought` in `data`; `MonetizationService` checks each pass id via `UserOwnsGamePassAsync` and fills `data.passes`; `PlayerStateUpdated` hydrates the client.
2. Effect sites (release cash, idle income, subs, worker speed) read `data.passes` through the `GameData.getPass*` helpers — pure in-memory reads, no per-tick web calls.
3. Buying a **pass**: client `PromptGamePassPurchase` → `PromptGamePassPurchaseFinished` (server) → `data.passes[key]=true` + apply + `PlayerStateUpdated` → StorePanel shows **Owned ✓**.
4. Buying a **product**: client `PromptProductPurchase` → `ProcessReceipt` (server) grants + `PlayerStateUpdated` → returns `PurchaseGranted`.

## VIP cosmetic/tag
On VIP ownership (join or purchase): apply a gold character recolour (reuse the Lobby outfit-recolour approach) + a small `BillboardGui` "💎 VIP" nametag over the head. Removed complexity: no TextChatService chat-tag in this pass (nametag is enough).

## Fairness / bounds
- Max cash multiplier from passes = ×2.5 (Cash2x × VIP), multiplicative with earned progression — a real edge, not a win button.
- Faster Workers ×1.5 and 2× Subs are throughput/pacing edges, both bounded.
- No purchase gates content; every pass effect is a *rate* boost a free player also gets over time.

## Edge cases
- **Placeholder ids (`0`):** MonetizationService skips ownership checks for id 0; ProcessReceipt never matches id 0; StorePanel shows those cards as "Coming soon". Lets us build + test before the IDs exist.
- **Starter Pack re-purchase:** if `data.starterPackBought` is already true, still return `PurchaseGranted` (consume the receipt) but grant nothing; StorePanel hides the card once bought so this is rare.
- **Ownership check fails (Studio / network):** `pcall` around `UserOwnsGamePassAsync`; on failure leave the pass unowned (fail safe — no free perks).
- **Boost stacking:** Mega Boost + Starter Pack boost go through `GameData.applyBoost`, which extends duration + adds to the multiplier (capped at ×10, matching the existing daily-boost logic).

## Testing / verification (no unit tests)
- `./rojo-bin/rojo build …` compiles clean.
- Studio playtest with **simulated ownership**: set `data.passes.Cash2x = true` etc. on the server and confirm a game release pays 2×, VIP adds +25%, Faster Workers shortens worker phases, 2× Subs doubles subs; fire a fake receipt for StarterPack/MegaBoost to confirm grants; open the 💎 Store and confirm cards + Owned ✓ states + "Coming soon" for id 0.
- Confirm the centralized `ProcessReceipt` still grants Lucky Crate spins (no regression).
- Then: create the real pass/product IDs on the Roblox site, paste them into `GameData`, and confirm live.

## Out of scope (deliberately)
- Direct "buy cash" packs (intentionally omitted to stay less pay-to-win).
- Chat tags via TextChatService (nametag only).
- Limited-time / rotating offers, bundles beyond Starter Pack.
