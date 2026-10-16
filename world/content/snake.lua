dofile('data/scripts/lib/register_monster_type.lua')
local monsterType=Game.createMonsterType('Snake')
monsterType:register({
    name='Snake',description='a snake',experience=10,outfit={lookType=28},
    health=2,maxHealth=2,race='blood',speed=60,manaCost=0,
    flags={attackable=true,hostile=true,pushable=true,staticAttackChance=90,targetDistance=1,runHealth=1},
    attacks={{name='melee',interval=2000,chance=100,minDamage=0,maxDamage=-1}},
    defenses={defense=0,armor=0},
})
