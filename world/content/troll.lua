dofile('data/scripts/lib/register_monster_type.lua')
local monsterType=Game.createMonsterType('Troll')
monsterType:register({
    name='Troll',description='a troll',experience=100,outfit={lookType=15},
    health=16,maxHealth=16,race='blood',speed=70,manaCost=0,
    flags={attackable=true,hostile=true,pushable=true,staticAttackChance=90,targetDistance=1,runHealth=5},
    attacks={{name='melee',interval=2000,chance=100,minDamage=0,maxDamage=-8}},
    defenses={defense=2,armor=2},
})
