# CLAUDE.md

Guidance for Claude Code when working in this repository.

## Project

- **Game:** Fantasy survivor-like roguelite, solo + co-op (1–4 players), low-poly stylized
- **Design:** Full design is in `docs/design.md`. Read it before starting gameplay work, and check which milestone we're on.
- **Current milestone:** M4 (content + polish), chunks 1-3 done, next is 4. Chunks: (1) Ogre boss + elites + archer facing, (2) Chain Lightning / Frost Nova / Holy Ground with evolutions + new passives (+ warding rings), (3) game feel: Creator Store sounds, hit VFX, UI pass, (4) collection log + phone perf check. Plan each chunk in plan mode.
- **Genre / core loop:** move to dodge and collect XP gems while weapons auto-fire (seconds); level up and pick 1 of 3 upgrades, survive 3 short stages and charge the portal at each stage end (one ~10 min run); spend Shards on permanent upgrades between runs (session, M3). Details in `docs/design.md` §3.
- **Target players:** TODO — age range. Platform: mobile-first (one-thumb movement is a design pillar).
- **Monetization:** principles only so far (no pay-to-win; cosmetics and convenience) — `docs/design.md` §12. Not until the core loop is fun.

## Status (last updated 2026-10-28)

- **M0** done. **M1** done in 6 steps (commits `707138e`..`6f2d3cb`), then playtest-driven changes: a stronger starting Spinning Blade (`837740b`), pausing the game for level-up picks (`d1c0c08`), and a polish pass (2026-10-11): readable crimson enemy shots (`02819d8`), multi-target Arrow Storm + archer cap of 8 (`067f1e6`), supply crates and meat/bomb/magnet pickups (`2b4aa58`), then archer damage below goblins, arrows target archers first, more frequent weapon level-ups, and a fix for even-count arrow fans that straddled and missed their target.
- **Playtest feedback so far:** the loop is fun; the user won a full run after the blade buff (stage 1 easy, stages 2 and 3 close). Archer shots are dodgeable, Giant HP and portal charge feel right, stage-1 level-up pacing is good. The 2026-10-11 polish (shots, Arrow Storm, archer cap, crates/pickups) hasn't been playtested yet. (Warding rings from the backlog were built in M4 chunk 2.)
- **Not yet verified:** a full natural run without dev commands; low-end phone performance (Studio device emulator at the 200-enemy cap); co-op pause behavior (all players picking, 15s idle limit, "WAITING FOR OTHERS") — needs 2 players, test in M2.
- **M2 (2026-10-11):** evolution hints on cards (`d6f7fad`), per-match refactor (`8b7e7fb`), lobby + portal pad + arena slots + back to lobby (`0fb3ede`), downed/revive + party scaling (`12f29a3`). Verified solo in Studio. **User's 2-player test (2026-10-11) passed:** pad shows 2/4 and Start now takes both into one arena; shared level-up pause with "waiting for others"; revive; a player leaving mid-run (run continues); 2-player scaling felt fair. **Still untested:** the 15s idle auto-pick, a defeat with both players downed, two parties in separate arenas at the same time, and server load with several full matches.
- **M3 (2026-10-15):** Shards per run + results breakdown (`a2b3dde`), heroes + Hero stand (`4226e33`), the Altar (`cced070`). Verified solo in Studio with unsaved data: Shard math on defeat and victory, Greed, hero select/unlock and server rejections (locked, unaffordable, mid-run, garbage args, same-frame double buy), every Altar effect except Rescue, Head Start picks in the countdown, reroll count. **User's 2-player test (2026-10-15) passed:** different heroes in one party, both players paid Shards, real save/load (Studio API access is on; Shards survived stop/start), plus the leftover M2 checks: the 15s auto-pick (one or both idle) and a defeat with both players downed. **Still untested:** Rescue revive speed, two parties in separate arenas at once, server load with several matches. The picker title says "LEVEL UP!" for Head Start picks too.
- **M4 chunk 1 (2026-10-15):** elites + archer facing (`688333f`), the Ogre + BossBrain (`fd61c1a`), the Boss phase (`e50be33`), then Ogre HP 3000 -> 4000 after a maxed triple-evolution build killed it in 20s. Verified in Studio: elite glow/size/chest, archers facing the player (0 degrees off), Ogre ring/summon/charge (charge hit 22 at stage 1, 1.1s after its telegraph), enrage code path not observed, Boss phase reached naturally from stage 3's timer, victory on kill, defeat during the fight, full skip-through with no errors. **Needs the user's playtest:** is the Ogre fight fair and dramatic, solo and co-op, and are elites too frequent or tanky?
- **M4 chunk 2 (2026-10-28):** Chain Lightning + Thunderstorm (Haste) and a `WeaponEffects` remote (`adc4acc`), Frost Nova + Blizzard (Armor) with enemy slows and the Armor passive (`133d09b`), Holy Ground + Sanctuary (Regen) with per-match weapon state and the Regen passive (`e27b218`), and the Warding passive (`349fffd`), then a balance pass (Thunderstorm cut to about half its damage output). Verified solo in Studio: hits and kills at levels 1/5/evolved, bolts drawn on the client, the slow (boss 6 -> 3.6 studs/s, i.e. half of 80%) and icy tint, Armor (6 -> 4.2 per goblin hit at 30%), Regen (+20 HP in 4s at level 5), Sanctuary healing 4 HP/s, zones holding still through a level-up pause, Warding stopping every archer shot (16 hits -> 0 in 10s). **Needs the user's playtest:** do the new weapons feel distinct and fun, is Blizzard worth picking. **User playtest (2026-10-28):** Chain Lightning is cool, more wave clear than single target (kept that way); in co-op both players see bolts and zones and Sanctuary heals teammates, but not its caster while moving. So Sanctuary's first zone now follows its caster, and Blizzard freezes enemies (1.5s, no moving/attacking/shooting; bosses only slowed 50%) instead of an 80% slow. Verified solo: frozen enemies move 0 studs, the Giant slows to 3.0, Sanctuary heals the moving caster ~4 HP/s (0 with no zones). **Needs the user's playtest:** do the freeze and the following zone feel right?
- **M4 chunk 3 (2026-10-28):** game feel. Sound effects + music + mute toggles (`d0eaa58`, explosion tails cut `33ff8c0`), hit feedback: sparks, death puffs, damage numbers, hurt flash/shake, level-up/evolution flair (`552d776`), weapon visuals: swords, arrow models, fire trails, lightning sparks, ice blocks on frozen enemies, Warding rims and pops (`ada96a0`), UI theme + HUD/health bars/build tiles/cards (`a0c4dae`), a playtest round (`c37365e`: chest picks pause with a TREASURE! title, consecrated-circle Holy Ground, HUD health bar, portal objective tracker on the right, per-category volume sliders; `63eef5d`: Holy Ground is cast up piece by piece), results + lobby menus (`db16161`). **User's playtest:** "feels a lot more fun and engaging"; swords look good. Perf (Studio, every evolution + Warding, ~150-180 enemies): server 60 Hz (worst frame 20 ms), client 60 fps (no frame over 25 ms), effect pools bounded (30 damage numbers). **Still untested:** co-op for all of chunk 3 (teammate health bars, shared chest pause, Sanctuary's following zone), dragging the volume sliders, the HEAD START title (needs a real Altar purchase), low-end phones (chunk 4). Every audio id is a free Creator Store asset in `Config/Audio.luau` (swap there). The DOWNED sign hasn't been restyled.
- **Known follow-ups:** Level-up picks can pile up with no cap. Archers face their direction of travel while shooting (user OK'd leaving it for now).
- **Working style:** for multi-step milestones, the user wants to discuss the plan first — remind them to switch to plan mode (Shift+Tab) before planning. Commit after each verified step.

## Architecture (gameplay)

- **Matches:** each party's run is a match (`server/Match.luau`) in its own arena (`workspace.Arenas.Arena<slot>`, x = 1000 × slot; the lobby is at the origin). Every run system is a per-match state object (`Module.new(...) -> State`, functions take the state first: EnemyService, Progression, ProjectileService, Pickups, Portal, WaveDirector, EnemyReplicator, WeaponService (Holy Ground zones), Pause clock, NetBatch). Builds live in Upgrades per player; picks/pauses are per party (`Upgrades.Party`). `server/Lobby.luau` forms parties on the portal pad and returns players.
- **Server is the simulation; clients only draw.** `server/Simulation.luau` steps every match; `Match.step` runs a fixed order: defeat check → Upgrades.step (pause control) → revives → run phases → WaveDirector → BossBrain (boss attacks; a charging boss is `locked` so movement skips it) → enemy movement → weapons → projectiles → contact damage → enemy shooting → gem pickup → item pickups → snapshots → `NetBatch.flush` to that match's members.
- **Client world switching:** the server sends `WorldReset(arenaName or nil)` when a player enters an arena or the lobby; `client/CurrentArena.luau` follows it, renderers drop everything on a reset, and HUD/results/clock read the current arena. Players carry an `ArenaName` attribute.
- **Enemies, gems, and projectiles are plain server data, not Parts or Humanoids.** Enemies replicate as binary position snapshots (`shared/EnemySnapshot.luau`, UnreliableRemoteEvent, ~20 Hz) plus reliable spawn/despawn events; clients pool primitive models and interpolate 100 ms behind. Gems only send spawn/collected events; projectiles only send a spawn event (clients compute the straight line) and a removal if they stop early. Other weapon visuals (lightning arcs, Holy Ground zones, Frost Nova chill) go through the visual-only `WeaponEffects` remote (`client/EffectRenderer.luau`; chill tint in EnemyRenderer). Enemy slows are `EnemyService.slow`; player damage goes through `Characters.damage` (Armor applies there). Hits use spatial hashes (`server/SpatialHash.luau`), never `.Touched`.
- **Game clock** (`shared/GameClock.luau`, owned by `server/Pause.luau`): server time minus time spent paused. All gameplay timing (stage timers, cooldowns, projectiles, blade angles, snapshots) uses it, so pausing freezes everything. Don't use `workspace:GetServerTimeNow()` for gameplay; use `Pause.now()` on the server and `GameClock.read(arena)` on clients.
- **Shared stat math:** `shared/BuildStats.luau` turns a build (weapon/passive levels, replicated as `W_<id>` / `P_<id>` Player attributes; weapon level 6 = evolved) into stats; both server hits and client visuals use it. `shared/BladeOrbit.luau` does the same for blade angles.
- **Run phases:** Countdown → Stage → Overtime (portal) → Transition → … ; the last stage ends in a `Boss` phase instead (Config.Waves `finalBoss`, killing it wins). Elites are a spawn flag (`EnemyService.spawn(..., elite)`), replicated in SpawnInfo.
- **Run state lives in each match's Arena model attributes** (`Phase`, `Stage`, `PhaseEndsAt`, `PortalCharge`, `PartyLevel`, `PartyXP`, `XPToNext`, `Kills`, `EnemiesAlive`, `BossName`, `BossHealth`, `ClockOffset`, `PausedAt`, `Result*`, `EndedAt`). The HUD reads them, and so can MCP tests. Player attributes: `ArenaName`, `OnPad`, `Downed`, `ReviveProgress`, `InvulnerableUntil`, `W_*`/`P_*` build levels.
- **Meta progression:** `server/Meta.luau` is the only gameplay code that touches `server/PlayerData` (data shape in `shared/Config/PlayerData.luau`: shards, hero, heroes, altar, stats). It grants run Shards (`shared/ShardReward.luau`, shared so the results screen shows the same breakdown), handles the lobby remotes (SelectHero, UnlockHero, BuyAltarUpgrade: lobby only, rate-limited, check-and-spend inside one `PlayerData.update`), and gives `Upgrades` each player's **loadout** (hero weapon + permanent bonuses from `shared/MetaStats.luau`). Permanent bonuses ride on the build as `build.bonus` and replicate as `B_<field>` attributes. Mirrored Player attributes: `Shards`, `Hero`, `ResultShards`, `ResultGreed`. Clients read saved data through `client/PlayerDataClient.luau`; the Hero stand and Altar (`server/LobbyStands.luau`) open menus via ProximityPrompts (`client/UI/LobbyMenus.luau`).
- **UI is built in code** (`client/UI/`, helpers `Create.luau` and `Theme.luau`: palette, fonts, panel/label/bar/button). Upgrade icons are emoji in `Config/Upgrades.luau` (`icon` fields).
- **Presentation is client-only and event-driven:** `SoundPlayer` (pooled 2D sounds, per-sound `minInterval`, per-category volume) + `SoundHooks` (which event plays what) + `Music` (crossfades by world/phase); `Particles` (one emitter per preset, moved and `Emit`ted; pooled flash lights); `HitEffects` (sparks, puffs, damage numbers from `EnemiesHit`, which carries id/damage pairs and arrives before the frame's despawns); `PlayerFeedback` (hurt flash, camera shake via `CameraController.shake`, level/evolve rings). Tuning in `Config/Audio.luau` and `Config/Effects.luau`.
- **Picks:** level-ups pause the party after a cooldown; chest picks pause right away (the offer's `chest` flag gives the TREASURE! title); Head Start picks open in the countdown without a pause.
- **Arena and enemy art are built in code** (`server/Arena.luau`, `client/EnemyModels.luau`), because the place file is gitignored. Characters spawn via `Characters.spawn` (CharacterAutoLoads is off).

## Testing in Studio via MCP

- Keep Studio's window in front, or screenshots come back blank and the client throttles to ~15 fps.
- `execute_luau` runs in the plugin's own Lua VM: `require` gives a fresh, unstarted copy of a module, so you can't reach live module state. Read instance attributes instead, or drive the game with dev commands.
- **Dev commands** (Studio only, `server/DevCommands.luau`): `workspace:SetAttribute("Dev_Command", "<cmd>")` (acts on the first player's match; arenas live at `workspace.Arenas.Arena<slot>`) with `skip`, `stage <n>`, `killall` (crates too), `god`, `xp <n>`, `freezexp on|off` (no XP, so no level-up pauses: use for benchmarks; it persists across runs, so always pass on/off), `give <id> <level>` (0 removes, 6 evolves a weapon), `spawn <kind>` (incl. `Crate`, `Ogre`), `elite <kind>`, `boss` (jump to the final boss fight; `skip` there kills it), `drop <Chest|Meat|Bomb|Magnet>`, `party` (start the pad's party now), `lobby` (everyone back to the lobby), `down` (down the first player), `shards <n>` (give the first player Shards), `resetmeta` (wipe the first player's Shards/heroes/Altar/stats; with API access on this overwrites real saved data).
- **Solo test flow:** players spawn in the lobby; teleport onto the pad (`character:PivotTo(CFrame.new(0, 4, -20))`) and run `party`, then wait for the arena's `Phase` to reach `Stage`.
- **Solo level-up pauses wait forever for a pick**, so long automated tests either `freezexp on` or click the picker cards; if a test shows nothing moving, check the Arena's `PausedAt` first; otherwise a script waiting on game time hangs.
- **Weapon benchmark:** `god` + `freezexp on`, one evolution alone (no passives), then for each weapon `stage 2` + `skip` for a **fresh** overtime (overtime keeps ramping, so a weapon measured later looks worse), wait 5s, and sample `EnemiesAlive` every 0.5s for 20s (lower average = better clearing; raw kills saturate at the spawn rate). Stage 3 no longer has an overtime (it ends in the boss). Latest (2026-10-28): Thunderstorm 34, Arrow Storm 30, Meteor 37, Bladestorm 42, Sanctuary 42, Blizzard 46 (its freeze holds enemies at the edge of its radius, so it clears less but protects more); single runs vary by a few points.
- **Screenshots skip AlwaysOnTop BillboardGuis** (damage numbers, health bars, the downed sign); to check one, set `AlwaysOnTop = false` on it from a Client `execute_luau` first. Studio must be visible (not minimized) or the client stops rendering and screenshots time out.
- **PlayerGui drops everything but ScreenGuis (ResetOnSpawn off) when the character respawns**, which happens on entering an arena; keep billboards elsewhere or recreate them.
- Studio's virtual input can't send the "1" key (use numpad 1 or click). Clicks work with `instance_path`, e.g. `LocalPlayer.PlayerGui.UpgradePicker.Container.Cards.Card1`.
- The DataStore warnings at startup are expected while "Enable Studio Access to API Services" is off; PlayerData falls back to unsaved defaults.
- When editing files with scripts, write bytes (or LF) explicitly; the repo enforces LF via `.gitattributes` and StyLua won't fix line endings inside `-- stylua: ignore` blocks.

## How this project is set up

- Roblox experience built in **Luau**, with code living on disk and synced into Roblox Studio by **Rojo**.
- Toolchain is pinned in `rokit.toml` (Rojo, StyLua, Selene, and Wally if added). Do not install tools globally.
- `default.project.json` defines how `src/` maps onto the Roblox DataModel. Read it before creating new top-level folders.
- The `.rbxl` place file (if present) holds the map, models, and UI built in Studio. It is not the source of truth for code.

### Layout

```
src/
  server/   -> ServerScriptService.Server       (server-only logic, never seen by clients)
  client/   -> StarterPlayer.StarterPlayerScripts.Client
  shared/   -> ReplicatedStorage.Shared         (modules used by both sides, config, types)
```

File naming (Rojo conventions):
- `*.server.luau` → Script, `*.client.luau` → LocalScript, `*.luau` → ModuleScript
- `init.luau` / `init.server.luau` turns a folder into that script, with siblings as its children

## Rules for editing

1. **Code changes go in `src/` only.** Never edit script source through the Studio MCP tools (`multi_edit` etc.) — Rojo will overwrite it on the next sync and the change will be lost. If a script exists only in Studio, move it into `src/` first.
2. Every Luau file starts with `--!strict`. Fix type errors rather than downgrading to `--!nonstrict`.
3. Before finishing a task, run:
   - `stylua src` (format)
   - `selene src` (lint) — resolve warnings, don't suppress them without a comment explaining why
4. Keep modules small and single-purpose. Prefer a ModuleScript in `shared/` or `server/` over a large script.
5. Don't add a dependency (Wally package) without asking first.
6. Make small, reviewable changes and commit at logical points with clear messages. Never commit secrets, API keys, or Open Cloud tokens.

## Architecture rules

- **The server is authoritative.** Assume every client is an exploiter.
  - Never trust values sent from the client (damage, currency, positions, purchase results, cooldowns).
  - Every `RemoteEvent` / `RemoteFunction` handler on the server validates argument types, ranges, and rate-limits the caller.
  - Avoid `RemoteFunction` calls from server to client.
- Define all remotes in one place (e.g. `shared/Remotes.luau`) rather than creating them ad hoc.
- Game tuning values (prices, cooldowns, drop rates) live in `shared/Config/` modules, not scattered as magic numbers.
- Clean up connections and instances when players leave or objects are destroyed; avoid memory leaks from lingering `:Connect` handlers.
- Prefer `task.wait` / `task.spawn` / `task.defer` over the deprecated `wait` / `spawn` / `delay`.

## Data and monetization

- Player data is saved through a single data module on the server (session locking, retries, autosave, save on `PlayerRemoving` and `game:BindToClose`). Never call DataStore APIs directly from gameplay code.
- `MarketplaceService.ProcessReceipt` must be idempotent: record each `PurchaseId` as granted and only return `PurchaseGranted` after the grant has been saved.
- Game pass ownership is checked on the server, not the client.
- Follow Roblox Community Standards and monetization policies (no paid random items without disclosed odds, no misleading purchase prompts).

## Studio MCP server

Studio exposes an MCP server (`Roblox_Studio`). Use it to:
- Inspect the live DataModel (`search_game_tree`, `inspect_instance`) — especially things built in Studio rather than in `src/`.
- Playtest: `start_stop_play`, then `get_console_output` and `screen_capture` to verify a change actually works.
- Run one-off Luau in Edit mode (`execute_luau`) for inspection or building non-script content (parts, folders, attributes).
- Look up current Engine API docs with `http_get` when unsure whether an API is current or deprecated.

Do not use it to edit scripts (see rule 1). Ask before running Luau that deletes or bulk-modifies instances in the place.

## Verifying work

A task isn't done until:
- StyLua and Selene pass,
- Rojo is syncing without errors,
- and, for gameplay changes, a playtest via the Studio MCP server shows the expected behavior with no new errors in the output log.

If something can't be verified (e.g. MCP not connected), say so explicitly instead of assuming it works.

## Commands

```
rokit install          # install pinned tools
rojo serve             # start syncing src/ into Studio (then click Connect in the Rojo plugin)
rojo build -o build.rbxl   # build a place file from the project
stylua src             # format
selene src             # lint
wally install          # install packages (only if Wally is in use)
```
