"""Start the configured local game; preserve database, accounts and progress."""
from pathlib import Path
import os, sys, socket, subprocess, shutil, time, urllib.request, webbrowser

ROOT=Path(__file__).resolve().parents[1]
RUNTIME=ROOT/'runtime'

def sync_combat_rules():
    """Keep the runtime's loaded 5e adapter and rule kernel from different revisions."""
    data=RUNTIME/'server'/'data'
    for source,target in [
        (ROOT/'rules'/'core.lua',data/'lib'/'dnd_rules.lua'),
        (ROOT/'rules'/'class_actions.lua',data/'lib'/'dnd_class_actions.lua'),
        (ROOT/'rules'/'characters.lua',data/'lib'/'dnd_characters.lua'),
        (ROOT/'rules'/'character_data.lua',data/'lib'/'dnd_character_data.lua'),
        (ROOT/'world'/'content'/'dnd_combat.lua',data/'scripts'/'dnd_combat.lua'),
        (ROOT/'world'/'content'/'gm_tools.lua',data/'scripts'/'gm_tools.lua'),
        (ROOT/'world'/'content'/'rookgaard_access.lua',data/'scripts'/'rookgaard_access.lua'),
    ]:
        target.parent.mkdir(parents=True,exist_ok=True)
        if not target.exists() or source.read_bytes()!=target.read_bytes():
            shutil.copy2(source,target)

def tcp(port):
    try:
        with socket.create_connection(('127.0.0.1',port),timeout=.5): return True
    except OSError: return False

def http(port,path):
    try:
        with urllib.request.urlopen(f'http://localhost:{port}{path}',timeout=3) as response:
            return response.status==200
    except OSError: return False

def start(name,command,ready,cwd=ROOT,env=None):
    if ready():
        print(f'{name}: ativo.',flush=True); return
    for path in [Path(command[0])]:
        if not path.is_file(): raise RuntimeError(f'Arquivo necessario ausente: {path}')
    with (RUNTIME/f'{name}.launcher.log').open('ab') as log:
        process=subprocess.Popen([str(a) for a in command],cwd=cwd,env=env,
            stdin=subprocess.DEVNULL,stdout=log,stderr=log,close_fds=True,
            creationflags=subprocess.CREATE_NO_WINDOW|subprocess.DETACHED_PROCESS)
    (RUNTIME/f'{name}.launcher.pid').write_text(str(process.pid))
    for _ in range(90):
        if ready(): print(f'{name}: iniciado.',flush=True); return
        if process.poll() is not None: break
        time.sleep(.5)
    raise RuntimeError(f'{name} nao iniciou. Consulte runtime/{name}.launcher.log.')

def main():
    if not (RUNTIME/'server/config.lua').exists():
        raise RuntimeError('Configuracao local ausente. Este atalho precisa do runtime preparado neste computador.')
    if not (ROOT/'build/client-web/bin/otclient.html').exists():
        raise RuntimeError('Cliente web ainda esta sendo compilado; tente novamente ao concluir.')
    sync_combat_rules()
    mariadb=ROOT/'tools/mariadb-11.4.12-winx64'
    start('banco',[mariadb/'bin/mariadbd.exe',f'--datadir={RUNTIME / "database"}',
          f'--basedir={mariadb}','--bind-address=127.0.0.1','--port=3307','--console'],lambda:tcp(3307))
    start('servidor',[ROOT/'build/server-vs/Release/tfs.exe'],lambda:tcp(7171) and tcp(7172),cwd=RUNTIME/'server')
    node=shutil.which('node') or str(ROOT/'tools/emsdk/node/24.19.0_64bit/node.exe')
    for name,port,target in [('login',8081,7171),('mundo',8082,7172)]:
        env=dict(os.environ,PORT=str(port),TFS_PORT=str(target),TFS_HOST='127.0.0.1',BIND='127.0.0.1',ALLOWED_ORIGINS='http://localhost:8080')
        start(name,[node,ROOT/'tools/gateway.mjs'],lambda p=port:http(p,'/healthz'),env=env)
    start('pagina',[sys.executable,ROOT/'client/tools/emscripten-web-serve.py','--root',
          ROOT/'build/client-web/bin','--bind','127.0.0.1','--port','8080'],lambda:http(8080,'/otclient.html'))
    print('\nAbra http://localhost:8080/otclient.html\nClique em Start. Conta: admin | Senha: admin',flush=True)
    print('Os servicos continuam ativos depois de fechar esta janela.')
    print('Criacao de personagem: http://localhost:8080/characters.html', flush=True)
    if '--no-browser' not in sys.argv: webbrowser.open('http://localhost:8080/otclient.html')

if __name__=='__main__':
    try: main()
    except Exception as error:
        print(f'\nNao foi possivel iniciar: {error}',flush=True); sys.exit(1)
