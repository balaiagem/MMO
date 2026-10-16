dofile('data/scripts/lib/register_monster_type.lua')
local monsterType=Game.createMonsterType('Wolf')
monsterType:register({
    name='Wolf',description='a wolf',experience=50,outfit={lookType=27},
    health=11,maxHealth=11,race='blood',speed=82,manaCost=0,
    flags={attackable=true,hostile=true,pushable=true,staticAttackChance=90,targetDistance=1,runHealth=1},
    attacks={{name='melee',interval=2000,chance=100,minDamage=0,maxDamage=-6}},
    defenses={defense=2,armor=1},
})
