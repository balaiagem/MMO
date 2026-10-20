-- D&D 5e rules for equipped Tibia items. Pure logic: the server adapter
-- passes the worn item ids and ability modifiers; nothing here touches the
-- engine. Data comes from equipment_data.lua (tools/build-equipment.py).
--
-- worn = {head=id, body=id, legs=id, feet=id, left=id, right=id, ammo=id}
local M={}
function M.new(data)
 local E={data=data}
 local function has(list,value)
  for _,x in ipairs(list or {})do if x==value then return true end end
  return false
 end
 function E.item(id)return id and data.items[id]or nil end
 for id,entry in pairs(data.items)do if entry.tibia=='backpack'then E.backpack=id end end

 -- Armour counts only when every piece of one set is worn.
 function E.armorSet(worn)
  local body=E.item(worn.body)
  if not body or body.kind~='armor'then return nil end
  for _,key in ipairs(body.sets)do
   local set=data.sets[key];local complete=true
   for slot,id in pairs(set.pieces)do if worn[slot]~=id then complete=false;break end end
   if complete then return set,key end
  end
  return nil
 end
 function E.shield(worn)
  for _,slot in ipairs({'left','right'})do
   local item=E.item(worn[slot])
   if item and item.kind=='shield'then return item end
  end
  return nil
 end
 function E.weapon(worn)
  for _,slot in ipairs({'left','right'})do
   local item=E.item(worn[slot])
   if item and item.kind=='weapon'then return item,worn[slot=='left'and'right'or'left']end
  end
  return nil
 end
 function E.proficientArmor(class,category)
  local p=data.proficiency[class];return p~=nil and has(p.armor,category)
 end
 function E.proficientWeapon(class,weapon)
  local p=data.proficiency[class];return p~=nil and(has(p.weapons,weapon.category)or has(p.weapons,weapon.srd))
 end

 -- ctx = {class, dex, con, wis} (ability modifiers)
 function E.ac(ctx,worn)
  local set=E.armorSet(worn);local shield=E.shield(worn);local value
  if set then
   local dex=set.dex and(set.dexMax and math.min(set.dexMax,ctx.dex)or ctx.dex)or 0
   value=set.base+dex
   if ctx.class==1 then value=value+1 end                 -- Fighting Style: Defense
  elseif ctx.class==5 then value=10+ctx.dex+ctx.con      -- Unarmored Defense (shield allowed)
  elseif ctx.class==8 and not shield then value=10+ctx.dex+ctx.wis
  elseif ctx.class==11 then value=13+ctx.dex             -- Draconic Resilience
  else value=10+ctx.dex end
  if shield then value=value+shield.bonus end
  local ring=E.item(worn.ring)                           -- Ring of Protection etc.
  if ring and ring.kind=='ring' then value=value+(ring.ac or 0) end
  return value,set,shield
 end
 -- Name of armour/shield worn without proficiency (disadvantage, no spells).
 function E.penalty(class,worn)
  local set=E.armorSet(worn)
  if set and not E.proficientArmor(class,set.category)then return set.name end
  if E.shield(worn)and not E.proficientArmor(class,'shield')then return 'Shield'end
  return nil
 end
 function E.tooHeavy(strengthScore,worn)
  local set=E.armorSet(worn);return set~=nil and set.strength>0 and strengthScore<set.strength
 end
 function E.stealthDisadvantage(worn)
  local set=E.armorSet(worn);return set~=nil and set.stealth
 end
 function E.heavy(worn)
  local set=E.armorSet(worn);return set~=nil and set.category=='heavy'
 end

 -- ctx = {class, level, str, dex, prof, rage}; opts.melee ignores ranged weapons.
 function E.attackProfile(ctx,worn,opts)
  local weapon,other=E.weapon(worn)
  if weapon and weapon.ranged and opts and opts.melee then weapon=nil end
  if not weapon then
   if ctx.class==8 then
    local ability=math.max(ctx.str,ctx.dex)
    return {dice=1,sides=ctx.level>=5 and 6 or 4,flat=ability,attack=ability+ctx.prof,name='Golpe Desarmado',reach=1,unarmed=true}
   end
   return {dice=0,sides=0,flat=math.max(1,1+ctx.str+(ctx.rage and 2 or 0)),attack=ctx.str+ctx.prof,name='Golpe Desarmado',reach=1,unarmed=true}
  end
  local finesse=has(weapon.props,'finesse')
  local monkWeapon=ctx.class==8 and(weapon.srd=='shortsword'or(weapon.category=='simple'and not weapon.ranged and
   not has(weapon.props,'two-handed')and not has(weapon.props,'heavy')))
  local ability=weapon.ranged and ctx.dex or((finesse or monkWeapon)and math.max(ctx.str,ctx.dex)or ctx.str)
  local sides=weapon.sides
  if weapon.versatile and not other then sides=weapon.versatile end   -- other hand free
  if monkWeapon and weapon.dice==1 then sides=math.max(sides,ctx.level>=5 and 6 or 4)end
  local proficient=E.proficientWeapon(ctx.class,weapon)
  local rage=(ctx.rage and not weapon.ranged and ability==ctx.str)and 2 or 0
  return {dice=weapon.dice,sides=sides,flat=ability+rage,attack=ability+(proficient and ctx.prof or 0),
   name=weapon.name,weapon=weapon,ranged=weapon.ranged,normal=weapon.normal,long=weapon.long,ammo=weapon.ammo,
   loading=has(weapon.props,'loading'),finesse=finesse,reach=has(weapon.props,'reach')and 2 or 1,proficient=proficient}
 end
 function E.ammoMatches(profile,ammoId)
  local ammo=E.item(ammoId);return ammo~=nil and ammo.kind=='ammo'and ammo.ammo==profile.ammo
 end
 return E
end
return M
