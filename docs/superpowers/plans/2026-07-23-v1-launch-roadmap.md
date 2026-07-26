# Become a Game Developer — v1.0 Launch Roadmap

**Goal:** Take the (already feature-rich) game to a **polished, published v1.0** — a full first impression, not a soft launch.

**Launch philosophy:** Polish to a complete v1.0 *before* the first public release.

**Monetization stance:** Between standard and heavy — **not pay-to-win**, but paying players get a real **advantage** (faster progress, convenience, cosmetics). F2P must stay fully viable.

**How to use this doc:** Strategic map, not one build plan. Each milestone is its own brainstorm → build-plan → build → Studio-test cycle. Work top-down; finish a milestone's "Done when…" before the next. Verification = `rojo build` + live Studio playtests (no unit tests).

---

## Already built (foundation)
Core make-games loop; workers with a full **rarity + case system** (normal/lucky cases, pity, Robux bundles, stackable spins, seated typing NPCs, rarity badges); **subscribers, prestige, daily rewards, leaderboards**; the **computer-desktop UI** (minigame inside, HUD hidden when seated); per-player multi-floor studios + drag-place decorations; the living town (plaza, roads, cars, NPCs, beach, mountains, shops); polished money HUD; Goals HUD; nav buttons; Lucky Crate monetization.

---

## M1 — Economy Lockdown & Balance
Revert temp values (`GameData.StartingCash` 50000 → 0). Tune the whole curve so progression is satisfying and money = edge, not win:
- Game-release payouts, worker-rarity multipliers, case costs, idle-room paybacks, subscriber rates, prestige requirement growth, daily-reward sizes.
- Target pacing: first game in the first minute; first room in session 1; first prestige a multi-hour goal.
**Done when:** a fresh $0 player has a smooth, tuned climb with no runaway or dead zones.

## M2 — Onboarding & First 5 Minutes
A real tutorial: player makes their first game within ~30s, guided by 3D arrows + the goal chain, with "what to do next" signposting at every step; a friendly first-time flow.
**Done when:** a stranger with zero help ships a game and gets subscribers within 5 minutes.

## M3 — Monetization (fair advantage)
Game passes: **2× Cash**, **Auto-Collect** (idle rooms self-collect), **VIP** (exclusive cosmetics + modest permanent boost + VIP tag), **Faster Workers**. Dev products: cash packs, a **Starter Pack**, spin bundles (done). Server-validated; odds shown; F2P viable.
**Done when:** all passes/products work, are balanced (edge not win), and are clearly presented.

## M4 — Audio
Music (lobby + studio themes), SFX for every action (click, cash, case-spin, milestone, purchase, prestige), light ambient sound; volume respects settings.
**Done when:** the game sounds alive and every action has audio feedback.

## M5 — Mobile & Cross-Platform
Roblox is mobile-majority. Audit + fix every screen for phone/tablet: touch-target sizes, layout scaling, the computer desktop, cases, all panels; test on a mobile viewport.
**Done when:** fully playable and good-looking on a phone.

## M6 — UI & Animation Perfection
A dedicated pass to make every screen and motion feel first-class, on **both desktop and mobile**:
- Consistent theming, spacing, fonts, corner radii, and colors across all panels (shops, worker hub/cases, decor, house/PC, workers, HUD, desktop).
- Smooth, reliable transitions everywhere — panel open/close, hovers, case spin, cash count-ups, milestone + prestige celebrations — using the manual-animation approach (TweenService is unreliable in this project; see the ZIndex/Tween notes).
- Remove any rough, placeholder, or inconsistent visuals; add tasteful "juice" (pops, easing, particles where fitting).
**Done when:** the whole game looks and animates like one cohesive, premium UI on every device.

## M7 — Model & Animation Polish (Blender)
Replace/upgrade the blocky procedural-Part builds with proper 3D models made in **Blender**, plus smoother, hand-crafted animations — so the game reads as premium, not just stacked bricks.
- **Models:** the key props, characters, and buildings (studio building, desks/PCs, the worker + townsfolk characters, shop stalls, signature landmarks) modelled in Blender, exported as meshes, imported to Studio, then coloured/placed to match the current style.
- **Animations:** smoother custom animations to replace the manual part-bobbing — worker typing, character idle/celebrate, case-open, milestone/rebirth moments — using Roblox animation tracks where it fits.
- **Constraints:** keep it **on-theme and cohesive** (don't mix styles), and **mobile-performant** (watch tri-counts / part counts after M5). Do the highest-impact models first (what the player sees most).
**Done when:** the game's models + animations look crafted and premium while staying smooth on phones.

## M8 — Robux Revenue Features
More ways to spend Robux — fair-advantage + cosmetic — on top of the M3 passes/products. This is also the milestone to **add more passes/dev products and to revisit & improve the existing M3 offers** (VIP, 2× Cash, Faster Workers, 2× Subs, Starter Pack, Mega Boost) based on how they've performed. Starting three pieces:
- **VIP+ pass — paid earning lounge:** a special **VIP+ area** (a lounge only VIP+ owners can enter) where **standing inside earns cash automatically — 0.5% of your current cash per second** while you're in the zone. Server-authoritative: award on a server tick, verify the player is genuinely in the zone, stop when they leave. Sold as a new **VIP+ pass** (a higher tier than the existing VIP pass from M3). ⚠️ **Balance note:** 0.5%/sec *compounds* fast (~2.7× your money in ~3.5 min of just standing there) and is AFK-farmable — when we build it, tune the rate and/or add a cap or diminishing curve so it stays a fair advantage and doesn't break the M1 economy.
- **Studio skins (cosmetic for Robux):** buy alternate **exterior skins** for your studio building so it looks different from the outside (e.g. neon, glass, retro, castle). Pure cosmetic — **no gameplay power**. Sold per-skin (dev products) or as a skins pass; owned skins saved to player data; applied by swapping the building's materials/colors/model. Pairs naturally with the M7 Blender models.
- **2× Movement Speed pass:** a game pass that **doubles your character's walk speed** (`Humanoid.WalkSpeed`) so you get around the studio and lobby faster. This is *player movement* — completely separate from the M3 Faster Workers pass (which speeds up worker output), so there's no overlap.
**Done when:** each Robux offer works end-to-end (purchase → effect → saved), the lounge earning is server-authoritative and balanced, and cosmetics never affect fairness.

## M9 — Social & Retention Depth
Friend referral reward, visiting a friend's studio, richer/global leaderboards, a medium-term **goal/quest ladder**, more prestige tiers + rewards.
- **Townsfolk quests (rebuild):** the old lobby "delivery" quest (walk-to-a-package for $120) was removed in M1 — it didn't fit the game-dev theme. Rebuild it here as a real, on-theme **quest/task system**: themed objectives ("release a Horror game", "hit 500 subs", "hire a Rare worker") with escalating rewards, given by the townsfolk NPCs.
- **More upgrades / deeper progression sinks:** right now a player can buy everything (a few floors, PC tiers, workers, 2 rooms) and then cash has nowhere to go. Add more upgrade depth so late-game always has a meaningful next purchase — e.g. more studio floors, higher PC tiers, new upgrade categories (marketing/reach, render speed, studio staff perks), and higher room tiers. Keep each one on the fair-advantage curve so it's reasonable, not a wall.
**Done when:** playing with friends is clearly better and there are goals weeks out.

## M10 — Hardening & QA
Save reliability (every data field persists across rejoin — cash, workers+rarity, subs, prestige, rooms, decorations, daily, pity, spins, passes, skins); server-authority/exploit checks on all remotes; full bug pass (incl. the `NewProjectSeat` infinite-yield warning); performance + part-count/mobile check.
**Done when:** no known bugs, reliable saves, no exploits, smooth performance.

## M11 — Store Presence & Launch
Game **icon** + **thumbnails**, title/loading screen, name + description + genre/tags, experience settings, a **codes** system (launch/streamers). Then: publish → soft-launch with friends → public.
**Done when:** published with a real, compelling store page.

## M12 — Live-ops readiness (light)
Analytics on the retention funnel (D1/D7, tutorial completion), a "What's New" board in-game, and the first content update queued to re-boost the game after launch.

---

## Suggested order note
Mobile (M5) is placed before UI/Animation Perfection (M6) on purpose, so the polish pass covers both layouts at once. If you'd rather see it polished on desktop first, M6 can move ahead of M5 — but doing it once, after mobile, avoids re-polishing twice.

## Immediate next step
Start **M1 (Economy Lockdown)** — it's fast, unblocks honest testing, and everything else balances against it. Each milestone after is its own brainstorm → plan → build → test.
