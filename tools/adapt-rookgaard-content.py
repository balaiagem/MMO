"""Translate legacy item references in curated Rookgaard content, not storages."""
from pathlib import Path
import json,re,xml.etree.ElementTree as ET,importlib.util,shutil
ROOT=Path(__file__).resolve().parents[1];WORK=ROOT/'runtime/rookgaard-import';SOURCE=WORK/'source';DATA=WORK/'server/data'
spec=importlib.util.spec_from_file_location('extract',ROOT/'tools/extract-rookgaard.py');extract=importlib.util.module_from_spec(spec);spec.loader.exec_module(extract)
mapping=extract.otb_items((SOURCE/'data/items/items.otb').read_bytes());report=json.loads((WORK/'staged/extraction.json').read_text());needed=set()
def ident(value):
    number=int(value)
    if number==0:return '0'
    if number not in mapping:raise ValueError('Unknown legacy item ID '+value)
    needed.add(number);return str(report['items'].get(str(number),{}).get('native',mapping[number]['client']))

def translate_lua(text,item_tables=False):
    # Positions, storages, AIDs and UIDs deliberately do not use this conversion.
    if item_tables:
        text=re.sub(r'\b\d{3,}\b',lambda m:ident(m[0]) if int(m[0]) in mapping and int(m[0])!=1000 else m[0],text)
        return text
    text=re.sub(r'((?:addItem|removeItem|getItemCount|getItemById|transform|ItemType|Item\.getItemType)\s*\(\s*)(\d+)',lambda m:m[1]+ident(m[2]),text)
    text=re.sub(r'((?:doCreateItem|doCreateItemEx)\s*\(\s*)(\d+)',lambda m:m[1]+ident(m[2]),text)
    text=re.sub(r'((?:doPlayerAddItem|doPlayerRemoveItem|getPlayerItemCount)\s*\([^,]+,\s*)(\d+)',lambda m:m[1]+ident(m[2]),text)
    text=re.sub(r'(\b(?:groundId|itemId|itemid|bridgeId|id)\s*=\s*)(\d+)',lambda m:m[1]+ident(m[2]),text)
    text=re.sub(r'((?:\.itemid|:getId\(\))\s*[~=]=\s*)(\d+)',lambda m:m[1]+ident(m[2]),text)
    return text

for file in (SOURCE/'data/npc').glob('*.xml'):
    tree=ET.parse(file)
    for node in tree.findall('./parameters/parameter'):
        if node.get('key','').startswith('shop_'):
            entries=[]
            for entry in node.get('value','').split(';'):
                values=entry.split(',')
                if len(values)>1 and values[1].isdigit():values[1]=ident(values[1])
                entries.append(','.join(values))
            node.set('value',';'.join(entries))
    tree.write(DATA/'npc'/file.name,encoding='utf-8',xml_declaration=True)
for file in (SOURCE/'data/npc/scripts').glob('*.lua'):
    (DATA/'npc/scripts'/file.name).write_text(translate_lua(file.read_text(encoding='utf-8',errors='replace')))

for file in (DATA/'monsters').glob('imported_*.lua'):
    text=file.read_text()
    text=re.sub(r'(\["id"\]=)(\d+)',lambda m:m[1]+ident(m[2]),text)
    name=re.search(r'createMonsterType\("([^"]+)"\)',text)[1]
    for source in (SOURCE/'data/monster').rglob('*.xml'):
        node=ET.parse(source).getroot()
        if node.get('name','').lower()==name.lower():
            look=node.find('look');corpse=int(look.get('corpse','0'))
            if corpse:text=text.replace('m:register({','m:register({["corpse"]='+ident(str(corpse))+',',1)
            break
    file.write_text(text)

libs=DATA/'lib/rookgaard';libs.mkdir(exist_ok=True)
for name in ['core/position.lua','core/storages.lua','compat/compat.lua']:
    shutil.copy2(SOURCE/'data/lib'/name,libs/Path(name).name)
    if name=='core/position.lua':
        p=libs/Path(name).name;text=p.read_text();text=text.replace('for direction = DIRECTION_NORTH, DIRECTION_NORTHEAST do','for directionIndex = DIRECTION_NORTH, DIRECTION_NORTHEAST do\n local direction=directionIndex');p.write_text(text)
sourceglobal=(SOURCE/'data/global.lua').read_text(encoding='utf-8',errors='replace')
tables=sourceglobal[sourceglobal.index('ropeSpots ='):sourceglobal.index('function getDistanceBetween')]
(libs/'item_tables.lua').write_text(translate_lua(tables,item_tables=True))
init='''-- Curated legacy content support; D&D rules remain authoritative.
if not table.contains then
 function table.contains(t,value) for _,entry in pairs(t) do if entry==value then return true end end return false end
end
if not table.maxn then
 function table.maxn(t) local n=0 for key in pairs(t) do if type(key)=="number" and key>n then n=key end end return n end
end
dofile('data/lib/rookgaard/position.lua')
dofile('data/lib/rookgaard/storages.lua')
dofile('data/lib/rookgaard/compat.lua')
dofile('data/lib/rookgaard/item_tables.lua')
'''
(DATA/'lib/lib.lua').write_text(init)
actions=json.loads((SOURCE/'actions-manifest.json').read_text());dest=DATA/'scripts/rookgaard_actions';dest.mkdir(exist_ok=True)
for index,(path,bindings) in enumerate(actions.items()):
    text=(SOURCE/path).read_text(encoding='utf-8',errors='replace')
    text=translate_lua(text,item_tables=('/tools/' in path.lower() or path.lower().endswith('/doors.lua')))
    if not re.search(r'function\s+onUse\s*\(',text):raise ValueError('No callback in '+path)
    result='do\nlocal onUse\n'+text+'\nlocal importedAction=Action()\n'
    if re.search(r'function\s+onUse\s*\(cid\s*,',text):result+='importedAction:onUse(function(player,...) return onUse(player:getId(),...) end)\n'
    else:result+='importedAction:onUse(onUse)\n'
    for key,method in [('ids','id'),('aids','aid'),('uids','uid')]:
        values=[int(ident(str(v))) if key=='ids' else v for v in bindings[key]]
        if values:result+='importedAction:'+method+'('+','.join(map(str,sorted(set(values))))+')\n'
    result+='importedAction:register()\nend\n'
    (dest/(str(index)+'_'+Path(path).name)).write_text(result)

# Include dynamic quest/door transformation targets in metadata/art coverage.
source_items={}
for node in ET.parse(SOURCE/'data/items/items.xml').getroot():
    first=int(node.get('id',node.get('fromid','0')));last=int(node.get('toid',str(first)))
    for i in range(first,last+1):source_items.setdefault(i,node)
needed.update(int(i) for i in report['items'])
for _ in range(4):
    for i in list(needed):
        node=source_items.get(i)
        if node is None:continue
        for attr in node:
            if attr.get('key','').lower() in ['decayto','rotateto','transformequipto','transformdeequipto','transformto','destroyto','maletransformto','femaletransformto']:
                value=attr.get('value','0')
                if value.isdigit() and int(value) in mapping:needed.add(int(value))
for i in needed:
    if str(i) not in report['items']:report['items'][str(i)]=dict(mapping[i],count=0)
(WORK/'staged/extraction.json').write_text(json.dumps(report,indent=2))
print('Adapted native item IDs in',len(actions),'source actions, NPC trades/scripts, loot and corpse references; storages/coordinates retained.')
