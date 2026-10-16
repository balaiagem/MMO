"""Extract source tiles without changing item stacks or the running world."""
from pathlib import Path
from collections import Counter
import struct, json, hashlib, xml.etree.ElementTree as ET

ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'runtime/rookgaard-import/source/data'
OUT=ROOT/'runtime/rookgaard-import/staged'
BOUNDS=(31968,32000,32223,32319)

def header(data,pos):
    assert data[pos]==254
    kind=data[pos+1];pos+=2;props=bytearray()
    while data[pos] not in (254,255):
        value=data[pos];pos+=1
        if value==253:value=data[pos];pos+=1
        props.append(value)
    return kind,bytes(props),pos

def parse(data,pos):
    kind,props,pos=header(data,pos);children=[]
    while data[pos]==254:
        child,pos=parse(data,pos);children.append(child)
    assert data[pos]==255
    return (kind,props,children),pos+1

def encode(node):
    kind,props,children=node
    escaped=props.replace(b'\xfd',b'\xfd\xfd').replace(b'\xfe',b'\xfd\xfe').replace(b'\xff',b'\xfd\xff')
    return bytes([254,kind])+escaped+b''.join(encode(c) for c in children)+b'\xff'

def string(value):
    raw=value.encode();return struct.pack('<H',len(raw))+raw

def inside(x,y):
    return BOUNDS[0]<=x<=BOUNDS[2] and BOUNDS[1]<=y<=BOUNDS[3]

def otb_items(data):
    root,_=parse(data,4);result={}
    for kind,props,children in root[2]:
        flags=struct.unpack_from('<I',props)[0];pos=4;attrs={}
        while pos<len(props):
            attr,size=struct.unpack_from('<BH',props,pos);pos+=3
            attrs[attr]=props[pos:pos+size];pos+=size
        if 16 in attrs and 17 in attrs:
            sid=struct.unpack('<H',attrs[16])[0]
            result[sid]={'client':struct.unpack('<H',attrs[17])[0],'group':kind,'flags':flags}
    return result

def item_ids(node,counts):
    kind,props,children=node
    if kind==6:counts[struct.unpack_from('<H',props)[0]]+=1
    if kind in (5,14):
        pos=6 if kind==14 else 2
        while pos<len(props):
            attr=props[pos];pos+=1
            if attr==3:pos+=4
            elif attr==9:counts[struct.unpack_from('<H',props,pos)[0]]+=1;pos+=2
            else:raise ValueError(f'Unrecognized tile attribute {attr}')
    for child in children:item_ids(child,counts)

def main():
    OUT.mkdir(parents=True,exist_ok=True)
    data=(SOURCE/'world/global.otbm').read_bytes()
    rootkind,rootprops,pos=header(data,4)
    kind,props,pos=header(data,pos);assert kind==2
    areas=[];counts=Counter();floors=Counter();houses=set();positions=set()
    while data[pos]==254:
        child,pos=parse(data,pos)
        if child[0]!=4:continue
        x,y,z=struct.unpack('<HHB',child[1]);tiles=[]
        if x>BOUNDS[2] or y>BOUNDS[3] or x+255<BOUNDS[0] or y+255<BOUNDS[1]:continue
        for tile in child[2]:
            tx,ty=x+tile[1][0],y+tile[1][1]
            if not inside(tx,ty):continue
            assert (tx,ty,z) not in positions, f'Duplicate source tile {(tx,ty,z)}'
            positions.add((tx,ty,z));tiles.append(tile);floors[z]+=1;item_ids(tile,counts)
            if tile[0]==14:houses.add(struct.unpack_from('<I',tile[1],2)[0])
        if tiles:areas.append((4,child[1],tiles))
    town=(13,struct.pack('<I',1)+string('Rookgaard')+struct.pack('<HHB',32097,32219,7),[])
    areas.append((12,b'',[town]))
    mapprops=b'\x01'+string('Rookgaard extracted from source commit e4113537; tile stacks preserved')
    mapprops+=b'\x0b'+string('rookgaard-spawn.xml')+b'\x0d'+string('rookgaard-house.xml')
    output=b'OTBM'+encode((rootkind,rootprops,[(2,mapprops,areas)]))
    (OUT/'rookgaard.otbm').write_bytes(output)
    spawnroot=ET.parse(SOURCE/'world/global-spawn.xml').getroot();selected=ET.Element('spawns')
    npcs=[];monsters=Counter()
    for spawn in spawnroot:
        cx,cy,cz=[int(spawn.get(k,'0')) for k in ('centerx','centery','centerz')]
        kept=[]
        for entry in spawn:
            x,y=cx+int(entry.get('x','0')),cy+int(entry.get('y','0'))
            if inside(x,y):
                kept.append(entry)
                if entry.tag=='npc':npcs.append({'name':entry.get('name'),'position':[x,y,int(entry.get('z',cz))]})
                else:monsters[entry.get('name')]+=1
        if kept:
            copy=ET.SubElement(selected,'spawn',spawn.attrib)
            for entry in kept:copy.append(entry)
    ET.indent(selected);ET.ElementTree(selected).write(OUT/'rookgaard-spawn.xml',encoding='utf-8',xml_declaration=True)
    selectedhouses=ET.Element('houses')
    for house in ET.parse(SOURCE/'world/global-house.xml').getroot():
        if int(house.get('houseid','0')) in houses:selectedhouses.append(house)
    ET.ElementTree(selectedhouses).write(OUT/'rookgaard-house.xml',encoding='utf-8',xml_declaration=True)
    mapping=otb_items((SOURCE/'items/items.otb').read_bytes())
    missing=sorted(set(counts)-mapping.keys());assert not missing, f'Unknown source item IDs {missing}'
    report={'source_commit':'e4113537e25870336811c4131e379c2710348ae6','bounds':BOUNDS,'tiles':len(positions),'floors':dict(floors),'distinct_items':len(counts),'item_instances':sum(counts.values()),'items':{str(k):dict(mapping[k],count=v) for k,v in sorted(counts.items())},'npcs':npcs,'monsters':dict(monsters),'houses':sorted(houses),'map_sha256':hashlib.sha256(output).hexdigest(),'status':'staged; no live deployment'}
    (OUT/'extraction.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    print(json.dumps({k:v for k,v in report.items() if k not in ('items','npcs','monsters')},indent=2))
    print('NPCs:',npcs)

if __name__=='__main__':main()
