"""Validate actual catalogue permissions and changed Lua syntax without a GUI mock."""
from pathlib import Path
import sys
root=Path(__file__).resolve().parents[1];sys.path.insert(0,str(root/'tools/python'))
from lupa.lua51 import LuaRuntime
lua=LuaRuntime(unpack_returned_tuples=True)
paths=['game_dnd/dnd.lua','game_actionbar/logics/ActionAssignmentWindows.lua','game_actionbar/logics/ActionButtonLogic.lua','game_actionbar/logics/MultiActionLogic.lua','game_healthinfo/healthinfo.lua','game_interface/widgets/statsbar.lua','game_interface/widgets/uigamemap.lua','game_interface/gameinterface.lua','game_skills/skills.lua','game_textmessage/textmessage.lua','gamelib/spells.lua']
for name in paths:
    result=lua.eval('loadstring')((root/'client/modules'/name).read_text(encoding='utf-8'))
    if isinstance(result,tuple): raise AssertionError((name,result[1]))
lua.execute((root/'client/modules/game_dnd/dnd.lua').read_text(encoding='utf-8'))
catalog=(root/'client/modules/gamelib/spells.lua').read_text(encoding='utf-8').split('-- Local authoritative 5E spell catalogue')[1]
lua.execute('SpellInfo = {}\n'+catalog[catalog.index('SpellInfo.Default'):])
g=lua.globals()
for cls in (1,2,3,4,5,8,9):
    for race in (1,2,3,4,8):
        g.classId,g.raceId=cls,race
        available={name for name,spell in g.SpellInfo.Default.items() if g.canLearn(spell) and spell.words.startswith('/cast ')}
        expected={'Fire Bolt','Magic Missile'} if cls==4 else {'Sacred Flame','Cure Wounds','Healing Word','Bless','Shield of Faith'} if cls==3 else set()
        if race==2:expected.add('Fire Bolt')
        assert available==expected,(cls,race,available,expected)
assert g.SpellInfo.Default['Fire Bolt'].mana==0
assert g.SpellInfo.Default['Magic Missile'].mana==1
for level in range(1,6):
    g.classId,g.raceId,g.characterLevel=9,1,level
    available={name for name,spell in g.SpellInfo.Default.items() if g.canLearn(spell) and spell.words.startswith('/cast ')}
    assert available==({'Cure Wounds','Bless','Shield of Faith'} if level>=2 else set()),(level,available)
g.classId,g.raceId,g.characterLevel=1,1,1
assert g.canLearn(g.SpellInfo.Default['[5e] Retomar o Folego'])
assert g.canLearn(g.SpellInfo.Default['[5e] Aumentar circulo de magia'])
assert not g.canLearn(g.SpellInfo.Default['[5e] Surto de Acao'])
g.classId,g.raceId,g.characterLevel=4,2,5
assert g.canLearn(g.SpellInfo.Default['[5e] Surto de Acao']) is False
assert not g.canLearn(g.SpellInfo.Default['[5e] Ancestralidade Feerica'])
assert g.canLearn(g.SpellInfo.Default['[5e] Recuperacao Arcana'])
lua.execute(r'''
map={}
local function pos(x,y,z)return {x=x,y=y,z=z}end
local player={getPosition=function()return pos(100,100,7)end}
function map:getPosition(mouse) return pos(mouse.x,mouse.y,7) end
function map:getTileRect(pos) return {x=pos.x*10,y=pos.y*10,width=10,height=10} end
modules={game_interface={getMapPanel=function()return map end}}
g_game={getLocalPlayer=function()return player end}
sentSpell=nil
g_game.talk=function(text)sentSpell=text end
MouseLeftButton=1;MouseRightButton=2
cursorPush,cursorPop=0,0
g_mouse={pushCursor=function()cursorPush=cursorPush+1 end,popCursor=function()cursorPop=cursorPop+1 end}
Position={translated=function(origin,dx,dy,dz)return {x=origin.x+dx,y=origin.y+dy,z=origin.z+(dz or 0)}end}
g_window={getMousePosition=function()return {x=105,y=106}end}
scheduleEvent=function(fn,delay)return {fn=fn,delay=delay}end
removeEvent=function()end
local previewCells={}
g_ui={createWidget=function(style,parent)
 local widget={visible=false,style=style}
 function widget:isDestroyed()return false end
 function widget:hide()self.visible=false end
 function widget:show()self.visible=true end
 function widget:destroy()self.destroyed=true end
 function widget:raise()end
 function widget:setRect(rect)self.rect=rect end
 if style:find('DndAreaPreviewCell',1,true) then table.insert(previewCells,widget) end
 return widget
end}
assert(beginSpellTargeting('/cast fireball'),'Fireball did not enter map-targeting mode')
assert(isAreaSpellTargeting() and cursorPush==1,'targeting cursor/state was not activated')
updateAreaSpellPreview(map,{x=105,y=106})
local visible=0
for _,cell in ipairs(previewCells) do if cell.visible then visible=visible+1 end end
assert(visible>1,'hovering a map tile did not show the area preview')
assert(onAreaSpellMapClick(pos(110,111,7),MouseLeftButton),'left-click did not select the fireball center')
assert(sentSpell=='/cast fireball 110 111 7','map click did not send the targeted spell command')
assert(not isAreaSpellTargeting() and cursorPop==1,'selected area failed to close target mode')
assert(beginSpellTargeting('/cast fireball'),'second Fireball did not enter targeting mode')
modules.game_dnd={
 isAreaSpellTargeting=isAreaSpellTargeting,
 cancelAreaSpellTargeting=cancelAreaSpellTargeting,
 updateAreaSpellPreview=updateAreaSpellPreview,
 onAreaSpellMapClick=onAreaSpellMapClick
}
extends=function()return {}end;UIMap={}
''')
lua.execute((root/'client/modules/game_interface/widgets/uigamemap.lua').read_text(encoding='utf-8'))
lua.execute(r'''
UIGameMap.onMouseRelease(map,{x=105,y=106},MouseLeftButton)
assert(sentSpell=='/cast fireball 105 106 7','map release did not cast directly when normal click handling was unavailable')
assert(not isAreaSpellTargeting() and cursorPop==2,'map selection failed to close targeting mode: active='..tostring(isAreaSpellTargeting())..' pops='..cursorPop)
assert(beginSpellTargeting('/cast fireball'),'third Fireball did not enter targeting mode')
UIGameMap.onMouseRelease(map,{x=105,y=106},MouseRightButton)
assert(not isAreaSpellTargeting() and cursorPop==3,'map right-click failed to cancel and restore the cursor')
''')
print('Changed Lua syntax, 35 creation class/race filters and Paladin levels 1-5 passed.')
