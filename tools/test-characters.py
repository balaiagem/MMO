from pathlib import Path
import os,sys
root=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(root/'tools/python'));os.chdir(root)
from lupa.lua51 import LuaRuntime as Lua51
from lupa.lua55 import LuaRuntime as Lua55
for name,runtime in [('5.1',Lua51),('5.5',Lua55)]:
    print('Character engine Lua '+name,flush=True)
    runtime().execute((root/'tests/characters.lua').read_text(encoding='utf-8'))
