"""Run the same Lua source on Lua 5.1 and 5.5, using local Lupa wheels."""
import sys
from pathlib import Path
import os
root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root / 'tools/python'))
os.chdir(root)
from lupa.lua51 import LuaRuntime as Lua51
from lupa.lua55 import LuaRuntime as Lua55
for version, runtime in [('5.1', Lua51), ('5.5', Lua55)]:
    print(f'Lua {version}', flush=True)
    lua = runtime()
    lua.execute((root / 'tests/rules.lua').read_text(encoding='utf-8'))
