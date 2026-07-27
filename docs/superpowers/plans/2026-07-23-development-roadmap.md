# Become a Game Developer — Development Roadmap

**Goal:** Turn the current feature-rich prototype into a polished, retaining, discoverable Roblox game, sequenced by what actually makes games in this genre engage players and blow up.

**How to use this doc:** This is the strategic map, not a single build plan. Each **feature** below is its own small project — when you're ready to build one, we brainstorm it briefly, write a focused build-plan, build, and Studio-test it. Work top-down: finish a phase's "Done when…" before moving on.

**How we verify in this project (there is no unit-test suite):**
- `./rojo-bin/rojo serve` for live sync; `./rojo-bin/rojo build default.project.json --output <tmp>` to check code compiles.
- Live Studio playtest via the Studio MCP (start Play, `execute_luau` to inspect Instances/state, check console for errors).
- "Done when…" on each phase is the acceptance check.

---

## Current state (already built)

- **Core loop:** make a game at the stations (Coding / Map-Building / Testing minigames) → release for cash based on **trend match + quality**.
- **Workers:** hire/upgrade; they auto-complete phases.
- **Progression:** House upgrades (floors → 2× cost & 2× earnings, max 3), PC upgrades.
- **Per-player studios:** multi-floor buildings on random plots; drag-to-place **studio decorations** (grid-snapped, saved).
- **Money rooms:** Arcade ($2,000 → +$64/3s) and Merch ($20,000 → +$500/3s), bought via **tycoon buy-buttons**, auto-income.
- **Subscribers:** gained from releases; passive ad-revenue cash; permanent earnings multiplier; **Game Developer Button** milestone trophies (Bronze→Ruby) + celebration.
- **Shared town:** plaza, roads, roundabout, driving cars, walking NPCs, swimmable beach + fish, solid mountains + invisible map boundary, skyline, **4 shops** (boosts + cosmetics), quest NPCs, basketball.
- **Systems:** stackable boosts + boost-timer HUD, cosmetic cap, polished centered **money HUD**, day/night cycle, DataStore save/load.

---

## Guiding principles (from research)

1. **The first 5 minutes decide retention.** Get a new player *doing the core activity in 10–30s*; teach by play, not text. ~80% of lifetime revenue comes from week-1 survivors.
2. **Manufacture reasons to return:** idle progression, escalating goals, "unfinished progress," daily-reward streaks, and **prestige/rebirth resets**.
3. **Social multiplies retention ~3×:** friends, leaderboards, a friend-referral loop; games spread because friends/streamers show them.
4. **Update often:** boosts "Recently Updated" placement and the recommendation algorithm.
5. **Discovery = a great icon/thumbnail (2–3× traffic) + shareable moments + codes.**

Sources: Endsights *Roblox Tycoon Games 2026*; RoLearn *First-Week Retention*; Robipedia *Game Discovery*; Tubefilter *Roblox Discovery 2025*; SQ Magazine *Monetization Stats 2026*.

---

## Phase 1 — 🚀 Launch-Ready
*Make what already exists shippable to strangers.*

- **F1.1 First-5-minutes onboarding.** On first join, a guided goal chain drives the player into making a game within ~30s: spawn → arrow to studio → "sit & make your first game" → release → "you got your first subscribers!". Replace any text-wall guide with 3D arrows + one-line goals.
- **F1.2 First-session goal chain UI.** A small "Goals" checklist HUD: *Release a game → Reach 100 subs → Buy your first room → Upgrade your studio.* Ties the existing systems into a guided path.
- **F1.3 Economy balance pass.** Revert `GameData.StartingCash` to 0 (currently 50,000 for testing). Tune release payouts, room paybacks, boost costs, and sub rates so early progress feels quick but not trivial (target: first room affordable in the first session, house upgrade a stretch goal).
- **F1.4 Save reliability + new-field safety.** Audit `PlayerData` backfill for every field; verify save on leave/BindToClose; confirm no data loss when new fields are added.
- **F1.5 Bug & polish pass.** Fix the `NewProjectSeat` infinite-yield warning; sweep console for errors on a fresh Play; verify all prompts reachable; verify TweenService works on a clean Studio launch.

**Done when:** a brand-new player with no explanation reaches their first game release and first subscribers within ~5 minutes, with no console errors and reliable saving.

---

## Phase 2 — 🔁 Keep Them Coming Back
*Give players a reason to return tomorrow and a goal weeks away.*

- **F2.1 Daily reward streak.** Login-reward popup; escalating rewards (cash → boost → cosmetic → big bonus) over a 7-day cycle; streak persists in `PlayerData`.
- **F2.2 Goal / quest ladder.** A persistent list of medium-term goals ("release 10 games", "reach 10K subs", "own both rooms", "3-floor studio") each granting a reward; the **Day-7 reward is shown on Day 1** as aspiration.
- **F2.3 Rebirth / Prestige.** At a threshold (e.g., 1M subs or full studio) let the player reset progress for a permanent global multiplier + a prestige level shown on their nameplate + prestige-only cosmetics ("GameDev Legend").

**Done when:** the game shows a login reward on day 2, a visible goal ladder with a far-off target, and a working prestige reset that grants a permanent multiplier.

---

## Phase 3 — 👥 Better With Friends
*Make it better with friends and let it spread itself.*

- **F3.1 Leaderboards.** In-world podium/boards for Most Subscribers, Richest, Most Games — global + friends. (Persist via OrderedDataStore.)
- **F3.2 Visit a friend's studio.** A way to teleport to / spectate another player's studio in the same server (show off decorations + Play Buttons).
- **F3.3 Shareable milestone moments.** Make the Game Developer Button celebration (and prestige) big and screenshot-worthy; add a "share" beat.
- **F3.4 Friend-referral reward.** Reward players when an invited friend joins (uses Roblox's referral system when available).

**Done when:** players can see leaderboards, visit each other's studios, and get a reward for bringing a friend.

---

## Phase 4 — 💰 Money & Meta
*Earn Robux fairly and become discoverable.*

- **F4.1 Game passes.** Fair, boost-not-required passes: 2× Cash, Auto-Collect, VIP studio (cosmetic + small perk). Server-validated.
- **F4.2 Developer products.** Repeatable cash packs / boost packs.
- **F4.3 Codes system.** Redeemable codes (for updates/streamers) granting cash or cosmetics; a small "Enter code" UI.
- **F4.4 Icon, thumbnails & title.** A strong game icon + thumbnail set (2–3× discovery traffic) and a title/loading screen.

**Done when:** the game has purchasable passes + products, a working codes box, and a real icon/thumbnail ready for the store page.

---

## Phase 5 — 🌱 Live Game
*Keep it feeling alive so the algorithm and players keep noticing.*

- **F5.1 Content drops:** new game genres/topics, new studio decorations, a 3rd/4th money room, more shop items.
- **F5.2 Seasonal / limited-time events:** holiday town themes, a limited "trend craze" event with special payouts and event-only cosmetics.
- **F5.3 Update cadence habit:** ship something small and visible regularly; announce it in-game ("What's New").

**Done when:** there's a repeatable pattern for shipping small updates, and at least one limited-time event has run.

---

## Suggested immediate next steps (in order)
1. **F1.3 economy balance** (fast, unblocks honest testing) — revert the temp $50k and tune.
2. **F1.1 + F1.2 onboarding + goal chain** (highest retention leverage).
3. **F2.1 daily rewards**, then **F2.3 prestige**.

Each of these is a separate brainstorm → build-plan → build → Studio-test cycle.
