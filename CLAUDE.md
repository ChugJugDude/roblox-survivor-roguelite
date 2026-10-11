# CLAUDE.md

Guidance for Claude Code when working in this repository.

## Project

- **Game:** Fantasy survivor-like roguelite, solo + co-op (1–4 players), low-poly stylized
- **Design:** Full design is in `docs/design.md`. Read it before starting gameplay work, and check which milestone we're on.
- **Current milestone:** M1 (solo run loop) is built and committed; waiting on the design doc's playtest gate ("is a solo run fun for 10 minutes?"). Next is **M2 (co-op)**. See "Status" below.
- **Genre / core loop:** move to dodge and collect XP gems while weapons auto-fire (seconds); level up and pick 1 of 3 upgrades, survive 3 short stages and charge the portal at each stage end (one ~10 min run); spend Shards on permanent upgrades between runs (session, M3). Details in `docs/design.md` §3.
- **Target players:** TODO — age range. Platform: mobile-first (one-thumb movement is a design pillar).
- **Monetization:** principles only so far (no pay-to-win; cosmetics and convenience) — `docs/design.md` §12. Not until the core loop is fun.

## Status (last updated 2026-10-09)

- **M0** done. **M1** done in 6 steps (commits `707138e`..`6f2d3cb`), then playtest-driven changes: a stronger starting Spinning Blade (`837740b`), pausing the game for level-up picks (`d1c0c08`), and a polish pass (2026-10-11): readable crimson enemy shots (`02819d8`), multi-target Arrow Storm + archer cap of 8 (`067f1e6`), supply crates and meat/bomb/magnet pickups (`2b4aa58`).
- **Playtest feedback so far:** the loop is fun; the user won a full run after the blade buff (stage 1 easy, stages 2 and 3 close). Archer shots are dodgeable, Giant HP and portal charge feel right, stage-1 level-up pacing is good. The 2026-10-11 polish (shots, Arrow Storm, archer cap, crates/pickups) hasn't been playtested yet. Backlog: projectile-deleting "warding rings" item (design doc §9).
- **Not yet verified:** a full natural run without dev commands; low-end phone performance (Studio device emulator at the 200-enemy cap); co-op pause behavior (all players picking, 15s idle limit, "WAITING FOR OTHERS") — needs 2 players, test in M2.
- **Known follow-ups:** M2 must turn the run-level server modules (Run, EnemyService, Progression, WaveDirector, Portal, Chests, ProjectileService, Pause) from module-level singletons into per-arena objects; builds in Upgrades are already per player. Boss/portal bars sit close to the player on short screens (M4 UI pass). Level-up picks can pile up with no cap.
- **Working style:** for multi-step milestones, the user wants to discuss the plan first — remind them to switch to plan mode (Shift+Tab) before planning. Commit after each verified step.

## Architecture (gameplay)

- **Server is the simulation; clients only draw.** One fixed-order Heartbeat tick in `server/Simulation.luau`: Upgrades.step (pause control) → Run → WaveDirector → enemy movement → weapons → projectiles → contact damage → enemy shooting → gem pickup → chests → replication → `NetBatch.flush()`.
- **Enemies, gems, and projectiles are plain server data, not Parts or Humanoids.** Enemies replicate as binary position snapshots (`shared/EnemySnapshot.luau`, UnreliableRemoteEvent, ~20 Hz) plus reliable spawn/despawn events; clients pool primitive models and interpolate 100 ms behind. Gems only send spawn/collected events; projectiles only send a spawn event (clients compute the straight line) and a removal if they stop early. Hits use spatial hashes (`server/SpatialHash.luau`), never `.Touched`.
- **Game clock** (`shared/GameClock.luau`, owned by `server/Pause.luau`): server time minus time spent paused. All gameplay timing (stage timers, cooldowns, projectiles, blade angles, snapshots) uses it, so pausing freezes everything. Don't use `workspace:GetServerTimeNow()` for gameplay; use `Pause.now()` on the server and `GameClock.read(arena)` on clients.
- **Shared stat math:** `shared/BuildStats.luau` turns a build (weapon/passive levels, replicated as `W_<id>` / `P_<id>` Player attributes; weapon level 6 = evolved) into stats; both server hits and client visuals use it. `shared/BladeOrbit.luau` does the same for blade angles.
- **Run state lives in Arena model attributes** (`Phase`, `Stage`, `PhaseEndsAt`, `PortalCharge`, `PartyLevel`, `PartyXP`, `XPToNext`, `Kills`, `EnemiesAlive`, `BossName`, `BossHealth`, `ClockOffset`, `PausedAt`, `Result*`). The HUD reads them, and so can MCP tests.
- **UI is built in code** (`client/UI/`, helper `client/UI/Create.luau`). Placeholder look; polish is M4.
- **Arena and enemy art are built in code** (`server/Arena.luau`, `client/EnemyModels.luau`), because the place file is gitignored. Characters spawn via `Characters.spawn` (CharacterAutoLoads is off).

## Testing in Studio via MCP

- Keep Studio's window in front, or screenshots come back blank and the client throttles to ~15 fps.
- `execute_luau` runs in the plugin's own Lua VM: `require` gives a fresh, unstarted copy of a module, so you can't reach live module state. Read instance attributes instead, or drive the game with dev commands.
- **Dev commands** (Studio only, `server/DevCommands.luau`): `workspace.Arena:SetAttribute("Dev_Command", "<cmd>")` with `skip`, `stage <n>`, `killall` (crates too), `god`, `xp <n>`, `freezexp` (no XP, so no level-up pauses: use for benchmarks), `give <id> <level>` (0 removes, 6 evolves a weapon), `spawn <kind>` (incl. `Crate`), `drop <Chest|Meat|Bomb|Magnet>`.
- **Solo level-up pauses wait forever for a pick**, so long automated tests either `freezexp` or click the picker cards; otherwise a script waiting on game time hangs.
- **Weapon benchmark:** stage 3 overtime, `god` + `freezexp`, one evolution alone, then sample `EnemiesAlive` every 0.5s for 20s (lower average = better clearing; raw kills saturate at the spawn rate). Baseline 2026-10-11: Meteor 84, Bladestorm 92, Arrow Storm 71.
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
