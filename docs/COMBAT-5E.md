# Authoritative combat milestone

Rules source: SRD 5.1 / 2014, https://www.dndbeyond.com/attachments/39j2li89/SRD5.1-CCBY4.0License.pdf. Follow `MASTER-DEVELOPMENT-PLAN.md` for the full target. This is the first engine-integrated slice, not a complete implementation of all 5e combat.

`world/content/dnd_combat.lua` runs on TFS. `rules/core.lua` is copied into the isolated runtime as `data/lib/dnd_rules.lua`; setup preserves both. Native physical hits against enrolled actors are suppressed through a health-change guard. The authoritative adapter sends the already rolled, exact damage through native combat with armor/shield/resistance processing disabled, preserving attribution and floating damage without adding Tibia random damage or defense a second time.

Combat now starts when a player selects one of the registered island monsters or a hostile island monster targets a player. The server rolls d4 + Dexterity for each participant, sorts the initiative order and keeps it for the encounter. Every participant gets a turn; action, bonus-action and reaction budgets reset only when initiative advances, not after six seconds. Players use the native Assign Spell hotkeys for `Ataque`, spells and class features, then `Encerrar turno`; monster turns resolve automatically, walking toward an out-of-reach target before using their attack. The supported roster is Rat, Snake, Spider, Wolf and Bug, with Orc and Troll available for GM encounter tests. Their creature outfits are imported from the installed local Tibia assets at the classic looktypes. The selected Tibia follow mode and native movement remain available. Movement is gated in the native server before a tile transfer. Each turn grants stored race speed (feet), with one tile costing 5 feet and a diagonal 7.07 feet. Outside the active turn the budget is zero; ending combat restores unrestricted exploration. Dash adds base speed and spends an action; Rogue level 2 can independently spend a bonus action for Cunning Action Dash. Blocked destination tiles do not consume server movement. Players see a persistent Tibia panel with remaining metres, action and bonus action plus End Turn. A player who does not end their turn holds the encounter.

Players use character-creation attributes and the D&D level/XP storages. Weapon attacks add ability and proficiency against target AC; total equal to AC hits. Natural 1 misses, natural 20 hits and doubles damage dice, not flat modifiers; Champion also crits on a 19. Fighter uses long sword d8, Rogue rapier d8 and DEX, Cleric mace d6 and Wizard staff d6. Logical starter loadouts determine AC; draggable equipment/item bonuses are not integrated. Existing characters initialize from their engine level; new characters start at D&D level 1. Rat kills add 10 D&D XP; thresholds through level 5 are 300, 900, 2700 and 6500. D&D level storage (95003) drives proficiency, HP, class progression, cantrip scaling, extra attacks and slots without relying on Tibia's XP curve. At level 4 the player must choose an ability increase or one of the two implemented feats, Tough and Resilient, before receiving level 5.

The roster uses compact combat profiles: Rat AC10, HP1, bite +0 for 1 piercing; Snake AC12, HP2, bite +4 for 1; Spider AC12, HP1, bite +4 for 1; Wolf AC13, HP11, bite +4 for 2d4+2; Bug AC14, HP1, bite +0 for 1; Orc AC13, HP15, melee +5 for 1d12+3; Troll AC15, HP16, melee +4 for 1d6+2. Creature hits and misses are written to the combat log, and the monster's AC is used when a player attacks it. These starter profiles omit monster-specific poison, resistances, and special traits. Their kills grant 10/10/10/50/10/100/100 D&D XP in the same order. Rogue Sneak Attack adds d6s once per turn when another player is adjacent to the enemy; broader ally recognition and advantage-based eligibility are pending. Halfling Lucky rerolls a natural 1 on its attacks. Fire Bolt rolls with disadvantage if a nearby monster threatens the caster.

Spells are authoritative server actions assigned through the native spell hotkey menu; their `/cast` commands remain available for chat testing:

- `firebolt`: Wizard or High Elf starter cantrip, 120 feet, spell attack with INT + proficiency, d10 fire, no ability damage modifier, critical/scaling cantrip dice.
- `sacredflame`: Cleric cantrip, 60 feet, target creature's DEX save against 8 + WIS + proficiency, d8 radiant, no damage on a successful save. The displayed d20 belongs to the defender.
- `magicmissile`: Wizard level-one spell, 120 feet, three simultaneous darts at selected target; one d4+1 damage roll shared across the darts. Automatically hits; no fake d20 or AC test.
- `curewounds`: Life Cleric level-one spell on self, d8 + WIS + 3 (Disciple of Life: 2 + spell level). No attack roll.
- `scorchingray`: Wizard level 2, three separate ranged spell attacks, each 2d6 fire.
- `spiritualweapon`: Cleric level 2, bonus-action spell attack, d8 + WIS radiant damage.
- `fireball`: Wizard level 3, 8d6 fire in a 3-tile radius; each creature's Dexterity save halves damage.
- `masshealingword`: Cleric level 3, heals nearby players for d4 + WIS + 5 (Life Domain) using a level-3 slot.

Casting validates class, target, line of sight, floor, range, level and the selected level's slot pool before committing costs. Rejected casts don't consume actions or slots. Spell slots by circle persist in player storage 95030–95032 and appear as three segmented tracks in the mana-bar area; cantrips don't spend slots. The catalogue is a small playable subset, not each class's complete spell list. The Tibia-style character button opens a server-fed progression window; at level 4 it offers the implemented ASI, Tough, and Resilient choices. Short rests spend selected Hit Dice (d10 Fighter, d8 Rogue/Cleric, d6 Wizard) and heal by the server's roll plus CON. Long rests are allowed only in the defined Rookgaard town area on floor 7, restore all HP and spell slots, and recover half the character's Hit Dice (minimum one). Rest buttons are hidden while combat monsters are nearby; the server checks safety and town bounds again when the command arrives. Prepared/known spell selection, components, concentration, opportunity reactions, conditions, full cover/advantage rules, movement budgets and death saves remain unimplemented. Channel Divinity, Action Surge, Cunning Action, Uncanny Dodge and other class features are not all active effects yet, even when they appear in the progression sheet.

Any class can use the Assign Spell hotkey named `Ataque` or `/attack` for one weapon Attack action. Wizard/Cleric spells and eligible class features spend their action or bonus action on the active turn. Use `Encerrar turno` or `/turn end` to pass the turn; a cast/attack does not advance initiative by itself, so a bonus action can still be used after an action. `/ficha` shows AC/HP/proficiency/remaining slots; `/dndprogress` returns the progression data used by the client window. `/rest short N` spends N Hit Dice and `/rest long` requests a safe long rest in town. Initiative and attack/spell rolls remain server-authoritative and are written to the Server Log. The client briefly animates the reported d20 above the player's name and health bar; turn changes show the round and position in order. Spell slots display as three Tibia-style segmented rows, one for each circle, with spent/available pips and a marker for the selected circle. Clicking a target preserves the selected chase mode; selecting an enemy does not turn on Follow While Attacking. When that mode is enabled, the server follows the current attack target; ordinary NPC follow stays independent. The client bot module is removed from automatic loading.

Tests: `tools/test-rules.py` checks 33 deterministic rules-kernel cases in Lua 5.1 and 5.5, including turn budgets that reset only when initiative advances. `tools/test-combat-adapter.py` executes the actual adapter source with stubbed engine fixtures, including initiative start, turn gating, no wall-clock reset, damage suppression, spells, slot costs and rests. These fixtures are not evidence of a live browser/TFS session. Runtime verification is recorded separately in `docs/STATUS.md`.

BG3 parity scope: movement/action/bonus resources, d20 initiative and basic automatic monster turns are implemented. Shared ally turns, reaction prompts, terrain costs, jumping/shoving, concentration, status effects, complete spell/feature implementations and party AI remain pending. This is an original implementation, not imported BG3 engine code. Native engine compilation and automated fixtures do not substitute for live game verification.


### Initiative portraits and opportunity reactions

The top-of-map initiative strip shows actor outfit, initiative total, HP,
current turn, reaction availability and next-round entry. It uses the existing
2014 SRD d20 + Dexterity initiative. Joining actors enter on the next round;
normal action, bonus action, reaction and movement reset only on their turn.
The End Turn button is enabled only for the local active actor.

Leaving a melee enemy's one-tile reach by an adjacent same-floor step consumes
that enemy's reaction and resolves one attack against AC. Moving inside reach,
changing floors and non-adjacent teleports do not provoke. Reactions are automatic.
`/combat disengage` spends an action and prevents these attacks until your next
turn. Rogues level 2+ may use `/combat bonusdisengage` instead. Both are available
through Assign Spell; existing hotkey action IDs are preserved.

Ground callbacks cover the current island's grass, cobblestone, floor and earth
IDs 100/101/102/110. New terrain requires registering its ground ID. This is not
a complete 5e implementation: forced adjacent movement during the actor's own
turn cannot yet be distinguished from walking by this movement callback, and
opportunity damage resolves after the successful tile move. Shared allied turns,
reaction confirmation dialogs, conditions and full spell-rule coverage remain
separate work. No claim of complete BG3 parity or complete 5e rules verification.
