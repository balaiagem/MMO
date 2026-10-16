"""Activate the reviewed Rookgaard import while preserving player profiles."""
from pathlib import Path
from datetime import datetime
import json, shutil, subprocess, sys

ROOT=Path(__file__).resolve().parents[1]
WORK=ROOT/'runtime/rookgaard-import'
STAGE=WORK/'server/data'
LIVE=ROOT/'runtime/server/data'
MDB=ROOT/'tools/mariadb-11.4.12-winx64/bin'
HIDDEN=getattr(subprocess,'CREATE_NO_WINDOW',0)

def sql(query):
    return subprocess.run([str(MDB/'mariadb.exe'),'--defaults-extra-file='+str(ROOT/'runtime/admin.cnf'),
        '--batch','--skip-column-names','tibia5e_local','-e',query],capture_output=True,check=True,creationflags=HIDDEN).stdout.decode().strip()

def copy(src,dst):
    src=Path(src);dst=Path(dst);dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,dst)

def backup_file(path,backup):
    path=Path(path)
    if path.exists():copy(path,backup/path.relative_to(ROOT))

def main():
    manifest=json.loads((ROOT/'world/rookgaard-import.json').read_text(encoding='utf-8'))
    required=[STAGE/'world/rookgaard.otbm',STAGE/'items/items.otb',STAGE/'scripts/dnd_combat.lua',WORK/'staged/client/Tibia.dat',WORK/'staged/client/Tibia.spr']
    if any(not p.is_file() for p in required):raise RuntimeError('O pacote preparado de Rookgaard está incompleto.')
    online=int(sql('SELECT COUNT(*) FROM players_online;'))
    if online:raise RuntimeError(f'{online} personagem(ns) ainda estão conectados; nenhum arquivo foi alterado.')
    stamp=datetime.now().strftime('%Y%m%d-%H%M%S');backup=WORK/'backup'/stamp;backup.mkdir(parents=True)
    changed=[LIVE/'items/items.otb',LIVE/'items/items.xml',LIVE/'world/rookgaard.otbm',LIVE/'world/rookgaard-spawn.xml',LIVE/'world/rookgaard-house.xml',LIVE/'lib/lib.lua',LIVE/'scripts/dnd_combat.lua',LIVE/'lib/dnd_world.lua',ROOT/'client/data/things/860/Tibia.dat',ROOT/'client/data/things/860/Tibia.spr']
    for p in changed:backup_file(p,backup)
    for rel in ['npc','monsters','scripts/rookgaard_actions']:
        src=LIVE/rel
        if src.exists():shutil.copytree(src,backup/'runtime/server/data'/rel,dirs_exist_ok=True)
    dump=backup/'tibia5e_local.sql'
    with dump.open('wb') as out:
        subprocess.run([str(MDB/'mariadb-dump.exe'),'--defaults-extra-file='+str(ROOT/'runtime/admin.cnf'),'--single-transaction','--hex-blob','--skip-lock-tables','tibia5e_local'],stdout=out,stderr=subprocess.PIPE,check=True,creationflags=HIDDEN)
    # A clean server shutdown is safe because the online-character check above
    # returned zero. Stop only the process bound to this project's game port.
    lines=subprocess.run(['netstat','-ano','-p','tcp'],capture_output=True,text=True,check=True,creationflags=HIDDEN).stdout.splitlines()
    pids=set()
    for line in lines:
        parts=line.split()
        if len(parts)>=5 and parts[1].endswith(':7172') and parts[3].upper()=='LISTENING':pids.add(parts[4])
    for pid in pids:subprocess.run(['taskkill','/PID',pid,'/F'],capture_output=True,check=True,creationflags=HIDDEN)

    for name in ['items.otb','items.xml']:copy(STAGE/'items'/name,LIVE/'items'/name)
    for name in ['rookgaard.otbm','rookgaard-spawn.xml','rookgaard-house.xml']:copy(STAGE/'world'/name,LIVE/'world'/name)
    for name in ['dnd_world.lua','rookgaard']:
        src=STAGE/'lib'/name
        dst=LIVE/'lib'/name
        if src.is_dir():shutil.copytree(src,dst,dirs_exist_ok=True)
        elif src.exists():copy(src,dst)
    lib=LIVE/'lib/lib.lua';text=lib.read_text(encoding='utf-8')
    if 'data/lib/rookgaard/position.lua' not in text:
        text+="\n-- Rookgaard legacy content compatibility, keeping existing libraries.\n"
        text+='if not table.contains then function table.contains(t,value) for _,entry in pairs(t) do if entry==value then return true end end return false end end\n'
        text+='if not table.maxn then function table.maxn(t) local n=0 for key in pairs(t) do if type(key)=="number" and key>n then n=key end end return n end end\n'
        for name in ['position.lua','storages.lua','compat.lua','item_tables.lua']:text+=f"dofile('data/lib/rookgaard/{name}')\n"
        lib.write_text(text,encoding='utf-8')
    copy(STAGE/'scripts/dnd_combat.lua',LIVE/'scripts/dnd_combat.lua')
    shutil.copytree(STAGE/'scripts/rookgaard_actions',LIVE/'scripts/rookgaard_actions',dirs_exist_ok=True)
    for p in (STAGE/'monsters').glob('imported_*.lua'):copy(p,LIVE/'monsters'/p.name)
    shutil.copytree(STAGE/'npc/lib',LIVE/'npc/lib',dirs_exist_ok=True)
    source_npcs=WORK/'source/data/npc'
    for xml in source_npcs.glob('*.xml'):
        staged_xml=STAGE/'npc'/xml.name;copy(staged_xml,LIVE/'npc'/xml.name)
        import xml.etree.ElementTree as ET
        script=ET.parse(xml).getroot().get('script')
        if script:copy(STAGE/'npc/scripts'/script,LIVE/'npc/scripts'/script)
    copy(ROOT/'world/content/rookgaard_access.lua',LIVE/'scripts/rookgaard_access.lua')
    old_access=LIVE/'scripts/rookgaard_actions/1_teleport.lua'
    if old_access.exists():old_access.replace(old_access.with_suffix('.lua.disabled'))
    scripts=LIVE/'scripts'
    for name in ['rookgaard_stairs.lua','rookgaard_world.lua']:
        src=scripts/name
        if src.exists():src.replace(src.with_suffix(src.suffix+'.disabled'))
    for name in ['Tibia.dat','Tibia.spr']:copy(WORK/'staged/client'/name,ROOT/'client/data/things/860'/name)

    positions=manifest['safe_positions'];player_ids=[int(x) for x in sql('SELECT id FROM players ORDER BY id;').splitlines() if x.strip()]
    updates=[]
    for index,pid in enumerate(player_ids):
        x,y,z=positions[index%len(positions)]
        updates.append(f'UPDATE players SET posx={x},posy={y},posz={z},town_id={int(manifest["town_id"])} WHERE id={pid};')
    if updates:sql('\n'.join(updates))
    (backup/'deployment.json').write_text(json.dumps({'backup_created':stamp,'players_relocated':len(player_ids),'spawn':manifest['spawn'],'source_commit':manifest['source_commit']},indent=2),encoding='utf-8')
    subprocess.run([sys.executable,str(ROOT/'tools/repack-client.py')],cwd=ROOT,check=True,creationflags=HIDDEN)
    subprocess.run([sys.executable,str(ROOT/'tools/start-local.py'),'--no-browser'],cwd=ROOT,check=True,creationflags=HIDDEN)
    print(f'Rookgaard ativo; {len(player_ids)} personagem(s) preservados e reposicionados. Backup: {backup.relative_to(ROOT)}')

if __name__=='__main__':
    try:main()
    except Exception as exc:
        print('Importação não ativada:',exc,file=sys.stderr);sys.exit(1)
