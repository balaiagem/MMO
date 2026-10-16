"""Encode original atlas + authored map into the actual OTClient/TFS 860 formats.

Format layout verified against client ThingType/SpriteManager and server itemloader/iomap.
This is asset conversion, not an alternate game renderer.
"""
from pathlib import Path
import struct as s
import json
import hashlib
from collections import deque
from PIL import Image
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
WORLD = json.loads((ROOT / 'world/rookgaard.json').read_text())
SYMBOLS = {'.':100, '=':101, '_':102, '#':103, '~':104, ':':110, '<':106, '>':107}
ITEMS = [
    (100, 'grass', 0), (101, 'cobblestones', 1), (102, 'plank floor', 2),
    (103, 'stone wall', 3), (104, 'deep water', 4), (106, 'stairs up', 6),
    (107, 'stairs down', 7), (110, 'earth path', 5),
]
u16 = lambda n: s.pack('<H', n)
u32 = lambda n: s.pack('<I', n)
string = lambda text: u16(len(text.encode())) + text.encode()

def node(kind, props=b'', children=()):
    escaped = b''.join((b'\xfd' if b >= 253 else b'') + bytes([b]) for b in props)
    return bytes([254,kind]) + escaped + b''.join(children) + b'\xff'

def validate_world():
    tiles = {}
    ox,oy = WORLD['origin']
    for z, rows in WORLD['floors'].items():
        assert len({len(row) for row in rows}) == 1, 'unequal row lengths'
        for y,row in enumerate(rows):
            for x, symbol in enumerate(row):
                assert symbol in SYMBOLS
                tiles[ox+x,oy+y,int(z)] = symbol
    links = {tuple(c['from']):tuple(c['to']) for c in WORLD['connections']}
    for source,target in links.items():
        assert tiles[source] in '<>' and tiles[target] not in '#~', 'invalid stair endpoint'
        assert target not in links, 'landing would immediately teleport again'
    spawn = tuple(WORLD['spawn'])
    assert tiles[spawn] not in '#~'
    visited = {spawn}; queue = deque([spawn])
    while queue:
        x,y,z=queue.popleft()
        for point in [(x+1,y,z),(x-1,y,z),(x,y+1,z),(x,y-1,z)]:
            if tiles.get(point,'#') in '#~': continue
            point=links.get(point,point)
            if point not in visited: visited.add(point); queue.append(point)
    for name,point in WORLD['landmarks'].items():
        assert tuple(point) in visited, f'unreachable landmark: {name}'
    for spawn in WORLD['spawns']:
        assert tuple(spawn['position']) in visited, f"unreachable spawn: {spawn['position']}"
    return tiles, len(visited)

def encode_spr(image):
    assert image.width == image.height
    size=image.width/4
    sprites=[]
    for y in range(4):
        for x in range(4):
            # Nearest-neighbor conversion to the native 32px sprite size.
            cell=image.crop(tuple(round(v*size) for v in (x,y,x+1,y+1))).resize((32,32), Image.Resampling.NEAREST).convert('RGBA')
            pixels=list(cell.getdata()); runs=bytearray(); i=0
            while i<len(pixels):
                clear=0; color=[]
                while i<len(pixels) and pixels[i][3]<128: clear+=1; i+=1
                while i<len(pixels) and pixels[i][3]>=128: color.extend(pixels[i][:3]); i+=1
                runs+=u16(clear)+u16(len(color)//3)+bytes(color)
            sprites.append(b'\xff\x00\xff'+u16(len(runs))+runs)
    offset=6+4*len(sprites); offsets=[]
    for sprite in sprites: offsets.append(u32(offset)); offset+=len(sprite)
    return u32(0x5E860001)+u16(len(sprites))+b''.join(offsets)+b''.join(sprites)

def thing(flags, sprites, directions=1):
    return flags+b'\xff'+bytes([1,1,1,directions,1,1,1])+b''.join(u16(i) for i in sprites)

def build():
    tiles,reachable=validate_world()
    atlas=ROOT/'assets/frontier-atlas.png'
    image=Image.open(atlas)
    client=ROOT/'client/data/things/860'; client.mkdir(parents=True,exist_ok=True)
    # TFS reserves item ID 105 for a poison field. Keep authored tiles in the
    # same protocol IDs except move the custom earth path to the free ID 110.
    dat=u32(0x5E860001)+s.pack('<HHHH',110,2,0,0)
    item_records={}
    otb=[]
    for item_id,name,sprite_index in sorted(ITEMS):
        blocking=item_id in (103,104)
        flags=b'\x00'+u16(150)+b'\x0d'+(b'\x0c\x0e\x0f' if blocking else b'')
        item_records[item_id]=thing(flags,[sprite_index+1])
        attrs=b''.join(bytes([key])+u16(2)+u16(value) for key,value in [(16,item_id),(17,item_id),(20,150)])
        otb.append(node(1,u32(7 if blocking else 0)+attrs))
    empty_thing=b'\xff'+bytes([1,1,1,1,1,1,0])
    for item_id in range(100,111):
        dat+=item_records.get(item_id,empty_thing)
    dat+=thing(b'',range(9,13),4)+thing(b'',range(13,17),4)
    (client/'Tibia.dat').write_bytes(dat)
    (client/'Tibia.spr').write_bytes(encode_spr(image))
    out=ROOT/'world/generated'; out.mkdir(exist_ok=True)
    version=u32(3)+u32(20)+u32(1)+b'Rookgaard-inspired original items'.ljust(128,b'\0')
    (out/'items.otb').write_bytes(b'OTBI'+node(0,u32(0)+b'\x01'+u16(len(version))+version,otb))
    groups=[]
    for z,rows in WORLD['floors'].items():
        tile_nodes=[]
        for (x,y,floor),symbol in tiles.items():
            if floor==int(z):
                ground=node(6,u16(SYMBOLS[symbol]))
                tile_nodes.append(node(5,bytes([x-100,y-100]),[ground]))
        groups.append(node(4,u16(100)+u16(100)+bytes([int(z)]),tile_nodes))
    town=node(13,u32(1)+string(WORLD['name'])+s.pack('<HHB',*WORLD['spawn']))
    groups.append(node(12,children=[town]))
    map_props=b'\x01'+string(WORLD['description'])
    map_props+=b'\x0b'+string('rookgaard-spawn.xml')+b'\x0d'+string('rookgaard-house.xml')
    root=node(0,s.pack('<IHHII',2,256,256,3,20),[node(2,map_props,groups)])
    (out/'rookgaard.otbm').write_bytes(b'OTBM'+root)
    xml='<items>\n'+''.join(f'  <item id="{item_id}" name="{name}"/>\n' for item_id,name,_ in sorted(ITEMS))+'</items>\n'
    (out/'items.xml').write_text(xml)
    spawn_xml=['<spawns>']
    for spawn in WORLD['spawns']:
        x,y,z=spawn['position']
        cx,cy,cz=spawn['center']
        spawn_xml.append(f'  <spawn centerx="{cx}" centery="{cy}" centerz="{cz}" radius="{spawn["radius"]}">')
        spawn_xml.append(f'    <monsters spawntime="{spawn["interval"]}"><monster name="{spawn["name"]}" x="{x-cx}" y="{y-cy}" z="0" /></monsters>')
        spawn_xml.append('  </spawn>')
    spawn_xml.append('</spawns>')
    (out/'rookgaard-spawn.xml').write_text('\n'.join(spawn_xml)+'\n')
    (out/'rookgaard-house.xml').write_text('<houses/>\n')
    installed_assets=Path.home()/'AppData/Local/Tibia/packages/Tibia/assets'
    if installed_assets.is_dir():
        subprocess.run([sys.executable,str(ROOT/'tools/import-installed-assets.py')],check=True)
    files=[client/'Tibia.dat',client/'Tibia.spr',out/'items.otb',out/'rookgaard.otbm',atlas]
    manifest={str(f.relative_to(ROOT)):hashlib.sha256(f.read_bytes()).hexdigest() for f in files}
    (out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    source='official local Tibia sprites' if installed_assets.is_dir() else 'original fallback sprites'
    print(f'Encoded Rookgaard with {source}, 8 map items, 2 outfits, {len(tiles)} tiles; {reachable} reachable positions and {len(WORLD["spawns"])} rat spawn points.')

if __name__=='__main__': build()
