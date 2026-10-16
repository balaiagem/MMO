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

Creation now exposes Fighter, Rogue, Cleric, Wizard, Barbarian and Monk.
Barbarian has Rage/Reckless/Frenzy/Extra Attack mechanics through five; Monk has
Martial Arts, Ki, Flurry, Patient Defense, Step of the Wind and Stunning Strike.
Open Hand options, Deflect Missiles and Slow Fall still need integration.
Bard, Druid, Paladin, Ranger, Sorcerer and Warlock are not yet playable.
None of the six exposed classes is a claim of complete SRD coverage. Subclass selection, level 6–20
progression, equipment-dependent proficiency/weapon handling, complete Sneak Attack
eligibility (including reaction attacks), optional reaction prompts, Shield,
Counterspell, concentration, duration/condition processing, complete summons,
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
