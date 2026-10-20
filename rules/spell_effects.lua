-- =====================================================================
-- Tibia 5e: efeitos das magias (SRD 2014) que nao cabem nos tipos simples
-- do dnd_combat (condicoes, zonas, controle, utilidade) + regras de 0 PV.
-- Carregado pelo dnd_combat com o contexto do motor (c). Puro Lua 5.4/5.5.
--
-- Condicoes: state(alvo).conds[nome] = {spell, sourceId, expires, rounds,
--   flags={...}, save={ability,dc,timing,advantage}, data}
--   rounds conta turnos do proprio alvo (descontado no inicio do turno dele);
--   fora de combate vale expires (tempo real, 1 rodada = 6 s).
-- Zonas: zones[id] = {spell, ownerId, center, radius, square, expires,
--   difficult, obscure, effect, follow}
-- =====================================================================
local M={}
function M.new(c)
 local R=c.R
 local S={}
 local zones={}
 local zoneSeq=0
 local ROUND=6000
 local DIRS={{0,-1},{1,0},{0,1},{-1,0},{-1,1},{1,1},{-1,-1},{1,-1}}
 local DIRCONST={[1]=DIRECTION_NORTH or 0,[2]=DIRECTION_EAST or 1,[3]=DIRECTION_SOUTH or 2,[4]=DIRECTION_WEST or 3,
  [5]=DIRECTION_SOUTHWEST or 4,[6]=DIRECTION_SOUTHEAST or 5,[7]=DIRECTION_NORTHWEST or 6,[8]=DIRECTION_NORTHEAST or 7}
 local ABIL={'str','dex','con','int','wis','cha'}
 local ABIL_PT={[0]='FOR','DES','CON','INT','SAB','CAR'}
 local ABIL_EN={[0]='STR','DEX','CON','INT','WIS','CHA'}
 local ABIL_ARG={str=0,forca=0,dex=1,des=1,destreza=1,con=2,constituicao=2,int=3,inteligencia=3,wis=4,sab=4,sabedoria=4,cha=5,car=5,carisma=5}
 local function tell(p,text) if c.isPlayer(p) then p:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE,'[5E] '..text) end end
 local function warn(p,text) if c.isPlayer(p) then p:sendTextMessage(MESSAGE_STATUS_SMALL,text) end end
 local function now() return c.now() end
 local function alive(x) return c.alive(x) end
 local hostileOrAny,concentrateFix,zoneFor
 local function inEncounter(x) return c.state(x).encounter~=nil end
 local function idOf(x) local ok,id=pcall(function() return x:getId() end);return ok and id or nil end
 local function creatureById(id) return id and Creature(id) or nil end
 local function posOf(x) local ok,p=pcall(function() return x:getPosition() end);return ok and p or nil end
 local function dist(a,b) return math.max(math.abs(a.x-b.x),math.abs(a.y-b.y)) end
 local function sqDist(a,b) local dx,dy=a.x-b.x,a.y-b.y;return dx*dx+dy*dy end
 local function rule(x) return c.monsterRule(x) end
 local function ctype(x) local r=rule(x);return r and r.creatureType or (c.isPlayer(x) and 'humanoid' or nil) end
 local function abilityScore(x,index)
  if c.isPlayer(x) then return c.score(x,index) end
  local r=rule(x);return r and r[ABIL[index+1]] or 10
 end
 local function d(count,sides,flat) return R.damage(math.max(1,count),sides,flat or 0,false,c.rng) end
 local function maxDice(count,sides,flat) return count*sides+(flat or 0) end

 -- ---------------------------------------------------------- condicoes
 local function conds(x) local s=c.state(x);s.conds=s.conds or {};return s.conds end
 local function condActive(x,entry)
  if not entry then return false end
  if inEncounter(x) then return entry.rounds==nil or entry.rounds>0 end
  return entry.expires==nil or entry.expires>now()
 end
 local function getCond(x,name)
  local list=c.state(x).conds
  local entry=list and list[name]
  if entry and not condActive(x,entry) then list[name]=nil;S.onCondRemoved(x,name,entry);return nil end
  return entry
 end
 S.getCond=getCond
 local function flag(x,f)
  local list=c.state(x).conds
  if not list then return nil end
  for name,entry in pairs(list) do
   if condActive(x,entry) then
    if entry.flags and entry.flags[f] then return entry end
   else list[name]=nil;S.onCondRemoved(x,name,entry) end
  end
  return nil
 end
 S.flag=flag
 local function addCond(x,name,entry)
  entry.spell=entry.spell or name
  if entry.duration then entry.expires=entry.expires or now()+entry.duration end
  conds(x)[name]=entry
  return entry
 end
 local function removeCond(x,name)
  local list=c.state(x).conds
  local entry=list and list[name]
  if entry then list[name]=nil;S.onCondRemoved(x,name,entry) end
  return entry
 end
 S.removeCond=removeCond
 local function frightenedBy(x)
  local e=flag(x,'frightened');if not e then return nil end
  return creatureById(e.sourceId),e
 end
 local function incapacitated(x)
  local s=c.state(x)
  if s.dying or s.dead or s.sleeping or s.stunned then return true end
  return flag(x,'incapacitated')~=nil or flag(x,'paralyzed')~=nil
 end
 S.incapacitated=incapacitated
 local function sees(viewer,target)
  if flag(viewer,'blinded') then return false end
  if flag(target,'invisible') and not flag(target,'outlined') then return false end
  return true
 end

 -- Tibia: condicoes visuais/engine
 local function tibiaCondition(x,ctype,ticks,params)
  if not Condition then return end
  local ok=pcall(function()
   local cond=Condition(ctype)
   cond:setParameter(CONDITION_PARAM_TICKS,ticks)
   for k,v in pairs(params or {}) do cond:setParameter(k,v) end
   x:addCondition(cond)
  end)
  return ok
 end
 local function giveLight(x,levelLight,ticks)
  tibiaCondition(x,CONDITION_LIGHT,ticks,{[CONDITION_PARAM_LIGHT_LEVEL]=levelLight,[CONDITION_PARAM_LIGHT_COLOR]=215})
 end
 local function setInvisible(x,on,ticks)
  pcall(function()
   if on then tibiaCondition(x,CONDITION_INVISIBLE,ticks or 3600000)
   else x:removeCondition(CONDITION_INVISIBLE) end
  end)
 end

 function S.onCondRemoved(x,name,entry)
  if entry.flags and entry.flags.invisible then setInvisible(x,false) end
  if name=='aid' and c.isPlayer(x) and entry.data then
   pcall(function()
    x:setMaxHealth(math.max(1,x:getMaxHealth()-entry.data))
    if x:getHealth()>x:getMaxHealth() then x:addHealth(x:getMaxHealth()-x:getHealth()) end
   end)
  end
  if name=='haste' and alive(x) then
   -- Letargia: ate o fim do proximo turno nao pode se mover nem agir.
   c.state(x).lethargy=true
   tell(x,'Velocidade acabou: letargia ate o fim do seu proximo turno.')
  end
  if entry.flags and (entry.flags.paralyzed or entry.flags.restrained or entry.flags.incapacitated) and not inEncounter(x) then
   if not incapacitated(x) and not flag(x,'restrained') then pcall(function() x:setTurnMovement(-1) end) end
  end
 end

 -- ----------------------------------------------------- concentracao
 local function concentrate(p,name,rounds,targets)
  c.endConcentration(p)
  local s=c.state(p)
  s.buffs=s.buffs or {}
  s.buffs[name]={source=p,expires=now()+rounds*ROUND}
  s.concentration={name=name,targets={p},turns=rounds,ext=true,extra=targets}
 end
 function S.onConcentrationEnd(p,active)
  if not active then return end
  local pid=p:getId()
  -- condicoes que esta concentracao mantinha
  for _,victim in ipairs(S.allTracked()) do
   local list=c.state(victim).conds
   if list then
    for name,entry in pairs(list) do
     if entry.sourceId==pid and entry.spell==active.name and entry.concentration then list[name]=nil;S.onCondRemoved(victim,name,entry) end
    end
   end
  end
  for id,z in pairs(zones) do
   if z.ownerId==pid and z.spell==active.name then zones[id]=nil end
  end
  local s=c.state(p)
  if s.flameBlade and active.name=='flameblade' then s.flameBlade=nil end
  if active.name=='shillelagh' then s.shillelagh=nil end
  if active.name=='expeditiousretreat' then s.expeditious=nil end
 end

 -- criaturas com condicao (para varrer): jogadores + participantes + vizinhos de zona
 local tracked={}
 local function track(x) local id=idOf(x);if id then tracked[id]=true end end
 function S.allTracked()
  local list={}
  for id in pairs(tracked) do
   local x=Creature(id)
   if x then list[#list+1]=x else tracked[id]=nil end
  end
  return list
 end

 -- ------------------------------------------------------------- zonas
 local function addZone(p,spell,center,radius,opts)
  zoneSeq=zoneSeq+1
  local z={id=zoneSeq,spell=spell,ownerId=p:getId(),center={x=center.x,y=center.y,z=center.z},radius=radius,expires=now()+(opts.duration or 60000)}
  for k,v in pairs(opts) do z[k]=v end
  zones[z.id]=z
  return z
 end
 local function zoneCenter(z)
  if z.follow then
   local owner=creatureById(z.ownerId)
   local pos=owner and posOf(owner)
   if pos then z.center={x=pos.x,y=pos.y,z=pos.z} end
  end
  return z.center
 end
 local function inZone(z,pos)
  if not pos then return false end
  local center=zoneCenter(z)
  if pos.z~=center.z then return false end
  if z.square then return math.abs(pos.x-center.x)<=z.radius and math.abs(pos.y-center.y)<=z.radius end
  return sqDist(pos,center)<=z.radius*z.radius
 end
 local function zonesAt(pos,filter)
  local out={}
  for id,z in pairs(zones) do
   if z.expires<=now() or not creatureById(z.ownerId) then zones[id]=nil
   elseif inZone(z,pos) and (not filter or filter(z)) then out[#out+1]=z end
  end
  return out
 end
 S.zonesAt=zonesAt
 function S.obscured(x)
  local pos=posOf(x)
  for _,z in ipairs(zonesAt(pos)) do if z.obscure then return true end end
  return false
 end
 function S.inSilence(x)
  for _,z in ipairs(zonesAt(posOf(x))) do if z.silence then return true end end
  return false
 end
 -- Nevoa/nuvens bloqueiam a visao entre dois pontos (como a Escuridao).
 function S.visionBlocked(viewer,target)
  local a,b=posOf(viewer),posOf(target)
  if not a or not b then return false end
  if flag(viewer,'blinded') then return true end
  for id,z in pairs(zones) do
   if z.obscure and z.expires>now() and creatureById(z.ownerId) then
    local center=zoneCenter(z)
    if center.z==a.z then
     if inZone(z,a) or inZone(z,b) then return true end
     local dx,dy=b.x-a.x,b.y-a.y;local length=dx*dx+dy*dy
     local t=length==0 and 0 or math.max(0,math.min(1,((center.x-a.x)*dx+(center.y-a.y)*dy)/length))
     local x,y=a.x+t*dx-center.x,a.y+t*dy-center.y
     if x*x+y*y<=z.radius*z.radius then return true end
    end
   end
  end
  return false
 end
 local function creaturesIn(z)
  local center=zoneCenter(z)
  local r=z.radius
  local out={}
  for _,x in ipairs(Game.getSpectators(Position(center.x,center.y,center.z),false,false,r,r,r,r)) do
   if alive(x) and (c.isPlayer(x) or c.isMonster(x)) and inZone(z,posOf(x)) then out[#out+1]=x end
  end
  return out
 end
 local function pulseZone(z)
  if not z.effect then return end
  local center=zoneCenter(z)
  local r=z.radius
  local count=0
  for dy=-r,r do for dx=-r,r do
   local inside=z.square or dx*dx+dy*dy<=r*r
   if inside and (r<=4 or (dx+dy)%2==0) then
    Position(center.x+dx,center.y+dy,center.z):sendMagicEffect(z.effect);count=count+1
   end
  end end
 end

 -- ----------------------------------------------------- utilitarios de alvo
 local function hostile(p,x) return c.hostileTarget(p,x) end
 -- Aliado: voce mesmo, alguem da mesma party, ou um jogador com quem voce nao esta lutando.
 local function friendly(p,x)
  if not x then return false end
  if idOf(x)==idOf(p) then return true end
  if not c.isPlayer(x) or not c.isPlayer(p) then return false end
  local ok,same=pcall(function()
   local pa,pb=p:getParty(),x:getParty()
   return pa~=nil and pb~=nil and pa:getLeader():getId()==pb:getLeader():getId()
  end)
  if ok and same then return true end
  local pt,xt=p:getTarget(),x:getTarget()
  if (pt and idOf(pt)==idOf(x)) or (xt and idOf(xt)==idOf(p)) then return false end
  return true
 end
 -- Inimigo escolhido (magias em que o conjurador escolhe os alvos): nunca aliados.
 local function enemyOf(p,x) return hostile(p,x) and not friendly(p,x) end
 S.friendly=friendly
 local function alliesNear(p,primary,count,radius)
  local list={primary}
  if count<=1 then return list end
  local origin=posOf(p)
  local candidates={}
  for _,x in ipairs(Game.getSpectators(origin,false,true,radius,radius,radius,radius)) do
   if c.isPlayer(x) and friendly(p,x) and idOf(x)~=idOf(primary) and alive(x) and c.range(p,x,radius) then candidates[#candidates+1]=x end
  end
  table.sort(candidates,function(a,b) return dist(posOf(a),origin)<dist(posOf(b),origin) end)
  for _,x in ipairs(candidates) do if #list>=count then break end;list[#list+1]=x end
  return list
 end
 local function enemiesNear(p,primary,count,radius)
  local list={}
  if primary then list[1]=primary end
  if #list>=count then return list end
  local origin=posOf(primary or p)
  local candidates={}
  for _,x in ipairs(Game.getSpectators(posOf(p),false,false,radius,radius,radius,radius)) do
   if enemyOf(p,x) and alive(x) and (not primary or idOf(x)~=idOf(primary)) and c.range(p,x,radius) then candidates[#candidates+1]=x end
  end
  table.sort(candidates,function(a,b) return dist(posOf(a),origin)<dist(posOf(b),origin) end)
  for _,x in ipairs(candidates) do if #list>=count then break end;list[#list+1]=x end
  return list
 end
 local function victimsInArea(p,center,radius,square,includeAllies,onlyEnemies)
  local out={}
  for _,x in ipairs(Game.getSpectators(Position(center.x,center.y,center.z),false,false,radius,radius,radius,radius)) do
   local pos=posOf(x)
   if pos and pos.z==center.z and alive(x) and (c.isPlayer(x) or c.isMonster(x)) then
    local inside=square and (math.abs(pos.x-center.x)<=radius and math.abs(pos.y-center.y)<=radius) or (not square and sqDist(pos,center)<=radius*radius)
    if inside and (onlyEnemies and enemyOf(p,x) or (not onlyEnemies and (hostile(p,x) or (includeAllies and idOf(x)~=idOf(p))))) then out[#out+1]=x end
   end
  end
  return out
 end
 local function areaEffect(center,radius,square,effect)
  for dy=-radius,radius do for dx=-radius,radius do
   if square or dx*dx+dy*dy<=radius*radius then Position(center.x+dx,center.y+dy,center.z):sendMagicEffect(effect) end
  end end
 end
 local function coneTiles(p,length,aim)
  local origin=posOf(p)
  local dirX,dirY=0,0
  local target=aim or p:getTarget()
  if target and posOf(target).z==origin.z and (posOf(target).x~=origin.x or posOf(target).y~=origin.y) then
   dirX,dirY=posOf(target).x-origin.x,posOf(target).y-origin.y
  else
   local dir=p:getDirection()
   dirX=(dir==DIRECTION_EAST and 1) or (dir==DIRECTION_WEST and -1) or 0
   dirY=(dir==DIRECTION_SOUTH and 1) or (dir==DIRECTION_NORTH and -1) or 0
  end
  local len=math.sqrt(dirX*dirX+dirY*dirY);if len==0 then dirY=1;len=1 end
  dirX,dirY=dirX/len,dirY/len
  local function inside(dx,dy)
   if dx==0 and dy==0 then return false end
   if dx*dx+dy*dy>length*length+length then return false end
   return (dx*dirX+dy*dirY)/math.sqrt(dx*dx+dy*dy)>=0.7
  end
  return inside,origin
 end
 local function lineTiles(p,length,aim)
  local origin=posOf(p)
  local target=aim or p:getTarget()
  local tx,ty
  if target and posOf(target).z==origin.z and (posOf(target).x~=origin.x or posOf(target).y~=origin.y) then
   tx,ty=posOf(target).x-origin.x,posOf(target).y-origin.y
  else
   local dir=p:getDirection()
   tx=(dir==DIRECTION_EAST and 1) or (dir==DIRECTION_WEST and -1) or 0
   ty=(dir==DIRECTION_SOUTH and 1) or (dir==DIRECTION_NORTH and -1) or 0
   if tx==0 and ty==0 then ty=1 end
  end
  local steps=math.max(math.abs(tx),math.abs(ty))
  local sx,sy=tx/steps,ty/steps
  local tiles={}
  for i=1,length do
   local pos=Position(origin.x+math.floor(sx*i+0.5),origin.y+math.floor(sy*i+0.5),origin.z)
   if not origin:isSightClear(pos,true) then break end
   tiles[#tiles+1]=pos
  end
  return tiles
 end
 local function walkable(pos,x)
  local tile=Tile(pos)
  if not tile or not tile:getGround() then return false end
  if x then
   local ok,rv=pcall(function() return tile:queryAdd(x) end)
   return ok and rv==RETURNVALUE_NOERROR
  end
  if tile.isWalkable then return tile:isWalkable() end
  return not tile:hasFlag(TILESTATE_BLOCKSOLID)
 end
 local function air(pos)
  local tile=Tile(pos)
  return not tile or not tile:getGround()
 end

 -- ------------------------------------------------------- testes / rolagens
 local function spellMod(p) return c.spellMod(p) end
 local function spellDC(p) return 8+c.proficiency(p)+spellMod(p) end
 local function spellAttackBonus(p) return spellMod(p)+c.proficiency(p)+(c.buff(p,'bless') and R.roll(4,c.rng) or 0) end
 local function save(x,index,dc,context,label,p,amount)
  local roll=c.saveRoll(x,index,dc,context or {magic=true})
  local bonus=c.isPlayer(x) and c.savingBonus(x,index) or R.modifier(abilityScore(x,index))
  if p then c.log(p,x,roll.dice[1],bonus,dc,roll.success and 'SALVOU' or 'FALHOU SALVAGUARDA',amount or 0,label,{kind='save',ab=ABIL_EN[index]}) end
  return roll.success,roll
 end
 local function spellAttack(p,target,ranged,label,die,count)
  local bonus=spellAttackBonus(p)
  local threatened=false
  if ranged then
   for _,x in ipairs(Game.getSpectators(posOf(p),false,false,1,1,1,1)) do
    if hostile(p,x) and alive(x) and not incapacitated(x) and c.range(p,x,1) then threatened=true;break end
   end
  end
  local roll=c.attackRoll(p,target,bonus,c.actorRng(p),c.attackAdvantage(p,target,ranged),threatened or c.attackDisadvantage(p,target,ranged))
  local amount=0
  if roll.hit and die then amount=R.damage(count,die,0,roll.critical,c.rng) end
  return roll,amount,bonus
 end
 local function logAttack(p,target,roll,bonus,amount,label,ranged)
  c.log(p,target,roll.natural,bonus,c.ac(target),roll.critical and 'CRITICO' or roll.hit and 'ACERTO' or 'ERRO',amount,label,{kind=ranged and 'ranged' or 'melee',ab=c.spellAbility(p)})
 end
 local function heal(p,target,amount,label)
  if amount<=0 then return 0 end
  c.heal(p,target,amount)
  c.log(p,target,0,0,0,'CURA',amount,label,{kind='none'})
  return amount
 end
 local function healRoll(target,count,sides,flat)
  if S.beacon(target) then return maxDice(count,sides,flat) end
  return d(count,sides,flat)
 end
 S.healRoll=healRoll
 function S.beacon(x) return getCond(x,'beaconofhope')~=nil end

 -- ===================================================== ganchos do motor
 function S.speed(x,value)
  local slowed=getCond(x,'slow')
  if flag(x,'speedZero') or flag(x,'paralyzed') or flag(x,'restrained') or c.state(x).dying or c.state(x).dead then return 0 end
  if c.state(x).lethargy then return 0 end
  if getCond(x,'haste') then value=value*2 end
  if slowed then value=math.floor(value/2) end
  if getCond(x,'longstrider') then value=value+10 end
  if getCond(x,'fly') then value=math.max(value,60) end
  -- Guardioes Espirituais: inimigos dentro da area andam metade
  for _,z in ipairs(zonesAt(posOf(x))) do
   if z.spell=='spiritguardians' then
    local owner=creatureById(z.ownerId)
    if owner and enemyOf(owner,x) then value=math.floor(value/2) end
   end
  end
  return value
 end
 function S.ac(x,value)
  if getCond(x,'barkskin') then value=math.max(value,16) end
  if getCond(x,'haste') then value=value+2 end
  if getCond(x,'slow') then value=value-2 end
  return value
 end
 function S.attackAdvantage(a,b,ranged)
  if flag(b,'paralyzed') or flag(b,'restrained') or flag(b,'blinded') or flag(b,'outlined') or c.state(b).dying or c.state(b).dead then return true end
  if (flag(b,'incapacitated') and flag(b,'proneLock')) and (not ranged or c.range(a,b,1)) then return true end
  if flag(a,'invisible') and not sees(b,a) then return true end
  local ts=getCond(a,'truestrike')
  if ts and ts.data.targetId==idOf(b) and c.state(a).economy.turn and c.state(a).economy.turn>=ts.data.fromTurn then return true end
  local enlarged=getCond(a,'enlarge')
  return false
 end
 function S.attackDisadvantage(a,b,ranged)
  if flag(a,'blinded') or flag(a,'poisoned') or flag(a,'restrained') then return true end
  if flag(b,'invisible') and not flag(b,'outlined') and not sees(a,b) then return true end
  if getCond(b,'blur') and not flag(a,'blinded') then return true end
  local source=frightenedBy(a)
  if source and alive(source) and c.range(a,source,24) then return true end
  if getCond(a,'heatmetalpenalty') then return true end
  local curse=getCond(a,'bestowcurse')
  if curse and curse.data.mode=='attack' and curse.sourceId==idOf(b) then return true end
  local prot=getCond(b,'protectionfromevilandgood')
  if prot then
   local t=ctype(a)
   if t=='aberration' or t=='celestial' or t=='elemental' or t=='fey' or t=='fiend' or t=='undead' then return true end
  end
  return false
 end
 -- Bonus/penalidade no d20 de ataque (Perdicao) e consumo de efeitos de um ataque.
 function S.attackBonus(a,b)
  local delta=0
  if getCond(a,'bane') then delta=delta-R.roll(4,c.rng) end
  return delta
 end
 -- Antes do ataque: Santuario e Imagem Espelhada podem desviar o golpe.
 function S.preAttack(a,b,roll)
  local sanct=getCond(b,'sanctuary')
  if sanct and idOf(a)~=idOf(b) and not (sanct.data.brokenBy and sanct.data.brokenBy[idOf(a)]) then
   local ok=save(a,4,sanct.data.dc,{magic=true},'Santuario',creatureById(sanct.sourceId) or b)
   if not ok then
    roll.hit=false;roll.critical=false;roll.sanctuary=true
    tell(a,'Santuario: voce nao consegue atacar este alvo agora.')
    return
   end
  end
  local mirror=c.state(b).mirrorImages
  if mirror and mirror.count>0 and mirror.expires>now() and not flag(a,'blinded') then
   local need=mirror.count>=3 and 6 or mirror.count==2 and 8 or 11
   local natural=R.roll(20,c.rng)
   if natural>=need then
    local imageAc=10+(c.isPlayer(b) and c.mod(b,1) or 0)
    roll.mirror=true
    if roll.total>=imageAc then
     mirror.count=mirror.count-1
     tell(b,'Imagem Espelhada: uma copia foi destruida ('..mirror.count..' restantes).')
     posOf(b):sendMagicEffect(CONST_ME_POFF)
    else
     tell(b,'Imagem Espelhada: o ataque acertou o ar entre as copias.')
    end
    roll.hit=false;roll.critical=false
   end
  end
 end
 function S.postAttack(a,b,roll)
  -- Paralisado/inconsciente: acerto a 1,5 m e critico.
  if roll.hit and (flag(b,'paralyzed') or c.state(b).dying) and c.range(a,b,1) then roll.critical=true end
  -- Golpe Certeiro: so o primeiro ataque.
  local ts=getCond(a,'truestrike')
  if ts and ts.data.targetId==idOf(b) and c.state(a).economy.turn and c.state(a).economy.turn>=ts.data.fromTurn then removeCond(a,'truestrike') end
  S.brokeStealth(a,b)
 end
 -- Atacar/conjurar algo nocivo encerra Invisibilidade e Santuario de quem age.
 function S.brokeStealth(a,b,harmless)
  if getCond(a,'invisibility') then removeCond(a,'invisibility');tell(a,'Voce ficou visivel.') end
  if harmless then return end
  if getCond(a,'sanctuary') then removeCond(a,'sanctuary');tell(a,'Santuario terminou: voce agiu de forma hostil.') end
  if b and c.isMonster(b) then
   local charm=getCond(b,'charmperson')
   if charm and c.isPlayer(a) then removeCond(b,'charmperson') end
  end
  if b and c.isPlayer(b) then
   local charm=getCond(b,'charmperson')
   if charm and c.isPlayer(a) and charm.sourceId==idOf(a) then removeCond(b,'charmperson') end
  end
 end
 function S.saveMods(x,index,context)
  local bonus,adv,dis,fail=0,false,false,false
  if (index==0 or index==1) and (flag(x,'paralyzed') or c.state(x).dying) then fail=true end
  if getCond(x,'bane') then bonus=bonus-R.roll(4,c.rng) end
  local res=getCond(x,'resistance')
  if res then bonus=bonus+R.roll(4,c.rng);removeCond(x,'resistance');tell(x,'Resistencia: +1d4 na salvaguarda.') end
  if index==1 then
   if getCond(x,'haste') then adv=true end
   if getCond(x,'slow') then bonus=bonus-2 end
   if flag(x,'restrained') then dis=true end
  end
  if index==4 and S.beacon(x) then adv=true end
  if index==0 then
   if getCond(x,'enlarge') then adv=true end
   if getCond(x,'reduce') then dis=true end
  end
  local curse=getCond(x,'bestowcurse')
  if curse and curse.data.mode=='ability' and curse.data.ability==index then dis=true end
  local enh=getCond(x,'enhanceability')
  if context and context.fear and getCond(x,'heroism') then fail=false end
  return bonus,adv,dis,fail
 end
 -- Testes de atributo (pericias, fuga, escapar de amarras).
 function S.checkMods(x,index)
  local bonus,adv,dis=0,false,false
  local guide=getCond(x,'guidance')
  if guide then bonus=bonus+R.roll(4,c.rng);removeCond(x,'guidance');tell(x,'Orientacao: +1d4 no teste.') end
  local enh=getCond(x,'enhanceability')
  if enh and enh.data.ability==index then adv=true end
  if index==0 and getCond(x,'enlarge') then adv=true end
  if index==0 and getCond(x,'reduce') then dis=true end
  if flag(x,'poisoned') then dis=true end
  local source=frightenedBy(x)
  if source and alive(source) and c.range(x,source,24) then dis=true end
  if getCond(x,'heatmetalpenalty') then dis=true end
  local curse=getCond(x,'bestowcurse')
  if curse and curse.data.mode=='ability' and curse.data.ability==index then dis=true end
  return bonus,adv,dis
 end
 -- Dano: resistencias e efeitos extras de acerto.
 function S.modifyParts(a,b,parts,attackHit,critical,weaponHit)
  local weaponLike=attackHit and (weaponHit or (a and c.isMonster(a)))
  if a and attackHit then
   if weaponLike then
    if getCond(a,'enlarge') then parts[#parts+1]={amount=R.damage(1,4,0,critical,c.rng),kind=parts[1].kind,effect=CONST_ME_NONE} end
    if getCond(a,'reduce') then parts[1].amount=math.max(1,parts[1].amount-R.damage(1,4,0,critical,c.rng)) end
    if getCond(a,'rayofenfeeblement') then for _,part in ipairs(parts) do part.amount=math.floor(part.amount/2) end end
   end
   if weaponHit and c.isPlayer(a) then
    if getCond(a,'divinefavor') then parts[#parts+1]={amount=R.damage(1,4,0,critical,c.rng),kind=COMBAT_HOLYDAMAGE,effect=CONST_ME_HOLYDAMAGE} end
    local brand=getCond(a,'brandingsmite')
    if brand and not brand.data.used then
     brand.data.used=true
     parts[#parts+1]={amount=R.damage(brand.data.dice,6,0,critical,c.rng),kind=COMBAT_HOLYDAMAGE,effect=CONST_ME_HOLYAREA}
     if getCond(b,'invisibility') then removeCond(b,'invisibility') end
     tell(a,'Destruicao Marcante: +'..brand.data.dice..'d6 radiante.')
     c.endConcentration(a)
    end
   end
   local curse=getCond(b,'bestowcurse')
   if curse and curse.data.mode=='damage' and curse.sourceId==idOf(a) then
    parts[#parts+1]={amount=R.damage(1,8,0,critical,c.rng),kind=COMBAT_DEATHDAMAGE,effect=CONST_ME_MORTAREA}
   end
  end
  local prot=getCond(b,'protectionfromenergy')
  local inSilence=S.inSilence(b)
  for _,part in ipairs(parts) do
   if prot and prot.data.kind==part.kind then part.amount=math.floor(part.amount/2) end
   if inSilence and part.thunder then part.amount=0 end
  end
 end
 -- Depois de sofrer dano.
 function S.afterDamage(a,b,amount,kind)
  if amount<=0 then return end
  for _,name in ipairs({'hypnoticpattern','charmperson'}) do
   if getCond(b,name) and (name=='hypnoticpattern' or (a and c.isPlayer(a))) then removeCond(b,name);tell(b,'O efeito foi quebrado pelo dano.') end
  end
  local laugh=getCond(b,'hideouslaughter')
  if laugh then
   local caster=creatureById(laugh.sourceId) or b
   local roll=c.saveRoll(b,4,laugh.data.dc,{magic=true})
   if not roll.success then roll=c.saveRoll(b,4,laugh.data.dc,{magic=true}) end
   if roll.success then removeCond(b,'hideouslaughter');c.state(b).prone=true;tell(b,'Voce parou de rir (salvaguarda).') end
  end
  -- Teia pega fogo
  if kind==COMBAT_FIREDAMAGE then
   for id,z in pairs(zones) do
    if z.spell=='web' and inZone(z,posOf(b)) then
     zones[id]=nil
     local owner=creatureById(z.ownerId)
     for _,x in ipairs(creaturesIn(z)) do
      removeCond(x,'web')
      if owner then c.damage(owner,x,d(2,4),COMBAT_FIREDAMAGE,CONST_ME_FIREAREA) end
     end
    end
   end
  end
  S.hellishRebuke(a,b)
 end

 -- ===================================================== 0 PV (morrendo)
 local DEATH_WINDOW=60000
 local function setFrozen(x,on)
  pcall(function() x:setTurnMovement(on and 0 or (inEncounter(x) and 0 or -1)) end)
 end
 function S.isDead(x) return c.state(x).dead~=nil end
 function S.isDying(x) return c.state(x).dying~=nil end
 function S.knockOut(p,attacker)
  local s=c.state(p)
  if s.dying or s.dead then return end
  s.dying={successes=0,failures=0,nextSave=now()+ROUND}
  s.prone=true
  c.endConcentration(p)
  if c.endRage then c.endRage(p) end
  pcall(function() p:removeCondition(CONDITION_REGENERATION) end)
  setFrozen(p,true)
  posOf(p):sendMagicEffect(CONST_ME_DRAWBLOOD)
  c.broadcast(p,string.format('%s caiu com 0 PV e esta morrendo.',p:getName()))
  tell(p,'Voce esta inconsciente com 0 PV. Salvaguardas contra a morte a cada turno: 3 sucessos estabilizam, 3 falhas matam. Qualquer cura te levanta.')
  track(p)
 end
 local function finishDeath(p)
  local s=c.state(p)
  s.dying=nil;s.dead=nil
  c.trueKill(p)
 end
 local function becomeDead(p)
  local s=c.state(p)
  s.dying=nil
  s.dead={expires=now()+DEATH_WINDOW}
  c.broadcast(p,p:getName()..' morreu. Revivificar ainda pode traze-lo de volta por 1 minuto.')
  tell(p,'Voce morreu. Um aliado tem 1 minuto para usar Revivificar (diamante de 300 po).')
 end
 -- Dano enquanto esta caido: 1 falha (critico = 2). Dano macico mata.
 function S.dyingHit(p,amount,critical)
  local s=c.state(p)
  if s.dead then return end
  if amount>=p:getMaxHealth() then becomeDead(p);return end
  s.dying.failures=s.dying.failures+(critical and 2 or 1)
  s.dying.stable=nil
  tell(p,string.format('Dano enquanto caido: falhas %d/3.',math.min(3,s.dying.failures)))
  if s.dying.failures>=3 then becomeDead(p) end
 end
 function S.wake(p,silent)
  local s=c.state(p)
  if not s.dying then return false end
  s.dying=nil
  setFrozen(p,false)
  if not silent then c.broadcast(p,p:getName()..' voltou a si.') end
  return true
 end
 local function deathSave(p)
  local s=c.state(p)
  local dying=s.dying
  if not dying or dying.stable then return end
  local natural=R.d20(c.actorRng(p),S.beacon(p),false)
  local result
  if natural==20 then
   result='SUCESSO'
   S.wake(p)
   tell(p,'20 natural: voce recupera 1 PV e se levanta.')
  elseif natural<10 then
   dying.failures=dying.failures+(natural==1 and 2 or 1);result='FALHA'
  else
   dying.successes=dying.successes+1;result='SUCESSO'
  end
  c.log(p,p,natural,0,10,result,0,'Salvaguarda contra a Morte',{kind='save',ab='-'})
  if s.dying then
   tell(p,string.format('Salvaguarda contra a morte: sucessos %d/3, falhas %d/3.',math.min(3,dying.successes),math.min(3,dying.failures)))
   if dying.failures>=3 then becomeDead(p)
   elseif dying.successes>=3 then
    dying.stable={wakeAt=now()+R.roll(4,c.rng)*60000}
    tell(p,'Voce esta estavel (inconsciente). Recupera 1 PV em alguns minutos ou com qualquer cura.')
   end
  end
 end
 function S.stabilize(p)
  local s=c.state(p)
  if not s.dying then return false end
  s.dying.stable={wakeAt=now()+R.roll(4,c.rng)*60000}
  s.dying.failures=0;s.dying.successes=0
  return true
 end
 function S.dyingTick(p)
  local s=c.state(p)
  if s.dead then
   if s.dead.expires<=now() then finishDeath(p) end
   if p:getHealth()>1 then p:addHealth(1-p:getHealth()) end
   setFrozen(p,true)
   return
  end
  if not s.dying then return end
  pcall(function() p:removeCondition(CONDITION_REGENERATION) end)
  -- Cura que nao passou pelo combate (pocao, Impor as Maos...): levanta (0 PV + cura).
  if p:getHealth()>1 then p:addHealth(-1);S.wake(p);return end
  setFrozen(p,true)
  if s.dying.stable then
   if now()>=s.dying.stable.wakeAt then S.wake(p);tell(p,'Voce recupera 1 PV e acorda.') end
   return
  end
  if not inEncounter(p) and now()>=s.dying.nextSave then
   s.dying.nextSave=now()+ROUND
   deathSave(p)
  end
 end
 -- Cura recebida: levanta quem estava caido; mortos nao recebem cura comum.
 function S.healingReceived(x,amount)
  local s=c.state(x)
  if s.dead then return 0 end
  if s.dying then S.wake(x);return math.max(0,amount-1) end
  return amount
 end

 -- ===================================================== turnos
 local function endOfTurnSave(x,name,entry)
  local sv=entry.save
  if not sv or sv.timing~='end' then return end
  if sv.needsNoSight then
   local source=creatureById(entry.sourceId)
   if source and alive(source) and c.range(x,source,24) and not S.visionBlocked(x,source) then return end
  end
  local caster=creatureById(entry.sourceId) or x
  local ok=save(x,sv.ability,sv.dc,{magic=true,fear=entry.flags and entry.flags.frightened},entry.label or name,caster)
  if ok then removeCond(x,name);tell(x,(entry.label or name)..': efeito encerrado (salvaguarda).') end
 end
 function S.onTurnEnd(x,enc)
  if not x then return end
  local list=c.state(x).conds
  if list then
   local names={}
   for name in pairs(list) do names[#names+1]=name end
   for _,name in ipairs(names) do
    local entry=list[name]
    if entry and condActive(x,entry) then
     endOfTurnSave(x,name,entry)
     if list[name] and entry.endTurn then entry.endTurn(x,entry) end
     if list[name] and entry.untilEndOfTurn then removeCond(x,name)
     elseif list[name] and entry.rounds then
      -- duracao em rodadas: conta os turnos do proprio alvo
      entry.rounds=entry.rounds-1
      if entry.rounds<=0 then removeCond(x,name) end
     end
    end
   end
  end
  -- Esfera Flamejante: quem termina o turno a 1,5 m dela
  for id,z in pairs(zones) do
   if z.spell=='flamingsphere' and z.expires>now() then
    local owner=creatureById(z.ownerId)
    local pos=posOf(x)
    if owner and pos and pos.z==z.center.z and dist(pos,z.center)<=1 and hostile(owner,x) then
     local dealt=d(z.dice,6)
     local ok=save(x,1,z.dc,{magic=true},'Esfera Flamejante',owner,dealt)
     c.damage(owner,x,ok and math.floor(dealt/2) or dealt,COMBAT_FIREDAMAGE,CONST_ME_FIREAREA)
    end
   end
   if z.spell=='grease' and inZone(z,posOf(x)) and not c.state(x).prone then
    local owner=creatureById(z.ownerId)
    if owner and not save(x,1,z.dc,{magic=true},'Graxa',owner) then c.state(x).prone=true end
   end
  end
  if c.state(x).lethargyServed then c.state(x).lethargy=nil;c.state(x).lethargyServed=nil end
  c.state(x).hasteAction=nil
 end
 local function zoneStartEffects(x,enc)
  local pos=posOf(x)
  for _,z in ipairs(zonesAt(pos)) do
   local owner=creatureById(z.ownerId)
   if owner then S.zoneTrigger(z,owner,x,'start') end
  end
 end
 function S.onTurnStart(x,enc)
  if not x then return end
  track(x)
  local s=c.state(x)
  if s.mirrorImages and s.mirrorImages.expires<=now() then s.mirrorImages=nil end
  if s.dying then deathSave(x) end
  if s.lethargy then s.lethargyServed=true end
  local hero=getCond(x,'heroism')
  if hero and c.tempHP then c.tempHP(x,hero.data.amount,'Heroismo') end
  if getCond(x,'haste') then s.hasteAction=true end
  local slowed=getCond(x,'slow')
  if slowed and s.economy then s.economy.reaction=false end
  zoneStartEffects(x,enc)
  -- Comando executado no turno do alvo
  local cmd=getCond(x,'command')
  if cmd then S.commandTurn(x,cmd) end
 end
 -- Depois de dar o movimento do turno: levantar-se gasta metade.
 function S.adjustMovement(x)
  local s=c.state(x)
  if s.prone and not incapacitated(x) and not flag(x,'proneLock') then
   s.prone=nil
   local move=x:getTurnMovement()
   if move>0 then x:setTurnMovement(math.floor(move/2)) end
   tell(x,'Voce se levanta (metade do movimento).')
  end
 end
 -- Lento: so acao OU acao bonus; sem reacoes. Velocidade: acao extra limitada.
 function S.limitEconomy(x)
  local e=c.state(x).economy
  if not e then return end
  if getCond(x,'slow') then
   e.reaction=false
   if not e.action then e.bonus=false end
   if not e.bonus then e.action=false;e.extraActions=0 end
  end
 end
 -- Pode agir? (motivo quando nao)
 function S.blockedReason(x)
  local s=c.state(x)
  if s.dead then return 'Voce esta morto.' end
  if s.dying then return 'Voce esta inconsciente com 0 PV.' end
  if s.lethargy then return 'Letargia da Velocidade: voce nao pode agir neste turno.' end
  if flag(x,'paralyzed') then return 'Voce esta paralisado.' end
  if getCond(x,'hideouslaughter') then return 'Voce esta caido de tanto rir.' end
  if getCond(x,'hypnoticpattern') then return 'Voce esta hipnotizado.' end
  if flag(x,'incapacitated') then return 'Voce esta incapacitado.' end
  return nil
 end
 function S.canTargetHarm(p,target)
  local charm=getCond(p,'charmperson')
  if charm and target and charm.sourceId==idOf(target) then return false,'Voce esta enfeiticado por este alvo e nao quer feri-lo.' end
  return true
 end

 -- ===================================================== IA de monstros
 local function stepAway(x,from)
  local a,b=posOf(x),posOf(from)
  local best,bestDist=nil,dist(a,b)
  for i,dv in ipairs(DIRS) do
   local pos=Position(a.x+dv[1],a.y+dv[2],a.z)
   local dd=dist(pos,b)
   if dd>bestDist and walkable(pos,x) then best=i;bestDist=dd end
  end
  if not best then return false end
  local ok,rv=pcall(function() return x:move(DIRCONST[best]) end)
  return ok and (rv==RETURNVALUE_NOERROR or rv==true)
 end
 local function stepToward(x,to)
  local path=x.getPathTo and x:getPathTo(posOf(to),0,1,true,true,12)
  if not path or #path==0 then return false end
  local ok,rv=pcall(function() return x:move(path[1]) end)
  return ok and (rv==RETURNVALUE_NOERROR or rv==true)
 end
 function S.targetable(monster,player)
  local s=c.state(player)
  if s.dead then return false end
  local charm=getCond(monster,'charmperson')
  if charm and charm.sourceId==idOf(player) then return false end
  return true
 end
 function S.targetPreference(monster,player)
  -- menor e melhor
  local score=0
  local s=c.state(player)
  if s.dying then score=score+1000 end
  if flag(player,'invisible') and not flag(player,'outlined') and not c.range(monster,player,1) then score=score+500 end
  return score
 end
 -- Turno de monstro sob condicao. Devolve 'end' (passa a vez), 'wait' (agiu, espera) ou nil.
 function S.monsterTurn(m,enc,target)
  local s=c.state(m)
  if incapacitated(m) or s.lethargy then return 'end' end
  local now_=os.mtime()
  if s.lastCondStep and now_-s.lastCondStep<500 then return 'wait' end
  local source=frightenedBy(m)
  if source and alive(source) then
   local fear=flag(m,'frightened')
   if fear.data and fear.data.dash and m:getTurnMovement()>=500 then
    s.lastCondStep=now_
    if stepAway(m,source) then return 'wait' end
    return 'end'
   end
   if target and not c.range(m,target,1) then
    if m:getTurnMovement()>=500 then
     -- pode andar, mas nunca para mais perto de quem o assusta
     local before=dist(posOf(m),posOf(source))
     local path=m.getPathTo and m:getPathTo(posOf(target),0,1,true,true,12)
     if path and #path>0 then
      local dv=({[DIRCONST[1]]={0,-1},[DIRCONST[2]]={1,0},[DIRCONST[3]]={0,1},[DIRCONST[4]]={-1,0},[DIRCONST[5]]={-1,1},[DIRCONST[6]]={1,1},[DIRCONST[7]]={-1,-1},[DIRCONST[8]]={1,-1}})[path[1]]
      if dv then
       local np=Position(posOf(m).x+dv[1],posOf(m).y+dv[2],posOf(m).z)
       if dist(np,posOf(source))<before then return 'end' end
      end
     end
    end
   end
  end
  if flag(m,'restrained') then
   if target and c.range(m,target,1) then return nil end
   -- usa a acao para escapar
   if R.spend(s.economy,'action',c.now()) then S.escapeAttempt(m) end
   return 'end'
  end
  return nil
 end
 function S.escapeAttempt(x)
  for name,entry in pairs(conds(x)) do
   if entry.flags and entry.flags.restrained and entry.escapeDC then
    local bonus,adv,dis=S.checkMods(x,0)
    local natural=R.d20(c.isPlayer(x) and c.actorRng(x) or c.rng,adv,dis)
    local mod=c.isPlayer(x) and c.athletics(x) or R.modifier(abilityScore(x,0))
    local total=natural+mod+bonus
    local ok=total>=entry.escapeDC
    c.log(x,x,natural,mod+bonus,entry.escapeDC,ok and 'SUCESSO' or 'FALHA',0,'Escapar ('..(entry.label or name)..')',{kind='check',ab='STR'})
    if ok then removeCond(x,name) end
    return ok
   end
  end
  return false
 end
 function S.commandTurn(x,cmd)
  local word=cmd.data.word
  local caster=creatureById(cmd.sourceId)
  cmd.data.done=true
  if word=='grovel' then c.state(x).prone=true;tell(x,'Comando: voce se prostra.') end
  if word=='halt' or word=='grovel' or word=='drop' then
   addCond(x,'commandhalt',{spell='command',flags={incapacitated=true,speedZero=true},untilEndOfTurn=true,expires=now()+ROUND})
  elseif word=='flee' and caster then
   addCond(x,'commandflee',{spell='command',flags={frightened=true},sourceId=idOf(caster),data={dash=true},untilEndOfTurn=true,expires=now()+ROUND})
  elseif word=='approach' and caster then
   c.state(x).commandApproach=idOf(caster)
  end
  removeCond(x,'command')
 end
 -- Movimento (detectado pelo tick): terreno dificil, Crescer Espinhos, entrar em zonas, medo.
 local lastPos={}
 function S.trackMovement(x)
  local id=idOf(x);local pos=posOf(x)
  if not id or not pos then return end
  local prev=lastPos[id]
  lastPos[id]={x=pos.x,y=pos.y,z=pos.z}
  if not prev or prev.z~=pos.z or (prev.x==pos.x and prev.y==pos.y) then return end
  local steps=dist(prev,pos)
  if steps>3 then return end
  -- Medo: nao pode se aproximar de quem o assusta
  local source,fear=frightenedBy(x)
  if source and alive(source) and posOf(source).z==pos.z and dist(pos,posOf(source))<dist(prev,posOf(source)) and c.isPlayer(x) then
   pcall(function() x:teleportTo(Position(prev.x,prev.y,prev.z),true) end)
   lastPos[id]=prev
   warn(x,'Voce esta amedrontado e nao consegue se aproximar.')
   return
  end
  local myTurn=c.isActorTurn(x)
  local before={};for _,z in ipairs(zonesAt(prev)) do before[z.id]=true end
  for _,z in ipairs(zonesAt(pos)) do
   local owner=creatureById(z.ownerId)
   if owner then
    if z.difficult and myTurn then
     local move=x:getTurnMovement()
     if move>0 then x:setTurnMovement(math.max(0,move-500*steps)) end
    end
    if z.spell=='spikegrowth' then
     local dealt=d(2*steps,4)
     c.log(owner,x,0,0,0,'ESPINHOS',dealt,'Crescer Espinhos',{kind='none'})
     c.damage(owner,x,dealt,COMBAT_PHYSICALDAMAGE,CONST_ME_DRAWBLOOD)
    end
    if not before[z.id] then S.zoneTrigger(z,owner,x,'enter') end
   end
  end
 end

 -- Efeito de zona sobre uma criatura (inicio do turno ou ao entrar).
 function S.zoneTrigger(z,owner,x,when)
  if not alive(x) or (not c.isPlayer(x) and not c.isMonster(x)) then return end
  local enc=c.state(x).encounter
  local serial=enc and enc.serial or math.floor(now()/ROUND)
  z.hits=z.hits or {}
  local key=idOf(x)
  local function oncePerTurn()
   if z.hits[key]==serial then return false end
   z.hits[key]=serial;return true
  end
  if z.spell=='moonbeam' and hostileOrAny(owner,x) and oncePerTurn() then
   local dealt=d(z.dice,10)
   local shapechanger=false
   local ok=save(x,2,z.dc,{magic=true},'Raio Lunar',owner,dealt)
   c.encounterFor(owner,x)
   c.damage(owner,x,ok and math.floor(dealt/2) or dealt,COMBAT_HOLYDAMAGE,CONST_ME_HOLYAREA)
  elseif z.spell=='spiritguardians' and enemyOf(owner,x) and oncePerTurn() then
   local dealt=d(z.dice,8)
   local ok=save(x,4,z.dc,{magic=true},'Guardioes Espirituais',owner,dealt)
   c.encounterFor(owner,x)
   c.damage(owner,x,ok and math.floor(dealt/2) or dealt,COMBAT_HOLYDAMAGE,CONST_ME_HOLYDAMAGE)
  elseif z.spell=='stinkingcloud' and when=='start' then
   local t=ctype(x)
   if t~='undead' and t~='construct' and not save(x,2,z.dc,{magic=true,poison=true},'Nuvem Fedorenta',owner) then
    local e=c.state(x).economy
    if e then e.action=false;e.extraActions=0 end
    tell(x,'Nuvem Fedorenta: voce passa a acao tossindo e vomitando.')
   end
  elseif z.spell=='web' and not getCond(x,'web') and (when=='enter' or when=='start') and oncePerTurn() then
   if not save(x,1,z.dc,{magic=true},'Teia',owner) then
    addCond(x,'web',{spell='web',sourceId=z.ownerId,concentration=true,label='Teia',flags={restrained=true},escapeDC=z.dc,expires=z.expires})
    track(x)
   end
  elseif z.spell=='grease' and when=='enter' and not c.state(x).prone then
   if not save(x,1,z.dc,{magic=true},'Graxa',owner) then c.state(x).prone=true end
  elseif z.spell=='sleetstorm' and (when=='enter' or when=='start') and oncePerTurn() then
   if not c.state(x).prone and not save(x,1,z.dc,{magic=true},'Tempestade de Granizo',owner) then c.state(x).prone=true;tell(x,'Voce escorregou no gelo e caiu.') end
   if c.state(x).concentration and c.isPlayer(x) then
    local roll=c.saveRoll(x,2,z.dc,{magic=true})
    if not roll.success then c.endConcentration(x) end
   end
  end
 end
 hostileOrAny=function(owner,x) return hostile(owner,x) end

 -- ===================================================== reacoes
 function S.hellishRebuke(a,b)
  if not a or not b or not c.isPlayer(b) or not alive(a) or not alive(b) then return end
  if c.class(b)~=12 or not c.hasSpell(b,'hellishrebuke') or not c.state(b).economy.reaction then return end
  if c.state(b).dying or c.state(b).dead or not c.range(b,a,12) then return end
  local circle
  for i=1,3 do if b:getStorageValue(95029+i)>0 then circle=i;break end end
  if not circle then return end
  local aid,bid=a:getId(),b:getId()
  c.runAsync(function()
   local A,B=Creature(aid),Creature(bid)
   if not A or not B then return end
   local yes=c.askReaction(B,'hellishrebuke',string.format('%s te feriu. Usar Repreensao Infernal (reacao + espaco de magia)?',A:getName()))
   if not yes then return end
   A,B=Creature(aid),Creature(bid)
   if not A or not B or not alive(A) or not c.state(B).economy.reaction then return end
   local slot
   for i=1,3 do local v=B:getStorageValue(95029+i);if v>0 then slot=i;B:setStorageValue(95029+i,v-1);break end end
   if not slot then return end
   R.spend(c.state(B).economy,'reaction',c.now());c.syncSlots(B);c.sendSlots(B)
   local dealt=d(1+slot,10)
   local ok=save(A,1,spellDC(B),{magic=true},'Repreensao Infernal',B,dealt)
   c.damage(B,A,ok and math.floor(dealt/2) or dealt,COMBAT_FIREDAMAGE,CONST_ME_FIREAREA)
  end)
 end

 -- ===================================================== utilidade de movimento
 local function facingStep(p)
  local dir=p:getDirection()
  local dx=(dir==DIRECTION_EAST and 1) or (dir==DIRECTION_WEST and -1) or 0
  local dy=(dir==DIRECTION_SOUTH and 1) or (dir==DIRECTION_NORTH and -1) or 0
  return dx,dy
 end
 local function spendMovement(p,squares)
  if not inEncounter(p) then return true end
  if not c.isActorTurn(p) then warn(p,'Aguarde seu turno.');return false end
  local cost=500*squares
  if p:getTurnMovement()<cost then warn(p,'Movimento insuficiente neste turno.');return false end
  p:setTurnMovement(p:getTurnMovement()-cost)
  return true
 end
 -- Salto: atravessa obstaculos baixos e buracos (nao paredes).
 function S.jump(p)
  if not getCond(p,'jump') then warn(p,'Conjure Salto antes (dura 1 minuto).');return end
  local reason=S.blockedReason(p);if reason then warn(p,reason);return end
  if flag(p,'restrained') or S.speed(p,30)==0 then warn(p,'Voce nao consegue saltar agora.');return end
  local dx,dy=facingStep(p)
  local origin=posOf(p)
  local maxSq=math.max(1,math.floor(abilityScore(p,0)*3/5))
  local best
  for i=maxSq,2,-1 do
   local pos=Position(origin.x+dx*i,origin.y+dy*i,origin.z)
   if origin:isSightClear(pos,true) and walkable(pos,p) then best=pos;break end
  end
  if not best then warn(p,'Nao ha onde aterrissar nessa direcao.');return end
  local squares=dist(origin,best)
  if not spendMovement(p,squares) then return end
  origin:sendMagicEffect(CONST_ME_POFF)
  p:teleportTo(best,true)
  best:sendMagicEffect(CONST_ME_GROUNDSHAKER or CONST_ME_POFF)
  tell(p,'Salto: '..(squares*1.5)..' m.')
 end
 local function descendFrom(p,maxFloors)
  local origin=posOf(p)
  for _,dv in ipairs({{0,0},{0,-1},{1,0},{0,1},{-1,0},{-1,1},{1,1},{-1,-1},{1,-1}}) do
   local edge=Position(origin.x+dv[1],origin.y+dv[2],origin.z)
   if (dv[1]~=0 or dv[2]~=0) and air(edge) then
    for z=origin.z+1,math.min(15,origin.z+maxFloors) do
     local below=Position(edge.x,edge.y,z)
     if walkable(below,p) then return below end
     if not air(below) then break end
    end
   end
  end
  return nil
 end
 function S.fly(p,direction)
  if not getCond(p,'fly') then warn(p,'Voce precisa estar sob Voo.');return end
  local reason=S.blockedReason(p);if reason then warn(p,reason);return end
  local origin=posOf(p)
  local dest
  if direction=='up' then
   if origin.z<=0 or not air(Position(origin.x,origin.y,origin.z-1)) then warn(p,'Ha um teto acima de voce.');return end
   for _,dv in ipairs({{0,0},{0,-1},{1,0},{0,1},{-1,0},{-1,1},{1,1},{-1,-1},{1,-1}}) do
    local pos=Position(origin.x+dv[1],origin.y+dv[2],origin.z-1)
    if walkable(pos,p) then dest=pos;break end
   end
   if not dest then warn(p,'Nao ha onde pousar no andar de cima.');return end
  else
   dest=descendFrom(p,1)
   if not dest then warn(p,'Va ate uma borda (vazio ao lado) para descer voando.');return end
  end
  if not spendMovement(p,2) then return end
  origin:sendMagicEffect(CONST_ME_POFF)
  p:teleportTo(dest,true)
  dest:sendMagicEffect(CONST_ME_POFF)
 end

 -- ===================================================== conjuracao
 local cast={}
 -- Ajuda: alvo amigo (seguido ou voce)
 local function needFriend(p,target,rangeSq)
  if not target or not friendly(p,target) then warn(p,'Escolha um aliado (seguir) ou voce mesmo.');return false end
  if idOf(target)~=idOf(p) and not c.range(p,target,rangeSq) then warn(p,'Aliado fora do alcance.');return false end
  return true
 end
 local function needEnemy(p,target,rangeSq)
  if not target or not hostile(p,target) then warn(p,'Selecione um inimigo.');return false end
  if not c.range(p,target,rangeSq) then warn(p,'Alvo fora do alcance.');return false end
  return true
 end
 local function rounds(minutes) return math.floor(minutes*10) end

 -- ---------------- truques
 cast.light=function(p,spell,ctx)
  local t=ctx.target or p
  giveLight(t,8,3600000)
  posOf(t):sendMagicEffect(CONST_ME_MAGIC_GREEN)
  tell(p,'Luz: '..t:getName()..' brilha por 1 hora (raio de 6 m).')
 end
 cast.resistance=function(p,spell,ctx)
  local t=ctx.target
  concentrate(p,'resistance',rounds(1))
  addCond(t,'resistance',{sourceId=p:getId(),concentration=true,label='Resistencia'})
  posOf(t):sendMagicEffect(CONST_ME_MAGIC_BLUE)
  tell(t,'Resistencia: +1d4 na proxima salvaguarda (1 minuto).')
 end
 cast.guidance=function(p,spell,ctx)
  local t=ctx.target
  concentrate(p,'guidance',rounds(1))
  addCond(t,'guidance',{sourceId=p:getId(),concentration=true,label='Orientacao'})
  posOf(t):sendMagicEffect(CONST_ME_MAGIC_BLUE)
  tell(t,'Orientacao: +1d4 no proximo teste de atributo (1 minuto).')
 end
 cast.shillelagh=function(p,spell,ctx)
  local weapon=c.weaponItem(p)
  if not weapon or (weapon.srd~='club' and weapon.srd~='quarterstaff') then warn(p,'Empunhe um porrete (club) ou cajado (quarterstaff).');return false end
  c.state(p).shillelagh={expires=now()+60000}
  posOf(p):sendMagicEffect(CONST_ME_MAGIC_GREEN)
  tell(p,'Bordao Mistico: sua arma usa SAB e causa 1d8 por 1 minuto.')
 end
 cast.sparethedying=function(p,spell,ctx)
  local t=ctx.target
  if not t or not c.state(t).dying then warn(p,'O alvo precisa estar caido com 0 PV.');return false end
  S.stabilize(t)
  posOf(t):sendMagicEffect(CONST_ME_MAGIC_BLUE)
  c.broadcast(p,t:getName()..' foi estabilizado.')
 end
 cast.truestrike=function(p,spell,ctx)
  local t=ctx.target
  concentrate(p,'truestrike',1)
  addCond(p,'truestrike',{sourceId=p:getId(),concentration=true,label='Golpe Certeiro',data={targetId=t:getId(),fromTurn=(c.state(p).economy.turn or 0)+1},rounds=2,expires=now()+2*ROUND})
  posOf(t):sendMagicEffect(CONST_ME_MAGIC_BLUE)
  tell(p,'Golpe Certeiro: vantagem no primeiro ataque contra '..t:getName()..' no seu proximo turno.')
 end

 -- ---------------- 1o circulo
 cast.bane=function(p,spell,ctx)
  local count=3+(ctx.castLevel-1)
  local list=enemiesNear(p,ctx.target,count,6)
  concentrate(p,'bane',rounds(1))
  for _,t in ipairs(list) do
   c.encounterFor(p,t)
   if not save(t,5,ctx.dc,{magic=true},'Perdicao',p) then addCond(t,'bane',{sourceId=p:getId(),concentration=true,label='Perdicao'});track(t);posOf(t):sendMagicEffect(CONST_ME_MAGIC_RED) end
  end
 end
 cast.charmperson=function(p,spell,ctx)
  local count=1+(ctx.castLevel-1)
  local list=enemiesNear(p,ctx.target,count,6)
  for _,t in ipairs(list) do
   if ctype(t)~='humanoid' then tell(p,t:getName()..' nao e humanoide: Enfeiticar Pessoa nao funciona.')
   else
    local fighting=inEncounter(t)
    local roll=c.saveRoll(t,4,ctx.dc,{magic=true,charm=true,advantage=fighting})
    c.log(p,t,roll.dice[1],0,ctx.dc,roll.success and 'SALVOU' or 'FALHOU SALVAGUARDA',0,'Enfeiticar Pessoa',{kind='save',ab='WIS'})
    if not roll.success then
     addCond(t,'charmperson',{sourceId=p:getId(),label='Enfeiticar Pessoa',flags={charmed=true},duration=3600000})
     track(t);posOf(t):sendMagicEffect(CONST_ME_HEARTS)
     if c.isMonster(t) then c.stopEngineCombat(t) end
     tell(t,'Voce esta enfeiticado por '..p:getName()..'.')
    end
   end
  end
 end
 cast.colorspray=function(p,spell,ctx)
  local inside,origin=coneTiles(p,3)
  for dy=-3,3 do for dx=-3,3 do if inside(dx,dy) then Position(origin.x+dx,origin.y+dy,origin.z):sendMagicEffect(CONST_ME_MAGIC_RED) end end end
  local victims={}
  for _,x in ipairs(Game.getSpectators(origin,false,false,3,3,3,3)) do
   local pos=posOf(x)
   if alive(x) and hostile(p,x) and pos.z==origin.z and inside(pos.x-origin.x,pos.y-origin.y) and not incapacitated(x) and not flag(x,'blinded') then victims[#victims+1]=x end
  end
  table.sort(victims,function(a,b) return a:getHealth()<b:getHealth() end)
  local pool=d(6+2*(ctx.castLevel-1),10)
  c.log(p,p,0,0,0,'POOL DE PV',pool,'Borrifo de Cores',{kind='none'})
  for _,x in ipairs(victims) do
   if x:getHealth()<=pool then
    pool=pool-x:getHealth()
    if hostile(p,x) then c.encounterFor(p,x) end
    addCond(x,'colorspray',{sourceId=p:getId(),label='Borrifo de Cores',flags={blinded=true},rounds=1,expires=now()+2*ROUND})
    track(x);c.log(p,x,0,0,0,'CEGO',0,'Borrifo de Cores',{kind='none'})
   end
  end
 end
 cast.command=function(p,spell,ctx)
  local words={approach='approach',aproxime='approach',venha='approach',drop='drop',largue='drop',solte='drop',flee='flee',fuja='flee',grovel='grovel',deite='grovel',prostre='grovel',halt='halt',pare='halt'}
  local word=words[(ctx.args or ''):lower():match('%a+') or '']or 'grovel'
  local count=1+(ctx.castLevel-1)
  for _,t in ipairs(enemiesNear(p,ctx.target,count,12)) do
   c.encounterFor(p,t)
   local r=rule(t)
   if ctype(t)=='undead' or (r and (r.int or 10)<=3) then tell(p,t:getName()..' nao entende o comando.')
   elseif not save(t,4,ctx.dc,{magic=true},'Comando',p) then
    addCond(t,'command',{sourceId=p:getId(),label='Comando',data={word=word},rounds=1,expires=now()+2*ROUND})
    track(t);t:say(({approach='Sim...',drop='...',flee='Fugir!',grovel='*prostra-se*',halt='...'})[word],TALKTYPE_MONSTER_SAY)
   end
  end
 end
 cast.divinefavor=function(p,spell,ctx)
  concentrate(p,'divinefavor',rounds(1))
  addCond(p,'divinefavor',{sourceId=p:getId(),concentration=true,label='Favor Divino'})
  posOf(p):sendMagicEffect(CONST_ME_HOLYAREA)
  tell(p,'Favor Divino: +1d4 radiante nos acertos com arma (1 minuto).')
 end
 local function zoneSpell(p,ctx,name,radius,square,opts)
  if not opts.noConcentration then concentrate(p,name,opts.rounds or rounds(1)) end
  opts.duration=(opts.rounds or rounds(1))*ROUND
  opts.square=square
  opts.dc=ctx.dc
  local z=addZone(p,name,ctx.position,radius,opts)
  areaEffect(ctx.position,radius,square,opts.effect or CONST_ME_MAGIC_GREEN)
  return z
 end
 cast.entangle=function(p,spell,ctx)
  local z=zoneSpell(p,ctx,'entangle',2,true,{difficult=true,effect=CONST_ME_GREEN_RINGS or CONST_ME_MAGIC_GREEN})
  for _,x in ipairs(victimsInArea(p,ctx.position,2,true,false)) do
   c.encounterFor(p,x)
   if not save(x,0,ctx.dc,{magic=true},'Constricao',p) then
    addCond(x,'entangle',{sourceId=p:getId(),concentration=true,label='Constricao',flags={restrained=true},escapeDC=ctx.dc})
    track(x)
   end
  end
 end
 cast.expeditiousretreat=function(p,spell,ctx)
  concentrate(p,'expeditiousretreat',rounds(10))
  c.state(p).expeditious=true
  if inEncounter(p) then p:setTurnMovement(p:getTurnMovement()+c.speed(p)*100) end
  tibiaCondition(p,CONDITION_HASTE,600000,{[CONDITION_PARAM_SPEED]=150})
  tell(p,'Recuo Acelerado: Disparada como acao bonus a cada turno (use Disparada/R).')
 end
 cast.faeriefire=function(p,spell,ctx)
  concentrate(p,'faeriefire',rounds(1))
  areaEffect(ctx.position,2,true,CONST_ME_MAGIC_BLUE)
  for _,x in ipairs(victimsInArea(p,ctx.position,2,true,false)) do
   if hostile(p,x) then c.encounterFor(p,x) end
   if not save(x,1,ctx.dc,{magic=true},'Fogo das Fadas',p) then
    addCond(x,'faeriefire',{sourceId=p:getId(),concentration=true,label='Fogo das Fadas',flags={outlined=true}})
    if getCond(x,'invisibility') then removeCond(x,'invisibility') end
    track(x);posOf(x):sendMagicEffect(CONST_ME_MAGIC_BLUE)
   end
  end
 end
 cast.featherfall=function(p,spell,ctx)
  local dest=descendFrom(p,10)
  if not dest then warn(p,'Va ate uma borda (vazio ao lado) para descer flutuando.');return false end
  local origin=posOf(p)
  local group={p}
  for _,x in ipairs(Game.getSpectators(origin,false,true,1,1,1,1)) do
   if idOf(x)~=idOf(p) and friendly(p,x) and #group<5+(ctx.castLevel-1) then group[#group+1]=x end
  end
  for i,x in ipairs(group) do
   local spot=dest
   if i>1 then
    for _,dv in ipairs(DIRS) do local pos=Position(dest.x+dv[1],dest.y+dv[2],dest.z);if walkable(pos,x) then spot=pos;break end end
   end
   posOf(x):sendMagicEffect(CONST_ME_POFF)
   x:teleportTo(spot,true)
   spot:sendMagicEffect(CONST_ME_MAGIC_BLUE)
  end
  tell(p,'Queda Suave: voce desce flutuando ate o chao.')
 end
 cast.fogcloud=function(p,spell,ctx)
  local radius=4*ctx.castLevel
  radius=math.min(8,radius)
  zoneSpell(p,ctx,'fogcloud',radius,false,{obscure=true,rounds=rounds(60),effect=CONST_ME_POFF})
 end
 cast.goodberry=function(p,spell,ctx)
  local ok,berry=pcall(function() return p:addItem(3588,10) end)
  if not ok or not berry then warn(p,'Sem espaco para as frutas.');return false end
  pcall(function()
   berry:setActionId(96601)
   berry:setAttribute(ITEM_ATTRIBUTE_DESCRIPTION,'Fruta Boa: cura 1 PV e alimenta por um dia. Murcha em 24 horas.')
   berry:setAttribute(ITEM_ATTRIBUTE_DATE,os.time()+86400)
  end)
  posOf(p):sendMagicEffect(CONST_ME_MAGIC_GREEN)
  tell(p,'Bom Fruto: 10 frutas magicas (1 PV cada, valem uma refeicao).')
 end
 cast.grease=function(p,spell,ctx)
  zoneSpell(p,ctx,'grease',1,true,{difficult=true,effect=CONST_ME_SMOKE or CONST_ME_POFF,rounds=rounds(1),noConcentration=true})
  for _,x in ipairs(victimsInArea(p,ctx.position,1,true,false)) do
   c.encounterFor(p,x)
   if not save(x,1,ctx.dc,{magic=true},'Graxa',p) then c.state(x).prone=true;track(x) end
  end
 end
 -- Graxa nao e concentracao: a zona fica 1 minuto sozinha.
 concentrateFix=function(p,name)
  local s=c.state(p)
  if s.concentration and s.concentration.name==name then s.concentration=nil end
 end
 cast.heroism=function(p,spell,ctx)
  local list=alliesNear(p,ctx.target,ctx.castLevel,1)
  concentrate(p,'heroism',rounds(1))
  for _,t in ipairs(list) do
   addCond(t,'heroism',{sourceId=p:getId(),concentration=true,label='Heroismo',data={amount=math.max(1,spellMod(p))}})
   removeCond(t,'fear')
   track(t);posOf(t):sendMagicEffect(CONST_ME_HOLYAREA)
   if c.tempHP then c.tempHP(t,math.max(1,spellMod(p)),'Heroismo') end
   tell(t,'Heroismo: imune a medo e PV temporarios a cada turno.')
  end
 end
 cast.hideouslaughter=function(p,spell,ctx)
  local t=ctx.target
  local r=rule(t)
  if r and (r.int or 10)<=4 then tell(p,t:getName()..' nao entende a piada (Inteligencia 4 ou menos).');return end
  concentrate(p,'hideouslaughter',rounds(1))
  if not save(t,4,ctx.dc,{magic=true},'Riso Histerico',p) then
   c.state(t).prone=true
   addCond(t,'hideouslaughter',{sourceId=p:getId(),concentration=true,label='Riso Histerico',flags={incapacitated=true,proneLock=true},save={ability=4,dc=ctx.dc,timing='end'},data={dc=ctx.dc}})
   track(t);t:say('HAHAHA!',TALKTYPE_MONSTER_SAY)
   if c.isMonster(t) then c.stopEngineCombat(t) end
  else c.endConcentration(p) end
 end
 cast.jump=function(p,spell,ctx)
  addCond(ctx.target,'jump',{sourceId=p:getId(),label='Salto',duration=60000,rounds=10})
  track(ctx.target)
  posOf(ctx.target):sendMagicEffect(CONST_ME_MAGIC_GREEN)
  tell(ctx.target,'Salto: use a acao Saltar (/jump) para pular na direcao em que olha (1 minuto).')
 end
 cast.longstrider=function(p,spell,ctx)
  for _,t in ipairs(alliesNear(p,ctx.target,ctx.castLevel,1)) do
   addCond(t,'longstrider',{sourceId=p:getId(),label='Passos Largos',duration=3600000})
   tibiaCondition(t,CONDITION_HASTE,3600000,{[CONDITION_PARAM_SPEED]=60})
   track(t);posOf(t):sendMagicEffect(CONST_ME_MAGIC_GREEN)
   tell(t,'Passos Largos: +3 m de deslocamento por 1 hora.')
  end
 end
 cast.protectionfromevilandgood=function(p,spell,ctx)
  concentrate(p,'protectionfromevilandgood',rounds(10))
  local t=ctx.target
  addCond(t,'protectionfromevilandgood',{sourceId=p:getId(),concentration=true,label='Protecao contra o Mal e o Bem'})
  for name,entry in pairs(conds(t)) do
   local src=creatureById(entry.sourceId)
   local st=src and ctype(src)
   if (entry.flags and (entry.flags.charmed or entry.flags.frightened)) and (st=='undead' or st=='fiend' or st=='fey' or st=='celestial' or st=='elemental' or st=='aberration') then removeCond(t,name) end
  end
  track(t);posOf(t):sendMagicEffect(CONST_ME_HOLYAREA)
  tell(t,'Protecao contra o Mal e o Bem: aberracoes, celestiais, elementais, fadas, corruptores e mortos-vivos atacam com desvantagem.')
 end
 cast.sanctuary=function(p,spell,ctx)
  addCond(ctx.target,'sanctuary',{sourceId=p:getId(),label='Santuario',duration=60000,rounds=10,data={dc=ctx.dc}})
  track(ctx.target);posOf(ctx.target):sendMagicEffect(CONST_ME_HOLYAREA)
  tell(ctx.target,'Santuario: quem quiser te atacar precisa passar numa salvaguarda de SAB. Atacar encerra o efeito.')
 end
 cast.hellishrebuke=function(p) warn(p,'Repreensao Infernal e uma reacao: o jogo pergunta quando alguem te ferir.');return false end

 -- ---------------- 2o circulo
 cast.acidarrow=function(p,spell,ctx)
  local t=ctx.target
  local extra=ctx.castLevel-2
  local roll,_,bonus=spellAttack(p,t,true,'Flecha Acida')
  local amount=d(4+extra,4)
  if not roll.hit then amount=math.floor(amount/2) end
  if roll.critical then amount=amount+d(4+extra,4) end
  logAttack(p,t,roll,bonus,amount,'Flecha Acida',true)
  posOf(p):sendDistanceEffect(posOf(t),CONST_ANI_POISONARROW or CONST_ANI_EARTH)
  c.damage(p,t,amount,COMBAT_EARTHDAMAGE,CONST_ME_GREEN_RINGS,roll.hit,nil,nil,roll.critical,false)
  if roll.hit then
   local pid=p:getId()
   addCond(t,'acidarrow',{sourceId=pid,label='Flecha Acida',rounds=2,expires=now()+2*ROUND,data={dice=2+extra},
    endTurn=function(x,entry)
     local src=Creature(pid) or x
     local later=d(entry.data.dice,4)
     c.log(src,x,0,0,0,'ACIDO',later,'Flecha Acida',{kind='none'})
     c.damage(src,x,later,COMBAT_EARTHDAMAGE,CONST_ME_GREEN_RINGS)
     removeCond(x,'acidarrow')
    end})
   track(t)
  end
 end
 cast.aid=function(p,spell,ctx)
  local bonus=5*(ctx.castLevel-1)
  for _,t in ipairs(alliesNear(p,ctx.target,3,6)) do
   local old=removeCond(t,'aid')
   t:setMaxHealth(t:getMaxHealth()+bonus);t:addHealth(bonus)
   addCond(t,'aid',{sourceId=p:getId(),label='Ajuda',duration=8*3600000,data=bonus})
   track(t);posOf(t):sendMagicEffect(CONST_ME_HOLYAREA)
   tell(t,'Ajuda: +'..bonus..' PV maximos e atuais por 8 horas.')
  end
 end
 cast.barkskin=function(p,spell,ctx)
  concentrate(p,'barkskin',rounds(60))
  addCond(ctx.target,'barkskin',{sourceId=p:getId(),concentration=true,label='Pele de Arvore'})
  track(ctx.target);posOf(ctx.target):sendMagicEffect(CONST_ME_MAGIC_GREEN)
  tell(ctx.target,'Pele de Arvore: CA minima 16.')
  if c.sendSheet then c.sendSheet(ctx.target) end
 end
 cast.blindnessdeafness=function(p,spell,ctx)
  local deaf=(ctx.args or ''):lower():find('surd') or (ctx.args or ''):lower():find('deaf')
  for _,t in ipairs(enemiesNear(p,ctx.target,1+(ctx.castLevel-2),6)) do
   c.encounterFor(p,t)
   if not save(t,2,ctx.dc,{magic=true},deaf and 'Surdez' or 'Cegueira',p) then
    addCond(t,'blindnessdeafness',{sourceId=p:getId(),label=deaf and 'Surdez' or 'Cegueira',flags=deaf and {deafened=true} or {blinded=true},rounds=10,expires=now()+60000,save={ability=2,dc=ctx.dc,timing='end'}})
    track(t);posOf(t):sendMagicEffect(CONST_ME_MAGIC_RED)
   end
  end
 end
 cast.blur=function(p,spell,ctx)
  concentrate(p,'blur',rounds(1))
  addCond(p,'blur',{sourceId=p:getId(),concentration=true,label='Nublar'})
  posOf(p):sendMagicEffect(CONST_ME_MAGIC_BLUE)
  tell(p,'Nublar: ataques contra voce tem desvantagem.')
 end
 cast.brandingsmite=function(p,spell,ctx)
  concentrate(p,'brandingsmite',rounds(1))
  addCond(p,'brandingsmite',{sourceId=p:getId(),concentration=true,label='Destruicao Marcante',data={dice=2+(ctx.castLevel-2)}})
  posOf(p):sendMagicEffect(CONST_ME_HOLYAREA)
  tell(p,'Destruicao Marcante: seu proximo acerto com arma causa +'..(2+(ctx.castLevel-2))..'d6 radiante.')
 end
 cast.darkvision=function(p,spell,ctx)
  giveLight(ctx.target,6,8*3600000)
  addCond(ctx.target,'darkvision',{sourceId=p:getId(),label='Visao no Escuro',duration=8*3600000})
  posOf(ctx.target):sendMagicEffect(CONST_ME_MAGIC_GREEN)
  tell(ctx.target,'Visao no Escuro: voce enxerga no escuro (18 m) por 8 horas.')
 end
 cast.enhanceability=function(p,spell,ctx)
  local ability=ABIL_ARG[(ctx.args or ''):lower():match('%a+') or '']
  if not ability then
   local t=ctx.target
   local best,bestScore=1,-1
   for i=0,5 do if abilityScore(t,i)>bestScore then best=i;bestScore=abilityScore(t,i) end end
   ability=best
  end
  concentrate(p,'enhanceability',rounds(60))
  for _,t in ipairs(alliesNear(p,ctx.target,1+(ctx.castLevel-2),1)) do
   addCond(t,'enhanceability',{sourceId=p:getId(),concentration=true,label='Aprimorar Atributo',data={ability=ability}})
   if ability==2 and c.tempHP then c.tempHP(t,d(2,6),'Vigor do Urso') end
   track(t);posOf(t):sendMagicEffect(CONST_ME_MAGIC_GREEN)
   tell(t,'Aprimorar Atributo: vantagem em testes de '..ABIL_PT[ability]..'.')
  end
 end
 cast.enlargereduce=function(p,spell,ctx)
  local t=ctx.target
  local arg=(ctx.args or ''):lower()
  local reduce=arg:find('reduz') or arg:find('reduce') or (hostile(p,t) and not arg:find('aument') and not arg:find('enlarge'))
  concentrate(p,'enlargereduce',rounds(1))
  if hostile(p,t) then
   c.encounterFor(p,t)
   if save(t,2,ctx.dc,{magic=true},'Aumentar/Reduzir',p) then c.endConcentration(p);return end
  end
  local name=reduce and 'reduce' or 'enlarge'
  addCond(t,name,{spell='enlargereduce',sourceId=p:getId(),concentration=true,label=reduce and 'Reduzir' or 'Aumentar'})
  track(t);posOf(t):sendMagicEffect(reduce and CONST_ME_MAGIC_RED or CONST_ME_MAGIC_GREEN)
  tell(t,reduce and 'Reduzido: -1d4 no dano com armas e desvantagem em FOR.' or 'Aumentado: +1d4 no dano com armas e vantagem em FOR.')
 end
 cast.flameblade=function(p,spell,ctx)
  concentrate(p,'flameblade',rounds(10))
  c.state(p).flameBlade={dice=3+math.floor((ctx.castLevel-2)/2)}
  giveLight(p,4,600000)
  posOf(p):sendMagicEffect(CONST_ME_FIREAREA)
  tell(p,'Lamina Flamejante: use Ataque (acao) para golpear com a lamina (ataque magico corpo a corpo, '..c.state(p).flameBlade.dice..'d6 fogo).')
 end
 cast.flamingsphere=function(p,spell,ctx)
  local z=zoneSpell(p,ctx,'flamingsphere',0,false,{effect=CONST_ME_FIREAREA,dice=2+(ctx.castLevel-2)})
  z.radius=0
  giveLight(p,4,60000)
  tell(p,'Esfera Flamejante criada. Conjure de novo (acao bonus, sem gastar espaco) clicando num sqm para move-la e atropelar.')
 end
 local function controlSphere(p,ctx,z)
  if not ctx.position then warn(p,'Clique no destino da esfera.');return false end
  local from=z.center
  if ctx.position.z~=from.z or dist(ctx.position,from)>6 then warn(p,'A esfera anda ate 9 m por vez.');return false end
  z.center={x=ctx.position.x,y=ctx.position.y,z=ctx.position.z}
  Position(from.x,from.y,from.z):sendDistanceEffect(ctx.position,CONST_ANI_FIRE)
  ctx.position:sendMagicEffect(CONST_ME_FIREAREA)
  -- atropelar: criatura adjacente ao destino
  for _,x in ipairs(victimsInArea(p,ctx.position,1,true,false)) do
   local dealt=d(z.dice,6)
   local ok=save(x,1,z.dc,{magic=true},'Esfera Flamejante',p,dealt)
   c.encounterFor(p,x)
   c.damage(p,x,ok and math.floor(dealt/2) or dealt,COMBAT_FIREDAMAGE,CONST_ME_FIREAREA)
   break
  end
 end
 cast.holdperson=function(p,spell,ctx)
  local list=enemiesNear(p,ctx.target,1+(ctx.castLevel-2),12)
  concentrate(p,'holdperson',rounds(1))
  local any=false
  for _,t in ipairs(list) do
   if ctype(t)~='humanoid' then tell(p,t:getName()..' nao e humanoide.')
   else
    c.encounterFor(p,t)
    if not save(t,4,ctx.dc,{magic=true},'Imobilizar Pessoa',p) then
     any=true
     addCond(t,'holdperson',{sourceId=p:getId(),concentration=true,label='Imobilizar Pessoa',flags={paralyzed=true},save={ability=4,dc=ctx.dc,timing='end'}})
     track(t);posOf(t):sendMagicEffect(CONST_ME_MAGIC_BLUE);t:setTurnMovement(0)
     if c.isMonster(t) then c.stopEngineCombat(t) end
    end
   end
  end
  if not any then c.endConcentration(p) end
 end
 cast.invisibility=function(p,spell,ctx)
  concentrate(p,'invisibility',rounds(60))
  for _,t in ipairs(alliesNear(p,ctx.target,1+(ctx.castLevel-2),1)) do
   addCond(t,'invisibility',{sourceId=p:getId(),concentration=true,label='Invisibilidade',flags={invisible=true}})
   setInvisible(t,true,3600000)
   track(t);posOf(t):sendMagicEffect(CONST_ME_POFF)
   tell(t,'Invisibilidade: atacar ou conjurar encerra o efeito.')
  end
 end
 cast.lesserrestoration=function(p,spell,ctx)
  local t=ctx.target
  local removed={}
  for name,entry in pairs(conds(t)) do
   if entry.flags and (entry.flags.blinded or entry.flags.deafened or entry.flags.paralyzed or entry.flags.poisoned) then removeCond(t,name);removed[#removed+1]=entry.label or name end
  end
  pcall(function() t:removeCondition(CONDITION_POISON) end)
  posOf(t):sendMagicEffect(CONST_ME_MAGIC_BLUE)
  tell(p,'Restauracao Menor em '..t:getName()..(#removed>0 and (': removido '..table.concat(removed,', ')) or ': nenhuma condicao a remover (veneno curado).'))
 end
 cast.magicweapon=function(p,spell,ctx)
  local t=ctx.target
  if not c.weaponItem(t) then warn(p,'O alvo precisa empunhar uma arma.');return false end
  concentrate(p,'magicweapon',rounds(60))
  addCond(t,'magicweapon',{sourceId=p:getId(),concentration=true,label='Arma Magica',data={bonus=1}})
  track(t);posOf(t):sendMagicEffect(CONST_ME_MAGIC_BLUE)
  tell(t,'Arma Magica: +1 no ataque e no dano da arma.')
 end
 cast.mirrorimage=function(p,spell,ctx)
  c.state(p).mirrorImages={count=3,expires=now()+60000}
  posOf(p):sendMagicEffect(CONST_ME_MAGIC_BLUE)
  tell(p,'Imagem Espelhada: 3 copias ilusorias desviam ataques (1 minuto).')
 end
 cast.mistystep=function(p,spell,ctx)
  local dest=ctx.position
  if not dest or dest.z~=posOf(p).z or dist(dest,posOf(p))>6 or not c.positionRange(p,dest,6) or not walkable(dest,p) then warn(p,'Escolha um sqm livre e visivel a ate 9 m.');return false end
  posOf(p):sendMagicEffect(CONST_ME_POFF)
  p:teleportTo(dest,true)
  dest:sendMagicEffect(CONST_ME_TELEPORT or CONST_ME_MAGIC_BLUE)
 end
 cast.moonbeam=function(p,spell,ctx)
  zoneSpell(p,ctx,'moonbeam',1,false,{effect=CONST_ME_HOLYAREA,dice=2+(ctx.castLevel-2)})
  for _,x in ipairs(victimsInArea(p,ctx.position,1,false,false)) do S.zoneTrigger(zoneFor(p,'moonbeam'),p,x,'enter') end
  tell(p,'Raio Lunar: conjure de novo (acao, sem gastar espaco) clicando para mover o raio ate 18 m.')
 end
 zoneFor=function(p,name)
  for _,z in pairs(zones) do if z.ownerId==p:getId() and z.spell==name then return z end end
 end
 cast.rayofenfeeblement=function(p,spell,ctx)
  local t=ctx.target
  concentrate(p,'rayofenfeeblement',rounds(1))
  local roll,_,bonus=spellAttack(p,t,true,'Raio do Enfraquecimento')
  logAttack(p,t,roll,bonus,0,'Raio do Enfraquecimento',true)
  posOf(p):sendDistanceEffect(posOf(t),CONST_ANI_DEATH)
  if roll.hit then
   addCond(t,'rayofenfeeblement',{sourceId=p:getId(),concentration=true,label='Raio do Enfraquecimento',save={ability=2,dc=ctx.dc,timing='end'}})
   track(t);posOf(t):sendMagicEffect(CONST_ME_MORTAREA)
  else c.endConcentration(p) end
 end
 cast.shatter=function(p,spell,ctx)
  areaEffect(ctx.position,2,false,CONST_ME_GROUNDSHAKER or CONST_ME_ENERGYAREA)
  for _,x in ipairs(victimsInArea(p,ctx.position,2,false,false)) do
   c.encounterFor(p,x)
   local dealt=d(3+(ctx.castLevel-2),8)
   local roll=c.saveRoll(x,2,ctx.dc,{magic=true,disadvantage=ctype(x)=='construct'})
   c.log(p,x,roll.dice[1],0,ctx.dc,roll.success and 'SALVOU' or 'FALHOU SALVAGUARDA',dealt,'Despedacar',{kind='save',ab='CON'})
   local part=roll.success and math.floor(dealt/2) or dealt
   if S.inSilence(x) then part=0 end
   c.damage(p,x,part,COMBAT_ENERGYDAMAGE,CONST_ME_ENERGYAREA)
  end
 end
 cast.silence=function(p,spell,ctx)
  zoneSpell(p,ctx,'silence',4,false,{silence=true,rounds=rounds(10),effect=CONST_ME_MAGIC_BLUE})
  tell(p,'Silencio: ninguem dentro da area consegue conjurar magias.')
 end
 cast.spikegrowth=function(p,spell,ctx)
  zoneSpell(p,ctx,'spikegrowth',4,false,{difficult=true,rounds=rounds(10),effect=CONST_ME_GREEN_RINGS or CONST_ME_MAGIC_GREEN})
  tell(p,'Crescer Espinhos: cada 1,5 m andado na area causa 2d4 perfurante.')
 end
 cast.web=function(p,spell,ctx)
  local z=zoneSpell(p,ctx,'web',2,true,{difficult=true,obscureLight=true,rounds=rounds(60),effect=CONST_ME_POFF})
  for _,x in ipairs(victimsInArea(p,ctx.position,2,true,false)) do c.encounterFor(p,x);S.zoneTrigger(z,p,x,'enter') end
 end
 local function carriesMetal(t)
  if c.isPlayer(t) then
   local set=c.armorSet(t)
   local weapon=c.weaponItem(t)
   return (set~=nil and set.category~='light') or (weapon~=nil and weapon.srd~='club' and weapon.srd~='quarterstaff' and weapon.srd~='greatclub' and not weapon.ranged)
  end
  local tp=ctype(t)
  local name=t:getName():lower()
  return tp=='humanoid' or tp=='giant' or name:find('minotaur',1,true)~=nil or name:find('skeleton',1,true)~=nil
 end
 cast.heatmetal=function(p,spell,ctx)
  local t=ctx.target
  if not carriesMetal(t) then warn(p,'O alvo nao carrega objeto de metal.');return false end
  concentrate(p,'heatmetal',rounds(1))
  c.state(p).heatMetal={targetId=t:getId(),dice=2+(ctx.castLevel-2)}
  S.heatPulse(p,t,ctx.dc)
  tell(p,'Esquentar Metal: conjure de novo (acao bonus, sem espaco) para repetir o dano.')
 end
 function S.heatPulse(p,t,dc)
  local hm=c.state(p).heatMetal
  local dealt=d(hm.dice,8)
  c.encounterFor(p,t)
  c.log(p,t,0,0,0,'METAL EM BRASA',dealt,'Esquentar Metal',{kind='none'})
  c.damage(p,t,dealt,COMBAT_FIREDAMAGE,CONST_ME_FIREAREA)
  if not save(t,2,dc,{magic=true},'Esquentar Metal (soltar)',p) then
   addCond(t,'heatmetalpenalty',{sourceId=p:getId(),label='Metal em brasa',rounds=1,expires=now()+2*ROUND})
   track(t)
  end
 end
 cast.prayerofhealing=function(p,spell,ctx)
  if inEncounter(p) then warn(p,'Oracao de Cura leva 10 minutos: so fora de combate.');return false end
  local pid=p:getId()
  local start=posOf(p)
  tell(p,'Oracao de Cura: concentre-se 10 segundos sem se mover...')
  c.state(p).praying={until_=now()+10000}
  local castLevel=ctx.castLevel
  local mod=spellMod(p)
  for i=1,5 do
   addEvent(function()
    local pl=Player(pid);if not pl then return end
    local pos=posOf(pl)
    if inEncounter(pl) or pos.x~=start.x or pos.y~=start.y or pos.z~=start.z then
     if c.state(pl).praying then c.state(pl).praying=nil;warn(pl,'Oracao interrompida.') end
     return
    end
    pos:sendMagicEffect(CONST_ME_HOLYAREA)
    if i==5 and c.state(pl).praying then
     c.state(pl).praying=nil
     for _,t in ipairs(alliesNear(pl,pl,6,6)) do
      heal(pl,t,healRoll(t,2+(castLevel-2),8,mod),'Oracao de Cura')
     end
    end
   end,i*2000)
  end
 end

 -- ---------------- 3o circulo
 cast.beaconofhope=function(p,spell,ctx)
  concentrate(p,'beaconofhope',rounds(1))
  for _,t in ipairs(alliesNear(p,p,12,6)) do
   addCond(t,'beaconofhope',{sourceId=p:getId(),concentration=true,label='Farol de Esperanca'})
   track(t);posOf(t):sendMagicEffect(CONST_ME_HOLYAREA)
   tell(t,'Farol de Esperanca: vantagem em SAB e contra a morte; curas recebidas sao maximas.')
  end
 end
 cast.bestowcurse=function(p,spell,ctx)
  local t=ctx.target
  local arg=(ctx.args or ''):lower()
  local mode='damage'
  local ability
  if arg:find('ataq') or arg:find('attack') then mode='attack'
  elseif arg:find('acao') or arg:find('action') then mode='action'
  elseif ABIL_ARG[arg:match('%a+') or ''] then mode='ability';ability=ABIL_ARG[arg:match('%a+')] end
  concentrate(p,'bestowcurse',rounds(1))
  c.encounterFor(p,t)
  if save(t,4,ctx.dc,{magic=true},'Rogar Maldicao',p) then c.endConcentration(p);return end
  addCond(t,'bestowcurse',{sourceId=p:getId(),concentration=true,label='Rogar Maldicao',data={mode=mode,ability=ability,dc=ctx.dc}})
  track(t);posOf(t):sendMagicEffect(CONST_ME_MORTAREA)
  local desc={damage='+1d8 necrotico nos seus ataques contra ele',attack='desvantagem nos ataques contra voce',action='salvaguarda de SAB a cada turno ou perde a acao',ability='desvantagem em '..(ability and ABIL_PT[ability] or '')}
  tell(p,'Rogar Maldicao: '..desc[mode]..'.')
 end
 cast.calllightning=function(p,spell,ctx)
  if posOf(p).z>7 then warn(p,'Convocar Relampagos precisa de ceu aberto.');return false end
  local z=zoneSpell(p,ctx,'calllightning',12,false,{rounds=rounds(10),dice=3+(ctx.castLevel-3)})
  z.effect=nil
  S.lightningStrike(p,z,ctx.position)
  tell(p,'Convocar Relampagos: conjure de novo (acao, sem espaco) clicando para outro raio.')
 end
 function S.lightningStrike(p,z,point)
  if dist(point,z.center)>z.radius or point.z~=z.center.z then warn(p,'O raio precisa cair sob a nuvem.');return false end
  point:sendMagicEffect(CONST_ME_BIGCLOUDS or CONST_ME_ENERGYAREA)
  areaEffect(point,1,true,CONST_ME_ENERGYHIT)
  for _,x in ipairs(victimsInArea(p,point,1,true,false)) do
   c.encounterFor(p,x)
   local dealt=d(z.dice,10)
   local ok=save(x,1,z.dc,{magic=true},'Convocar Relampagos',p,dealt)
   c.damage(p,x,ok and math.floor(dealt/2) or dealt,COMBAT_ENERGYDAMAGE,CONST_ME_ENERGYAREA)
  end
 end
 cast.dispelmagic=function(p,spell,ctx)
  local t=ctx.target
  local count=0
  if t then
   local list=c.state(t).conds or {}
   for name,entry in pairs(list) do
    list[name]=nil;S.onCondRemoved(t,name,entry);count=count+1
    local src=creatureById(entry.sourceId)
    if src and c.state(src).concentration and c.state(src).concentration.name==entry.spell then c.endConcentration(src) end
   end
   if c.state(t).mirrorImages then c.state(t).mirrorImages=nil;count=count+1 end
   if c.state(t).mageArmor then c.state(t).mageArmor=nil;count=count+1 end
   for _,b in pairs(c.state(t).buffs or {}) do
    if b.source and b.source~=t and c.state(b.source).concentration then c.endConcentration(b.source);count=count+1 end
   end
   if c.state(t).sleeping then c.state(t).sleeping=nil;count=count+1 end
  end
  local center=ctx.position or (t and posOf(t))
  if center then
   for id,z in pairs(zones) do
    if inZone(z,center) or dist(zoneCenter(z),center)<=1 then
     local owner=creatureById(z.ownerId)
     zones[id]=nil;count=count+1
     if owner and c.state(owner).concentration and c.state(owner).concentration.name==z.spell then c.endConcentration(owner) end
    end
   end
   count=count+c.dispelDarkness(center,1)
  end
  if t then posOf(t):sendMagicEffect(CONST_ME_MAGIC_BLUE) end
  tell(p,'Dissipar Magia: '..count..' efeito(s) encerrado(s).')
 end
 cast.fear=function(p,spell,ctx)
  local inside,origin=coneTiles(p,6)
  for dy=-6,6 do for dx=-6,6 do if inside(dx,dy) then Position(origin.x+dx,origin.y+dy,origin.z):sendMagicEffect(CONST_ME_MAGIC_RED) end end end
  concentrate(p,'fear',rounds(1))
  for _,x in ipairs(Game.getSpectators(origin,false,false,6,6,6,6)) do
   local pos=posOf(x)
   if hostile(p,x) and alive(x) and pos.z==origin.z and inside(pos.x-origin.x,pos.y-origin.y) then
    c.encounterFor(p,x)
    if getCond(x,'heroism') then tell(p,x:getName()..' esta imune a medo.')
    elseif not save(x,4,ctx.dc,{magic=true,fear=true},'Medo',p) then
     addCond(x,'fear',{sourceId=p:getId(),concentration=true,label='Medo',flags={frightened=true},data={dash=true},save={ability=4,dc=ctx.dc,timing='end',needsNoSight=true}})
     track(x);x:say('!!!',TALKTYPE_MONSTER_SAY)
    end
   end
  end
 end
 cast.fly=function(p,spell,ctx)
  concentrate(p,'fly',rounds(100))
  for _,t in ipairs(alliesNear(p,ctx.target,1+(ctx.castLevel-3),1)) do
   addCond(t,'fly',{sourceId=p:getId(),concentration=true,label='Voo'})
   track(t);posOf(t):sendMagicEffect(CONST_ME_MAGIC_BLUE)
   tell(t,'Voo: deslocamento 18 m. Use Voar para cima / Voar para baixo (/fly up, /fly down).')
  end
 end
 cast.haste=function(p,spell,ctx)
  concentrate(p,'haste',rounds(1))
  local t=ctx.target
  addCond(t,'haste',{sourceId=p:getId(),concentration=true,label='Velocidade'})
  track(t);posOf(t):sendMagicEffect(CONST_ME_MAGIC_GREEN)
  if inEncounter(t) and c.isActorTurn(t) then t:setTurnMovement(t:getTurnMovement()+c.speed(t)*50);c.state(t).hasteAction=true end
  tibiaCondition(t,CONDITION_HASTE,60000,{[CONDITION_PARAM_SPEED]=300})
  tell(t,'Velocidade: deslocamento dobrado, +2 CA, vantagem em DES e uma acao extra (1 ataque, Disparada ou Desengajar).')
 end
 cast.hypnoticpattern=function(p,spell,ctx)
  concentrate(p,'hypnoticpattern',rounds(1))
  areaEffect(ctx.position,3,true,CONST_ME_MAGIC_RED)
  for _,x in ipairs(victimsInArea(p,ctx.position,3,true,false)) do
   if not flag(x,'blinded') then
    if hostile(p,x) then c.encounterFor(p,x) end
    if not save(x,4,ctx.dc,{magic=true,charm=true},'Padrao Hipnotico',p) then
     addCond(x,'hypnoticpattern',{sourceId=p:getId(),concentration=true,label='Padrao Hipnotico',flags={charmed=true,incapacitated=true,speedZero=true}})
     track(x);x:setTurnMovement(0)
     if c.isMonster(x) then c.stopEngineCombat(x) end
    end
   end
  end
 end
 cast.lightningbolt=function(p,spell,ctx)
  local tiles=lineTiles(p,20)
  local hit={}
  for _,pos in ipairs(tiles) do
   pos:sendMagicEffect(CONST_ME_ENERGYHIT)
   local tile=Tile(pos)
   for _,x in ipairs(tile and tile:getCreatures() or {}) do
    if hostile(p,x) and alive(x) and not hit[idOf(x)] then
     hit[idOf(x)]=true
     c.encounterFor(p,x)
     local dealt=d(8+(ctx.castLevel-3),6)
     local ok=save(x,1,ctx.dc,{magic=true},'Relampago',p,dealt)
     c.damage(p,x,ok and math.floor(dealt/2) or dealt,COMBAT_ENERGYDAMAGE,CONST_ME_ENERGYAREA)
    end
   end
  end
  if #tiles>0 then posOf(p):sendDistanceEffect(tiles[#tiles],CONST_ANI_ENERGY) end
 end
 cast.protectionfromenergy=function(p,spell,ctx)
  local kinds={fire=COMBAT_FIREDAMAGE,fogo=COMBAT_FIREDAMAGE,cold=COMBAT_ICEDAMAGE,frio=COMBAT_ICEDAMAGE,gelo=COMBAT_ICEDAMAGE,lightning=COMBAT_ENERGYDAMAGE,eletrico=COMBAT_ENERGYDAMAGE,raio=COMBAT_ENERGYDAMAGE,thunder=COMBAT_ENERGYDAMAGE,trovao=COMBAT_ENERGYDAMAGE,acid=COMBAT_EARTHDAMAGE,acido=COMBAT_EARTHDAMAGE}
  local word=(ctx.args or ''):lower():match('%a+') or 'fire'
  local kind=kinds[word] or COMBAT_FIREDAMAGE
  concentrate(p,'protectionfromenergy',rounds(60))
  addCond(ctx.target,'protectionfromenergy',{sourceId=p:getId(),concentration=true,label='Protecao contra Energia',data={kind=kind}})
  track(ctx.target);posOf(ctx.target):sendMagicEffect(CONST_ME_MAGIC_BLUE)
  tell(ctx.target,'Protecao contra Energia: resistencia a '..word..'.')
 end
 cast.revivify=function(p,spell,ctx)
  local t=ctx.target
  if not t or not c.state(t).dead then warn(p,'O alvo precisa ter morrido ha menos de 1 minuto.');return false end
  if p:getItemCount(3028)<1 then warn(p,'Revivificar consome um diamante de 300 po (small diamond).');return false end
  p:removeItem(3028,1)
  c.state(t).dead=nil;c.state(t).dying=nil
  pcall(function() t:setTurnMovement(inEncounter(t) and 0 or -1) end)
  posOf(t):sendMagicEffect(CONST_ME_HOLYAREA)
  c.broadcast(p,t:getName()..' foi revivificado com 1 PV.')
 end
 cast.slow=function(p,spell,ctx)
  concentrate(p,'slow',rounds(1))
  local n=0
  for _,x in ipairs(victimsInArea(p,ctx.position,4,true,false,true)) do
   if n>=6 then break end
   n=n+1
   c.encounterFor(p,x)
   if not save(x,4,ctx.dc,{magic=true},'Lentidao',p) then
    addCond(x,'slow',{sourceId=p:getId(),concentration=true,label='Lentidao',save={ability=4,dc=ctx.dc,timing='end'}})
    track(x);posOf(x):sendMagicEffect(CONST_ME_MAGIC_RED)
   end
  end
  areaEffect(ctx.position,4,true,CONST_ME_MAGIC_RED)
 end
 cast.spiritguardians=function(p,spell,ctx)
  ctx.position=posOf(p)
  local z=zoneSpell(p,ctx,'spiritguardians',3,false,{follow=true,rounds=rounds(10),effect=CONST_ME_HOLYDAMAGE,dice=3+(ctx.castLevel-3)})
  tell(p,'Guardioes Espirituais: inimigos a 4,5 m de voce andam metade e sofrem 3d8 radiante (SAB metade).')
 end
 cast.stinkingcloud=function(p,spell,ctx)
  local z=zoneSpell(p,ctx,'stinkingcloud',4,false,{obscure=true,rounds=rounds(1),effect=CONST_ME_POISONAREA or CONST_ME_GREEN_RINGS})
  for _,x in ipairs(victimsInArea(p,ctx.position,4,false,false)) do c.encounterFor(p,x) end
 end
 cast.vampirictouch=function(p,spell,ctx)
  concentrate(p,'vampirictouch',rounds(1))
  c.state(p).vampiric={dice=3+(ctx.castLevel-3)}
  return S.vampiricStrike(p,ctx.target)
 end
 function S.vampiricStrike(p,t)
  local v=c.state(p).vampiric
  if not t or not hostile(p,t) or not c.range(p,t,1) then warn(p,'Toque Vampirico: encoste num inimigo (1 sqm).');return false end
  c.encounterFor(p,t)
  local roll,amount,bonus=spellAttack(p,t,false,'Toque Vampirico',6,v.dice)
  logAttack(p,t,roll,bonus,amount,'Toque Vampirico',false)
  c.damage(p,t,amount,COMBAT_DEATHDAMAGE,CONST_ME_MORTAREA,roll.hit,nil,nil,roll.critical,false)
  if roll.hit and amount>0 then
   local pid=p:getId()
   addEvent(function() local pl=Player(pid);if pl then c.heal(pl,pl,math.floor(amount/2));c.log(pl,pl,0,0,0,'CURA',math.floor(amount/2),'Toque Vampirico',{kind='none'}) end end,1800)
  end
  return true
 end
 cast.daylight=function(p,spell,ctx)
  local t=ctx.target or p
  giveLight(t,10,3600000)
  posOf(t):sendMagicEffect(CONST_ME_HOLYAREA)
  local removed=c.dispelDarkness(posOf(t),12)
  tell(p,'Luz do Dia: luz intensa por 1 hora'..(removed>0 and ' (Escuridao dissipada)' or '')..'.')
 end
 cast.sleetstorm=function(p,spell,ctx)
  local z=zoneSpell(p,ctx,'sleetstorm',8,false,{difficult=true,obscure=true,rounds=rounds(1),effect=CONST_ME_ICEAREA or CONST_ME_ICEATTACK})
  for _,x in ipairs(victimsInArea(p,ctx.position,8,false,false)) do
   if hostile(p,x) then c.encounterFor(p,x) end
   S.zoneTrigger(z,p,x,'enter')
  end
 end

 -- ===================================================== entrada pelo /cast
 -- Magias de concentracao com comando repetido (sem gastar espaco).
 local CONTROL={flamingsphere='bonus',moonbeam='action',calllightning='action',heatmetal='bonus',vampirictouch='action'}
 function S.controlKind(p,name)
  local conc=c.state(p).concentration
  if not conc or conc.name~=name or not CONTROL[name] then return nil end
  return CONTROL[name]
 end
 function S.control(p,name,ctx)
  local z=zoneFor(p,name)
  if name=='flamingsphere' then if not z then return false end;return controlSphere(p,ctx,z)~=false end
  if name=='moonbeam' then
   if not z or not ctx.position then warn(p,'Clique no novo lugar do Raio Lunar.');return false end
   if ctx.position.z~=z.center.z or dist(ctx.position,z.center)>12 then warn(p,'O raio se move ate 18 m.');return false end
   Position(z.center.x,z.center.y,z.center.z):sendDistanceEffect(ctx.position,CONST_ANI_HOLY)
   z.center={x=ctx.position.x,y=ctx.position.y,z=ctx.position.z}
   areaEffect(ctx.position,1,false,CONST_ME_HOLYAREA)
   for _,x in ipairs(victimsInArea(p,ctx.position,1,false,false)) do S.zoneTrigger(z,p,x,'enter') end
   return true
  end
  if name=='calllightning' then
   if not z then return false end
   return S.lightningStrike(p,z,ctx.position or (p:getTarget() and posOf(p:getTarget())) or posOf(p))~=false
  end
  if name=='heatmetal' then
   local hm=c.state(p).heatMetal
   local t=hm and Creature(hm.targetId)
   if not t or not alive(t) or not c.range(p,t,12) then warn(p,'O alvo do Esquentar Metal saiu do alcance.');return false end
   S.heatPulse(p,t,8+c.proficiency(p)+spellMod(p))
   return true
  end
  if name=='vampirictouch' then return S.vampiricStrike(p,p:getTarget()) end
  return false
 end
 -- ctx: target, position, castLevel, args, dc
 function S.cast(p,name,spell,ctx)
  local fn=cast[name]
  if not fn then warn(p,'Magia sem efeito definido.');return false end
  ctx.dc=8+c.proficiency(p)+spellMod(p)
  track(p)
  if ctx.target then track(ctx.target) end
  local result=fn(p,spell,ctx)
  if c.sendSheet then c.sendSheet(p) end
  return result
 end
 -- Validacao de alvo antes de gastar recursos (mesma tabela do motor).
 function S.validate(p,name,spell,ctx)
  local t=ctx.target
  if spell.target=='ally' then return needFriend(p,t,spell.range) end
  if spell.target=='enemy' then return needEnemy(p,t,spell.range) end
  if spell.target=='any' then
   if not t then warn(p,'Selecione um alvo.');return false end
   if idOf(t)~=idOf(p) and not c.range(p,t,spell.range) then warn(p,'Alvo fora do alcance.');return false end
   return true
  end
  if spell.target=='dying' then
   if not t then warn(p,'Selecione (seguir) quem esta caido.');return false end
   if not c.range(p,t,spell.range) then warn(p,'Chegue ao lado do alvo.');return false end
   return true
  end
  if spell.target=='point' then
   if not ctx.position then warn(p,'Escolha o sqm no mapa.');return false end
   if not c.positionRange(p,ctx.position,spell.range) then warn(p,'Escolha um sqm visivel dentro do alcance.');return false end
   return true
  end
  return true
 end

 -- Conferencias antes de gastar acao/espaco.
 function S.precheck(p,name,ctx)
  local t=ctx.target
  if name=='shillelagh' then
   local w=c.weaponItem(p)
   if not w or (w.srd~='club' and w.srd~='quarterstaff') then warn(p,'Bordao Mistico: empunhe um porrete (club) ou cajado (staff).');return false end
  elseif name=='sparethedying' then
   if not t or not c.state(t).dying then warn(p,'O alvo precisa estar caido com 0 PV (siga-o).');return false end
  elseif name=='revivify' then
   if not t or not c.state(t).dead then warn(p,'O alvo precisa ter morrido ha menos de 1 minuto (siga-o).');return false end
   if p:getItemCount(3028)<1 then warn(p,'Revivificar consome um diamante de 300 po (small diamond).');return false end
  elseif name=='heatmetal' then
   if not t or not carriesMetal(t) then warn(p,'O alvo nao carrega objeto de metal.');return false end
  elseif name=='magicweapon' then
   if not t or not c.weaponItem(t) then warn(p,'O alvo precisa empunhar uma arma.');return false end
  elseif name=='featherfall' then
   if not descendFrom(p,10) then warn(p,'Va ate uma borda (vazio ao lado) para descer flutuando.');return false end
  elseif name=='mistystep' then
   local dest=ctx.position
   if not dest or dest.z~=posOf(p).z or dist(dest,posOf(p))>6 or not walkable(dest,p) then warn(p,'Passo Nebuloso: escolha um sqm livre e visivel a ate 9 m.');return false end
  elseif name=='prayerofhealing' then
   if inEncounter(p) then warn(p,'Oracao de Cura leva 10 minutos: so fora de combate.');return false end
  elseif name=='calllightning' then
   if posOf(p).z>7 then warn(p,'Convocar Relampagos precisa de ceu aberto.');return false end
  elseif name=='flameblade' or name=='shillelagh' then
  elseif name=='enlargereduce' or name=='dispelmagic' or name=='light' or name=='daylight' then
   if not t then warn(p,'Selecione um alvo.');return false end
  elseif name=='vampirictouch' then
   if not t or not hostile(p,t) or not c.range(p,t,1) then warn(p,'Toque Vampirico: encoste num inimigo (1 sqm).');return false end
  end
  return true
 end
 -- ===================================================== tick
 local lastPulse=0
 local lastOut=0
 function S.tick()
  local t=now()
  local doPulse=t-lastPulse>=2000
  if doPulse then lastPulse=t end
  for id,z in pairs(zones) do
   local owner=creatureById(z.ownerId)
   if not owner or z.expires<=t then zones[id]=nil
   elseif doPulse then pulseZone(z) end
  end
  for _,x in ipairs(S.allTracked()) do
   S.trackMovement(x)
   if c.isPlayer(x) then S.dyingTick(x) end
   local s=c.state(x)
   -- congelados fora de combate
   if not inEncounter(x) and (flag(x,'paralyzed') or flag(x,'restrained') or flag(x,'speedZero')) then pcall(function() x:setTurnMovement(0) end) end
   if s.prone and not inEncounter(x) and not flag(x,'proneLock') and not s.dying and not s.dead then
    s.proneSince=s.proneSince or t
    if t-s.proneSince>=ROUND then s.prone=nil;s.proneSince=nil end
   end
   if s.mirrorImages and s.mirrorImages.expires<=t then s.mirrorImages=nil end
   if s.shillelagh and s.shillelagh.expires<=t then s.shillelagh=nil end
  end
  -- fora de combate: efeitos de "inicio de turno" a cada 6 s
  if t-lastOut>=ROUND then
   lastOut=t
   for _,z in pairs(zones) do
    local owner=creatureById(z.ownerId)
    if owner then
     for _,x in ipairs(creaturesIn(z)) do
      if not inEncounter(x) then
       S.zoneTrigger(z,owner,x,'start')
       S.onTurnEnd(x)
      end
     end
    end
   end
   for _,x in ipairs(S.allTracked()) do
    if not inEncounter(x) and c.state(x).conds then
     for name,entry in pairs(c.state(x).conds) do
      if entry.save and entry.save.timing=='end' and condActive(x,entry) then endOfTurnSave(x,name,entry) end
     end
    end
   end
  end
  -- caminhando para perto dos zonas: acompanhar quem esta perto
  for _,z in pairs(zones) do
   local center=zoneCenter(z)
   local r=z.radius+2
   for _,x in ipairs(Game.getSpectators(Position(center.x,center.y,center.z),false,false,r,r,r,r)) do track(x) end
  end
 end
 function S.onLogout(p)
  removeCond(p,'aid')
  local s=c.state(p)
  if s.dying or s.dead then s.dying=nil;s.dead=nil end
  for id,z in pairs(zones) do if z.ownerId==p:getId() then zones[id]=nil end end
  s.conds=nil
 end
 function S.onRest(p,kind)
  if kind=='long' then removeCond(p,'aid') end
 end
 -- Bordao Mistico, Arma Magica: ajustes no perfil da arma
 function S.weaponStats(p,stats)
  local s=c.state(p)
  if s.shillelagh and s.shillelagh.expires>now() and stats.weapon and (stats.weapon.srd=='club' or stats.weapon.srd=='quarterstaff') and not stats.ranged then
   local wis=c.mod(p,4)
   local copy={};for k,v in pairs(stats) do copy[k]=v end
   copy.attack=wis+c.proficiency(p);copy.flat=wis;copy.sides=8;copy.dice=1;copy.name='Bordao Mistico'
   stats=copy
  end
  local mw=getCond(p,'magicweapon')
  if mw and stats.weapon then
   local copy={};for k,v in pairs(stats) do copy[k]=v end
   copy.attack=copy.attack+mw.data.bonus;copy.flat=copy.flat+mw.data.bonus
   stats=copy
  end
  return stats
 end
 -- Lamina Flamejante substitui o Ataque
 function S.flameBladeAttack(p,t)
  local fb=c.state(p).flameBlade
  if not fb then return false end
  if not c.range(p,t,1) then warn(p,'Lamina Flamejante: chegue a 1 sqm do alvo.');return true end
  local e=c.state(p).economy
  if not R.spend(e,'action',c.now()) then warn(p,'Voce ja usou sua acao neste turno.');return true end
  c.actionCooldown(p,e)
  local roll,amount,bonus=spellAttack(p,t,false,'Lamina Flamejante',6,fb.dice)
  logAttack(p,t,roll,bonus,amount,'Lamina Flamejante',false)
  c.damage(p,t,amount,COMBAT_FIREDAMAGE,CONST_ME_FIREAREA,roll.hit,nil,nil,roll.critical,false)
  return true
 end
 function S.expeditious(p) return c.state(p).expeditious==true end
 function S.useHasteAction(p)
  local s=c.state(p)
  if s.hasteAction and getCond(p,'haste') then s.hasteAction=nil;return true end
  return false
 end
 function S.berryAction()
  local berry=Action()
  berry:onUse(function(p,item)
   local expires=0
   pcall(function() expires=item:getAttribute(ITEM_ATTRIBUTE_DATE) or 0 end)
   if expires>0 and os.time()>expires then item:remove(1);warn(p,'A fruta magica murchou.');return true end
   item:remove(1)
   if c.state(p).dead then return true end
   local amount=S.healingReceived(p,1)
   if amount>0 then p:addHealth(amount) end
   if c.feed then c.feed(p) end
   posOf(p):sendMagicEffect(CONST_ME_MAGIC_GREEN)
   tell(p,'Bom Fruto: +1 PV e alimentado.')
   return true
  end)
  berry:aid(96601)
  berry:register()
 end
 return S
end
return M
