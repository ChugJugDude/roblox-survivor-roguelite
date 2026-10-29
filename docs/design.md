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
- **Feel (M4):** every hit sparks and shows a damage number (big hits gold), kills puff, elites and bosses burst in gold. Weapons look like what they are: swords with swing trails, fletched arrows, fireballs trailing flame, lightning that sparks where it strikes, ice that encases frozen enemies, Holy Ground as a consecrated circle cast up rune by rune. Getting hurt flashes the screen edges red and shakes the camera. Sound: licensed Creator Store effects and music (lobby, run, boss), with mute buttons and per-weapon volume sliders.
- **UI:** one shared theme (dark rounded panels, kind colors: weapons orange, passives blue, evolutions gold). Mobile-first placement: build tiles and health top left (the bottom left is the thumbstick), objectives on the right, only the stage panel and boss bar top middle.

## 3. Core loop

**Moment to moment (every few seconds):** move to dodge enemies and collect XP gems; weapons fire automatically.

**Run loop (~10 minutes, "race the clock"):**
1. Pick a hero (starting weapon + passive).
2. A run is **3 short stages (~3 min each)** in the arena, each harder than the last. Waves escalate in density and enemy variety within a stage.
3. Level up → choose 1 of 3 upgrades (new weapon, weapon level, passive, or evolution).
4. A **Goblin Giant mini-boss** appears mid-stage and drops a chest (bonus upgrade).
   - **Supply crates** appear near the player every ~35s; weapons break them and they drop an item: **meat** (heal 30%), a **bomb** (clears the screen, hurts bosses), or a **magnet** (pulls in every gem). Regular enemies rarely (0.5%) drop one too. This is how a player recovers when low.
5. When a stage's timer runs out, **overtime** starts: a portal opens and spawns ramp up hard. Stand in the portal to charge it; a full charge moves the party to the next stage.
6. Stage 3 has no final portal: when its timer runs out, the **Ogre boss** arrives, and killing it wins the run. Normal stage-3 spawns keep coming (no overtime ramp) along with the Ogre's own adds.
7. Win or die → earn **Shards** based on time survived, kills, stages cleared, giants slain, and a victory bonus (×Greed). Only players still in the run when it ends are paid.

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

Heroes differ in starting kit and passive only. All upgrades are available to every hero. A hero's passive is an **innate bonus**: it doesn't take one of the 4 passive slots and doesn't count toward evolutions. Heroes are picked at the **Hero stand** in the lobby.

## 6. Upgrades (v1 target: ~20)

Three kinds, all offered through the level-up choice:

- **Weapons (6):** max 4 equipped per run. Each has 5 levels.
  - Spinning Blade, Volley Arrows, Fireball.
  - **Chain Lightning:** strikes the nearest enemy, then jumps to the nearest enemy it hasn't hit (more jumps and bolts with levels).
  - **Frost Nova:** when an enemy is close, a burst around the player damages and **slows** everything in range (bosses take half the slow). Slowed enemies are tinted icy.
  - **Holy Ground:** blesses the ground at the player's feet (plus extra zones nearby at higher levels); enemies walking in burn once per tick until it fades.
- **Passives (9 in v1):** max 4 per run. Each has 5 levels.
  - Might (+damage), Haste (−cooldown), Reach (+area), Swiftness (+move speed), Vitality (+max HP), Magnet (+pickup radius), **Armor** (6–30% less damage taken), **Regen** (1–5 HP per second), **Warding** (1–5 orbiting rings that destroy enemy shots they touch and nick enemies).
  - Later ideas: Multishot, Duration, Luck. (Greed is an Altar upgrade.)
- **Evolutions (2–4 in v1):** once a weapon is max level and you **own its paired passive (any level)**, the evolution appears as a level-up choice (Survivor.io style), turning the weapon into an upgraded version. This is the main build-crafting payoff.
  - Spinning Blade + Might → Bladestorm
  - Volley Arrows + Swiftness → Arrow Storm (fans at up to 3 enemies in different directions, so it answers threats from all sides)
  - Fireball + Reach → Meteor
  - Chain Lightning + Haste → Thunderstorm (four bolts at once)
  - Frost Nova + Armor → Blizzard (huge radius; **freezes** enemies for 1.5s: no moving, attacking, or shooting. Bosses are only slowed 50%)
  - Holy Ground + Regen → Sanctuary (three wide zones that also heal any player standing in them; the first zone of each cast follows its caster, so the caster heals on the move and teammates heal when near them or walking through the others)
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
| Elite (goblin or archer) | 1.6x size, gold glow, x8 HP, x1.5 damage, x5 XP; one every 45s of a stage | Drops a chest |
| Supply crate | Doesn't move or attack; breakable | Drops meat, a bomb, or a magnet |
| **Mini-boss: Goblin Giant** | Slow, tanky, big hitbox; appears mid-stage | Drops a chest |
| **Boss: Ogre** | Cycles attacks: ring of 16 crimson shots, summons 6 goblins, and a charge down a red ground lane (1.1s warning). Below 33% HP it enrages: faster attacks, double rings | End-of-run climax: replaces stage 3's portal |

A **wave director** controls spawns over time: which enemy types are allowed, spawn rate, max alive count, and elite/boss timings. All of it lives in config so runs can be tuned without code changes.

Per-kind caps keep any one threat from taking over: at most **8 skeleton archers** alive at once, so overtime can't ring the player with shooters they can't reach.

Readability rule: **enemy shots are solid crimson orbs drawn above everything the player has** (no player effect uses red), so they stay visible even inside evolved weapons. Boss warnings are solid red ground lanes.

Skeleton archers face the player they're aiming at.

## 8. Co-op

- Parties of 1–4. Solo is the same mode with a party of 1.
- **XP is shared** across the party, but each player gets their own level-up choice.
- **Level-ups pause the whole party.** XP is shared, so everyone levels at the same moment: the game pauses and every player picks at once, resuming when all have chosen (with 2+ players, a 15-second limit picks at random for anyone idle). After a pause, the next one waits at least 5 seconds of play; level-ups in between come up together in that next pause. Everyone gets a brief invulnerability grace on resume.
- **Chest picks pause too** (changed after playtesting: an unpaused pick got players hit while reading cards): the pause starts right away, without the cooldown, and in co-op the others wait as with level-ups.
- **Downed, not dead:** a hit that would kill instead downs the player: they can't move, enemies ignore them, and their weapons stop. A teammate standing within ~5 studs for 3 seconds revives them at 50% HP with a moment of invulnerability (progress holds if the teammate steps away). If the whole party is down, the run ends. Solo is a party of 1, so going down ends the run.
- **Scaling with party size** (fixed at run start), per player past the first: enemy HP +50%, spawn rate +35%, max enemies alive +35% (still capped). Per-player Shard rewards stay the same, so co-op is never punished.
- Each player's build is their own; synergies between players (e.g., one slows, one does AoE) are a stretch goal, not v1.

## 9. Meta progression

- **Shards:** earned every run (win or lose). Saved per player.
- **Permanent upgrades (the "Altar"):** small stat boosts bought with Shards at the Altar in the lobby, cost ×1.5 per level. 8 in v1: Might, Vitality, Swiftness, Magnet, Greed (+Shards), Reroll (+1 per run), Rescue (revive teammates faster), and **Head Start** (free upgrade picks during the run's countdown; replaces "Starting XP", which doesn't fit shared party XP). Maxing everything costs ~4,900 Shards (~20 winning runs).
- **Hero unlocks:** Pyromancer for 400 Shards.
- Tuning lives in `Config/Meta.luau` (Shard formula, heroes, Altar costs and effects).
- **The Codex (collection log, M4):** a lectern in the lobby. Tabs for weapons and evolutions, passives, and enemies (elites and bosses included), each a dark "?" until discovered in a run, with found counts. Discoveries are saved per player; everyone in a party discovers what the party kills.

Stretch (post-v1): daily quests, a second map, more heroes, harder difficulty tiers, cosmetic unlocks from achievements.

**Backlog ideas (from playtests):**
- ~~Chest polish~~ and ~~a pause menu with the build~~: built in M4 chunk 4. The pause menu pauses solo runs; in co-op it only shows the build. A "rarity" reveal before chest picks is still an idea.
- **Graphics quality:** High (every effect) or Low (fewer particles and damage numbers, no extra lights or sword trails), Low by default on phones, switchable in Settings.
- ~~Warding rings~~: built in M4 as the **Warding** passive (§6).

## 10. Structure and flow

**v1 approach: one place, instanced arenas.**
- Players spawn in a small **lobby** (a town square) with a hero select stand, the Altar, and a **portal**.
- Players who step into the portal together (party of up to 4, 10-second countdown that starts with the first player on the pad; stepping off leaves; anyone on the pad can press **Start now**) are moved into their **own arena instance**, built far from other arenas in the same server (up to 4 at once; the pad waits if all are busy).
- On run end, a results screen with **Back to lobby** (automatic after 20 seconds). An arena is torn down once its last player leaves.
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
| M5 | Progression (proposed, §16) | Worlds with new enemies and bosses, gear, lobby loot chests | TBD |
| M6 | Launch prep | Monetization, thumbnail/icon, maturity questionnaire, mobile test, publish | TBD |

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

## 16. Progression loop (proposal, to plan next)

The core run is fun and the Altar and heroes give some meta goals, but there isn't enough to keep players coming back after a few wins. The loop: **finish a world to unlock the next, harder one; bring back loot chests; open them in the lobby for gear that changes how your build plays.**

- **Worlds.** Today's arena becomes World 1 (the Meadow). Each new world has 3 stages and a boss, a new floor, wall, and light palette with a few props, and its own enemy mix. Clearing a world (beating its boss) unlocks the next. Later worlds scale enemy HP and damage and pay more Shards. A world select on the portal pad (the party leader picks). Ideas: Meadow → Frozen Wastes → Haunted Crypt → Volcano.
- **New enemies, mostly reskins.** Each world swaps models and colors and tweaks stats or behavior on the existing kinds (chase, ranged, swarm, mini-boss), for example ice wolves (fast chasers), frost archers (slowing shots), skeleton knights (tanky), cultists (casters that summon). It's all config: `Config.Enemies` + `EnemyModels`, so a world costs mostly art and tuning.
- **New bosses.** One per world on `BossBrain`'s attack-pattern system: the existing attacks (rings, summons, charges) in new mixes, plus one signature attack each, e.g. an ice boss that freezes a lane, or a lich that raises the dead.
- **Gear.** Three slots: **weapon charm** (boosts one weapon, e.g. +1 blade or +20% Fireball blast), **armor** (health, armor, or regen), and **trinket** (utility: pickup range, XP, Shards, cooldowns). Rarity (common / rare / epic / legendary) sets the number and size of bonuses. Gear is equipped in the lobby and applies like Altar bonuses (`build.bonus` via `MetaStats`), so it's server-side and easy to balance. Duplicates can be salvaged for Shards.
- **Loot chests in the lobby.** Runs drop chest *keys* or sealed chests (more for wins and bosses, better in later worlds). Chests are opened at a lobby stand with a reveal animation. They're earned, never sold; if chests or keys are ever sold for Robux, the odds must be shown (Roblox policy) and the items stay non-pay-to-win.
- **Daily/weekly goals** (later): small quests ("kill 500 enemies with Fireball") that pay keys, to give a reason to log in.
- **Data:** new saved fields (unlocked worlds, inventory, equipped gear, keys) go through `PlayerData`'s default-filling, so older saves keep working.
