# M4 — Audio & Music Design Spec

**Goal:** Give the (currently silent) game a full layer of sound — looping background music + ambience and one-shot sound effects for every meaningful moment — driven by one client module with all audio IDs in one editable place, plus a saved mute toggle.

**Architecture:** A single client `Sound` module (a sibling to `Fx.luau`) owns a `CUES` config table (every sound: id + volume + looped), builds reusable `Sound` instances under `SoundService`, and exposes `Sound.play("Cue")`. The rest of the client calls only `Sound.play(...)`. A 🔊/🔇 mute toggle (mirroring the existing DarkMode toggle) silences everything and persists to the player's profile. All sounds are 2D/local (personal feedback — other players don't hear them). Sounds with an unset id (`rbxassetid://0`) are silent no-ops, so the game runs today and gains each sound as its ID is filled in.

**Tech Stack:** Roblox / Luau, Rojo, `SoundService`, existing `DarkMode` persistence pattern (PlayerData field + `Set*` remote + `RequestInitialState` pull).

## Global Constraints

- **Client-only:** all playback logic is client-side. The server's only involvement is persisting the mute preference (one boolean + one remote), exactly like DarkMode.
- **Unset = silent, never an error:** any cue whose `id` is `rbxassetid://0` must make `Sound.play` a no-op. The game must run and never error with every slot empty. IDs get filled from Studio's Toolbox → Audio later (same "fill in later" pattern as `GameData.GamePasses`).
- **Rapid repeats must not break:** mashing (button clicks, minigame taps) triggers the same cue many times per second — playback must overlap cleanly without cutting off or leaking Sound instances.
- **Mute persists and covers everything:** the toggle silences music, ambience, and effects; the choice saves to the profile and restores on rejoin. Default = sound ON.
- **Modest by default:** music/ambience volumes stay low so audio never annoys; a player who mutes stays muted.
- **Mobile:** 2D sounds play fine on phones; the mute button is a HUD button ≥ 44px, tappable, placed by the DarkMode toggle.
- **Layer, don't replace:** sounds hook alongside the existing `Fx` celebrations and UI juice — no existing visual/behavioral logic changes.
- **Cross-session note:** the saved mute preference can't be verified in Studio (DataStore is off there); verify persistence on a published server, like other saved settings.

## 1. The `Sound` module

`src/client/Sound.luau`. Top of file — the single config table:

```lua
local CUES = {
    -- looping beds
    Music   = { id = "rbxassetid://0", volume = 0.30, looped = true },
    Ambient = { id = "rbxassetid://0", volume = 0.15, looped = true },
    -- one-shots
    Click   = { id = "rbxassetid://0", volume = 0.50 },
    -- ... (full list in section 2)
}
```

**Setup (`Sound.init(player)`):**
- Create a `Folder` "GameAudio" in `SoundService`.
- For each cue, create one template `Sound` (SoundId, Volume, Looped) parented there. A cue with `id` ending in `//0` is flagged `unset` and skipped by `play`.
- Read the saved mute preference (via the existing `RequestInitialState` pull, same as DarkMode) and set the initial mute state.
- Start the looping beds (`Music`, `Ambient`) unless muted.
- Build the 🔊/🔇 toggle button (section 3).

**API:**
- `Sound.play(cueName)` — one-shot. Returns immediately if muted, unknown cue, or unset id. For overlap safety it **clones** the template, plays the clone, and cleans it up on `Ended`/timeout (so rapid taps stack instead of cutting each other off). Looping cues are not played through this.
- `Sound.setMuted(isMuted)` — set master mute: pause/resume the loop beds, gate one-shots, and fire `SetSoundMuted` to persist. Updates the toggle icon.
- `Sound.isMuted()` — current state.

Keeping every id, volume, and loop flag in `CUES` is the whole point: one place to read, one place to fill in.

## 2. The cue list

Fill only the ones you want — the rest stay silently unset. Looping beds marked ▶.

| Cue | Plays when | Vol | Loop |
|---|---|---|---|
| **Music** | always, quietly under everything | 0.30 | ▶ |
| **Ambient** | always — soft city/park background | 0.15 | ▶ |
| **Click** | any UI button tap | 0.50 | |
| **PanelOpen** | a panel/popup opens (Store, upgrades, daily…) | 0.45 | |
| **Error** | action denied / can't afford | 0.45 | |
| **Teleport** | "To Studio" / "Go to Leaderboards" transition | 0.50 | |
| **Cash** | you earn money (game payout / idle collect) | 0.50 | |
| **Purchase** | upgrade or game-pass bought | 0.60 | |
| **Hire** | hire a worker | 0.55 | |
| **DailyReward** | claim the daily reward | 0.60 | |
| **RoundStart** | a minigame round begins | 0.40 | |
| **MinigameTap** | tapping/acting inside a minigame | 0.40 | |
| **Correct** | right answer / good placement | 0.50 | |
| **Wrong** | wrong answer | 0.40 | |
| **Shipped** | you release a game | 0.60 | |
| **TrendHit** | released game **matched the trend** (extra sting on top of Shipped) | 0.70 | |
| **Milestone** | subscriber Play Button milestone reached | 0.70 | |
| **CaseSpin** | worker Lucky Crate starts spinning | 0.45 | |
| **CaseReveal** | crate reveals the worker | 0.65 | |
| **Rebirth** | prestige / rebirth | 0.70 | |

20 cues. Any left at `//0` simply make no sound.

## 3. Mute toggle + persistence

- **Button:** `Sound.init` creates a 🔊/🔇 `TextButton` in the top-left HUD stack, directly beside the DarkMode 🌙 button (same size/style). Tapping flips `Sound.setMuted` and swaps the icon (🔊 ↔ 🔇).
- **Persistence (mirror DarkMode exactly):**
  - `PlayerData`: add `soundMuted` (default `false`).
  - New remote `SetSoundMuted` (client → server) — server writes `data.soundMuted`.
  - On join, the client reads it through the existing `RequestInitialState` response (the same pull DarkMode uses) and applies it before starting the beds.
- Default: **sound ON**. Muting stops the loop beds and gates all one-shots.

## 4. Where each sound hooks in

Each hook is a single `Sound.play(...)` added at a spot that already exists — no logic rewrites.

- **Click** → inside `juiceAllButtons` (every button already routes through it → one hook covers all buttons).
- **PanelOpen** → in the `popIn` / panel `Visible`-changed handler in `UI.luau`.
- **Error** → the `*ActionResult` remote handlers (House/PC/Worker/Prestige) when `success == false`.
- **Teleport** → the `RequestGoToStudio` / `RequestGoToLeaderboards` button handlers.
- **Cash** → where the cash-gain coin burst fires. **Purchase** → successful upgrade/pass result. **Hire** → successful `WorkerActionResult` (hire). **DailyReward** → `DailyRewardClaimed`.
- **RoundStart / MinigameTap / Correct / Wrong** → in the minigame client flow: `RoundStarted` → RoundStart; the Host's `report` callback → MinigameTap; `RoundComplete` → Correct if the round score ≥ 0.5, else Wrong.
- **Shipped** + **TrendHit** → `DevelopmentComplete` (TrendHit additionally when its `hitBonus` is true). **Milestone** → `SubscribersGained` when a milestone was reached.
- **CaseSpin / CaseReveal** → the WorkerHub crate-spin start and reveal beats.
- **Rebirth** → prestige success (PrestigePanel).
- **Music / Ambient** → started in `Sound.init`.

## 5. Filling in IDs + testing

- **Workflow:** In Studio, open **Toolbox → Audio**, preview free sounds, and copy each asset's ID into the matching `CUES` slot (replace the `0`). Fill as many or few as you like; unfilled = silent.
- **Testing:** audio can't be unit-tested, so verify by a Studio playtest — click a button (Click), earn cash (Cash), ship a game (Shipped/TrendHit), open a panel (PanelOpen), toggle 🔊/🔇 (everything silences), etc. Confirm rapid taps overlap cleanly and no errors appear with unset cues.
- **Compile check** after each change: `./rojo-bin/rojo build default.project.json -o /tmp/x.rbxl`.

## 6. Files touched

```
src/client/Sound.luau              -- CREATE: CUES table, init, play, setMuted, mute button
src/client/UI.luau                 -- MODIFY: call Sound.init; add Click in juiceAllButtons;
                                      PanelOpen in popIn; Cash/Shipped/TrendHit/Milestone/
                                      Teleport hooks at existing event points
src/client/Minigames/MinigameHost.luau -- MODIFY: RoundStart / MinigameTap / Correct / Wrong
src/client/WorkerHub.luau          -- MODIFY: CaseSpin / CaseReveal
src/client/PrestigePanel.luau      -- MODIFY: Rebirth
src/client/*Panel.luau             -- MODIFY: Purchase / Hire / DailyReward / Error at result handlers
src/server/PlayerData.luau         -- MODIFY: add soundMuted (default false)
src/server/init.server.luau (or the settings handler) -- MODIFY: handle SetSoundMuted (mirror SetDarkMode)
src/shared/Remotes.luau            -- MODIFY: add "SetSoundMuted"
```

## 7. Non-goals (YAGNI)

- No separate music-vs-effects volume sliders — one master mute only.
- No server-broadcast sounds (other players never hear your feedback sounds).
- No 3D/positional audio.
- No per-sound user settings beyond the single mute.
