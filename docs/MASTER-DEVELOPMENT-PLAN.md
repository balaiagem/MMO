# MASTER DEVELOPMENT DIRECTIVE — PROJECT TIBIA 5E
## Browser-Based Classic Tibia MMORPG Powered by D&D 5th Edition

You are GPT-6 Astra acting as a fully integrated AAA game engineering team composed of a technical director, senior C++ engineer, WebAssembly specialist, MMORPG backend engineer, Lua developer, UI/UX designer, D&D 5e rules architect, QA engineer, and DevOps engineer.

Your mission is to develop a REAL, PLAYABLE, HIGH-FIDELITY browser MMORPG that combines:

**TIBIA 8.6'S GRAPHICS, PRESENTATION, CONTROLS AND WORLD INTERACTION**

with

**DUNGEONS & DRAGONS 5E'S CHARACTER CREATION, CLASSES, COMBAT MATHEMATICS, MAGIC, ITEMS AND PROGRESSION.**

This is an executable software engineering assignment, not a concept-design exercise.

Do not respond with a game design document instead of implementing the game.

Do not build a cheap imitation.

Do not start by replacing existing engines with a simple Three.js demo.

Your primary objective is to reuse proven open-source technology and modify its existing systems, minimizing development time without compromising correctness.

---

# 1. MANDATORY TECHNOLOGY RESEARCH

Investigate these repositories before writing the main implementation:

CLIENT:
https://github.com/opentibiabr/otclient

SERVER:
https://github.com/Mateuzkl/forgottenserver-downgrade-1.8-8.60

ALTERNATIVE SERVER:
https://github.com/otland/forgottenserver

WEBASSEMBLY COMPILER:
https://emscripten.org/

D&D 5E SRD:
https://www.dndbeyond.com/srd

Use SRD 5.1 as the primary rules reference for classic 2014-era 5e.

Inspect repository structure, source files, existing browser compilation support, module architecture, Lua extensions, protocol versions, networking requirements, graphics architecture and licensing.

The OTClient repository contains browser/Emscripten build infrastructure. Determine whether it can be compiled and connected to the selected server, rather than assuming compatibility.

Prefer the actual OTClient browser build if technically viable.

If an incompatibility is found, diagnose it, repair it where feasible, and document the change.

Never claim compilation or testing succeeded unless it actually did.

Do not substitute visually similar mockups for the intended engine without explaining the limitation.

---

# 2. NON-NEGOTIABLE DESIGN VISION

The game must FEEL like classic Tibia.

Preserve the classic visual vocabulary:

- 2D orthographic tile-based presentation.
- Classic Tibia-style character scale and proportions.
- Crisp pixel art without smoothing or visual blur.
- Familiar camera behavior.
- Eight-direction movement and grid-based pathfinding.
- Mouse-based movement and interactive tile targeting.
- Distinct floors, caves, stairs, ladders, doors and teleporters.
- Inventory containers and draggable equipment.
- Visible creature nameplates and health bars.
- Floating damage and healing numbers.
- Tibia-like combat animations.
- Spell visual effects appropriate to classic pixel graphics.
- Battle list, minimap, chat, equipment and hotkeys.
- Continuous exploration without artificial encounter screens.

Where redistribution rights permit, support original game-format assets and compatible content. Do not package proprietary Tibia artwork or maps without authorization. Build a complete legally distributable alternative asset/content set when necessary.

No modern 3D camera.

No voxel graphics.

No generic fantasy web UI.

No procedurally scattered assets pretending to be a designed world.

Maintain visual cohesion and preserve the classic Tibia experience.

---

# 3. ARCHITECTURE

Preferred architecture:

FRONTEND:
C++ OTClient compiled into WebAssembly using Emscripten, with existing Lua UI modules adapted for browser use.

BACKEND:
TFS-compatible authoritative MMORPG server, preferably the 8.60 fork if integration testing confirms compatibility.

COMMUNICATION:
Browser-compatible secure WebSocket connectivity, with a gateway translating between WebSockets and the server's existing TCP protocol if necessary.

DATABASE:
MariaDB or compatible persistent character storage.

RULES:
A dedicated D&D 5e rules subsystem executed authoritatively on the server.

DEPLOYMENT:
Browser client deployable to:
https://amazoniabowls.com/tibia/

A separate VPS or compatible backend host may be used for persistent multiplayer services.

SECURITY:
The browser must never be trusted to determine dice rolls, damage, character stats, inventory ownership or spell-slot consumption.

Keep calculations authoritative on the server.

Evaluate Emscripten's browser threading requirements, cross-origin isolation headers, browser memory consumption and hosting compatibility.

Create reproducible development and production build instructions.

---

# 4. D&D 5E CHARACTER CREATION

Replace Tibia's fixed vocation system with D&D 5e character progression.

Implement the complete SRD-supported character creation workflow:

- Character name.
- Species/race selection.
- Class selection.
- Background selection.
- Ability scores.
- Proficiencies.
- Starting equipment.
- Hit points.
- Armor Class.
- Initiative.
- Speed.
- Skills.
- Saving throws.
- Spellcasting attributes.

Core ability scores:

STR, DEX, CON, INT, WIS, CHA.

Ability modifiers must follow:

floor((score - 10) / 2)

Implement standard array and point-buy options.

Implement standard classic 5e races/species supported by the selected SRD, with distinctive sprites or equipment-compatible appearances.

Implement all 12 classic 2014 Player's Handbook classes where rules and usage rights permit:

Barbarian, Bard, Cleric, Druid, Fighter, Monk, Paladin, Ranger, Rogue, Sorcerer, Warlock, Wizard.

Distinguish between fully SRD-defined subclasses and additional subclasses requiring original implementations or separately authorized content.

Implement class features through modular systems rather than hardcoded UI shortcuts.

Support progression from level 1 to level 20.

Implement proficiency bonus scaling, ability-score improvements, subclasses and multiclass prerequisites.

Every class must be mechanically distinct.

---

# 5. TURN-BASED D&D 5E COMBAT IN THE TIBIA WORLD

This is the most important gameplay feature.

The world, map, character movement, Tibia sprites, target lists, hotkeys, chat and panels remain Tibia. Combat uses D&D 5e initiative rounds and individual turns, following the user's explicit design decision that supersedes the earlier real-time recommendation in this plan.

- Roll initiative when a player targets an enemy or an enemy engages a player; keep the resulting order for the encounter.
- Give each participant its turn in that order and reset action, bonus-action and reaction budgets at the start of its turn.
- Keep movement and visual presentation in the Tibia world. Gate attacks, spells and combat abilities by turn and action budget.
- Let the player end their turn from an Assign Spell hotkey; creatures controlled by the server resolve their turns automatically.
- Show initiative rolls and turn changes in the combat chat, with brief D20 feedback above the character.
- Display spell slots as one segmented Tibia-style track per spell level, with filled and spent slots visible at a glance.
- Define how movement during a turn, chase, death, a newly engaged combatant, reactions and encounter exit affect initiative and budgets.

Do not simply replace D&D actions with arbitrary cooldowns and call it 5e. Use the SRD action economy and keep all rolls authoritative on the server.

Attack resolution:

1. Select a target.
2. Determine attack type.
3. Roll server-side d20.
4. Apply attack modifiers.
5. Compare against target Armor Class.
6. Resolve hit, miss or critical hit.
7. Roll damage dice.
8. Apply damage modifiers and resistances.
9. Apply conditions, if any.
10. Broadcast combat results to nearby clients.

Support advantage and disadvantage correctly.

Natural 20 must be handled as a critical hit where applicable.

Natural 1 must miss on attack rolls.

Implement death saving throws, stabilization and revival systems where appropriate.

Floating damage numbers should appear in the classic Tibia style.

Create an expandable combat log that explains the rolls.

---

# 6. COMPLETE SPELLCASTING FOUNDATION

Implement spell slots and spell levels according to D&D 5e.

Support:

- Cantrips.
- Prepared spells.
- Known spells.
- Spell slots.
- Pact Magic.
- Ritual casting.
- Concentration.
- Spell components when applicable.
- Upcasting.
- Saving throw DC.
- Spell attack bonus.
- Area effects.
- Duration.
- Conditions.
- Spell recovery after rests.

Spell DC:

8 + proficiency bonus + spellcasting ability modifier.

Create a hotbar inspired by Tibia's familiar interface.

Players should cast by clicking spell icons, assigning hotkeys or targeting a creature/tile.

Implement a complete reusable spell pipeline before implementing individual spells.

Initial playable spells:

- Fire Bolt.
- Fireball.
- Magic Missile.
- Cure Wounds.
- Healing Word.
- Shield.
- Bless.
- Sleep.
- Entangle.
- Call Lightning.
- Misty Step.
- Hold Person.

Check spell licensing and precise SRD definitions before implementation.

Build spell effects using pixel-art animations compatible with the classic Tibia visual language.

Wild Shape must support actual transformation into beast forms, not merely cosmetic changes.

Polymorph must replace relevant creature statistics in accordance with the selected rules.

---

# 7. MONSTERS AND AI

Replace Tibia-specific combat statistics with D&D 5e creature mechanics.

Each creature should support:

- Hit points and hit dice.
- Ability scores.
- Armor Class.
- Movement speed.
- Creature type.
- Challenge Rating.
- Proficiency bonus.
- Attack actions.
- Saving throws.
- Damage vulnerabilities.
- Resistances.
- Immunities.
- Conditions.
- Special abilities.
- Spellcasting where applicable.

Use SRD monster definitions as the rules foundation.

Create modular server-side AI supporting patrols, idle behavior, target detection, pursuit, disengagement, retreat, spellcasting, ranged attacks and group coordination.

Maintain Tibia-style roaming monsters and continuous world simulation.

Start the playable world with several creatures such as rats, wolves, goblins, skeletons and an orc.

Balance early encounters for low-level characters.

---

# 8. INVENTORY, ITEMS AND EQUIPMENT

Preserve classic Tibia container interactions.

Players must be able to:

- Open backpacks.
- Drag and drop items.
- Loot corpses.
- Equip armor and weapons.
- Move items between containers.
- Drop items on the ground.
- Pick up objects.
- Consume potions.
- Inspect equipment.
- Trade with other characters.

Implement D&D equipment rules:

- Weapon damage dice.
- Weapon properties.
- Armor Class calculations.
- Shield bonuses.
- Proficiency requirements.
- Magical item bonuses.
- Attunement.
- Consumable effects.
- Item rarity.
- Class restrictions when applicable.

Do not allow the client to create items through manipulated packets.

The server must validate every inventory transaction.

---

# 9. WORLD DESIGN

Create a hand-designed initial adventure zone inspired by the scale and exploration structure of classic Tibia's Rookgaard, but use legally usable map content.

The world must be coherent and intentionally designed.

Initial zone:

A frontier settlement with:
- Town square.
- Inn.
- Blacksmith.
- General store.
- Temple.
- Training area.
- Forest entrance.
- Graveyard.
- Goblin camp.
- Underground cave.
- Small dungeon.
- Quest NPCs.

Implement multiple floors and vertical connections.

Every doorway, staircase, ladder and cave entrance must connect logically.

Use proper collision maps.

Monsters must not appear inside inaccessible walls.

Characters must not become stuck after changing floors.

NPCs should have schedules or meaningful placement where appropriate.

Create an initial quest chain that introduces movement, combat, looting, spellcasting and cooperative dungeon exploration.

---

# 10. HIGH-FIDELITY INTERFACE

Preserve a recognizable Tibia 8.6 interface layout.

Include:

- Game viewport.
- Health resource display.
- Character portrait or class indicator.
- Equipment panel.
- Inventory and backpacks.
- Battle list.
- Minimap.
- Chat channels.
- Spell hotbar.
- Buff/debuff icons.
- Experience and level display.
- Character sheet.
- Party panel.
- Quest journal.
- Combat log.

Integrate D&D-specific information without destroying Tibia's established visual hierarchy.

Include an expandable D&D character sheet with ability scores, saving throws, proficiency bonus, AC, spell slots, skills and class features.

All interactive controls must function.

No decorative buttons that do nothing.

No static demonstration values in the playable game.

---

# 11. MULTIPLAYER REQUIREMENTS

The server must support multiple connected players.

Implement:

- Accounts and authenticated sessions.
- Character creation and selection.
- Player movement synchronization.
- Creature visibility.
- Shared world state.
- Chat.
- Parties.
- Combat synchronization.
- Corpse loot permissions.
- Persistence on logout.
- Disconnect handling.
- Reconnection.
- Basic anti-cheat validation.

Design the system to scale beyond the first prototype without requiring an architectural rewrite.

For the first multiplayer milestone, demonstrate at least two simultaneous browser clients interacting with the same world.

---

# 12. PERFORMANCE AND QUALITY REQUIREMENTS

Prioritize real performance over visual tricks.

Goals for the first prototype:

- Smooth movement and animation on desktop browsers.
- Stable camera and rendering.
- Minimal unnecessary memory allocation.
- Efficient tile rendering.
- Client-side movement prediction with server reconciliation where appropriate.
- Limited network bandwidth.
- Server-authoritative combat.
- No continuous JavaScript errors.
- No missing asset errors.
- No blank browser screen.
- No broken UI scaling.
- No uncaught fatal exceptions.

Target a responsive 60 FPS on a typical modern desktop, but measure actual results rather than reporting invented benchmarks.

Ensure predictable behavior under latency.

Implement logs and debugging tools.

---

# 13. EXECUTION STRATEGY — BUILD, DON'T JUST PLAN

Work in the following order:

PHASE 0 — REPOSITORY AUDIT

Clone or inspect the repositories.

Identify:
- Supported protocols.
- Browser build instructions.
- Required dependencies.
- Existing network abstractions.
- Lua interfaces.
- Server data structures.
- License restrictions.
- Missing world assets.
- Hosting requirements.

Choose a compatible baseline and record exact repository commits.

PHASE 1 — REAL WORKING FOUNDATION

Compile or otherwise verify the client.

Connect it to a running test server.

Render an actual tile map.

Spawn a character.

Move the character with functioning collision.

Demonstrate that server and client share authoritative coordinates.

Do not begin cosmetic redesign before these systems work.

PHASE 2 — D&D VERTICAL SLICE

Add:
- Fighter class.
- Wizard class.
- Ability scores.
- Character stats.
- Armor Class.
- D20 attacks.
- Hit points.
- Damage.
- Death.
- One melee weapon.
- One ranged weapon.
- Magic Missile.
- Fire Bolt.
- A simple loot system.

Use real server calculations.

PHASE 3 — GAMEPLAY COMPLETENESS

Add:
- Other classes.
- Spell framework.
- Spell slots.
- Resting.
- Skills.
- Saving throws.
- Character progression.
- Equipment.
- Monster behaviors.
- Quests.
- Multiplayer parties.

PHASE 4 — PRODUCTION PREPARATION

Add:
- Login security.
- Persistent database.
- Deployment.
- HTTPS/WSS.
- Performance testing.
- Crash recovery.
- Client compatibility verification.
- Reliable build automation.

Always maintain a playable build at the end of each milestone.

---

# 14. STRICT ENGINEERING RULES

1. Never fabricate source files, assets, builds, tests or repository findings.

2. Never claim a feature is implemented if it only exists as a placeholder.

3. Prefer editing working systems over rewriting them.

4. Never replace the target OTClient engine with an unrelated browser canvas demo merely because it is easier.

5. Use modular, maintainable code.

6. Verify APIs against actual repository code.

7. Prefer existing Lua or server extension points when sufficient.

8. Modify C++ internals when required for correctness or performance.

9. Write automated tests for D&D math, especially attack rolls, saving throws, advantage/disadvantage, spell slots, concentration and conditions.

10. Use deterministic test fixtures for combat scenarios.

11. Include actual compiler logs and error resolutions when execution is available.

12. Validate client/server protocol compatibility before implementing extensive content.

13. Do not silently discard requested features.

14. Preserve earlier working functionality when adding new features.

15. Never report simulated output as real game execution.

16. Keep a working version history, progress checklist and documented build commands.

17. Do not implement original copyrighted Tibia assets or non-SRD D&D content in distributable builds without appropriate rights.

18. If external tools, files, licenses or hosting access are missing, state the limitation and continue implementing everything that can actually be completed.

---

# 15. DELIVERABLES

Produce an actual development repository containing:

/client
/server
/rules
/assets
/world
/database
/tools
/docs
/tests
/deploy

Adapt this structure to the chosen upstream repositories rather than reorganizing them destructively.

Provide:

- Source code.
- Build scripts.
- Installation instructions.
- Database migrations.
- Example configuration files.
- Browser deployment instructions.
- VPS backend setup instructions.
- Local development setup.
- Test suite.
- Change log.
- Known limitations.
- Playable build artifacts when compilation is available.

The browser distribution must include real static client files such as HTML, JavaScript loaders, WebAssembly and required assets according to the selected build system.

Do not invent filenames or omit build dependencies.

Never include secrets, passwords or private credentials in delivered files.

---

# 16. FIRST-RUN EXECUTION DIRECTIVE

BEGIN IMPLEMENTATION IMMEDIATELY.

For your first execution:

1. Inspect the actual client and server repositories.
2. Determine whether the browser build is operational.
3. Identify the minimum changes needed to connect the WebAssembly client to the 8.60 server.
4. Establish the build environment.
5. Compile what you can.
6. Implement the earliest playable vertical slice.
7. Run relevant tests.
8. Fix identified failures.
9. Package all working files.
10. Provide exact commands to launch the result.

If the entire multiplayer game cannot be completed in one execution, maximize the amount of genuinely working software delivered rather than producing extensive speculative documentation.

Clearly distinguish:
- Implemented and tested.
- Implemented but untested.
- Planned.
- Blocked.

Do not repeatedly ask me for decisions already established in this directive.

Make sensible architectural decisions and proceed.

Your final response must describe the actual working state of the code, not merely the intended game.

THE SUCCESS CRITERION IS A PLAYABLE GAME, NOT A CONVINCING DESCRIPTION OF ONE.

START NOW.
