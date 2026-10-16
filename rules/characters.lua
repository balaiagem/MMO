-- Executable character mathematics for SRD 5.1, single-class levels 1-5.
-- The caller supplies equipment and choices; absent choices do not grant features.
local C={}
function C.new(data)
 local M={classes=data.classes,races=data.races}
 local abilities={'STR','DEX','CON','INT','WIS','CHA'}
 local armors={padded={11,99,'light'},leather={11,99,'light'},studded={12,99,'light'},hide={12,2,'medium'},chainshirt={13,2,'medium'},scale={14,2,'medium'},breastplate={14,2,'medium'},halfplate={15,2,'medium'},ringmail={14,0,'heavy'},chain={16,0,'heavy',13},splint={17,0,'heavy',15},plate={18,0,'heavy',15}}
 local function integer(n,lo,hi) assert(type(n)=='number' and n==math.floor(n) and n>=lo and n<=hi,'invalid character value');return n end
 local function modifier(n) return math.floor((integer(n,1,30)-10)/2) end
 local function contains(t,v) for _,x in ipairs(t) do if x==v then return true end end return false end
 function M.derive(classId,raceId,level,scores,options)
  options=options or {}
  local class=assert(data.classes[classId],'unknown class');local race=assert(data.races[raceId],'unknown race')
  integer(level,1,5)
  local mods={}
  for _,ability in ipairs(abilities) do mods[ability]=modifier(assert(scores[ability],'missing ability '..ability)) end
  local subclass=options.subclass
  if subclass then assert(subclass==class.subclass,'subclass does not belong to class') end
  local extraHp=(raceId==3 and 1 or 0)+(classId==11 and subclass=='draconic' and 1 or 0)
  local perLevel=math.max(1,math.floor(class.hitDie/2)+1+mods.CON+extraHp)
  local hp=math.max(1,class.hitDie+mods.CON+extraHp)+(level-1)*perLevel
  if options.feat=='tough' then hp=hp+2*level end
  local armor=options.armor and assert(armors[options.armor],'unknown armor') or nil
  local shield=options.shield and 2 or 0
  local ac=10+mods.DEX
  if armor then ac=armor[1]+(armor[2]==0 and 0 or math.min(armor[2],mods.DEX))
  else
   if classId==5 then ac=math.max(ac,10+mods.DEX+mods.CON) end
   if classId==8 and shield==0 then ac=math.max(ac,10+mods.DEX+mods.WIS) end
   if classId==11 and subclass=='draconic' then ac=math.max(ac,13+mods.DEX) end
   if options.mageArmor then ac=math.max(ac,13+mods.DEX) end
  end
  ac=ac+shield
  if options.fightingStyle=='defense' and armor then ac=ac+1 end
  local speed=race.speed
  if classId==5 and level>=5 and (not armor or armor[3]~='heavy') then speed=speed+10 end
  if classId==8 and level>=2 and not armor and shield==0 then speed=speed+10 end
  if armor and armor[4] and scores.STR<armor[4] and raceId~=3 then speed=math.max(0,speed-10) end
  local row=class.levels[level];local magic=row.magic;local slots={}
  for circle=1,3 do slots[circle]=magic['spell_slots_level_'..circle] or 0 end
  local features={}
  for lv=1,level do
   for _,feature in ipairs(class.levels[lv].features) do features[#features+1]=feature end
   if subclass then for _,feature in ipairs(class.subclassLevels[lv] or {}) do features[#features+1]=feature end end
  end
  local prof=level>=5 and 3 or 2
  local saves={}
  for _,ability in ipairs(abilities) do saves[ability]=mods[ability]+((contains(class.saves,ability) or options.resilient==ability) and prof or 0) end
  local prepared=0
  if classId==3 or classId==4 or classId==7 then prepared=math.max(1,level+(mods[class.spellAbility] or 0))
  elseif classId==9 and level>=2 then prepared=math.max(1,math.floor(level/2)+mods.CHA) end
  local attacks=(level>=5 and (classId==1 or classId==5 or classId==8 or classId==9 or classId==10)) and 2 or 1
  local cantrips=magic.cantrips_known or 0
  if classId==7 and subclass=='land' and level>=2 then cantrips=cantrips+1 end
  local canCast=cantrips>0 or slots[1]+slots[2]+slots[3]>0
  return {class=classId,race=raceId,level=level,hp=hp,ac=ac,speed=speed,hitDie=class.hitDie,proficiency=prof,initiative=mods.DEX+(classId==6 and level>=2 and math.floor(prof/2) or 0),darkvision=(raceId==2 or raceId==3 or raceId==6 or raceId==7 or raceId==8 or raceId==9) and 60 or 0,modifiers=mods,saves=saves,slots=slots,pactMagic=classId==12,attacks=attacks,preparedLimit=prepared,spellsKnown=magic.spells_known or 0,cantrips=cantrips,spellbook=classId==4 and (6+2*(level-1)) or 0,spellAbility=class.spellAbility,spellDC=canCast and class.spellAbility~='' and (8+prof+mods[class.spellAbility]) or 0,features=features}
 end
 function M.resources(classId,level,charisma,options)
  options=options or {}
  local class=assert(data.classes[classId],'unknown class');integer(level,1,5);integer(charisma,-5,10)
  local specific=class.levels[level].specific;local result={}
  local function pool(key,cap,recovery) if cap>0 then result[key]={maximum=cap,recovery=recovery} end end
  if classId==1 then pool('secondwind',1,'short');pool('actionsurge',level>=2 and 1 or 0,'short')
  elseif classId==3 then pool('channeldivinity',specific.channel_divinity_charges or 0,'short')
  elseif classId==4 then pool('arcanerecovery',1,'long')
  elseif classId==5 then pool('rage',specific.rage_count or 0,'long')
  elseif classId==6 then pool('inspiration',math.max(1,charisma),level>=5 and 'short' or 'long')
  elseif classId==7 then pool('wildshape',level>=2 and 2 or 0,'short');pool('naturalrecovery',level>=2 and options.subclass=='land' and 1 or 0,'long')
  elseif classId==8 then pool('ki',specific.ki_points or 0,'short')
  elseif classId==9 then pool('layonhands',5*level,'long');pool('divinesense',math.max(0,1+charisma),'long');pool('channeldivinity',level>=3 and 1 or 0,'short')
  elseif classId==11 then pool('sorcery',specific.sorcery_points or 0,'long') end
  return result
 end
 function M.syncPools(previous,definitions)
  local pools={}
  for key,definition in pairs(definitions) do
   local old=previous and previous[key]
   local maximum=integer(definition.maximum,1,100)
   local remaining=old and math.min(maximum,math.max(0,old.remaining)+math.max(0,maximum-old.maximum)) or maximum
   pools[key]={maximum=maximum,remaining=remaining,recovery=definition.recovery}
  end
  return pools
 end
 function M.spendPool(pools,key,amount)
  amount=integer(amount or 1,1,100)
  local pool=pools[key]
  if not pool or pool.remaining<amount then return false end
  pool.remaining=pool.remaining-amount;return true
 end
 function M.restorePools(pools,rest)
  assert(rest=='short' or rest=='long','invalid rest')
  for _,pool in pairs(pools) do if rest=='long' or pool.recovery=='short' then pool.remaining=pool.maximum end end
 end
 function M.skillBonus(classId,level,abilityModifier,trained,expertise)
  integer(level,1,5);integer(abilityModifier,-5,10)
  assert(not expertise or trained,'expertise requires proficiency')
  local prof=level>=5 and 3 or 2
  return abilityModifier+(trained and prof*(expertise and 2 or 1) or (classId==6 and level>=2 and math.floor(prof/2) or 0))
 end
 function M.saveTraits(raceId,ability,context)
  assert(data.races[raceId],'unknown race');context=context or {}
  return {advantage=(raceId==3 and context.poison) or ((raceId==2 or raceId==7) and context.charm) or (raceId==4 and context.fear) or (raceId==6 and context.magic and (ability=='INT' or ability=='WIS' or ability=='CHA')) or false,
   immuneSleep=(raceId==2 or raceId==7) and context.magicalSleep or false}
 end
 function M.resistance(raceId,damageType,ancestry)
  if raceId==3 then return damageType=='poison' end
  if raceId==9 then return damageType=='fire' end
  if raceId==5 then
   local types={black='acid',blue='lightning',brass='fire',bronze='lightning',copper='acid',gold='fire',green='poison',red='fire',silver='cold',white='cold'}
   assert(types[ancestry],'dragonborn ancestry required');return damageType==types[ancestry]
  end
  return false
 end
 return M
end
return C
