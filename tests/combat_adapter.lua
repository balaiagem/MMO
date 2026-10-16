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
 local mapped={['data/lib/dnd_rules.lua']='rules/core.lua',['data/lib/dnd_characters.lua']='rules/characters.lua',['data/lib/dnd_character_data.lua']='rules/character_data.lua'}
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
