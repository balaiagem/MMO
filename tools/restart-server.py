"""Restart only the game server (tfs.exe) so it reloads the Lua scripts.

Jogar.bat skips the server when it is already running, and the server runs
without a window, so script changes never load without this.
"""
from pathlib import Path
import subprocess, sys, time, socket

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import importlib.util
spec = importlib.util.spec_from_file_location('start_local', ROOT / 'tools' / 'start-local.py')
start_local = importlib.util.module_from_spec(spec); spec.loader.exec_module(start_local)

def port_open(port):
    try:
        with socket.create_connection(('127.0.0.1', port), timeout=.5): return True
    except OSError: return False

print('Parando o servidor (tfs.exe)...', flush=True)
subprocess.run(['taskkill', '/IM', 'tfs.exe', '/F'], capture_output=True)
for _ in range(40):
    if not port_open(7171) and not port_open(7172): break
    time.sleep(.5)
else:
    raise SystemExit('O servidor nao parou. Feche o tfs.exe pelo Gerenciador de Tarefas.')

start_local.sync_combat_rules()
start_local.start('servidor', [ROOT / 'build/server-vs/Release/tfs.exe'],
                  lambda: port_open(7171) and port_open(7172), cwd=start_local.RUNTIME / 'server')
print('Servidor reiniciado com os scripts atuais. Entre de novo no jogo.', flush=True)
