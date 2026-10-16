local M=dofile('rules/characters.lua').new(dofile('rules/character_data.lua'))
local scores={STR=16,DEX=14,CON=14,INT=12,WIS=13,CHA=10}
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local count=0
for classId=1,12 do for raceId=1,9 do for level=1,5 do
 local c=M.classes[classId]
 local p=M.derive(classId,raceId,level,scores,{subclass=c.subclass})
 eq(p.hitDie,c.hitDie);eq(p.proficiency,level==5 and 3 or 2)
 assert(p.hp>0 and p.speed>=0 and p.ac>=10)
 eq(#p.slots,3)
 local last=level>1 and M.derive(classId,raceId,level-1,scores,{subclass=c.subclass}) or nil
 if last then assert(p.hp>last.hp) end
 count=count+1
end end end
eq(count,540)
local p=M.derive(5,8,5,{STR=17,DEX=13,CON=15,INT=8,WIS=12,CHA=10},{subclass='berserker'})
eq(p.hp,50);eq(p.ac,13);eq(p.speed,40);eq(p.attacks,2)
p=M.derive(8,1,5,{STR=10,DEX=16,CON=14,INT=8,WIS=16,CHA=10},{subclass='open-hand'})
eq(p.hp,38);eq(p.ac,16);eq(p.speed,40);eq(p.attacks,2)
eq(M.derive(8,1,5,scores,{shield=true}).speed,30)
eq(M.derive(5,1,5,scores,{armor='chain'}).speed,30)
eq(M.derive(1,1,1,{STR=8,DEX=14,CON=14,INT=12,WIS=13,CHA=10},{armor='chain'}).speed,20)
eq(M.derive(1,3,1,{STR=8,DEX=14,CON=14,INT=12,WIS=13,CHA=10},{armor='chain'}).speed,25)
eq(M.derive(1,3,5,{STR=16,DEX=14,CON=16,INT=12,WIS=13,CHA=10},{}).hp,54)
eq(M.derive(11,1,5,{STR=8,DEX=16,CON=14,INT=12,WIS=10,CHA=16},{subclass='draconic'}).hp,37)
eq(M.derive(11,1,1,scores,{subclass='draconic'}).ac,15)
for level=1,5 do
 local p=M.derive(12,1,level,scores,{subclass='fiend'})
 local circle=math.ceil(level/2)
 for i=1,3 do eq(p.slots[i],i==circle and (level==1 and 1 or 2) or 0) end
 assert(p.pactMagic)
end
eq(M.derive(9,1,1,scores,{}).spellDC,0)
eq(M.derive(9,1,5,scores,{}).slots[2],2)
eq(M.derive(10,1,5,scores,{}).slots[3],0)
eq(M.derive(4,1,5,scores,{}).spellbook,14)
eq(M.derive(7,1,2,scores,{subclass='land'}).cantrips,3)
eq(M.derive(7,1,2,scores,{}).cantrips,2)
eq(M.skillBonus(6,5,2,false,false),3)
eq(M.skillBonus(6,5,2,true,false),5)
eq(M.skillBonus(2,5,2,true,true),8)
assert(not pcall(M.skillBonus,2,5,2,false,true))
assert(M.saveTraits(6,'INT',{magic=true}).advantage)
assert(not M.saveTraits(6,'DEX',{magic=true}).advantage)
assert(M.saveTraits(2,'WIS',{magicalSleep=true}).immuneSleep)
assert(M.saveTraits(4,'WIS',{fear=true}).advantage)
assert(M.resistance(3,'poison'));assert(M.resistance(9,'fire'));assert(M.resistance(5,'cold','silver'))
assert(not M.resistance(5,'fire','silver'))
local pools=M.syncPools(nil,M.resources(5,2,0))
eq(pools.rage.remaining,2);assert(M.spendPool(pools,'rage',2));assert(not M.spendPool(pools,'rage'))
pools=M.syncPools(pools,M.resources(5,3,0));eq(pools.rage.remaining,1)
M.restorePools(pools,'short');eq(pools.rage.remaining,1)
M.restorePools(pools,'long');eq(pools.rage.remaining,3)
pools=M.syncPools(nil,M.resources(6,4,3));M.spendPool(pools,'inspiration');M.restorePools(pools,'short');eq(pools.inspiration.remaining,2)
pools=M.syncPools(pools,M.resources(6,5,3));M.restorePools(pools,'short');eq(pools.inspiration.remaining,3)
eq(M.resources(8,1,0).ki,nil);eq(M.resources(8,5,0).ki.maximum,5)
eq(M.resources(9,5,0).layonhands.maximum,25)
eq(M.resources(7,2,0).naturalrecovery,nil)
eq(M.resources(7,2,0,{subclass='land'}).naturalrecovery.maximum,1)
assert(not pcall(M.derive,1,1,6,scores,{}))
assert(not pcall(M.derive,1,1,3,scores,{subclass='fiend'}))
print('Characters: 540 class/race/level sheets, equipment AC, half/pact slots, resources and racial saves passed')
