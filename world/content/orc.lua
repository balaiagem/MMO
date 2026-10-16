dofile('data/scripts/lib/register_monster_type.lua')
local monsterType=Game.createMonsterType('Orc')
monsterType:register({
    name='Orc',description='an orc',experience=100,outfit={lookType=5},
    health=15,maxHealth=15,race='blood',speed=82,manaCost=0,
    flags={attackable=true,hostile=true,pushable=true,staticAttackChance=90,targetDistance=1,runHealth=5},
    attacks={{name='melee',interval=2000,chance=100,minDamage=0,maxDamage=-8}},
    defenses={defense=2,armor=1},
})
