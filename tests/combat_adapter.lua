-- Adapter fixtures, not a substitute for live TFS/browser verification.
local time=100000
os.mtime=function() return time end
local events={}
local function register(kind,name)
 local obj={}
 for _,method in ipairs({'type','interval','separator','register','id'}) do obj[method]=function() end end
 for _,method in ipairs({'onLogin','onLogout','onKill','onHealthChange','onSay','onThink','onStepOut'}) do obj[method]=function(self,fn) self.callback=fn end end
 events[kind..name]=obj;return obj
end
CreatureEvent=function(n)return register('event:',n)end
TalkAction=function(n)return register('talk:',n)end
GlobalEvent=function(n)return register('global:',n)end
MoveEvent=function()
 local e=register('move:','opportunity')
 e.type=function(self,value) self.eventType=value end
 e.register=function(self) assert(self.eventType=='stepout','movement event type must be set before native registration') end
 return e
end
MESSAGE_STATUS_SMALL=26;MESSAGE_STATUS_CONSOLE_BLUE=27;COMBAT_HEALING=1;COMBAT_PHYSICALDAMAGE=2;COMBAT_FIREDAMAGE=3;COMBAT_HOLYDAMAGE=4;COMBAT_ENERGYDAMAGE=5;ORIGIN_SPELL=1
COMBAT_DEATHDAMAGE=6;COMBAT_ICEDAMAGE=7;COMBAT_EARTHDAMAGE=8
CONST_ME_NONE=0;CONST_ME_DRAWBLOOD=1;CONST_ME_FIREAREA=2;CONST_ME_HOLYDAMAGE=3;CONST_ME_ENERGYHIT=4;CONST_ME_MAGIC_BLUE=5
CONST_ANI_FIRE=1;CONST_ANI_HOLY=2;CONST_ANI_ENERGY=3
local visualEvents={}
Position=function(x,y,z)
 local pos={x=x,y=y,z=z}
 function pos:isSightClear()return true end
 function pos:sendDistanceEffect(to,effect)visualEvents[#visualEvents+1]={kind='projectile',from={x=self.x,y=self.y,z=self.z},to={x=to.x,y=to.y,z=to.z},effect=effect}end
 function pos:sendMagicEffect(effect)visualEvents[#visualEvents+1]={kind='impact',at={x=self.x,y=self.y,z=self.z},effect=effect}end
 return pos
end
local creatures={}
Creature=function(id)return creatures[id]end
local function creature(id,player,cls)
 local c={id=id,player=player,hp=100,pos=Position(111,111,7),storage={[95000]=1,[95001]=cls or 1,[95002]=1,[95010]=19,[95030]=2,[95033]=2,[95034]=0,[95035]=0,[95020]=16,[95021]=14,[95022]=14,[95023]=16,[95024]=16,[95025]=10}}
 function c:getId()return self.id end
 function c:getGuid()return self.id end
 if player then function c:isPlayer()return true end
 else function c:isMonster()return true end end
 function c:getName()return self.player and 'Test' or self.name or 'Rat' end
 function c:getLevel()return 1 end
 function c:getHealth()return self.hp end
 function c:getMaxHealth()return self.maxhp or 100 end
 function c:setMaxHealth(n)self.maxhp=n end
 function c:getOutfit()return self.outfit or {lookType=131,lookHead=78,lookBody=69,lookLegs=58,lookFeet=76}end
 function c:setOutfit(outfit)self.outfit=outfit end
 function c:addHealth(n)self.hp=math.min(self:getMaxHealth(),self.hp+n)end
 function c:getGroup()return {getAccess=function()return true end}end
 function c:getMana()return self.mana or 0 end
 function c:getMaxMana()return self.maxMana or 0 end
 function c:setMana(n)self.mana=n end
 function c:setMaxMana(n)self.maxMana=n end
 function c:getStorageValue(k)return self.storage[k] or -1 end
 function c:setStorageValue(k,v)self.storage[k]=v end
 function c:getTarget()return self.target end
 function c:setTarget(target)self.target=target;return true end
 function c:isTarget(target)
     if self.canSee==false or not target then return false end
     return self.pos.z==target:getPosition().z
 end
 function c:setTurnMovement(value)self.turnMovement=value end
 function c:getTurnMovement()return self.turnMovement or -1 end
 function c:getFollowCreature()return self.follow end
 function c:setFollowCreature(target)self.follow=target end
 function c:isChasingEnabled()return self.chase or false end
 function c:getPosition()return self.pos end
 function c:registerEvent()end
 function c:sendTextMessage(mode,text)
     self.message=text;self.messages=self.messages or {};self.messages[#self.messages+1]={mode=mode,text=text}
 end
 creatures[id]=c;return c
end
local p=creature(1,true,1);local rat=creature(2,false);p.target=rat;rat.target=nil
local extra
Game={getPlayers=function()return {p}end,getSpectators=function(pos,multi,players)
 if players then return {p} end
 local visible={p,rat};if extra then visible[#visible+1]=extra end;return visible
end}
local hits=0
doTargetCombat=function(a,b,kind,min,max)
 local target=creatures[b]
 local amount=events['event:DndDamageGuard'].callback(target,creatures[a],min,kind,0,0)
 assert(amount==min,'authoritative damage was suppressed')
 target.hp=target.hp+(kind==COMBAT_HEALING and math.abs(amount) or -math.abs(amount));hits=hits+1
end
local nativeDofile=dofile
dofile=function(path)
 local mapped={['data/lib/dnd_rules.lua']='rules/core.lua',['data/lib/dnd_characters.lua']='rules/characters.lua',['data/lib/dnd_character_data.lua']='rules/character_data.lua',['data/lib/dnd_class_actions.lua']='rules/class_actions.lua'}
 return nativeDofile(mapped[path] or path)
end
nativeDofile('world/content/dnd_combat.lua')
local fixed=20
math.random=function(low,high)return math.min(fixed,high)end
local tick=events['global:DndCombatTick'].callback
tick();local rolledInitiative=false;for _,m in ipairs(p.messages or {}) do if m.text:find('INITIATIVE',1,true) then rolledInitiative=true end end
local sentOrder=false;for _,m in ipairs(p.messages or {}) do if m.text:find('[5E] ORDER ',1,true) and m.text:find('2:',1,true) then sentOrder=true end end
assert(hits==0 and rolledInitiative and sentOrder,'selecting a hostile target must start initiative and publish the order without attacking immediately')
assert(rat.target==nil and rat.follow==nil,'native monster targeting/following must yield to turn-based initiative')
p.target=rat
local attack=events['talk:/attack'].callback
attack(p,'/attack','');assert(p.target==rat,'attack cleared chosen target');assert(hits==1 and rat.hp==81,'critical doubles 1d8 but not STR modifier')
attack(p,'/attack','');assert(hits==1,'a second attack must wait for the next turn')
time=time+60000;tick();assert(hits==1,'turn budget must not refresh with elapsed wall time')
local value=events['event:DndDamageGuard'].callback(p,rat,-8,COMBAT_PHYSICALDAMAGE,0,0)
assert(value==0,'native damage was not disabled')
assert(p:getTurnMovement()==3000 and rat:getTurnMovement()==0,'only active actor should receive movement')
extra=creature(88,false);extra.target=p;p.target=nil;tick();attack(p,'/attack','')
local joinedOrder=false;for _,m in ipairs(p.messages or {}) do if m.text:find('[5E] ORDER ',1,true) and m.text:find('88:',1,true) then joinedOrder=true end end
assert(extra.hp==100 and p:getTurnMovement()==3000 and joinedOrder,'a newly aggressive enemy must join initiative without refreshing the active turn')
assert(extra.target==nil and extra.follow==nil,'newly rostered enemies must stop native pursuit immediately')
extra=nil;p=creature(3,true,4);rat=creature(22,false);p.target=rat
local cast=events['talk:/cast'].callback
fixed=20;tick();cast(p,'/cast','firebolt');assert(p.target==rat,'spell cleared chosen target');assert(rat.hp==80,'fire bolt critical doubles 1d10, no INT damage bonus')
assert(not p.storage[95030] or p.storage[95030]==2,'cantrip must not spend a spell slot')
local slots=p.storage[95030]
cast(p,'/cast','magicmissile');assert(p.storage[95030]==slots,'rejected action consumed slot')
events['talk:/turn'].callback(p,'/turn','end');tick();fixed=4;cast(p,'/cast','magicmissile');assert(rat.hp==65 and p.storage[95030]==1,string.format('3 darts or slot incorrect: hp=%d slots=%s',rat.hp,tostring(p.storage[95030])));assert(p.mana==1 and p.maxMana==2,'native slot bar not synchronized')
cast(p,'/cast','curewounds');assert(p.storage[95030]==1,'wrong class consumed slot')
p=creature(4,true,3);rat=creature(24,false);p.target=rat;fixed=1;tick()
cast(p,'/cast','sacredflame');assert(rat.hp==99,'failed save should take 1d8 radiant')
events['talk:/turn'].callback(p,'/turn','end');tick();p.hp=10;fixed=8;cast(p,'/cast','curewounds');assert(p.hp==24 and p.storage[95030]==1,'Life cleric cure must be 1d8+WIS+3')
print('Adapter: initiative, turn gating, server damage guard, spells and slot costs passed')
-- Chase mode must work for a caster too, and remain independent of normal follow.
p.chase=true;tick();assert(p.follow==rat,'enabled chase did not follow enemy')
p.chase=false;tick();assert(p.follow==nil,'disabled chase still followed enemy')
local npc=creature(9,false);p.target=nil;p.follow=npc;tick();assert(p.follow==npc,'ordinary NPC follow was cancelled')
p.target=rat;p.follow=nil;p.chase=false;tick();assert(p.follow==nil and not p.chase,'attack forced chase mode on')
print('Chase: enabled/disabled caster pursuit, NPC follow and preserved mode passed')

-- Rest dialog actions are validated by the server adapter and use persistent Hit Dice/slots.
Game.getSpectators=function()return {p}end
fixed=10;p=creature(10,true,1);p.target=nil;p.hp=50;p.storage[95060]=2;p.storage[95061]=2
events['talk:/rest'].callback(p,'/rest','short 1')
assert(p.hp==62 and p.storage[95061]==1,'short rest must heal with one Fighter Hit Die and spend it')
p=creature(11,true,4);p.target=nil;p.hp=5;p.storage[95060]=4;p.storage[95061]=1
p.storage[95030]=0;p.storage[95033]=2;p.storage[95034]=0;p.storage[95035]=0
events['talk:/rest'].callback(p,'/rest','long')
assert(p.hp==100 and p.storage[95061]==3 and p.storage[95030]==2,'long rest must restore HP, half Hit Dice, and spell slots in town')
p=creature(12,true,1);p.target=nil;p.pos={x=118,y=103,z=8};p.hp=5
events['talk:/rest'].callback(p,'/rest','long')
assert(p.hp==5,'long rest must be refused outside the city floor')
print('Rest: Hit Die healing, safe city long-rest recovery and location validation passed')

-- Slot-circle hotkeys select a level, the cast spends that pool, and feature
-- actions remain server-authoritative and recover on the appropriate rest.
Game.getSpectators=function(pos,multi,players)return players and {p} or {p,rat}end
p=creature(14,true,4);rat=creature(25,false);p.target=rat;p.storage[95003]=5;p.storage[95030]=4;p.storage[95031]=3;p.storage[95032]=2
p.storage[95033]=4;p.storage[95034]=3;p.storage[95035]=2;p.storage[95036]=1
events['talk:/slot'].callback(p,'/slot','up')
assert(p.storage[95036]==2,'slot up hotkey did not select circle 2')
fixed=20;tick();fixed=4;local before=rat.hp
cast(p,'/cast','magicmissile')
assert(p.storage[95031]==2 and rat.hp==before-20 and p.storage[95036]==2,'selected level-2 Magic Missile must spend level 2 and fire four darts')
local slotUpdate=false;for _,m in ipairs(p.messages) do if m.text:find('slots1=4 slots2=2 slots3=2 max1=4 max2=3 max3=2 selected=2',1,true) then slotUpdate=true end end
assert(slotUpdate,'slot bar synchronization omitted circle counts')

-- A spell above the selected circle automatically raises selection to its base
-- circle; a lower-level spell keeps the selected circle and applies its scaling.
p=creature(18,true,4);rat=creature(28,false);p.target=rat;p.storage[95003]=5
p.storage[95030]=4;p.storage[95031]=2;p.storage[95032]=2
p.storage[95033]=4;p.storage[95034]=3;p.storage[95035]=2;p.storage[95036]=1
fixed=20;tick();fixed=4;cast(p,'/cast','scorchingray')
assert(p.storage[95030]==4 and p.storage[95031]==1 and p.storage[95036]==2,
    'level-2 spell with level 1 selected must automatically spend and select level 2')

p=creature(19,true,4);rat=creature(29,false);p.target=rat;p.storage[95003]=5
p.storage[95030]=4;p.storage[95031]=3;p.storage[95032]=2
p.storage[95033]=4;p.storage[95034]=3;p.storage[95035]=2;p.storage[95036]=2
fixed=20;tick();fixed=1;cast(p,'/cast','fireball')
assert(p.storage[95032]==1 and p.storage[95036]==3,
    'level-3 Fireball with level 2 selected must automatically spend and select level 3')

-- The client can target an empty tile. The server resolves the circular blast
-- independently of the selected creature and emits projectile and impact FX.
p=creature(193,true,4);rat=creature(293,false);p.target=nil
p.pos=Position(110,111,7)
rat.pos=Position(114,111,7)
rat.storage[95021]=10 -- ensure the caster wins initiative for this deterministic fixture
p.storage[95003]=5;p.storage[95030]=4;p.storage[95031]=3;p.storage[95032]=2
p.storage[95033]=4;p.storage[95034]=3;p.storage[95035]=2;p.storage[95036]=3
local beforeVisuals=#visualEvents;fixed=1;tick();cast(p,'/cast','fireball 113 111 7')
assert(rat.hp<100 and p.storage[95032]==1,'targeted Fireball must damage a creature near an empty center sqm and spend its slot')
local projectile,impact=false,false
for index=beforeVisuals+1,#visualEvents do
 local effect=visualEvents[index]
 if effect.kind=='projectile' and effect.to.x==113 and effect.to.y==111 then projectile=true end
 if effect.kind=='impact' and effect.at.x==113 and effect.at.y==111 then impact=true end
end
assert(projectile and impact,'Fireball omitted its flight trail or center explosion effect')

-- A chosen circle is a preference: fall back one circle at a time, never below
-- the spell's base level, and report the actual circle used to the client.
p=creature(192,true,4);rat=creature(292,false);p.target=rat;p.storage[95003]=5
p.storage[95030]=4;p.storage[95031]=1;p.storage[95032]=0
p.storage[95033]=4;p.storage[95034]=3;p.storage[95035]=2;p.storage[95036]=3
fixed=20;tick();fixed=1;cast(p,'/cast','scorchingray')
assert(p.storage[95031]==0 and p.storage[95032]==0 and p.storage[95036]==2,
    'Scorching Ray selected at level 3 must fall back to its available level-2 slot')
local fallbackReported=false
for _,m in ipairs(p.messages or {}) do
    if m.text:find('slots1=4 slots2=0 slots3=0 max1=4 max2=3 max3=2 selected=2',1,true) then fallbackReported=true end
end
assert(fallbackReported,'slot update must report the actual lower circle consumed')

-- If the effective circle has no slots, the spell must not consume the action.
p=creature(191,true,4);rat=creature(291,false);p.target=rat;p.storage[95003]=5
p.storage[95030]=4;p.storage[95031]=3;p.storage[95032]=0
p.storage[95033]=4;p.storage[95034]=3;p.storage[95035]=2;p.storage[95036]=1
fixed=20;tick();local beforeUnavailableCast=rat.hp
cast(p,'/cast','fireball')
assert(rat.hp==beforeUnavailableCast and p.storage[95032]==0,
    'Fireball without a level-3 slot must not deal damage or consume another circle')
cast(p,'/cast','firebolt')
assert(rat.hp<beforeUnavailableCast,
    'a rejected spell for missing slots must leave the action available')

p=creature(20,true,4);rat=creature(30,false);p.target=rat;p.storage[95003]=5
p.storage[95030]=4;p.storage[95031]=3;p.storage[95032]=2
p.storage[95033]=4;p.storage[95034]=3;p.storage[95035]=2;p.storage[95036]=3
fixed=20;tick();fixed=4;local lowCircleHp=rat.hp;cast(p,'/cast','magicmissile')
assert(p.storage[95032]==1 and p.storage[95036]==3 and rat.hp==lowCircleHp-25,
    'level-1 Magic Missile selected at level 3 must spend level 3 and scale to five darts')

p=creature(17,true,1);rat=creature(27,false);p.target=rat;p.storage[95003]=2;fixed=20;tick()
attack(p,'/attack','');local afterFirstAttack=rat.hp
events['talk:/ability'].callback(p,'/ability','actionsurge')
attack(p,'/attack','');assert(rat.hp<afterFirstAttack,'Action Surge did not grant a second Attack action in the same turn')
-- Action Surge before any attack and during an unfinished Attack action.
for _,afterOne in ipairs({false,true}) do
 p=creature(afterOne and 811 or 801,true,1);rat=creature(afterOne and 812 or 802,false)
 p.target=rat;p.storage[95003]=5;fixed=20;tick()
 if afterOne then attack(p,'/attack','') end
 events['talk:/ability'].callback(p,'/ability','actionsurge')
 for i=1,(afterOne and 3 or 4) do attack(p,'/attack','') end
 local hp=rat.hp
 attack(p,'/attack','')
 assert(rat.hp==hp,'Action Surge must allow exactly two Attack actions / four attacks at level 5')
 assert(hp==24,'Action Surge lost an Attack action or a pending Extra Attack')
end
print('Action Surge: before attacking and between Extra Attacks gives exactly four attacks')
p=creature(15,true,1);p.storage[95003]=3;p.storage[95070]=0;p.hp=60
fixed=10;events['talk:/ability'].callback(p,'/ability','secondwind')
assert(p.hp==73 and p.storage[95070]==1,'Second Wind must heal 1d10 + level once per short rest')
events['talk:/ability'].callback(p,'/ability','secondwind')
assert(p.hp==73,'Second Wind was available more than once before a short rest')
p=creature(16,true,4);p.storage[95003]=2;p.storage[95030]=1;p.storage[95033]=3;p.storage[95034]=0;p.storage[95035]=0
events['talk:/ability'].callback(p,'/ability','arcanerecovery')
assert(p.storage[95030]==2 and p.storage[95072]==1,string.format('Arcane Recovery must restore a level-1 slot once per long rest (slots=%s used=%s message=%s)',tostring(p.storage[95030]),tostring(p.storage[95072]),tostring(p.message)))
print('Spell slots and hotkeys: selected-circle upcast, Second Wind and Arcane Recovery passed')
p=creature(31,true,2);rat=creature(32,false);p.target=rat;p.storage[95003]=2;fixed=20;tick()
events['talk:/combat'].callback(p,'/combat','dash')
assert(p:getTurnMovement()==6000,'Dash should add speed to remaining movement')
events['talk:/combat'].callback(p,'/combat','bonusdash')
assert(p:getTurnMovement()==9000,'Cunning Action Dash should independently spend bonus action')
events['talk:/combat'].callback(p,'/combat','bonusdash')
assert(p:getTurnMovement()==9000,'spent bonus action must not grant more movement')
events['talk:/turn'].callback(p,'/turn','end')
assert(p:getTurnMovement()==0 and rat:getTurnMovement()==2000,'ending turn must block previous actor and permit enemy')
tick();assert(p:getTurnMovement()==3000,'next turn must restore base speed')
print('Movement: turn ownership, Dash resources and joining encounter preserves budgets passed')

nativeDofile('world/content/gm_tools.lua')
p=creature(13,true,1);p.storage[95022]=14
events['talk:/gm'].callback(p,'/gm','level 4')
assert(p.storage[95003]==4 and p.storage[95004]==2700 and p.storage[95005]==1,'GM level must set D&D level and pend the level-four choice')
assert(p.storage[95060]==4 and p.storage[95061]==4 and p:getMaxHealth()>0,'GM level must initialize Hit Dice and derived HP')
assert(p:getLevel()==1,'GM D&D level must not mutate the engine level')
events['talk:/gm'].callback(p,'/gm','xp 3456')
assert(p.storage[95003]==4 and p.storage[95004]==3456)
local found=false;for _,message in ipairs(p.messages)do if message.text:find('PROGRESS level=4 xp=3456 next=6500',1,true)then found=true end end
assert(found,'GM XP must publish the final total, not only the level threshold')
print('GM: D&D level, level-four choice and derived resources passed without native addLevel')

-- Every enemy turn must use a real damage die; a 1d1 rule aborts the global
-- combat tick before initiative can advance.
extra=nil;p=creature(901,true,1);rat=creature(902,false);rat.name='Snake';rat.target=p
p.storage[95021]=1;p.pos=Position(111,111,7);rat.pos=Position(112,111,7)
fixed=20;tick()
assert(p.hp<100,'a Snake winning initiative must complete its 1d4+1 bite and advance the turn')
print('Enemy turns: Snake damage die completes without aborting initiative')

-- A rostered monster must still get its turn if TFS clears its selected target.
-- The global tick should reacquire the participating player and complete its attack.
p=creature(903,true,1);rat=creature(904,false);rat.name='Rat';rat.target=p
p.storage[95021]=20;p.pos=Position(111,111,7);rat.pos=Position(112,111,7)
fixed=20;tick()
assert(p:getTurnMovement()>0,'player should act first in the target-loss fixture')
rat.target=nil
events['talk:/turn'].callback(p,'/turn','end')
assert(rat:getTurnMovement()>0,'a rostered monster with a cleared target was skipped in initiative')
local hpBeforeRatTurn=p.hp;tick()
assert(p.hp<hpBeforeRatTurn,'monster turn failed to reacquire the player and attack after target loss')
print('Enemy turns: lost target is reacquired and initiative advances')

-- Spider damage must use a valid die size so its turn cannot abort the tick.
p=creature(905,true,1);rat=creature(906,false);rat.name='Spider';rat.target=p
p.storage[95021]=1;p.pos=Position(111,111,7);rat.pos=Position(112,111,7)
Game.getSpectators=function()return {p,rat}end
fixed=20;tick()
assert(p.hp<100,'Spider turn must complete its valid 1d4+1 bite')
print('Enemy turns: Spider bite completes without a Lua rules error')


-- PvP uses the same initiative and action budget, while respecting safe zones.
TILESTATE_PROTECTIONZONE=1
local safe=false
Tile=function() return {hasFlag=function() return safe end} end
p=creature(991,true,1);local opponent=creature(992,true,4)
p.storage[95021]=20;opponent.storage[95021]=8
p.target=opponent;rat=nil;extra=nil
Game.getPlayers=function() return {p,opponent} end
Game.getSpectators=function() return {p,opponent} end
fixed=20;tick()
local hp=opponent.hp
attack(p,'/attack','')
assert(opponent.hp<hp,'PvP weapon attack did not resolve through initiative')
events['talk:/turn'].callback(p,'/turn','end')
assert(opponent:getTurnMovement()>0,'PvP encounter ended instead of advancing to the opponent')
p=creature(993,true,1);opponent=creature(994,true,4);p.target=opponent
safe=true;tick();hp=opponent.hp;attack(p,'/attack','')
assert(opponent.hp==hp and p:getTurnMovement()==-1,'PvP bypassed a protection zone')
print('PvP: initiative, damage, opponent turn and protection zones passed')

-- Opportunity: one reaction per turn, only crossing out of melee reach.
safe=false;p=creature(995,true,1);rat=creature(996,false)
p.storage[95021]=20;p.target=rat;rat.pos=Position(112,111,7)
Game.getPlayers=function() return {p} end
Game.getSpectators=function() return {p,rat} end
fixed=20;tick()
local step=events['move:opportunity'].callback
local before=p.hp
p.pos=Position(111,112,7);step(p,nil,Position(111,111,7))
assert(p.hp==before,'movement within reach provoked a reaction')
p.pos=Position(110,111,7);step(p,nil,Position(111,111,7))
assert(p.hp==before-1,'leaving melee reach did not provoke Rat reaction')
step(p,nil,Position(111,111,7));assert(p.hp==before-1,'enemy used two reactions before its turn')
events['talk:/turn'].callback(p,'/turn','end');tick()
step(p,nil,Position(111,111,7));assert(p.hp==before-2,'reaction did not refresh at start of enemy turn')
events['talk:/combat'].callback(p,'/combat','disengage')
events['talk:/turn'].callback(p,'/turn','end');tick()
-- A new turn removes Disengage; taking it again consumes the new action.
events['talk:/combat'].callback(p,'/combat','disengage')
before=p.hp;step(p,nil,Position(111,111,7));assert(p.hp==before,'Disengage failed to prevent opportunity attack')
p.pos=Position(111,111,7);local enemyHp=rat.hp
attack(p,'/attack','');assert(rat.hp==enemyHp,'Disengage did not consume the action')
print('Opportunity: reach crossing, one reaction, turn refresh and Disengage passed')

-- A newly visible enemy cannot insert an immediate turn into this round.
p=creature(997,true,1);rat=creature(998,false);extra=nil
p.storage[95021]=20;p.target=rat
Game.getPlayers=function() return {p} end
Game.getSpectators=function() local list={p,rat};if extra then list[#list+1]=extra end;return list end
fixed=20;tick();extra=creature(999,false);extra.name='Snake';extra.target=p;tick()
events['talk:/turn'].callback(p,'/turn','end')
assert(rat:getTurnMovement()>0 and extra:getTurnMovement()==0,'new enemy stole a turn in the current round')
tick();events['talk:/turn'].callback(p,'/turn','end')
assert(extra:getTurnMovement()>0,'new enemy was not eligible on the next round')
print('Initiative: late enemy waits for next round and then takes its sorted turn')

p=creature(1001,true,1);rat=creature(1002,false);extra=nil
p.storage[95021]=20;p.target=rat;p.chase=true
Game.getPlayers=function()return {p}end
Game.getSpectators=function()return {p,rat}end
fixed=20;tick();p:setTurnMovement(0);p.follow=nil;tick()
assert(p.target==rat and p.follow==nil,'exhausted movement should retain attack target without starting pursuit')
p.target=nil;tick();assert(p.target==nil,'explicit cancellation was undone')
print('Target persistence: attack, spell, spent movement and explicit cancellation passed')

-- Player saves use class proficiency, and Resilient never adds it twice.
for index,scenario in ipairs({{class=2,feat=false,expected=100},{class=1,feat=false,expected=92},{class=1,feat=true,expected=100},{class=2,feat=true,expected=100}}) do
 p=creature(1100+index*2,true,3);rat=creature(p.id+1,true,scenario.class);extra=nil
 p.target=rat;p.storage[95024]=16;rat.storage[95021]=14
 if scenario.feat then rat.storage[95008]=2;rat.storage[95009]=1 end
 Game.getPlayers=function()return {p}end
 Game.getSpectators=function()return {p,rat}end
 fixed=20;tick();fixed=9;cast(p,'/cast','sacredflame')
 assert(rat.hp==scenario.expected,'Dexterity save scenario '..index..' hp='..rat.hp..' message='..tostring(p.message))
end
print('Saving throws: class proficiency and Resilient apply to spell defenses without stacking')

-- Barbarian's actual hotkey -> attack -> enemy turn path, not a sheet-only test.
local useAbility=events['talk:/ability'].callback
p=creature(1200,true,5);rat=creature(1201,false);p.target=rat;extra=nil
p.storage[95003]=5
Game.getPlayers=function()return {p}end
Game.getSpectators=function()return {p,rat}end
fixed=20;tick()
assert(p:getTurnMovement()==4000,'Fast Movement must add ten feet at barbarian 5')
useAbility(p,'/ability','frenzy')
assert(p.storage[95100]==1,'Frenzy must spend one daily Rage')
local hp=rat.hp;useAbility(p,'/ability','frenzyattack')
assert(rat.hp==hp,'Frenzy bonus attack was allowed on the activation turn')
attack(p,'/attack','');attack(p,'/attack','')
assert(rat.hp==42,'barbarian must get two d12 attacks with +2 Rage damage at level 5')
hp=rat.hp;attack(p,'/attack','');assert(rat.hp==hp,'barbarian received a third Attack-action strike')
events['talk:/turn'].callback(p,'/turn','end');tick()
assert(p.hp==100,'Rage physical resistance must round one physical damage down to zero')
useAbility(p,'/ability','frenzyattack')
assert(rat.hp==13,'Frenzy must grant one bonus-action attack on subsequent turns')
hp=rat.hp;useAbility(p,'/ability','frenzyattack');assert(rat.hp==hp,'Frenzy did not consume the bonus action')
events['event:DndLogout'].callback(p)
assert(p.storage[95101]==1,'Ending Frenzy must persist one level of exhaustion')
assert(p.storage[95100]==1,'Logging out reset the daily Rage budget')
p.target=nil;Game.getSpectators=function()return {p}end
events['talk:/rest'].callback(p,'/rest','short 0')
assert(p.storage[95100]==1 and p.storage[95101]==1,'short rest incorrectly restored Rage or exhaustion')
events['talk:/rest'].callback(p,'/rest','long')
assert(p.storage[95100]==0 and p.storage[95101]==0,'long rest must restore Rage uses and remove one exhaustion level')
print('Barbarian: Frenzy hotkeys, d12 weapon, Rage damage/resistance, Extra Attack, movement, exhaustion and recovery passed')

-- Uncanny Dodge halves one attack per reaction, not every ray or area damage.
p=creature(1210,true,1);rat=creature(1211,true,2);p.target=rat
p.storage[95003]=5;rat.storage[95003]=5
Game.getPlayers=function()return {p}end;Game.getSpectators=function()return {p,rat}end
fixed=20;tick();attack(p,'/attack','');assert(rat.hp==91,'Uncanny Dodge must halve a visible attack')
attack(p,'/attack','');assert(rat.hp==72,'Uncanny Dodge spent the same reaction twice')
p=creature(1220,true,4);rat=creature(1221,true,2);p.target=rat
p.storage[95003]=5;rat.storage[95003]=5
fixed=1;tick();cast(p,'/cast','fireball 111 111 7')
assert(rat.hp==92,'Uncanny Dodge must not reduce Fireball save damage')
print('Rogue: Uncanny Dodge spends one reaction and excludes save/area damage')

p=creature(1230,true,8);rat=creature(1231,false);p.target=rat;p.storage[95003]=5
fixed=20;tick();local hp=rat.hp
useAbility(p,'/ability','flurry');assert(rat.hp==hp and not p.storage[95120],'Flurry was allowed before the Attack action')
attack(p,'/attack','');attack(p,'/attack','');useAbility(p,'/ability','flurry')
assert(rat.hp==40 and p.storage[95120]==1,'Monk must get two weapon attacks and two d6 martial arts strikes for one Ki/bonus action')
hp=rat.hp;useAbility(p,'/ability','martialarts');assert(rat.hp==hp,'Monk bonus attack did not respect the spent bonus action')
assert(p:getTurnMovement()==4000,'Monk unarmored movement missing')
events['event:DndLogout'].callback(p);p.target=nil;Game.getSpectators=function()return {p}end
events['talk:/rest'].callback(p,'/rest','short 0');assert(p.storage[95120]==0,'Monk Ki must recover on short rest')

p=creature(1240,true,8);rat=creature(1241,false);p.target=rat;p.storage[95003]=5
Game.getSpectators=function()return {p,rat}end
fixed=10;tick();useAbility(p,'/ability','stunningstrike');attack(p,'/attack','')
assert(p.storage[95120]==1,'Stunning Strike must spend Ki on a hit')
events['talk:/turn'].callback(p,'/turn','end');local hp=p.hp;tick()
assert(p.hp==hp and p:getTurnMovement()>0,'A stunned enemy must skip its turn without freezing initiative')
events['talk:/turn'].callback(p,'/turn','end');fixed=20;tick()
assert(p.hp<hp,'Stun must end at the end of the monk next turn')
print('Monk: Attack/Flurry/bonus budgets, Ki recovery, movement and Stunning Strike expiry passed')

p=creature(1250,true,4);rat=creature(1251,false);p.target=rat;p.storage[95003]=3;rat.hp=1
function rat:getName()assert(self.hp>0,'accessed removed creature after lethal spell ray');return 'Rat' end
fixed=20;tick();cast(p,'/cast','scorchingray')
assert(rat.hp<=0,'Scorching Ray did not resolve its lethal first ray')
print('Spell volley: lethal ray stops without accessing a removed target')

events['event:DndLogout'].callback(p)
db={storeQuery=function()return nil end}
local function ended(actor)
 for _,entry in ipairs(actor.messages or {}) do if entry.text=='[5E] ENCOUNTER ended' then return true end end
 return false
end
for _,multiple in ipairs({false,true}) do
 p=creature(multiple and 1310 or 1300,true,1);rat=creature(p.id+1,false);extra=multiple and creature(p.id+2,false) or nil
 p.target=rat;p.follow=rat;rat.target=p;if extra then extra.target=p end
 Game.getPlayers=function()return {p}end
 Game.getSpectators=function(pos,multi,players)if players then return {p}end;return extra and {p,rat,extra} or {p,rat}end
 fixed=10;tick();rat.target=p;rat.follow=p
 events['talk:/turn'].callback(p,'/turn','flee')
 assert(ended(p) and p.target==nil and p.follow==nil,'Successful flee did not clear the player target/follow and end initiative')
 assert(p:getTurnMovement()==-1 and rat:getTurnMovement()==-1,'Successful flee kept a native turn movement limit')
 assert(rat.target==nil and rat.follow==nil,'Enemy retained chase after successful flee')
 if extra then assert(extra:getTurnMovement()==-1,'Orphan monster encounter remained after last player fled') end
 local afterFlee=#p.messages
 for _=1,6 do time=time+250;tick();assert(p:getTurnMovement()==-1,'Next tick re-applied turn movement after escape')end
 for index=afterFlee+1,#p.messages do
  local text=p.messages[index].text
  assert(not text:find('[5E] ORDER ',1,true) and not text:find('[5E] TURNSTATE ',1,true),'Fled player still received initiative/resource restrictions')
 end
 p.pos=Position(125,125,7);time=time+11000;tick()
 assert(p:getTurnMovement()==-1,'Exploration remained turn limited after running away')
end

-- A tie/failure must keep the encounter and spend the attempt's action.
p=creature(1320,true,1);rat=creature(1321,false);extra=nil;p.target=rat;rat.name='Orc'
fixed=10;tick();events['talk:/turn'].callback(p,'/turn','flee')
assert(not ended(p) and p:getTurnMovement()>=0,'Failed/tied Athletics erroneously escaped')
local beforeFailure=rat.hp;attack(p,'/attack','');assert(rat.hp==beforeFailure,'Failed flee did not consume the action')
events['event:DndLogout'].callback(p)

-- The opponent's stale PvP selection cannot immediately put the runner back.
p=creature(1330,true,1);rat=creature(1331,true,1);p.target=rat;rat.target=p;rat.follow=p;rat.storage[95020]=2
Game.getPlayers=function()return {p,rat}end
Game.getSpectators=function()return {p,rat}end
fixed=10;tick();events['talk:/turn'].callback(p,'/turn','flee')
assert(ended(p) and ended(rat) and rat.target==nil and rat.follow==nil,'PvP opponent retained an escaped target')
tick();assert(p:getTurnMovement()==-1 and rat:getTurnMovement()==-1,'Stale PvP selection restarted initiative')
print('Flee: successful exit restores free exploration, closes orphan encounters, clears chase and preserves failed-attempt action cost in PvE/PvP')

local function scenario(id,cls,lv,enemyClass)
 p=creature(id,true,cls);rat=creature(id+1,enemyClass~=nil,enemyClass);extra=nil
 p.storage[95003]=lv;p.storage[95021]=20;p.target=rat;rat.pos=Position(112,111,7)
 Game.getPlayers=function()return enemyClass and {p,rat}or {p}end
 Game.getSpectators=function()return {p,rat}end
 fixed=10;tick();return p,rat
end
local function hasMessage(actor,part)
 for _,entry in ipairs(actor.messages or {}) do if entry.text:find(part,1,true) then return true end end
 return false
end
scenario(1400,9,2)
useAbility(p,'/ability','divinesmite');local slots=p.storage[95030]
attack(p,'/attack','')
assert(rat.hp==73 and p.storage[95030]==slots-1,'Smite must add 2d8 radiant and spend one first-level slot on hit')
local hp=rat.hp;attack(p,'/attack','');assert(rat.hp==hp,'Smite granted an extra action')

scenario(1410,9,5);p.storage[95036]=2;useAbility(p,'/ability','divinesmite');fixed=20
attack(p,'/attack','')
assert(rat.hp==33 and p.storage[95031]==1,'Critical second-level Smite must double all 3d8 radiant dice')
fixed=10;attack(p,'/attack','');assert(rat.hp==-2,'Paladin level 5 must have two attacks per action')

scenario(1420,9,2);useAbility(p,'/ability','divinesmite');fixed=1;local slots=p.storage[95030]
attack(p,'/attack','');assert(rat.hp==100 and p.storage[95030]==slots,'Miss spent a Smite slot')

scenario(1430,9,2,2);rat.storage[95003]=5;rat.storage[95010]=10
useAbility(p,'/ability','divinesmite');attack(p,'/attack','')
assert(rat.hp==87,'Uncanny Dodge must reduce the weapon and radiant parts of the same attack with one reaction')

scenario(1440,9,2);p.hp=50
useAbility(p,'/ability','layonhands 5');assert(p.hp==55 and p.storage[95131]==5,'Lay on Hands must heal and spend its own pool')
local hp=rat.hp;attack(p,'/attack','');assert(rat.hp==hp,'Lay on Hands did not consume the action')
events['talk:/turn'].callback(p,'/turn','end');tick()
useAbility(p,'/ability','layonhands 6');assert(p.storage[95131]==5,'Lay on Hands exceeded its remaining pool')
useAbility(p,'/ability','layonhands 5');assert(p.storage[95131]==10,'Lay on Hands rejected its exact remaining pool')
events['event:DndLogout'].callback(p);p.target=nil;Game.getSpectators=function()return {p}end
events['talk:/rest'].callback(p,'/rest','short 0');assert(p.storage[95131]==10,'Short rest restored Lay on Hands')
events['talk:/rest'].callback(p,'/rest','long');assert(p.storage[95131]==0,'Long rest did not restore Lay on Hands')

scenario(1450,9,2);p.hp=50;p.storage[95025]=16
cast(p,'/cast','curewounds');assert(p.hp==61,'Paladin Cure Wounds must use CHA without Life Domain bonus')

scenario(1460,9,3);p.storage[95025]=16
useAbility(p,'/ability','sacredweapon');local hp=rat.hp
attack(p,'/attack','');assert(rat.hp==hp,'Sacred Weapon did not spend an action')
events['talk:/turn'].callback(p,'/turn','end');tick();attack(p,'/attack','')
assert(hasMessage(p,'d20=10 +8 = 18'),'Sacred Weapon failed to add CHA to weapon accuracy')
events['event:DndLogout'].callback(p);p.target=nil;Game.getSpectators=function()return {p}end
events['talk:/rest'].callback(p,'/rest','short 0');assert(p.storage[95133]==0,'Channel Divinity did not recover on short rest')
print('Paladin: Smite hit/miss/critical/slots/reaction, Extra Attack, Lay on Hands, CHA healing, Sacred Weapon and recovery passed')

scenario(1470,3,3);p.hp=50
cast(p,'/cast','healingword');local healed=p.hp;local slots=p.storage[95030]
cast(p,'/cast','curewounds');assert(p.hp==healed and p.storage[95030]==slots,'Bonus-action spell rule allowed a leveled action spell')
assert(healed==60,'Healing Word must use d4 + WIS + Disciple of Life')

scenario(1480,3,3,1);rat.storage[95021]=8;rat.storage[95010]=10
cast(p,'/cast','bless');assert(hasMessage(p,'CONCENTRACAO'),'Bless did not start concentration')
events['talk:/turn'].callback(p,'/turn','end');tick()
cast(rat,'/cast','bless');assert(rat.message=='Sua classe/raca nao conhece essa magia.','Fighter gained a class-restricted spell')
rat.target=p;p.storage[95010]=10;p.storage[95022]=8;fixed=6
attack(rat,'/attack','');assert(hasMessage(p,'PERDEU'),'Damage did not trigger or break concentration')
events['talk:/turn'].callback(rat,'/turn','end');tick()
cast(p,'/cast','bless');events['talk:/turn'].callback(p,'/turn','end');tick()
events['talk:/turn'].callback(rat,'/turn','end');tick()
cast(p,'/cast','shieldoffaith');assert(hasMessage(p,'Concentracao encerrada: bless'),'New concentration did not replace the old spell')
print('Spell integration: Healing Word bonus action, Life Domain, class access, concentration saves and replacement passed')

scenario(1500,2,5,1);rat.storage[95010]=10
attack(p,'/attack','');assert(rat.hp==87,'A solo PvP target counted as its own ally for Sneak Attack')

scenario(1510,2,5);extra=creature(1512,true,1);extra.pos=Position(112,112,7)
Game.getSpectators=function()return {p,rat,extra}end
attack(p,'/attack','');assert(rat.hp==69,'Adjacent non-incapacitated ally must enable 3d6 Sneak Attack at level 5')
events['talk:/turn'].callback(p,'/turn','end')
rat.pos=Position(113,111,7);step(rat,nil,Position(112,111,7))
assert(rat.hp==38,'Sneak Attack must also work once on an enemy turn with an opportunity reaction')
step(rat,nil,Position(112,111,7));assert(rat.hp==38,'Opportunity attack reused its reaction')
print('Rogue: solo PvP exclusion, adjacent ally and once-per-turn opportunity Sneak Attack passed')

scenario(1520,1,1);p.storage[95002]=8;fixed=20
attack(p,'/attack','');assert(rat.hp==73,'Half-Orc critical must add one weapon die, not double the extra racial die')

scenario(1530,1,1);p.storage[95002]=8;p.hp=1
events['talk:/turn'].callback(p,'/turn','end');fixed=20;tick()
assert(p.hp==1 and p.storage[95140]==1,'Relentless Endurance must leave one HP and spend its daily use')
events['talk:/turn'].callback(p,'/turn','end');tick();assert(p.hp==0,'Relentless Endurance reused its daily charge')

scenario(1540,1,1);p.storage[95002]=8;p.hp=1;p.maxhp=1;rat.name='Orc'
events['talk:/turn'].callback(p,'/turn','end');fixed=20;tick()
assert(p.hp<0 and not p.storage[95140],'Relentless Endurance must not prevent instant death from massive damage')
print('Half-Orc: Savage Attacks critical die, daily Relentless Endurance and massive-damage exclusion passed')

-- Expanded classes are tested through actual world command callbacks before
-- exposing them in creation; catalogue presence alone cannot pass these tests.
scenario(1600,12,5);p.storage[95025]=16
useAbility(p,'/ability','invocation agonizingblast')
assert(p.storage[95430]==1,'Agonizing Blast choice was not persisted')
fixed=10;cast(p,'/cast','eldritchblast')
assert(rat.hp==74,'Eldritch Blast level 5 must resolve two d10+CHA beams independently')
events['event:DndLogout'].callback(p);p.target=nil;Game.getSpectators=function()return {p}end
p.storage[95032]=0;events['talk:/rest'].callback(p,'/rest','invalid')
assert(p.storage[95032]==0,'Malformed rest restored Pact Magic')
events['talk:/rest'].callback(p,'/rest','short 0');assert(p.storage[95032]==2,'Pact Magic did not recover both third-level slots on short rest')

scenario(1610,12,2)
useAbility(p,'/ability','invocation fiendishvigor');useAbility(p,'/ability','fiendishvigor')
events['talk:/turn'].callback(p,'/turn','end');local hp=p.hp;tick()
assert(p.hp==hp,'Temporary HP did not absorb enemy damage')
print('Warlock: invocation persistence, two Agonizing Blast beams, temporary HP, short-rest Pact Magic and malformed-rest rejection passed')

scenario(1620,11,3)
useAbility(p,'/ability','metamagic quickened');fixed=10;local slots=p.storage[95030]
cast(p,'/cast','magicmissile');assert(rat.hp==85 and p.storage[95420]==2,'Quickened Spell must use two Sorcery Points')
cast(p,'/cast','magicmissile');assert(p.storage[95030]==slots-1,'Quickened spell bypassed the bonus/action spell restriction')
useAbility(p,'/ability','metamagicoff');cast(p,'/cast','firebolt')
assert(rat.hp==75,'An action cantrip must remain legal after a quickened leveled spell')

scenario(1630,11,2);useAbility(p,'/ability','fontslot 1')
assert(p.storage[95420]==2 and p.storage[95030]==4,'Font of Magic did not create an extra first-level slot for two points')
tick();assert(p.storage[95030]==4,'Slot synchronization erased a created spell slot')
useAbility(p,'/ability','fontpoints 1');assert(p.storage[95030]==4,'Font of Magic reused its bonus action')
events['talk:/turn'].callback(p,'/turn','end');tick();useAbility(p,'/ability','fontpoints 1')
assert(p.storage[95030]==3 and p.storage[95420]==1,'Slot conversion did not restore exactly one Sorcery Point')
events['event:DndLogout'].callback(p);p.target=nil;Game.getSpectators=function()return {p}end
events['talk:/rest'].callback(p,'/rest','long')
assert(p.storage[95420]==0 and p.storage[95441]==0 and p.storage[95030]==3,'Long rest did not clear created slots and restore base Sorcerer resources')
print('Sorcerer: Quickened Spell cost, legal action cantrip, Font bonus costs, created slots and long-rest reset passed')

scenario(1640,6,5,1);p.storage[95025]=16
local ally=creature(1642,true,1);ally.pos=Position(111,112,7);p.follow=ally
useAbility(p,'/ability','inspiration');assert(p.storage[95410]==1,'Bardic Inspiration did not spend a daily use')
useAbility(ally,'/ability','useinspiration')
ally.target=rat;Game.getSpectators=function()return {p,rat,ally}end
events['talk:/turn'].callback(p,'/turn','end');events['talk:/turn'].callback(rat,'/turn','end');tick()
-- Roster join can defer the ally until the next round; its received die must
-- remain until a real attack/check consumes it, never just target selection.
assert(not hasMessage(ally,'Inspiracao Bardica: +'),'Selecting a target consumed Bardic Inspiration')
events['event:DndLogout'].callback(p);p.target=nil;p.follow=nil;Game.getSpectators=function()return {p}end
events['talk:/rest'].callback(p,'/rest','short 0');assert(p.storage[95410]==0,'Font of Inspiration at level 5 must restore uses on short rest')
print('Bard: bonus-action Inspiration, non-self target, persistent die and Font of Inspiration recovery passed')

scenario(1650,10,5);rat.hp=99;fixed=10
attack(p,'/attack','');assert(rat.hp==80,'Colossus Slayer must add d8 against an already wounded target')
attack(p,'/attack','');assert(rat.hp==69,'Colossus Slayer applied twice during the same turn')
print('Ranger: Extra Attack and Colossus Slayer once-per-turn wounded-target requirement passed')

scenario(1660,7,3);p.hp=50
useAbility(p,'/ability','wildshape wolf')
assert(p.hp==11 and p:getMaxHealth()==11 and p:getOutfit().lookType==27 and p.storage[95450]==1,'Wild Shape must replace HP, AC/physical stats and outfit while spending one use')
local slots=p.storage[95030];cast(p,'/cast','curewounds');assert(p.storage[95030]==slots,'Wild Shape allowed spellcasting')
attack(p,'/attack','');assert(rat.hp==100,'Wild Shape failed to spend its action')
events['talk:/turn'].callback(p,'/turn','end');tick()
attack(p,'/attack','');assert(rat.hp==90,'Wolf form must use its actual +4 bite for 2d4+2 damage')
p.hp=2;rat.name='Orc'
events['talk:/turn'].callback(p,'/turn','end');tick()
assert(p.hp==39 and p:getMaxHealth()==100 and p:getOutfit().lookType==131,'Dropping Wild Shape must restore original HP and carry only excess damage into normal form')
useAbility(p,'/ability','wildshape rat');assert(p.hp==1 and p.storage[95450]==2,'Second Wild Shape did not use its independent beast HP')
events['event:DndLogout'].callback(p)
assert(p.hp==39 and p:getMaxHealth()==100 and p.storage[95469]==0,'Logout must not persist a beast body or lose original HP')
p.target=nil;Game.getSpectators=function()return {p}end
events['talk:/rest'].callback(p,'/rest','short 0');assert(p.storage[95450]==0,'Wild Shape uses must recover on short rest')
print('Druid: action cost, real beast HP/outfit/attack, no casting, overflow damage, logout restoration and short-rest uses passed')

scenario(1670,12,5);p.storage[95025]=16;useAbility(p,'/ability','invocation agonizingblast')
cast(p,'/cast','hex');local pact=p.storage[95032]
cast(p,'/cast','eldritchblast')
assert(rat.hp==62 and pact==1 and p.storage[95032]==1,'Hex must use the current Pact slot, add d6 necrotic to each hit and allow an action cantrip')

scenario(1680,10,5);cast(p,'/cast','huntersmark');attack(p,'/attack','');attack(p,'/attack','')
assert(rat.hp==58,'Hunter Mark weapon dice and once-per-turn Colossus Slayer did not combine correctly')

scenario(1690,1,1);p.storage[95002]=5;p.storage[95500]=8
useAbility(p,'/ability','breath');assert(rat.hp==88 and p.storage[95501]==1,'Dragonborn red cone must deal 2d6 fire on a failed Dexterity save')
attack(p,'/attack','');assert(rat.hp==88,'Dragon breath failed to spend the action')
useAbility(p,'/ability','breath');assert(rat.hp==88,'Dragon breath reused its short-rest charge')
events['event:DndLogout'].callback(p);p.target=nil;Game.getSpectators=function()return {p}end
events['talk:/rest'].callback(p,'/rest','short 0');assert(p.storage[95501]==0,'Short rest did not restore Dragonborn breath')

scenario(1700,1,3);p.storage[95002]=9;p.storage[95010]=10;useAbility(p,'/ability','hellishrebuke')
events['talk:/turn'].callback(p,'/turn','end');tick()
assert(p.hp==99 and rat.hp==85 and p.storage[95521]==1,'Tiefling Hellish Rebuke must spend one reaction and its daily second-level casting, allowing the attacker save for half')

scenario(1710,4,1,1);rat.storage[95002]=9;rat.storage[95010]=10
cast(p,'/cast','firebolt');assert(rat.hp==95,'Tiefling fire resistance was not applied to live damage')

for _,race in ipairs({1,6})do
 scenario(1720+race*2,6,1,1);rat.storage[95002]=race
 local count=0
 math.random=function(low,high)if high==20 then count=count+1;return count==1 and 6 or 10 end;return high end
 cast(p,'/cast','viciousmockery')
 assert(count==(race==6 and 2 or 1)and rat.hp==(race==6 and 100 or 96),'Gnome Cunning must grant advantage on a magical Wisdom save, not a flat bonus')
 math.random=function(low,high)return math.min(fixed,high)end
end

scenario(1760,4,1,1);rat.storage[95002]=7;rat.hp=5
cast(p,'/cast','sleep 112 111 7');assert(not hasMessage(p,'ADORMECEU'),'Half-Elf must be immune to magical sleep without rolling a save')
scenario(1770,4,1,1);rat.hp=5;rat.storage[95010]=10
cast(p,'/cast','sleep 112 111 7');assert(hasMessage(p,'ADORMECEU'),'Sleep did not affect a non-Elf within its hit point pool')
events['talk:/turn'].callback(p,'/turn','end');local hp=p.hp;tick()
assert(p.hp==hp and p:getTurnMovement()>0,'Sleeping enemy did not skip its incapacitated turn')
attack(p,'/attack','');assert(rat.hp==-10,'An adjacent successful attack against a sleeping creature must be a critical hit')
print('Races and spells: Dragonborn breath/recovery, Tiefling fire resistance/reaction, Gnome magical-save advantage, Half-Elf Sleep immunity, Hex and Hunter Mark passed')

scenario(1800,1,1,4);rat.storage[95010]=12;useAbility(rat,'/ability','shield')
attack(p,'/attack','');assert(rat.hp==100 and rat.storage[95030]==1,'Shield must spend one reaction/slot and turn a normal hit into a miss')
events['talk:/turn'].callback(p,'/turn','end');useAbility(rat,'/ability','shield');events['talk:/turn'].callback(rat,'/turn','end')
attack(p,'/attack','');assert(rat.hp==89,'Shield must expire at the start of its caster next turn')
scenario(1810,1,1,4);useAbility(rat,'/ability','shield');fixed=20;attack(p,'/attack','')
assert(rat.hp==81 and rat.storage[95030]==2,'Shield must not negate a natural critical or automatically waste a slot on it')
scenario(1820,4,1,4);useAbility(rat,'/ability','shield');cast(p,'/cast','magicmissile')
assert(rat.hp==100 and rat.storage[95030]==1 and p.storage[95030]==1,'Shield must block Magic Missile while both spell slots remain spent')

scenario(1830,4,5,12);rat.storage[95003]=5;tick();useAbility(rat,'/ability','counterspell')
cast(p,'/cast','fireball 112 111 7')
assert(rat.hp==100 and p.storage[95032]==1 and rat.storage[95032]==1,'Counterspell must negate a spell after its action/slot cost, spending a reaction and third-level slot')
scenario(1840,4,5,12);rat.storage[95003]=5;tick();useAbility(p,'/ability','counterspell');useAbility(rat,'/ability','counterspell')
cast(p,'/cast','fireball 112 111 7')
assert(rat.hp==52 and p.storage[95032]==0 and rat.storage[95032]==1,'A legal Counterspell against Counterspell must let the original spell resolve')
scenario(1850,11,5,12);rat.storage[95003]=5;rat.storage[95010]=10;tick()
useAbility(p,'/ability','counterspell');useAbility(rat,'/ability','counterspell');useAbility(p,'/ability','metamagic quickened')
cast(p,'/cast','firebolt');assert(rat.hp==100 and p.storage[95032]==2,'A bonus-action caster must not cast a reaction spell during that same turn')
useAbility(p,'/ability','metamagicoff');cast(p,'/cast','firebolt');assert(rat.hp==80,'Countered quickened spell must still leave an action cantrip legal')
print('Reactions: Shield hit/miss/critical/duration/Magic Missile and Counterspell costs, chains and bonus-spell restriction passed')

scenario(1860,1,5);p.storage[95002]=9;cast(p,'/cast','darkness 112 111 7')
assert(p.storage[95522]==1 and p.storage[95030]==0 and p.storage[95032]==0,'Tiefling Darkness must work once daily without requiring or creating class slots')
scenario(1870,12,5);useAbility(p,'/ability','invocation devilssight');cast(p,'/cast','darkness 112 111 7')
events['talk:/turn'].callback(p,'/turn','end');tick()
do
 local count=0
 math.random=function(low,high)if high==20 then count=count+1 end;return math.min(10,high)end
 cast(p,'/cast','eldritchblast')
 assert(count==4,'Devils Sight must let its caster see through Darkness and attack an otherwise blinded enemy with advantage')
 math.random=function(low,high)return math.min(fixed,high)end
end
print('Darkness: once-daily Tiefling casting, concentration, obscured attacks and Devils Sight passed')

do
 local queries=0
 db.storeQuery=function()queries=queries+1;return 1 end
 result={getString=function(_,key)return key=='trained'and'["Performance","Persuasion","Deception","Insight","Religion","Survival"]'or'[]'end,free=function()end}
 scenario(1880,6,3)
 useAbility(p,'/ability','loreproficiency perception,stealth,athletics')
 useAbility(p,'/ability','expertise perception,performance')
 assert(p.storage[95481]>0 and p.storage[95480]>0,'Lore skill and Expertise choices must persist in separate masks')
 events['talk:/check'].callback(p,'/check','perception')
 assert(hasMessage(p,'d20=10 +7 = 17'),'Chosen Bard Expertise did not double proficiency in a real skill check')
 assert(queries==1,'Skill choices/checks must read the profile once per session, not issue a query per skill')
 scenario(1890,1,1);p.storage[95002]=6
 events['talk:/check'].callback(p,'/check','history magic-item')
 assert(hasMessage(p,'d20=10 +7 = 17'),'Rock Gnome Artificer Lore must add double proficiency to a relevant History check even if untrained')
end
print('Progression: Lore bonus skills, chosen Expertise, Gnome Artificer Lore and cached profile reads passed')

-- XP must refresh even when an award does not cross a level threshold.
do
 scenario(1900,1,1)
 p.storage[95004]=12
 events['event:DndKill'].callback(p,rat,true)
 assert(p.storage[95004]>12,'Kill must award D&D XP')
 assert(hasMessage(p,'PROGRESS level=1 xp='..p.storage[95004]..' next=300'),'Non-level-up XP must refresh the HUD')
end
print('XP: authoritative D&D progress refreshes after ordinary kill awards')

do
 scenario(1910,1,4)
 p.storage[95004]=6499;p.storage[95005]=0
 events['event:DndKill'].callback(p,rat,true)
 assert(p.storage[95003]==5,'A completed level-four choice must permit level five at 6500 XP')
 scenario(1920,1,4)
 p.storage[95004]=6499;p.storage[95005]=1
 events['event:DndKill'].callback(p,rat,true)
 assert(p.storage[95003]==4,'Pending ASI must remain available before level five')
 events['talk:/levelup'].callback(p,'/levelup','str+2')
 assert(p.storage[95003]==5 and p.storage[95005]==0,'Completing ASI must immediately apply the earned fifth level')
end
print('XP: level-four choice gates correctly and releases earned level five immediately')

do
 scenario(1930,1,4)
 p.storage[95004]=6500;p.storage[95005]=0
 events['event:DndLogin'].callback(p)
 assert(p.storage[95003]==5,'Reconnect must repair level five blocked by the old ASI condition')
end
print('XP: reconnect repairs previously earned level five without changing saved XP')
