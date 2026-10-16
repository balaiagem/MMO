"""Read the user's installed assets without modifying the Tibia installation.

The protobuf wire reader skips unknown fields; field numbers come from
client/src/protobuf/appearances.proto. Imported pixels stay local/ignored.
"""
from pathlib import Path
import json, lzma, struct, io, hashlib
from bisect import bisect_right
import xml.etree.ElementTree as ET
from PIL import Image
import numpy as np

SOURCE=Path.home()/'AppData/Local/Tibia/packages/Tibia/assets'
ROOT=Path(__file__).resolve().parents[1]

def varint(data, pos):
    value=shift=0
    while True:
        b=data[pos]; pos+=1; value|=(b&127)<<shift
        if b<128: return value,pos
        shift+=7
        if shift>63: raise ValueError('Invalid protobuf varint')

def fields(data):
    result={}; pos=0
    while pos<len(data):
        key,pos=varint(data,pos); kind=key&7; number=key>>3
        if kind==0: value,pos=varint(data,pos)
        elif kind==2:
            size,pos=varint(data,pos); value=data[pos:pos+size]; pos+=size
        elif kind in (1,5):
            size=8 if kind==1 else 4; value=data[pos:pos+size]; pos+=size
        else: raise ValueError(f'Unsupported protobuf wire type {kind}')
        result.setdefault(number,[]).append(value)
    return result

class Assets:
    def __init__(self):
        self.catalog=json.loads((SOURCE/'catalog-content.json').read_text())
        entry=next(e for e in self.catalog if e['type']=='appearances')
        self.appearances=fields((SOURCE/entry['file']).read_bytes())
        self.sheets=sorted((e for e in self.catalog if e['type']=='sprite'), key=lambda e:e['firstspriteid'])
        self.sheet_starts=[e['firstspriteid'] for e in self.sheets]
        self.cache={}

    def appearance(self, category, ident):
        return next(a for raw in self.appearances[category] if (a:=fields(raw))[1][0]==ident)

    def sprite(self, ident):
        index=bisect_right(self.sheet_starts,ident)-1
        if index<0 or ident>self.sheets[index]['lastspriteid']:
            raise KeyError(f'No installed sprite sheet contains sprite {ident}')
        sheet=self.sheets[index]
        name=sheet['file']
        if name not in self.cache:
            # Import sprites in ascending source-ID order so only one decoded
            # atlas needs to stay resident at a time.
            self.cache.clear()
            raw=(SOURCE/name).read_bytes()
            # The 32-byte CIP wrapper precedes an LZMA-alone header.
            prop=raw[32]; dictionary=struct.unpack_from('<I',raw,33)[0]
            decoder=lzma.LZMADecompressor(format=lzma.FORMAT_RAW,filters=[dict(id=lzma.FILTER_LZMA1,dict_size=dictionary,lc=prop%9,lp=(prop//9)%5,pb=prop//45)])
            bmp=decoder.decompress(raw[45:])
            im=Image.open(io.BytesIO(bmp)).convert('RGBA')
            pixels=np.frombuffer(im.tobytes(),dtype=np.uint8).reshape(-1,4).copy()
            pixels[np.all(pixels[:,:3]==255,axis=1),3]=0
            im=Image.frombytes('RGBA',im.size,pixels.tobytes())
            self.cache[name]=im
        sizes=[(32,32),(32,64),(64,32),(64,64)]
        layout=sheet['spritetype']
        if layout>=len(sizes): raise ValueError(f'Unsupported sprite layout {layout}')
        w,h=sizes[layout]; index=ident-sheet['firstspriteid']; cols=384//w
        x=(index%cols)*w; y=(index//cols)*h
        return self.cache[name].crop((x,y,x+w,y+h))

def convert():
    assets=Assets(); sprites=[]; sprite_indices={}; sprite_dimensions={}
    u16=lambda v:struct.pack('<H',v)
    u32=lambda v:struct.pack('<I',v)
    # The earth-path ID is 110 because TFS reserves 105 for its poison field.
    # 412 is the upward wooden staircase; 414 is the open hole used to go down.
    mappings=[(100,1,106),(101,1,416),(102,1,408),(103,1,384),(104,1,622),
              (106,1,412),(107,1,414),(110,1,103)]
    item_records={}; outfit_records={}
    max_item_id=0; max_outfit_id=0
    def encode_sprite(source_id):
        im=assets.sprite(source_id)
        width,height=im.size
        if width%32 or height%32 or width>64 or height>64:
            raise ValueError(f'Unsupported installed sprite dimensions {im.size} for {source_id}')
        sprite_dimensions[source_id]=(width,height)
        # Classic DATs express a large creature frame as adjacent 32px tiles.
        # Keep the installed pixels at full size and split each frame in the
        # same row-major order expected by the 8.60 renderer.
        indices=[]
        # DAT stores a multi-tile frame from its bottom-right tile toward the
        # top-left; ThingType reassembles them in the opposite direction.
        for y in range(height-32,-1,-32):
            for x in range(width-32,-1,-32):
                tile=im.crop((x,y,x+32,y+32))
                pixels=np.frombuffer(tile.tobytes(),dtype=np.uint8).reshape(-1,4)
                opaque=pixels[:,3]>=128
                boundaries=np.concatenate(([0],np.flatnonzero(opaque[1:]!=opaque[:-1])+1,[len(pixels)]))
                runs=bytearray()
                for start,end in zip(boundaries[:-1],boundaries[1:]):
                    count=int(end-start)
                    if opaque[start]:
                        runs+=u16(0)+u16(count)+pixels[start:end,:3].tobytes()
                    else:
                        runs+=u16(count)+u16(0)
                indices.append(len(sprites)+1)
                sprites.append(b'\xff\x00\xff'+u16(len(runs))+runs)
        sprite_indices[source_id]=indices

    def sprite_index(source_id):
        return sprite_indices[source_id]

    def group_record(info, keep_all=True, phase_limit=None):
        ids=list(info[5])
        px,py,pz,layers=[info.get(i,[1])[0] for i in [1,2,3,4]]
        frame_size=px*py*pz*layers
        phases=len(ids)//frame_size
        assert phases>0 and len(ids)==frame_size*phases
        if phase_limit is not None:
            phases=min(phases,phase_limit); ids=ids[:frame_size*phases]
        width=max(sprite_dimensions[i][0] for i in ids)//32
        height=max(sprite_dimensions[i][1] for i in ids)//32
        indices=[index for source_id in ids for index in sprite_index(source_id)]
        record=bytes([width,height])
        if width>1 or height>1: record+=bytes([max(width,height)*32])
        record+=bytes([layers,px,py,pz,phases])+b''.join(map(u32,indices))
        return record

    appearances={fields(raw)[1][0]:fields(raw) for raw in assets.appearances[2]}
    effects={fields(raw)[1][0]:fields(raw) for raw in assets.appearances.get(3,[])}
    missiles={fields(raw)[1][0]:fields(raw) for raw in assets.appearances.get(4,[])}
    aliases={1:128,2:21}
    # Monster looktypes used by the local 8.60 world/combat roster. The source
    # appearance IDs come from the user's installed Tibia assets, kept local.
    monster_looktypes={5,15,21,27,28,30,45}
    outfit_xml=ET.parse(ROOT/'server/data/XML/outfits.xml').getroot()
    outfit_ids={int(node.attrib['looktype']) for node in outfit_xml.findall('outfit') if 'looktype' in node.attrib}
    missing=sorted(outfit_ids-appearances.keys())
    if missing: raise ValueError(f'Installed client assets lack server outfit looktypes: {missing}')
    appearances={ident:appearances[ident] for ident in outfit_ids | set(aliases.values()) | monster_looktypes}
    item_infos={}
    source_sprite_ids=set()
    for thing_id,category,ident in mappings:
        appearance=assets.appearance(category,ident)
        frame=fields(appearance[2][0]); info=fields(frame[3][0])
        # Terrain is a single-tile item; use the first variant only.
        ids=info[5][:1]
        item_infos[thing_id]=ids
        source_sprite_ids.update(ids)

    for appearance in appearances.values():
        for raw in appearance.get(2,[]):
            group=fields(raw)
            source_sprite_ids.update(fields(group[3][0])[5])
    for appearance in [*effects.values(),*missiles.values()]:
        for raw in appearance.get(2,[]):
            group=fields(raw)
            source_sprite_ids.update(fields(group[3][0])[5])

    # Sort source IDs so each packed atlas is decoded only once.
    for source_id in sorted(source_sprite_ids):
        encode_sprite(source_id)

    for thing_id,ids in item_infos.items():
        width=max(sprite_dimensions[i][0] for i in ids)//32
        height=max(sprite_dimensions[i][1] for i in ids)//32
        assert (width,height)==(1,1), f'Terrain item {thing_id} must be one tile'
        indices=[index for source_id in ids for index in sprite_index(source_id)]
        flags=(b'\x00'+u16(150)+b'\x0d'+(b'\x0c\x0e\x0f' if thing_id in (103,104) else b''))
        record=flags+b'\xff'+bytes([1,1,1,1,1,1,1])+b''.join(map(u32,indices))
        item_records[thing_id]=record
        max_item_id=max(max_item_id,thing_id)

    # Import every installed creature/outfit appearance at its native client
    # looktype. Keep the existing local player and rat aliases for the world.
    for outfit_id,appearance in appearances.items():
        groups={}
        for raw in appearance.get(2,[]):
            group=fields(raw); group_type=group.get(1,[0])[0]
            groups[group_type]=fields(group[3][0])
        moving=groups.get(1) or groups.get(0)
        idle=groups.get(0)
        if moving is None: continue
        if idle is None:
            # Some installed creatures contain no idle group. Use their first
            # frame as a stable standing pose.
            idle=fields(b'')
            idle.update(moving)
            idle[5]=moving[5][:moving.get(1,[1])[0]*moving.get(2,[1])[0]*moving.get(3,[1])[0]*moving.get(4,[1])[0]]
        record=b'\xff\x02\x00'+group_record(idle,phase_limit=1)
        if 1 in groups:
            record+=b'\x01'+group_record(moving)
        else:
            # An appearance without movement remains still when walking.
            record+=b'\x01'+group_record(idle,phase_limit=1)
        outfit_records[outfit_id]=record
        max_outfit_id=max(max_outfit_id,outfit_id)
    for alias,source_id in aliases.items():
        outfit_records[alias]=outfit_records[source_id]
        max_outfit_id=max(max_outfit_id,alias)
    effect_records={ident:b'\xff'+group_record(fields(fields(appearance[2][0])[3][0])) for ident,appearance in effects.items() if ident>0}
    missile_records={ident:b'\xff'+group_record(fields(fields(appearance[2][0])[3][0])) for ident,appearance in missiles.items() if ident>0}
    max_effect_id=max(effect_records,default=0); max_missile_id=max(missile_records,default=0)
    empty_thing=b'\xff'+bytes([1,1,1,1,1,1,0])
    empty_outfit=b'\xff\x01\x00'+bytes([1,1,1,1,1,1,0])
    records=[item_records.get(thing_id,empty_thing) for thing_id in range(100,max_item_id+1)]
    records.extend(outfit_records.get(looktype,empty_outfit) for looktype in range(1,max_outfit_id+1))
    records.extend(effect_records.get(ident,empty_thing) for ident in range(1,max_effect_id+1))
    records.extend(missile_records.get(ident,empty_thing) for ident in range(1,max_missile_id+1))
    destination=ROOT/'client/data/things/860'
    backup=ROOT/'runtime/assets-backup'; backup.mkdir(exist_ok=True)
    for name in ['Tibia.dat','Tibia.spr']:
        if not (backup/name).exists(): (backup/name).write_bytes((destination/name).read_bytes())
    # In this DAT format counts are highest IDs; item IDs start at 100.
    dat=u32(0x5E860002)+struct.pack('<HHHH',max_item_id,max_outfit_id,max_effect_id,max_missile_id)+b''.join(records)
    offset=8+4*len(sprites); offsets=[]
    for sprite in sprites: offsets.append(u32(offset)); offset+=len(sprite)
    spr=u32(0x5E860002)+u32(len(sprites))+b''.join(offsets)+b''.join(sprites)
    (destination/'Tibia.dat').write_bytes(dat); (destination/'Tibia.spr').write_bytes(spr)
    report={'source':str(SOURCE),'mappings':mappings,'outfits':len(outfit_ids),'monsterLooktypes':sorted(monster_looktypes),'looktypes':max_outfit_id,'effects':max_effect_id,'missiles':max_missile_id,'sprites':len(sprites),'sha256':{n:hashlib.sha256(b).hexdigest() for n,b in [('Tibia.dat',dat),('Tibia.spr',spr)]}}
    (ROOT/'runtime/imported-assets.json').write_text(json.dumps(report,indent=2))
    print(f'Converted 8 map items, {len(outfit_ids)} playable outfits, effects and missiles ({len(sprites)} deduplicated native sprites); installation unchanged.')

if __name__=='__main__': convert()
