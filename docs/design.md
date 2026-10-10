# Game Design Doc

> Working title: **TBD** (placeholder ideas: *Emberfall*, *Hollow Crown*, *Wildwood Siege*)
> Status: pre-production, v1 scope
> Last updated: 2026-10-09

## 1. Pitch

A fantasy survivor-like roguelite for Roblox. Drop into a cursed arena alone or with up to 3 friends, survive endless waves of monsters with auto-attacking weapons, pick upgrades as you level, and stack them into broken builds. Beat the boss at the end of the run, earn shards, and unlock permanent upgrades and new heroes for the next run.

**Pillars** (every feature should serve at least one):
1. **Build crafting is the fun.** Upgrade choices should create synergies worth chasing, not flat stat bumps.
2. **Short, replayable runs.** A full run fits in ~10 minutes; dying still makes progress.
3. **Better with friends.** Co-op multiplies the chaos without making solo feel worse.
4. **Plays great on a phone.** One-thumb movement; everything else is automatic.

## 2. Look and feel

- **Art style:** low-poly, stylized and cartoony fantasy. Bright, readable colors; chunky silhouettes; exaggerated hit effects.
- Players keep their own Roblox avatars (blocky or not); the world and enemies are low-poly so both read well together.
- **Readability over detail:** enemies, projectiles, and pickups must be identifiable at a glance on a small screen, even with 100+ things on screen.
- Asset sources: primitive parts, Creator Store low-poly packs (check licenses), and Studio's mesh/material generation for one-offs.

## 3. Core loop

**Moment to moment (every few seconds):** move to dodge enemies and collect XP gems; weapons fire automatically.

**Run loop (~10 minutes, "race the clock"):**
1. Pick a hero (starting weapon + passive).
2. A run is **3 short stages (~3 min each)** in the arena, each harder than the last. Waves escalate in density and enemy variety within a stage.
3. Level up → choose 1 of 3 upgrades (new weapon, weapon level, passive, or evolution).
4. A **Goblin Giant mini-boss** appears mid-stage and drops a chest (bonus upgrade).
5. When a stage's timer runs out, **overtime** starts: a portal opens and spawns ramp up hard. Stand in the portal to charge it; a full charge moves the party to the next stage.
6. Charging the portal after stage 3 wins the run. (M4: the **Ogre boss** guards the end of stage 3.)
7. Win or die → earn **Shards** based on time survived, kills, and bosses.

Why stages instead of one long timer: short goals every few minutes keep the payoff coming, which suits Roblox players better than one 10–15 minute stretch.

**Session / meta loop:** spend Shards on permanent upgrades and hero unlocks → start another run slightly stronger, with new options.

## 4. Controls

| Platform | Move | Other |
| --- | --- | --- |
| Mobile | Virtual thumbstick | Tap to choose upgrades |
| PC | WASD | Mouse/number keys for upgrade choice |
| Console | Left stick | D-pad/face buttons for upgrade choice |

All weapons auto-fire and auto-target (nearest enemy unless the weapon says otherwise). No aiming required in v1.

## 5. Heroes (v1: 3)

| Hero | Starting weapon | Passive | Unlock |
| --- | --- | --- | --- |
| Knight | Spinning blade (melee orbit) | +Max HP | Default |
| Ranger | Volley arrows (nearest target) | +Move speed | Default |
| Pyromancer | Fireball (AoE on impact) | +Area size | Shards |

Heroes differ in starting kit and passive only. All upgrades are available to every hero.

## 6. Upgrades (v1 target: ~20)

Three kinds, all offered through the level-up choice:

- **Weapons (6):** max 4 equipped per run. Each has 5 levels.
  - Spinning Blade, Volley Arrows, Fireball, Chain Lightning, Frost Nova, Holy Ground (damage zone).
- **Passives (~12):** max 4 per run. Each has 5 levels.
  - Examples: Might (+damage), Haste (−cooldown), Reach (+area), Swiftness (+move speed), Vitality (+max HP), Magnet (+pickup radius), Multishot (+projectiles), Duration, Armor, Regen, Luck, Greed (+Shards).
- **Evolutions (2–4 in v1):** once a weapon is max level and you **own its paired passive (any level)**, the evolution appears as a level-up choice (Survivor.io style), turning the weapon into an upgraded version. This is the main build-crafting payoff.
  - Spinning Blade + Might → Bladestorm
  - Volley Arrows + Swiftness → Arrow Storm
  - Fireball + Reach → Meteor
- **M1 set (9):** Spinning Blade, Volley Arrows, Fireball; Might, Haste, Swiftness, Reach, Vitality, Magnet; plus the 3 evolutions above.

Design rules:
- Every upgrade should be noticeable when picked. Avoid tiny +2% bumps.
- Offer weapons more often early, passives more often once weapon slots are full.
- One reroll per run by default (more via meta upgrades).

## 7. Enemies (v1: 4 + mini-boss + boss)

| Enemy | Behavior | Role |
| --- | --- | --- |
| Goblin | Walks straight at nearest player | Filler / XP source |
| Bat swarm | Fast, low HP, moves in groups | Pressure movement |
| Skeleton archer | Keeps distance, shoots slow projectiles | Forces dodging |
| Elite (any type) | Larger, glowing, more HP | Drops a chest |
| **Mini-boss: Goblin Giant** | Slow, tanky, big hitbox; appears mid-stage | Drops a chest |
| **Boss: Ogre** | Phases: summons adds, ring of projectiles, charge | End-of-run climax (M4) |

A **wave director** controls spawns over time: which enemy types are allowed, spawn rate, max alive count, and elite/boss timings. All of it lives in config so runs can be tuned without code changes.

## 8. Co-op

- Parties of 1–4. Solo is the same mode with a party of 1.
- **XP is shared** across the party, but each player gets their own level-up choice.
- **The game does not pause on level-up** (it can't, with other players). The player picking gets ~2 seconds of invulnerability and the choice UI stays on screen until they pick; their weapons keep firing meanwhile.
- **Downed, not dead:** at 0 HP a player is downed. A teammate standing next to them for 3 seconds revives them at 50% HP. If the whole party is down, the run ends.
- **Scaling with party size:** enemy HP and spawn rate scale up with players; per-player Shard rewards stay the same, so co-op is never punished.
- Each player's build is their own; synergies between players (e.g., one slows, one does AoE) are a stretch goal, not v1.

## 9. Meta progression

- **Shards:** earned every run (win or lose). Saved per player.
- **Permanent upgrades (the "Altar"):** small stat boosts bought with Shards, with increasing costs. ~8 in v1 (Might, Vitality, Swiftness, Magnet, Greed, Reroll +1, Revive speed, Starting XP).
- **Hero unlocks:** Pyromancer purchasable with Shards.
- **Collection log:** tracks weapons, evolutions, and enemies discovered. Cheap to build and gives completionists a goal.

Stretch (post-v1): daily quests, a second map, more heroes, harder difficulty tiers, cosmetic unlocks from achievements.

## 10. Structure and flow

**v1 approach: one place, instanced arenas.**
- Players spawn in a small **lobby** (a town square) with a hero select stand, the Altar, and a **portal**.
- Players who step into the portal together (party of up to 4, 10-second countdown) are moved into their **own arena instance**, cloned far from other arenas in the same server.
- On run end, players return to the lobby with a results screen.
- Server size kept small (e.g., 12–16) so the server never runs too many arenas at once.

**Later:** move runs to reserved servers in a separate place (TeleportService) once the game is proven. Better performance and isolation, but harder to test in Studio, so not worth it for v1.

## 11. Technical notes

- **Enemy performance is the main risk.** The game needs 100–200 enemies alive at once.
  - Don't use Humanoids for enemies. Use simple anchored models moved by a server-side update loop (or a lightweight custom mover).
  - Server owns enemy positions, HP, and damage; clients render and interpolate.
  - Pool and reuse enemy models instead of creating/destroying them.
  - Hard cap on alive enemies, configured per wave.
- **Server authoritative** for everything that matters: damage, XP, level-ups, upgrade choices (server offers the 3 options and validates the pick), Shards, purchases.
- Hit detection: spatial queries (`GetPartBoundsInRadius`, `GetPartsInPart`) or a simple grid/spatial hash on the server — not `.Touched`.
- All tuning (weapons, upgrades, enemies, waves, scaling, costs) lives in `src/shared/Config/`.
- Profile early: check server heartbeat and client FPS on a low-end phone (Studio device emulator) at max enemy count.

## 12. Monetization (decide details later; principles now)

Principles:
- **No pay-to-win**, especially because of co-op: friends shouldn't feel outclassed by someone who paid.
- Sell **cosmetics and convenience**, never raw power that can't be earned.
- Don't add monetization until the core loop is fun and players are coming back.

Candidates:
- **Game passes:** VIP (cosmetic aura + name tag + small Shard bonus), extra hero cosmetic slots, emotes for the lobby.
- **Developer products:** cosmetic skins for weapon effects (fire trail colors, arrow skins), Shard packs (careful — only if Shard upgrades stay modest).
- **Private servers** for friend groups (cheap, easy, fits the co-op pillar).
- Premium Payouts come automatically from Premium members' playtime.

## 13. Milestones (~10 hrs/week)

| # | Milestone | Done when… | Est. |
| --- | --- | --- | --- |
| M0 | Movement + one fight | Player moves in an arena, one enemy type chases, one auto-weapon kills it, player can die | Week 1 |
| M1 | Solo run loop | XP gems, leveling, choose 1 of 3, ~8 upgrades, wave director, 3 enemy types, run timer | Weeks 2–3 |
| M2 | Co-op | Lobby + portal, parties of 1–4, instanced arenas, shared XP, downed/revive, scaling | Weeks 4–5 |
| M3 | Meta progression | Player data saving, Shards, Altar upgrades, hero unlock, results screen | Weeks 6–7 |
| M4 | Content + polish | All v1 weapons/passives/evolutions, 5 enemies + boss, UI pass, sound, hit VFX | Weeks 8–9 |
| M5 | Launch prep | Monetization, thumbnail/icon, maturity questionnaire, mobile test, publish | Week 10 |

**Playtest gates:** after M1, play it and ask "is a solo run fun for 10 minutes?" After M2, play with friends. Don't move past a gate until the answer is yes.

Estimates are rough; slipping is normal. Cut scope (fewer upgrades, fewer enemies) before cutting quality of the core loop.

## 14. Success metrics (after launch)

- **Day 1 retention:** do players come back the next day?
- **Day 7 retention:** is the meta loop working?
- **Average session length** and **runs per session.**
- **Co-op rate:** share of runs with 2+ players.
- Payer conversion and revenue per daily user (only once monetization is live).

Roblox's discovery rewards retention over the first 28 days, so retention matters more than raw visits.

## 15. Open questions

- Final name and logo.
- Exact run length (10 min is a starting guess; tune from playtests).
- Does the boss need a separate arena phase, or spawn in the same arena?
- Should parties be able to queue with strangers (matchmaking) in v1, or friends/portal-only?
- How strong can Altar upgrades get before new players feel too weak in co-op with veterans?
