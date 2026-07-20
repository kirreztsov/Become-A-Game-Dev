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
3. When the bar completes, the game "releases": Cash earned is derived from
   the player's Quality Boost upgrade level and how the release compares to
   the current Trends Board (see below).
4. Player spends Cash on upgrades (Dev Speed, Quality Boost).
5. Repeat indefinitely — there is no end state or final goal.

## Genres & Topics

Small, fixed starting lists (expandable later):

- **Genres**: Racing, Horror, Adventure, Simulator
- **Topics**: Space, Zombies, Sports, Fantasy

There is no fixed "good combo" table — any Genre+Topic pair is valid and
equally normal to make. What matters is the Trends Board, below.

## Trends Board & Quality

The studio has a **Trends Board**, shared by everyone in the server:

- It shows **2 trending games**, each just a randomly rolled Genre+Topic pair
  (rolled independently — it's fine if it doesn't make sense, e.g.
  "Simulator + Zombies").
- It **refreshes every 5 minutes**: both trending pairs are re-rolled at once
  for the whole server.

When a player releases a game, its Genre+Topic is compared against both
currently trending pairs:

- **Exact copy** — both Genre and Topic match one trending pair exactly →
  **Cash earned = 0**. It's a copy, not a hit.
- **Partial match** — only the Genre matches a trending pair's Genre, OR only
  the Topic matches a trending pair's Topic (not both) → roll a **10%
  chance**:
  - Hit (10%) → **Cash = base Cash × 5**
  - Miss (90%) → Cash = base Cash (no bonus)
- **No match** — Genre and Topic match neither trending pair at all → Cash =
  base Cash (normal, no bonus, no penalty)

**Base Cash** = Quality Boost multiplier × payout multiplier (constant for
v1). The old idea of a fixed per-combo quality rating is gone — Quality Boost
is now the only thing raising your baseline, and the Trends Board is the only
source of bonus (or zeroed-out) Cash.

## Upgrades

Two independent upgrade tracks. Each has discrete levels purchased with Cash;
cost increases per level (exact curve is an implementation detail, not fixed
in this spec — a simple exponential or linear-step cost table is fine).

- **Dev Speed**: reduces the development timer duration per level (e.g.
  Lv1: 30s → Lv5: 10s).
- **Quality Boost**: increases the multiplier applied to Base Cash per level,
  so releases keep earning more as the player progresses, independent of
  trends.

## Architecture

Server-authoritative: the client never decides outcomes, it only requests
actions and displays state the server sends back. This prevents players from
editing their own client to cheat Cash/upgrades.

- **Client** (`src/client`): UI screen — Genre/Topic picker buttons, "Start
  Developing" button, progress bar, Cash display, Upgrades shop panel. Fires
  RemoteEvents to request actions; listens for state updates to refresh the
  UI.
- **Server** (`src/server`): source of truth. Owns the per-player state
  (Cash, upgrade levels, games-released count), runs each player's
  development timer, owns the single server-wide Trends Board state and its
  5-minute refresh timer, computes Cash on release (including the copy/trend
  check and the 10% roll), validates and applies upgrade purchases, and
  pushes state updates back to clients.
- **Shared** (`src/shared`): static data both sides can read — the list of
  Genres/Topics, upgrade cost/effect tables.

### Data flow

1. Client fires `RequestStartDevelopment(genre, topic)` → Server validates
   the player isn't already developing, starts a server-side timer, tells the
   client to show the progress bar.
2. On timer completion, Server checks the release against the current Trends
   Board, computes Cash, updates the player's saved state, and fires a
   `DevelopmentComplete(cashEarned, wasCopy, hitTrendBonus)` event back to the
   client (so the UI can show "Copy!" / "Trendy hit!" / normal feedback).
3. Client fires `RequestBuyUpgrade(upgradeType)` → Server checks the player
   has enough Cash, applies the upgrade level, deducts Cash, and confirms back
   to the client.
4. Every 5 minutes, Server re-rolls the 2 trending Genre+Topic pairs and
   fires a `TrendsUpdated(trend1, trend2)` event to all clients in the
   server, so every player's Trends Board UI updates at the same time.

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
