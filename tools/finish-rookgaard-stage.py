"""Apply explicit compatibility fixes to the isolated import only."""
from pathlib import Path
import json, xml.etree.ElementTree as ET, copy, importlib.util, struct, re
ROOT=Path(__file__).resolve().parents[1];WORK=ROOT/'runtime/rookgaard-import';DATA=WORK/'server/data'
spec=importlib.util.spec_from_file_location('stage',ROOT/'tools/stage-rookgaard-server.py');stage=importlib.util.module_from_spec(spec);spec.loader.exec_module(stage)
report=json.loads((WORK/'staged/extraction.json').read_text())
spec=importlib.util.spec_from_file_location('extract',ROOT/'tools/extract-rookgaard.py');extract=importlib.util.module_from_spec(spec);spec.loader.exec_module(extract)
mapping=extract.otb_items((WORK/'source/data/items/items.otb').read_bytes())
def native(ident):
    if ident==0:return 0
    if ident not in mapping:raise ValueError('Unknown source item '+str(ident))
    return report['items'].get(str(ident),{}).get('native',mapping[ident]['client'])
# Distinct legacy items can share art but have different behavior. Allocate
# separate wire IDs and duplicate the appearance, never merge their metadata.
otb=(WORK/'source/data/items/items.otb').read_bytes();otbroot,_=extract.parse(otb,4);otbnodes=[]
for kind,props,children in otbroot[2]:
    props=bytearray(props);pos=4;sid=None;offsets={}
    while pos<len(props):
        attr,size=struct.unpack_from('<BH',props,pos);pos+=3;offsets[attr]=pos
        if attr==16:sid=struct.unpack_from('<H',props,pos)[0]
        pos+=size
    if str(sid) not in report['items']:continue
    for attr in [16,17]:struct.pack_into('<H',props,offsets[attr],native(sid))
    otbnodes.append((kind,bytes(props),children))
(DATA/'items/items.otb').write_bytes(otb[:4]+extract.encode((otbroot[0],otbroot[1],otbnodes)))
# This TFS fork deliberately ignores legacy OTB server IDs. Translate every
# map item reference to its OTB client ID, leaving coordinates/AIDs/UIDs intact.
raw=(WORK/'staged/rookgaard.otbm').read_bytes();maproot,_=extract.parse(raw,4)
converted_items=0;converted_pvp_tiles=0
def translate(node):
    global converted_items,converted_pvp_tiles
    kind,props,children=node;props=bytearray(props)
    if kind==6:
        ident=struct.unpack_from('<H',props)[0];struct.pack_into('<H',props,0,native(ident));converted_items+=1
    elif kind in (5,14):
        pos=6 if kind==14 else 2
        while pos<len(props):
            attr=props[pos];pos+=1
            if attr==3:
                flags=struct.unpack_from('<I',props,pos)[0]
                if flags&4:struct.pack_into('<I',props,pos,flags&~4);converted_pvp_tiles+=1
                pos+=4
            elif attr==9:
                ident=struct.unpack_from('<H',props,pos)[0];struct.pack_into('<H',props,pos,native(ident));pos+=2;converted_items+=1
            else:raise ValueError('Unrecognized tile attribute')
    return kind,bytes(props),[translate(c) for c in children]
(DATA/'world/rookgaard.otbm').write_bytes(raw[:4]+extract.encode(translate(maproot)))
for p in (DATA/'npc/lib').rglob('*.lua'):
    text=p.read_text(encoding='utf-8',errors='replace')
    text=text.replace('for i, destination in pairs(module.destinations) do','for destinationIndex, destination in pairs(module.destinations) do\n local i=destinationIndex')
    p.write_text(text,encoding='utf-8')
# Preserve native item attributes only for the map and its content, avoiding
# unrelated modern duplicate definitions in the source's global item catalog.
needed={int(i) for i in report['items']};selected={}
for entry in ET.parse(WORK/'source/data/items/items.xml').getroot():
    first=int(entry.get('id',entry.get('fromid','0')));last=int(entry.get('toid',str(first)))
    for ident in needed.intersection(range(first,last+1)):
        if ident in selected:continue
        node=copy.deepcopy(entry);node.attrib.pop('fromid',None);node.attrib.pop('toid',None);node.set('id',str(native(ident)))
        for attr in node:
            if attr.get('key','').lower() in ['decayto','rotateto','transformequipto','transformdeequipto','transformto','destroyto','maletransformto','femaletransformto']:
                value=attr.get('value','0')
                if value.isdigit():attr.set('value',str(native(int(value))))
        selected[ident]=node
items=ET.Element('items')
for ident in sorted(selected):items.append(selected[ident])
ET.ElementTree(items).write(DATA/'items/items.xml',encoding='utf-8',xml_declaration=True)
tree=ET.parse(DATA/'world/rookgaard-spawn.xml');intervals=[]
for entry in tree.findall('.//monster'):
    value=int(entry.get('spawntime','0'))
    if value<10:intervals.append({'name':entry.get('name'),'original_seconds':value});entry.set('spawntime','10')
tree.write(DATA/'world/rookgaard-spawn.xml',encoding='utf-8',xml_declaration=True)
# New island creatures use explicit bounded 5e-style stat blocks. Existing
# Rat/Spider/Snake/Wolf/Bug/Orc/Troll rules remain owned by dnd_combat.lua.
# name: AC,DEX,attack,dice,sides,flat,speed,XP,HP
rows={
 'Cave Rat':(10,11,0,0,0,1,20,10,2),'Poison Spider':(12,14,4,1,4,1,20,25,5),
 'Wasp':(13,14,4,1,4,2,40,25,5),'Minotaur':(13,10,5,1,8,3,30,100,22),
 'Orc Spearman':(13,12,5,1,6,3,30,100,15),'Bear':(11,10,5,1,8,4,40,100,34),
 'Rabbit':(12,15,0,0,0,1,30,0,1),'Deer':(13,16,2,1,4,0,50,10,4),
 'Chicken':(10,10,0,0,0,1,20,0,1),'Sheep':(10,10,1,1,4,0,30,0,3),
 'Skeleton':(13,14,4,1,6,2,30,50,13),'Rotworm':(11,8,3,1,6,2,20,50,18),
 'Carrion Worm':(12,8,4,1,8,2,20,100,26),'Cyclops':(13,8,6,2,8,4,30,200,45),
 'Ghoul':(12,15,4,2,4,2,30,200,22),'Goblin':(15,14,4,1,6,2,30,50,7),
 'Minotaur Mage':(12,12,4,1,6,2,30,200,27),'Serpent Spawn':(15,14,7,2,6,4,30,450,75),
}
monsters={name:dict(zip(['ac','dex','attack','dice','sides','flat','speed','xp'],values[:8])) for name,values in rows.items()}
world={'groundIds':sorted({v.get('native',v['client']) for k,v in report['items'].items() if v['group']==1}),'protectionZoneRest':True,'spawn':[32097,32219,7],'monsters':monsters}
(DATA/'lib/dnd_world.lua').write_text('return '+stage.lua(world)+'\n')
(DATA/'scripts/dnd_combat.lua').write_bytes((ROOT/'world/content/dnd_combat.lua').read_bytes())
config=WORK/'server/config.lua';text=config.read_text()
if 'mapCacheMode="off"' not in text:text+='\nmapCacheMode="off"\n'
config.write_text(text)
(WORK/'staged/compatibility-report.json').write_text(json.dumps({'source_item_stacks_preserved_with_native_id_translation':True,'translated_item_instances':converted_items,'no_pvp_flags_removed_to_preserve_project_pvp':converted_pvp_tiles,'protection_zones_preserved':True,'items_xml_filtered_to_required_ids':len(selected),'spawn_interval_adjustments':intervals,'new_dnd_monster_profiles':list(monsters),'npc_library_lua55_fix':True,'map_cache_disabled':True},indent=2))
print('Staged compatibility: item metadata, NPC Lua 5.5, spawn timing, terrain reactions and D&D creature rules.')
