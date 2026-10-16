from pathlib import Path
import os,sys
root=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(root/'tools/python'));os.chdir(root)
from lupa.lua51 import LuaRuntime as Lua51
from lupa.lua55 import LuaRuntime as Lua55
for cls in (Lua51,Lua55):cls().execute((root/'tests/combat_adapter.lua').read_text(encoding='utf-8'))
