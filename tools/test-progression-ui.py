"""Execute the real Skills progression functions against widget stand-ins."""
from pathlib import Path
import sys
root=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(root/'tools/python'))
from lupa.lua51 import LuaRuntime as Lua51
from lupa.lua55 import LuaRuntime as Lua55
source=(root/'client/modules/game_skills/skills.lua').read_text(encoding='utf-8')
curve=source[source.index('function expForLevel('):source.index('function resetSkillColor(')]
refresh=source[source.index('function onDndLevelChange('):source.index('function onDndSlotsChange(')]
for runtime in (Lua51,Lua55):
    lua=runtime()
    lua.execute("skillsWindow={}; values={}; tips={}; percents={}; comma_value=tostring; setSkillValue=function(k,v) values[k]=v end; setSkillTooltip=function(k,v) tips[k]=v end; setSkillPercent=function(k,v,t) percents[k]=v end")
    lua.execute(curve+refresh)
    lua.execute("""
        onDndLevelChange(4,3456,6500)
        assert(values.level=='4' and values.experience=='3456')
        assert(math.abs(percents.level-(3456-2700)*100/3800)<0.001)
        assert(expToAdvance(4,3456)==3044)
        onDndLevelChange(4,3500,6500)
        assert(values.experience=='3500' and expToAdvance(4,3500)==3000)
        onDndLevelChange(5,8000,0)
        assert(values.level=='5' and values.experience=='8000' and percents.level==100)
        assert(expToAdvance(5,8000)==0)
        onDndLevelChange(1,0,300)
        assert(values.experience=='0' and percents.level==0)
    """)
print('Skills: D&D XP values, GM totals, progress percentages, level cap and reset passed on Lua 5.1/5.5.')
