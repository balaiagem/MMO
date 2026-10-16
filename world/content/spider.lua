dofile('data/scripts/lib/register_monster_type.lua')
local monsterType=Game.createMonsterType('Spider')
monsterType:register({
    name='Spider',description='a spider',experience=10,outfit={lookType=30},
    health=1,maxHealth=1,race='blood',speed=67,manaCost=0,
    flags={attackable=true,hostile=true,pushable=true,staticAttackChance=90,targetDistance=1,runHealth=1},
    attacks={{name='melee',interval=2000,chance=100,minDamage=0,maxDamage=-1}},
    defenses={defense=0,armor=0},
})
