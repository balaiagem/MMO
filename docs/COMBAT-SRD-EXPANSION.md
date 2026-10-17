# Combat expansion — SRD 5.1 / 2014

This remains an implementation in progress. The imported reference catalogue is
not a claim that every class, spell or feature is executable in the game.

## Rules and source

The master development plan selects SRD 5.1 (2014). BG3 differs, including its
initiative die and some spell/action rules. Initiative now uses d20 plus Dexterity under the confirmed 2014 ruleset.

Pinned structured reference: rules/content/srd2014/manifest.json. The importer
records checksums, repository commit and upstream licence. It includes 12 classes,
all their SRD class levels 1–20, 319 spells, 407 features, six ability scores,
18 skills, 15 conditions and the SRD equipment/race/subclass collections.
These are SRD contents, not every published supplement or every BG3 subclass.

## Implemented in this revision

- Additional actions accumulate separately from the regular action. Action Surge
  before attacking and between Extra Attacks preserves the exact remaining budget.
- No additional bonus action, reaction or movement is granted by Action Surge.
- Action Surge cannot be spent outside an encounter or during another actor's turn.
- Bonus-action spellcasting applies the 2014 restriction in both casting orders.
- The left combat panel reports the number of available actions.
- Scorching Ray gains one ray per slot above second; Mass Healing Word uses a
  bonus action. Existing spell handlers are still partial implementations.
- Preserve Life respects the half-maximum-HP cap before spending its action.
- Cunning Action's generic information command does not consume the bonus action
  before the actual tactical option is chosen.
- Short rest permits zero Hit Dice, and each Hit Die's healing floors at zero.
- Rest is blocked for any active encounter, including PvP. Exploration spellcasting
  restores its action budget on the exploration interval, not during initiative.
- Character creation calculates all 18 SRD skill modifiers.
- Creation now accepts source-validated class skill selections, replacements for
  duplicate background/racial proficiencies, and rogue skill/tool Expertise.
  Choices persist in the character profile; the preview no longer claims the
  default Expertise when different options were selected.
- The shared character calculation engine covers 12 SRD classes, nine races and
  levels 1–5: HP, saving proficiencies, armor formulas, movement, spell-slot
  progressions (including half-casters and Pact Magic), and resource pool budgets.
  This calculation coverage does not unlock their active features in live play.
- Combat spell Dexterity saves now include class proficiency and Resilient once,
  and use Halfling Lucky when applicable. The sheet uses the same save calculation.
- Flee Athletics reads selected skill Expertise from the persisted profile.

The web creation changes are served immediately. Modified game Lua rules require
a game-server restart; a connected player's session must be accounted for before
deploying them.

## Outstanding integration

Creation now exposes all 12 stable SRD class IDs and all nine race IDs.
This is not a claim of complete class or spell coverage: the runtime slices
and their concrete remaining gaps are recorded below.
Barbarian has Rage/Reckless/Frenzy/Extra Attack mechanics through five; Monk has
Martial Arts, Ki, Flurry, Patient Defense, Step of the Wind and Stunning Strike.
Open Hand options, Deflect Missiles and Slow Fall still need integration.
None of the exposed classes is a claim of complete SRD coverage. Subclass selection, level 6–20
progression, equipment-dependent proficiency/weapon handling and Sneak Attack
eligibility, optional reaction prompts, complete duration/condition processing, complete summons,
spell preparation/learning and the remaining spell handlers require integration.
Existing Spiritual Weapon lacks persistent summoned-weapon behavior. Area spells
need full friendly-fire/party targeting rules. Preserve Life's selectable healing
pool and all party interactions are not complete. These features must not be
presented as finished merely because their names exist in the catalogue.

## Validation

The rules kernel and native-adapter fixtures execute on Lua 5.1 and Lua 5.5.
Regression scenarios cover Action Surge before attacking, after one Extra Attack,
four attacks at fighter level 5, exhausted actions, independent budgets, and the
bonus-action spell restrictions. Client Lua syntax/catalogue filters and pinned
SRD class levels/skills/spells are checked separately. Fixtures do not replace
live browser combat verification.

The character calculation suite evaluates 540 class/race/level combinations in
Lua 5.1 and 5.5, plus concrete equipment, slot and resource recovery cases. Creation
tests reject invalid skill choices, untrained Expertise and forged equipment
quantities. Browser checks exercise skill replacements, chosen Expertise, account
listing and a narrow viewport without creating test characters in the live DB.

## Martial expansion verification

Adapter fixtures exercise Barbarian and Monk hotkeys against real adapter callbacks:
bonus/action budgets, physical Rage resistance, d12 weapon damage, Extra Attack,
Frenzy exhaustion persisted across logout, long/short-rest recovery, Monk Ki,
Flurry and Stunning Strike expiration. Stunned monsters skip their turn and
initiative advances. Rogue Uncanny Dodge is an automatic reaction preference
that can be toggled via Assign Spell; it reduces one visible attack and never
Fireball/save damage. Scorching Ray now resolves each ray separately so a single
reaction cannot halve an entire volley. Interactive reaction prompts are pending.

Storage: 95100 Rage uses spent, 95101 exhaustion level, 95110 automatic Uncanny
Dodge preference (0 disabled), 95120 Ki spent, 95121 automatic Stunning Strike
preference (1 enabled). Legacy class IDs 1–4 and slot storage keys are unchanged;
Monk keeps stable class ID 8 even while Bard/Druid are not exposed.

## Paladin, concentration and Half-Orc integration

Paladin (stable class ID 9) now has an executable level 1-5 combat slice:
Lay on Hands with explicit healing amount and a persistent 5*level HP pool,
Divine Sense with action/use limits and typed monster detection, automatic
opt-in Divine Smite on successful melee weapon attacks (including opportunity
attacks), critical dice, Extra Attack, and Devotion's Sacred Weapon action,
Charisma attack bonus, duration and short-rest Channel Divinity recovery.
The default starting chain-mail/shield profile gains Defense at level 2.
This does not complete Paladin: Turn the Unholy, poison/disease removal,
equipment-aware Defense, full oath/prepared spell choices, disease conditions
and the complete spell list remain outstanding. Divine Sense can report typed
monster profiles; consecrated objects/hallow are not yet represented.

Healing Word uses a bonus action and d4 healing. Cure Wounds uses the caster's
class ability and grants Disciple of Life only to Life Clerics. Follow a player
to select an adjacent healing recipient; no follow target means self.
Bless and Shield of Faith apply real attack/save or AC bonuses and exclusive
concentration. Damage prompts a server-side CON save with proficiency and a
minimum DC of 10; failed saves, unconsciousness, Rage, logout, replacement and
expiration end the effect. Combat duration advances with caster turns rather
than time spent choosing actions. End Concentration is a free hotkey control.
Buff target selection currently covers self or one followed player, not a full
multi-recipient Bless picker. Spell learning/preparation remains incomplete.

Half-Orc retains stable race ID 8 despite being the fifth exposed race. Creation
grants STR+2, CON+1 and Intimidation with duplicate-proficiency replacement.
Savage Attacks adds exactly one weapon die on melee criticals. Relentless
Endurance leaves 1 HP once per long rest and does not prevent massive-damage
instant death. Darkvision exists in the shared sheet calculation; native
darkvision rendering is not yet integrated for the races that have it.

Sneak Attack now excludes the victim from adjacent allies, excludes incapacitated
allies and uncancelled disadvantage, and permits advantage-based eligibility.
Its once-per-turn key uses the current initiative turn, allowing an eligible
opportunity attack on another creature's turn. The adapter still assumes its
default finesse weapon for Rogues; equipped weapon classification is pending.

Persistent storage: 95130 automatic Smite preference; 95131 Lay on Hands points
spent; 95132 Divine Sense uses spent; 95133 Channel Divinity uses spent;
95140 Relentless Endurance spent. Temporary buffs never refill spell slots.
Adapter regression tests cover these mechanics on Lua 5.1 and 5.5; native
Assign Spell filters now cover all 540 class/race/level combinations.

## Remaining five classes: executable integration

The engine-facing module `rules/class_actions.lua` is loaded by the combat adapter
and copied to runtime by the normal launcher. No catalogue-only placeholders are
used as successful active actions. Its direct callback tests cover:

| Class | Integrated mechanics | Still incomplete through level 5 |
| --- | --- | --- |
| Bard / Lore | Inspiration d6/d8, explicit recipient/next-roll use, bonus cost, short-rest Font at 5, Jack of All Trades in checks/initiative, Song of Rest d6, three chosen Lore proficiencies, two chosen Expertise skills, automatic opt-in Cutting Words against attacks | Cutting Words checks/damage and deaf/charm-immunity conditions; full spells known/selection and full Bard spell list |
| Druid / Land | Wild Shape action/bonus reversion, two uses per short rest, real Wolf/Rat HP/outfits/physical scores/AC/attacks/speed, original HP retained, excess damage and logout/crash recovery, casting prohibition, Natural Recovery, real healing and Produce Flame | Other observed beast forms including swim forms at 4, beast riders such as Wolf Pack Tactics/prone, Land choice/spells, extra cantrip choice, full prepared spell selection/list and languages |
| Ranger / Hunter | Extra Attack, Colossus Slayer once per initiative turn including reactions, Hunter's Mark with concentration and d6 per weapon hit, retargeting a defeated mark without another slot, chosen favored creature types or two humanoid groups, favored terrain and applicable skill-check bonuses | Fighting Style/equipment choices and ranged weapons, other Hunter's Prey options, Primeval Awareness, world travel/terrain automation, full spell choices/list |
| Sorcerer / Draconic | Draconic HP/AC, persistent Font points, bonus-action slot/point conversion, created slots retained until long rest, two chosen Metamagics from Quickened/Distant/Extended, spell-cost/bonus-spell restrictions | Other Metamagic choices, Draconic ancestry language/social features, spells-known choices/full spell list |
| Warlock / Fiend | Pact slots restore on short rest, separate Eldritch Blast beams and Agonizing damage per beam, Fiend temporary HP without stacking, 2/3 chosen invocations from Agonizing Blast/Fiendish Vigor/Armor of Shadows/Devil's Sight, Hex damage per attack and critical, defeated-mark retargeting | Pact Boon Blade/Tome/Chain including familiar control, remaining invocations, expanded Fiend spell choices/full known-spell selection/list |

Class choices are available from the native progression dialog. Skill profiles
are read once and cached per login; opening the sheet does not issue one query
per skill. `/check <skill-id> [context]` executes server rolls, including chosen
Expertise, Jack of All Trades, applicable favored-enemy/terrain checks, Dwarven
Stonecunning and Rock Gnome Artificer's Lore. In combat an active check costs an
action; outside combat it respects the exploration interval.

## Remaining four races: executable integration

- Dragonborn: chosen one of ten ancestries persists as stable storage 95500;
  matching elemental resistance, directional 15-foot cone/30-foot line, 2d6,
  CON-based DC, correct DEX/CON target save, half damage and short-rest charge.
  Acid and poison remain distinct rule flavors even though their native visual
  engine damage enum is shared.
- Rock Gnome: INT/CON bonuses, advantage on magical INT/WIS/CHA saves, double
  proficiency on relevant History checks. Tinker crafting/devices and native
  darkvision rendering remain pending.
- Half-Elf: two chosen non-CHA +1 abilities, two chosen skills, duplicate
  proficiency replacements, CHA+2, magical Sleep immunity. Charm-save advantage
  is supported by the generic trait hook; complete charm conditions/spells and
  language selection are not integrated.
- Tiefling: INT/CHA bonuses, real fire resistance, opt-in racial Hellish Rebuke
  at level 3 as a second-level spell once per long rest, racial Darkness at level
  5 without class slots. Thaumaturgy utility interactions and native darkvision
  rendering remain pending.

## Spell and reaction additions

The direct `/cast` handlers cover 18 spells, not the entire imported catalogue:
Fire Bolt, Sacred Flame, Magic Missile, Cure Wounds, Healing Word, Bless,
Shield of Faith, Scorching Ray, Spiritual Weapon (partial summon behavior),
Fireball, Mass Healing Word (party selection incomplete), Eldritch Blast,
Hex, Hunter's Mark, Produce Flame (attack use), Vicious Mockery, Sleep, Darkness.
The class/race availability of these spells is tested across all 540 sheets.

Shield and Counterspell additionally resolve as opt-in automatic reaction
preferences, not free information messages. Shield spends a reaction/slot,
raises AC until the next caster turn and blocks Magic Missile. Counterspell
spends a third-level slot/reaction, preserves the cancelled spell's costs,
allows legal counter-counterspell chains and respects the 2014 bonus-action
spell restriction. Interactive reaction prompts and complete known/prepared
spell validation remain pending; this is not full BG3 reaction UI coverage.

Sleep resolves an ascending HP pool, Elf/Half-Elf immunity, incapacitation,
turn skips, wake on damage and adjacent critical hits. Darkness has map center,
exclusive concentration, obscured attack rules and Devil's Sight. Persistent
darkness-zone world rendering is not yet implemented; targeting previews work.
Mixed weapon/radiant/necrotic damage is mitigated per type and uses one reaction
and one concentration check per hit; temporary HP do not bypass concentration.

New storage: 95410 Inspiration spent; 95411 Cutting Words preference;
95420 Sorcery Points spent; 95421 Metamagic choices; 95430 invocation choices;
95441-43 created slot capacity; 95450 Wild Shape uses; 95451 Natural Recovery;
95460-69 original body recovery; 95480-81 Lore/Expertise masks;
95490-92 Ranger choices; 95493-94 Shield/Counterspell preferences;
95500 ancestry, 95501 breath spent, 95520 Hellish Rebuke preference,
95521 racial Rebuke spent, 95522 racial Darkness spent.

## Authoritative experience and level

For D&D characters (storage 95000=1), native protocol stats now serialize
storage 95003/95004, with thresholds 0/300/900/2700/6500. Native Tibia XP gains
and death XP deductions are skipped; DndKill is the sole combat XP award path.
Storage changes refresh native stats immediately. Kill and GM progress messages
also refresh the cached sheet, including awards below the next level threshold.
The Skills XP value, level bar and advancement tooltip use the D&D curve only.
The current level cap is five; XP continues accumulating without a sixth level.
