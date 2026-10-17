"""Run access actions, rest-zone rules and native Space targeting without a world write."""
from pathlib import Path
import sys,os
ROOT=Path(__file__).resolve().parents[1];os.chdir(ROOT)
sys.path.insert(0,str(ROOT/'tools/python'))
from lupa.lua51 import LuaRuntime as Lua51
from lupa.lua55 import LuaRuntime as Lua55
for runtime in (Lua51,Lua55):
    lua=runtime()
    lua.execute('''
RETURNVALUE_NOERROR=0;RETURNVALUE_PLAYERISPZLOCKED=1;TILESTATE_PROTECTIONZONE=1;TILESTATE_FLOORCHANGE=2
Position=function(x,y,z)return {x=x,y=y,z=z}end
local tiles={}
local function key(p)return p.x..':'..p.y..':'..p.z end
function setTile(x,y,z,blocked,pz,opening)
 tiles[key(Position(x,y,z))]={getGround=function()return true end,queryAdd=function()return blocked and 9 or 0 end,hasFlag=function(self,f)return f==1 and pz or f==2 and opening or false end}
end
Tile=function(p)return tiles[key(p)]end
Action=function()return {onUse=function(self,fn)useAccess=fn end,id=function()end,register=function()end}end
player={teleportTo=function(self,p)self.destination=p end,sendCancelMessage=function(self,msg)self.message=msg end,isPzLocked=function(self)return self.locked end}
item={getId=function(self)return self.id end}
''')
    lua.execute((ROOT/'world/content/rookgaard_access.lua').read_text(encoding='utf-8'))
    lua.execute('''
setTile(100,100,8);item.id=435;useAccess(player,item,Position(100,100,7))
assert(player.destination.z==8,'sewer Use did not descend')
setTile(100,101,7);item.id=1948;useAccess(player,item,Position(100,100,8))
assert(player.destination.z==7 and player.destination.y==101,'ladder did not use its upper landing')
player.destination=nil;useAccess(player,item,Position(65535,0,8));assert(not player.destination,'inventory item teleported player')
setTile(200,200,8,false,true);player.locked=true;item.id=435;useAccess(player,item,Position(200,200,7))
assert(not player.destination and player.message==RETURNVALUE_PLAYERISPZLOCKED,'PZ combat lock bypassed')
player.locked=false;setTile(300,300,7,false,false,true);item.id=1948;useAccess(player,item,Position(300,300,8))
assert(not player.destination,'upper opening caused immediate floor-change loop')
''')
    source=(ROOT/'world/content/dnd_combat.lua').read_text(encoding='utf-8')
    code=source[source.index('local function cityFloor(p)'):source.index('local function sendProgressSheet(p)')]
    lua.execute('''
worldConfig={protectionZoneRest=true,spawn={32097,32219,7}}
local spectators={}
Game={getSpectators=function()return spectators end}
function setNpc(name,x,y,z)
 spectators={{isNpc=function()return true end,getName=function()return name end,getPosition=function()return Position(x,y,z)end}}
end
function range(a,b,n)
 local p,q=a:getPosition(),b:getPosition()
 return p.z==q.z and math.max(math.abs(p.x-q.x),math.abs(p.y-q.y))<=n
end
player.getPosition=function(self)return self.pos end
''')
    check=lua.execute(code+'\nreturn cityFloor')
    lua.globals().checkRest=check
    lua.execute('''
player.pos=Position(32101,32182,8);setNpc('Amber',32101,32182,8);assert(checkRest(player),'Amber rest not allowed')
player.pos=Position(32105,32182,8);assert(not checkRest(player),'Amber zone extends too far')
player.pos=Position(32101,32182,7);assert(not checkRest(player),'Amber allowed rest on a different floor')
player.pos=Position(32097,32219,7);setNpc('Cipfried',32096,32217,7);assert(checkRest(player),'temple rest not allowed')
player.pos=Position(32098,32219,8);assert(not checkRest(player),'rest allowed under temple')
''')
    lua.execute((ROOT/'client/modules/game_dnd/dnd.lua').read_text(encoding='utf-8'))
    ui=(ROOT/'client/modules/game_dnd/dnd.lua').read_text(encoding='utf-8')
    message=lua.execute(ui[ui.index('local function message(mode,text)'):ui.index('local function hide()')]+'\nreturn message')
    # A selection/initiative notification must return without touching dice UI.
    message(0,'[5E] INITIATIVE actor=Rat d20=14 +0 = 14 | turno 2/2')
    # Encounter exit must also release the client's movement gate and pending UI.
    movement=ui[ui.index('function consumeTurnMovement(dir)'):ui.index('local abilityKeys=')]
    lua.execute('''
local combatResources={own=false,move=0}
local removed,hidden,cleared=0,0,false
local rolling,hideRoll=1,2
local function removeEvent() removed=removed+1 end
local function clearAreaSpellTargeting() cleared=true end
local function widget() return {hide=function()hidden=hidden+1 end} end
local panel,turnHud,initiativeWindow=widget(),widget(),widget()
'''+movement+ui[ui.index('local function message(mode,text)'):ui.index('local function hide()')]+'''
assert(not consumeTurnMovement(0),'fixture must start movement locked')
message(0,'[5E] ENCOUNTER ended')
assert(combatResources==nil and consumeTurnMovement(0) and consumeTurnMovement(4),'encounter exit left movement locked')
assert(cleared and removed==2 and hidden==3,'encounter exit left targeting, timers or turn UI active')
assert(rolling==nil and hideRoll==nil,'roll timers not cleared')
''')
    lua.execute('''
local editing=false
local focused={getFocusedChild=function()return nil end,getClassName=function()return editing and 'UITextEdit' or 'UIWidget' end}
g_ui={getRootWidget=function()return {getFocusedChild=function()return focused end}end}
local function enemy(id,x,y,z,kind)
 return {getId=function()return id end,isMonster=function()return kind~='npc' end,isRemoved=function()return false end,getHealthPercent=function()return 100 end,getPosition=function()return {x=x,y=y,z=z}end}
end
local list={enemy(1,100,100,7,'npc'),enemy(2,104,100,7),enemy(3,101,100,7),enemy(4,100,100,8)}
local target,count=nil,0
g_game={isOnline=function()return true end,getLocalPlayer=function()return {getPosition=function()return {x=100,y=100,z=7}end}end,getAttackingCreature=function()return target end,attack=function(c)target=c;count=count+1 end}
g_map={getSpectators=function()return list end}
assert(selectNearestEnemy() and target:getId()==3,'Space did not select nearest monster on the same floor')
selectNearestEnemy();assert(count==1,'Space toggled off the already nearest target')
editing=true;assert(not selectNearestEnemy() and count==1,'Space intercepted typing in a text field')
''')
    print(runtime.__module__+': sewer/ladder/PZ, temple/Amber and Space targeting passed')
