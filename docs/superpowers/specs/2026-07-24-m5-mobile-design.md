# M5 — Mobile & Cross-Platform (Design Spec)

**Milestone:** M5 of the v1.0 launch roadmap.

**Goal:** Make the game's UI fit and be usable on phones (the majority of Roblox players), without reworking every panel — by auto-scaling menus/HUD to the screen and hand-fixing anything that still doesn't fit.

**Context:** The UI is built with mostly fixed pixel sizes (panels ~380–560px wide, HUD cards ~220px, the computer-desktop menus). On a phone viewport these overflow or are oversized. Roblox provides the movement joystick + jump button and treats button clicks as taps for free, so touch *input* mostly works already; the problem is *layout fit*.

---

## Success criteria (Done when…)
- Every menu and the HUD fit within a phone-sized viewport (portrait and landscape) with nothing cut off the screen.
- Buttons stay large enough to tap.
- Full-size and unchanged on desktop/large screens (scaling only kicks in when the screen is small).
- Re-fits correctly when the device rotates (viewport changes).
- Verified in Studio at a phone-size viewport; final confirmation by the user on a real phone.

---

## Approach: one shared auto-fit scaler + targeted fixes

### 1. `MobileScale` (new client module)
A single system that scales UI to the screen — like the theme / dark-mode systems, it covers every menu at once.

- On init it adds a `UIScale` to each of the game's menu/HUD ScreenGuis and sets its `Scale` from the viewport size.
- **Scale formula:** `scale = clamp(min(viewportX / 1000, viewportY / 650), 0.55, 1)`.
  - Desktop / large (≥1000×650): `scale = 1` (no change).
  - Phone/tablet: scales down just enough to fit; floored at `0.55` so buttons never get too tiny to tap.
- **Recompute on resize:** listen to `workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize")` (fires on rotate / window resize) and update every managed `UIScale`.
- **New GUIs:** hook `PlayerGui.DescendantAdded`; when a new ScreenGui appears (a panel built on first open), give it a `UIScale` at the current scale too.
- **Scaled ScreenGuis:** `GameDevTycoonUI` (main HUD + centered station panels), `StoreGui`, `PrestigeGui`, `PrestigeConfirmGui`, `RebirthProgressGui`, `TutorialGui`, `DecorPanelGui`, `DecorPlacingOverlay`, `DailyRewardGui`, `HousePanelGui`, `PCPanelGui`, `ShopPanelGui`, `WorkersPanelGui`, `WorkerHubGui`, `ComputerDesktopGui`, `DarkModeGui`.
- **Excluded (blocklist):** `FxGui` (full-screen confetti/coin bursts positioned in absolute screen pixels — scaling would misplace them) and `LoadingScreen` (already full-screen, `IgnoreGuiInset`). These stay unscaled.

**Why `UIScale`:** centered modal panels (`AnchorPoint 0.5,0.5` at screen center) scale perfectly around their centre. Corner-anchored HUD (cash/subs bottom-right, nav buttons) will drift slightly *inward* when scaled down — acceptable because it keeps them on-screen (the failure we're preventing is overflow *off* the screen). Egregious drift is handled in step 3.

### 2. Touch-target pass
After scaling, confirm the primary action buttons (Claim, Buy/Get, Upgrade, Start, Spin, Skip, nav buttons, the 💎/🌙/? corner buttons) are still comfortably tappable at the smallest scale (~0.55). Bump the base size of any that end up too small. (Most are already 40–52px, which stays ≥ ~26px scaled — usable; only outliers need bumping.)

### 3. Fit fixes (found by testing)
Auto-scale gets ~90% there; the rest is per-screen cleanup discovered by testing at phone sizes. Likely candidates to check:
- Tall panels that exceed phone *height* even when scaled (WorkerHub cases view, Store list, the Rebirth confirm) — ensure internal scrolling or reduced height.
- HUD corner elements overlapping Roblox's on-screen controls (jump button bottom-right, joystick bottom-left) — nudge if needed.
- The tutorial banner / boost card stacking bottom-right near the jump button.

### Files
- **Create:** `src/client/MobileScale.luau` — `MobileScale.init(player)`.
- **Modify:** `src/client/UI.luau` — `require` + call `MobileScale.init(player)` at the end of `init` (after all panels + DarkMode are set up, so every existing ScreenGui is present when it first scans).
- **Targeted fixes:** small edits in individual panels only where testing shows overflow (none assumed up front).

---

## Data flow
Pure client-side and stateless — no server, no saved data. `MobileScale` reads the viewport and drives `UIScale` values. Nothing to persist.

## Edge cases
- **Viewport reads 1px in headless Studio MCP** (known quirk): my in-Studio verification will resize/emulate a phone view where possible and otherwise reason from the formula; the user's real-phone check is the source of truth.
- **A ScreenGui created before init** — covered by the initial scan; **created after** — covered by `DescendantAdded`.
- **Desktop unaffected** — scale clamps to 1, so no visual change on PC (protects the M6 look we just built).
- **`DarkModeGui` / dark mode** — scaling is orthogonal to colour; both apply independently.

## Testing (no unit tests)
- `rojo build` clean.
- In Studio, check the UI scales down at a small viewport and stays 1:1 at desktop size; confirm no errors and that new panels (opened after join) also scale.
- User confirms on a real phone (portrait + landscape): menus fit, buttons tappable.

## Out of scope
- Mobile-first *redesigns* of any panel (chosen approach is auto-fit, not rebuild).
- Custom on-screen controls (Roblox's defaults are used).
- Console/gamepad-specific navigation.
