"""Prepare an isolated map-import server; never replaces live config or DB."""
from pathlib import Path
import json, shutil, re, urllib.request, urllib.parse, concurrent.futures
import xml.etree.ElementTree as ET
import importlib.util, subprocess, sys
ROOT=Path(__file__).resolve().parents[1]
WORK=ROOT/'runtime/rookgaard-import';SOURCE=WORK/'source';STAGE=WORK/'staged';SERVER=WORK/'server'

def lua(v):
    if isinstance(v,bool):return 'true' if v else 'false'
    if isinstance(v,str):return json.dumps(v)
    if isinstance(v,dict):return '{'+','.join('['+lua(k)+']='+lua(x) for k,x in v.items())+'}'
    if isinstance(v,list):return '{'+','.join(map(lua,v))+'}'
    return str(v)

def main():
    tree=json.loads((ROOT/'world/realmap-candidate-tree.json').read_text())['tree']
    lookup={e['path'].lower():e['path'] for e in tree}
    base='https://raw.githubusercontent.com/Brunowots/RealMap-Global-8.0-With-Mount-Market-TFS-1.2/e4113537e25870336811c4131e379c2710348ae6/'
    def get(path):
        path=lookup.get(path.lower(),path);dest=SOURCE/path;dest.parent.mkdir(parents=True,exist_ok=True)
        if not dest.exists():dest.write_bytes(urllib.request.urlopen(base+urllib.parse.quote(path,safe='/'),timeout=45).read())
    paths=[e['path'] for e in tree if e['type']=='blob' and e['path'].startswith('data/npc/lib/') and e['path'].endswith('.lua')]
    for file in (SOURCE/'data/npc').glob('*.xml'):
        script=ET.parse(file).getroot().get('script')
        if script:paths.append('data/npc/scripts/'+script)
    list(concurrent.futures.ThreadPoolExecutor(8).map(get,paths))
    SERVER.mkdir(exist_ok=True)
    shutil.copytree(ROOT/'runtime/server/data',SERVER/'data',dirs_exist_ok=True)
    data=SERVER/'data'
    if (ROOT/'runtime/server/key.pem').exists():shutil.copy2(ROOT/'runtime/server/key.pem',SERVER/'key.pem')
    for name in ['rookgaard.otbm','rookgaard-spawn.xml','rookgaard-house.xml']:shutil.copy2(STAGE/name,data/'world'/name)
    for name in ['items.otb','items.xml']:shutil.copy2(SOURCE/'data/items'/name,data/'items'/name)
    # Disable only the authored prototype's tile teleports and guide population.
    for name in ['rookgaard_stairs.lua','rookgaard_world.lua']:
        path=data/'scripts'/name
        if path.exists():path.replace(path.with_suffix('.lua.disabled'))
    shutil.copytree(ROOT/'server/data/npc/lib',data/'npc/lib',dirs_exist_ok=True)
    shutil.copytree(SOURCE/'data/npc',data/'npc',dirs_exist_ok=True)
    config=(ROOT/'runtime/server/config.lua').read_text()
    config+='\n-- Isolated Rookgaard import validation\nloginProtocolPort=7175\ngameProtocolPort=7176\nstatusProtocolPort=7177\nadminPort=7174\nmysqlDatabase="tibia5e_rookgaard_qa"\n'
    (SERVER/'config.lua').write_text(config)
    # Legacy creatures become native RevScripts; only D&D resolves damage.
    source_items_module=importlib.util.spec_from_file_location('extract',ROOT/'tools/extract-rookgaard.py')
    extract=importlib.util.module_from_spec(source_items_module);source_items_module.loader.exec_module(extract)
    mapping=extract.otb_items((SOURCE/'data/items/items.otb').read_bytes())
    report=json.loads((STAGE/'extraction.json').read_text());needed=set();looks=set()
    for file in (SOURCE/'data/npc').glob('*.xml'):
        node=ET.parse(file).getroot();look=node.find('look')
        if look is not None and look.get('type'):looks.add(int(look.get('type')))
        for param in node.findall('./parameters/parameter'):
            if param.get('key','').startswith('shop_'):
                for entry in param.get('value','').split(';'):
                    values=entry.split(',')
                    if len(values)>1 and values[1].isdigit():needed.add(int(values[1]))
    for file in (SOURCE/'data/npc/scripts').glob('*.lua'):
        text=file.read_text(encoding='utf-8',errors='replace')
        needed.update(int(x) for x in re.findall(r'(?:addItem|getItemCount|removeItem)\(\s*(\d+)',text))
    source_monsters=[]
    for file in (SOURCE/'data/monster').rglob('*.xml'):
        if file.name=='monsters.xml':continue
        node=ET.parse(file).getroot();name=node.get('name');look=node.find('look');health=node.find('health');looks.add(int(look.get('type','0')))
        flags={}
        for flag in node.findall('./flags/flag'):flags.update(flag.attrib)
        loot=[]
        for entry in node.findall('.//loot//item'):
            if entry.get('id'):
                ident=int(entry.get('id'));needed.add(ident)
                loot.append({'id':ident,'chance':int(entry.get('chance','100000')),'maxCount':int(entry.get('countmax','1'))})
        info={'name':name,'description':node.get('nameDescription',name),'experience':int(node.get('experience','0')),'outfit':{'lookType':int(look.get('type','0'))},'health':int(health.get('max')),'maxHealth':int(health.get('max')),'race':node.get('race','blood'),'speed':int(node.get('speed','100')),
              'flags':{'attackable':flags.get('attackable','1')=='1','hostile':flags.get('hostile','1')=='1','pushable':flags.get('pushable','1')=='1','targetDistance':1,'runHealth':0},
              'attacks':[{'name':'melee','interval':2000,'chance':100,'minDamage':0,'maxDamage':0}], 'loot':loot}
        source_monsters.append({'name':name,'hostile':info['flags']['hostile'],'health':info['health'],'outfit':info['outfit']['lookType']})
        # Existing seven definitions preserve their current D&D tuning.
        if name.lower() in ['rat','snake','spider','wolf','bug','orc','troll']:continue
        dest=data/'monsters'/('imported_'+file.stem.replace(' ','_')+'.lua')
        dest.write_text('local m=Game.createMonsterType('+lua(name)+')\nm:register('+lua(info)+')\n')
    for ident in sorted(needed):
        if ident in mapping and str(ident) not in report['items']:report['items'][str(ident)]=dict(mapping[ident],count=0)
    report['required_content_items']=sorted(needed);report['required_looktypes']=sorted(looks);report['source_monster_profiles']=source_monsters
    (STAGE/'extraction.json').write_text(json.dumps(report,indent=2))
    # Separate database ensures the test process cannot reset live online state.
    mdb=ROOT/'tools/mariadb-11.4.12-winx64/bin';cnf='--defaults-extra-file='+str(ROOT/'runtime/admin.cnf')
    flags=getattr(subprocess,'CREATE_NO_WINDOW',0)
    def sql(text):
        subprocess.run([str(mdb/'mariadb.exe'),cnf],input=text.encode(),capture_output=True,check=True,creationflags=flags)
    sql("CREATE DATABASE IF NOT EXISTS tibia5e_rookgaard_qa; GRANT ALL ON tibia5e_rookgaard_qa.* TO 'tibia5e'@'127.0.0.1';")
    dump=WORK/'qa-database.sql'
    with dump.open('wb') as out:
        subprocess.run([str(mdb/'mariadb-dump.exe'),cnf,'--single-transaction','--hex-blob','--skip-lock-tables','tibia5e_local'],stdout=out,stderr=subprocess.PIPE,check=True,creationflags=flags)
    sql('USE tibia5e_rookgaard_qa;\n'+dump.read_text(encoding='utf-8')+'\nDELETE FROM players_online; UPDATE players SET posx=32097,posy=32219,posz=7,town_id=1;')
    print('Prepared isolated server/DB,',len(report['npcs']),'NPC points and',len(source_monsters),'monster types. Live world unchanged.')

if __name__=='__main__':main()
