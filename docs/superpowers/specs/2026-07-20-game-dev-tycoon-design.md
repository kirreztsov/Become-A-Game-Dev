# Game Dev Tycoon — Design Spec

## Overview

A solo-studio game development tycoon, inspired by "Game Dev Tycoon" and the
"Minecraft, but We Became Game Developers" video series — but endless, with
no scripted ending. Each player builds up their own private game studio:
release games, earn Cash, buy upgrades, repeat forever.

## Core Loop

Each player has their own private studio. Other players in the server do not
affect your progress (no shared economy, no competition, no visiting other
studios — out of scope for v1).

1. Player picks a **Genre** + a **Topic** from a menu.
2. Player presses **"Start Developing"**. A progress bar fills over a fixed
   duration (shortened by the player's Dev Speed upgrade level).
3. When the bar completes, the game "releases":
   - **Quality Score** is derived from the Genre+Topic match rating and the
     player's Quality Boost upgrade level.
   - **Cash** earned is derived from the Quality Score.
4. Player spends Cash on upgrades (Dev Speed, Quality Boost).
5. Repeat indefinitely — there is no end state or final goal.

## Genres, Topics & Quality

Small, fixed starting lists (expandable later):

- **Genres**: Racing, Horror, Adventure, Simulator
- **Topics**: Space, Zombies, Sports, Fantasy

Every Genre+Topic pair has a **match rating**: `Perfect`, `Good`, `Okay`, or
`Bad` (e.g. Horror+Zombies = Perfect, Racing+Zombies = Bad). This is a fixed
lookup table, not computed — defined once as data so it's easy to extend when
more genres/topics are added later.

**Quality Score** = match rating value × Quality Boost multiplier

**Cash earned** = Quality Score × payout multiplier (constant for v1)

## Upgrades

Two independent upgrade tracks. Each has discrete levels purchased with Cash;
cost increases per level (exact curve is an implementation detail, not fixed
in this spec — a simple exponential or linear-step cost table is fine).

- **Dev Speed**: reduces the development timer duration per level (e.g.
  Lv1: 30s → Lv5: 10s).
- **Quality Boost**: increases the multiplier applied to Quality Score per
  level, so lower-match combos still earn meaningful Cash as the player
  progresses.

## Architecture

Server-authoritative: the client never decides outcomes, it only requests
actions and displays state the server sends back. This prevents players from
editing their own client to cheat Cash/upgrades.

- **Client** (`src/client`): UI screen — Genre/Topic picker buttons, "Start
  Developing" button, progress bar, Cash display, Upgrades shop panel. Fires
  RemoteEvents to request actions; listens for state updates to refresh the
  UI.
- **Server** (`src/server`): source of truth. Owns the per-player state
  (Cash, upgrade levels, games-released count), runs the development timer,
  computes Quality Score/Cash on release, validates and applies upgrade
  purchases, and pushes state updates back to the owning client.
- **Shared** (`src/shared`): static data both sides can read — the list of
  Genres/Topics, the match-rating lookup table, upgrade cost/effect tables.

### Data flow

1. Client fires `RequestStartDevelopment(genre, topic)` → Server validates
   the player isn't already developing, starts a server-side timer, tells the
   client to show the progress bar.
2. On timer completion, Server computes Quality/Cash, updates the player's
   saved state, and fires a `DevelopmentComplete(quality, cashEarned)` event
   back to the client.
3. Client fires `RequestBuyUpgrade(upgradeType)` → Server checks the player
   has enough Cash, applies the upgrade level, deducts Cash, and confirms back
   to the client.

### Persistence

Per-player Cash, upgrade levels, and games-released count are saved via
Roblox DataStore, loaded on join and saved on leave (and periodically, as a
safety net against data loss on crash/shutdown).

## Out of scope for v1

- More than 4 Genres / 4 Topics (planned expansion, not now)
- Any interaction between players (shared economy, leaderboard, visiting
  other studios)
- Staff/employees that auto-produce games
- Cosmetics or office decoration
- A scripted ending or final goal — the loop is intentionally endless
