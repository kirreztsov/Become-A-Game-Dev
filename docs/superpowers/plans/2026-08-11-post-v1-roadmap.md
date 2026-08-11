# Roadmap v2 — Pre-Public Polish & Depth (2026-08-11)

**Decision (user, 2026-08-11):** The game is feature-complete for a v1 but stays **PRIVATE** for now.
Store page is ready (icon, 3 thumbnails, name "Become a Game Dev: Studio Tycoon", description, genre).
Goal of this roadmap: add depth, retention and polish so that when we DO flip it public, it holds players.
Do NOT make it public until the "Ready-to-Launch gate" at the bottom is green.

Build order is top-down; each item is its own brainstorm → build → Studio-test cycle.

---

## Phase A — Make the core loop deeper (highest priority)
Players stay for *progression*. Right now the loop is: make game → earn → upgrade. Add more rungs.

- **A1. More content to grind toward** — more game genres/topics, more PC-part tiers/models, more worker types/rarities, more studio rooms/upgrades. The loop feels bigger when there's always a next thing.
- **A2. Quest / achievement ladder** — a visible list of goals ("release 10 games", "reach 1k subs", "max out your CPU") that pay cash/boosts. Gives new players direction and old players a checklist.
- **A3. Daily & weekly challenges** — rotating tasks with rewards → a reason to log in tomorrow.
- **A4. Prestige/rebirth depth** — more rebirth perks / a perk tree, so rebirthing feels like a real choice, not just a reset.

## Phase B — Retention & "come back tomorrow"
- **B1. Login streak polish** — bigger streak rewards, a visible calendar, catch-up.
- **B2. Limited-time event** — one seasonal/weekend event with an exclusive reward (a worker skin, a PC part, a title). Even one recurring event lifts retention a lot.
- **B3. Offline earnings** — small passive cash while away (with a "welcome back" popup) → reason to return.

## Phase C — Social (retention ~3x when friends play together)
- **C1. Visit friends' studios** — teleport to a friend's plot to see their setup.
- **C2. Shareable milestones** — a nice popup/card when you hit a big number, easy to screenshot/share.
- **C3. Global + friends leaderboards depth** — already have some; add "friends only" view.

## Phase D — Monetization depth (only after the loop is deep)
- **D1. More passes/products** — VIP+ earning lounge, 2x movement-speed pass, exterior studio skins (from the old M8 list).
- **D2. Season pass / battle pass** — free + paid track of rewards over ~30 days. The single biggest revenue+retention system in modern Roblox games. Big build — do it once the core loop is deep.
- **D3. Revisit existing offers** — tune prices/value once there's real playtest data.

## Phase E — Polish & juice
- **E1. Fix the minigame input exploit** (QA finding #4, 2026-08-11) — mash/sequence minigames trust client-reported counts; add server-side rate/plausibility checks. Bot-farming only (bounded by the 2.5x quality cap), not urgent, but do before public.
- **E2. More animation/juice** — screen transitions, better minigame feel, celebration moments.
- **E3. Mobile real-device pass** — M5 built but never confirmed on an actual phone; test button reach + text fit.

---

## Ready-to-Launch gate (all must be true before flipping Public)
- [ ] Core loop has enough depth that a new player has 30+ min of clear goals (Phase A)
- [ ] At least one "come back tomorrow" hook beyond daily reward (Phase B)
- [ ] Minigame input exploit fixed (E1)
- [ ] Mobile confirmed on a real phone (E3)
- [ ] A friend playtests blind for 15 min and gets it without help
- [ ] Live purchase test passes on a published (still-private) server — confirms the 2026-08-11 money fix

## Already done (context)
Economy, onboarding, monetization framework (real pass/product IDs live), audio (21 cues),
mobile scaling, white-card UI + juice + dark mode, PC Parts Shop, the 3D PC install minigame
(polished + sounds), Blender scenery (trees/mountains/rocks/bushes), and a launch QA pass with
the Robux-purchase-persistence bug fixed. Store page art + copy ready but game kept private.

## Suggested next
**Phase A** — start with A2 (quest/achievement ladder): it's high-impact, gives direction to
every player, and reuses systems that already exist (cash rewards, HUD panels).
