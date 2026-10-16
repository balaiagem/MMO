"""Add only the 8.60 monster outfits to the local client asset package."""
from pathlib import Path
import importlib.util, io, json, struct
import numpy as np
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('installed_assets',ROOT/'tools/import-installed-assets.py')
module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
assets=module.Assets()
looktypes={5,15,21,27,28,30,45}

def skip_group(data,pos):
    width,height=data[pos],data[pos+1];pos+=2
    if width>1 or height>1:pos+=1
    layers,px,py,pz,phases=data[pos:pos+5];pos+=5
    return pos+4*width*height*layers*px*py*pz*phases

def read_outfit(data,pos):
    if data[pos]!=0xff:raise ValueError(f'Invalid outfit start at {pos}')
    kind=data[pos+1]
    if kind==1:return pos+10
    if kind!=2:raise ValueError(f'Unknown outfit kind {kind} at {pos}')
    pos+=3
    pos=skip_group(data,pos)
    if data[pos]==1:pos=skip_group(data,pos+1)
    return pos

def encode_sprite(image):
    width,height=image.size
    if width%32 or height%32 or width>64 or height>64:
        raise ValueError(f'Unsupported sprite dimensions {image.size}')
    encoded=[]
    for y in range(height-32,-1,-32):
        for x in range(width-32,-1,-32):
            tile=image.crop((x,y,x+32,y+32)).convert('RGBA')
            pixels=np.frombuffer(tile.tobytes(),dtype=np.uint8).reshape(-1,4)
            opaque=pixels[:,3]>=128
            boundaries=np.concatenate(([0],np.flatnonzero(opaque[1:]!=opaque[:-1])+1,[len(pixels)]))
            runs=bytearray()
            for start,end in zip(boundaries[:-1],boundaries[1:]):
                count=int(end-start)
                if opaque[start]:runs+=struct.pack('<HH',0,count)+pixels[start:end,:3].tobytes()
                else:runs+=struct.pack('<HH',count,0)
            encoded.append(b'\xff\x00\xff'+struct.pack('<H',len(runs))+runs)
    return encoded

def group_record(info,sprite_indices,sprite_dimensions,phase_limit=None):
    ids=list(info[5]);px,py,pz,layers=[info.get(i,[1])[0] for i in [1,2,3,4]]
    frame_size=px*py*pz*layers;phases=len(ids)//frame_size
    if phase_limit is not None:phases=min(phases,phase_limit);ids=ids[:frame_size*phases]
    assert phases>0 and len(ids)==frame_size*phases
    width=max(sprite_dimensions[i][0] for i in ids)//32
    height=max(sprite_dimensions[i][1] for i in ids)//32
    out=bytes([width,height])
    if width>1 or height>1:out+=bytes([max(width,height)*32])
    out+=bytes([layers,px,py,pz,phases])
    out+=b''.join(struct.pack('<I',index) for source in ids for index in sprite_indices[source])
    return out

def main():
    client=ROOT/'client/data/things/860';dat_path=client/'Tibia.dat';spr_path=client/'Tibia.spr'
    dat=dat_path.read_bytes();spr=spr_path.read_bytes()
    item_max,outfit_max,effect_max,missile_max=struct.unpack_from('<HHHH',dat,4)
    if outfit_max<max(looktypes):raise ValueError('The current DAT has no room for the selected monster looktypes')
    pos=12
    for _ in range(item_max-99):
        flags_end=dat.index(b'\xff',pos);pos=flags_end+1
        width,height,layers,px,py,pz,phases=dat[pos:pos+7];pos+=7
        pos+=4*width*height*layers*px*py*pz*phases
    item_end=pos;outfit_records=[];outfit_offsets={}
    for looktype in range(1,outfit_max+1):
        start=pos;pos=read_outfit(dat,pos);outfit_offsets[looktype]=len(outfit_records)
        outfit_records.append(dat[start:pos])
    outfit_end=pos;effect_records=[]
    for _ in range(effect_max):
        start=pos
        if dat[pos]!=0xff:raise ValueError(f'Invalid effect start at {pos}')
        pos=skip_group(dat,pos+1);effect_records.append(dat[start:pos])
    missile_records=[]
    for _ in range(missile_max):
        start=pos
        if dat[pos]!=0xff:raise ValueError(f'Invalid missile start at {pos}')
        pos=skip_group(dat,pos+1);missile_records.append(dat[start:pos])
    if pos!=len(dat):raise ValueError(f'DAT parser stopped at {pos}, expected {len(dat)}')

    new_records={};source_ids=set()
    for looktype in looktypes:
        appearance=assets.appearance(2,looktype);groups={}
        for raw in appearance.get(2,[]):
            group=module.fields(raw);group_id=group.get(1,[0])[0]
            groups[group_id]=module.fields(group[3][0])
        moving=groups.get(1) or groups.get(0);idle=groups.get(0)
        if moving is None:raise ValueError(f'Looktype {looktype} has no creature frames')
        if idle is None:
            idle={**moving,5:moving[5][:moving.get(1,[1])[0]*moving.get(2,[1])[0]*moving.get(3,[1])[0]*moving.get(4,[1])[0]]}
        for info in {id(idle):idle,id(moving):moving}.values():source_ids.update(info[5])
        new_records[looktype]=(idle,moving,1 in groups)

    spr_count=struct.unpack_from('<I',spr,4)[0]
    old_offsets=list(struct.unpack_from(f'<{spr_count}I',spr,8))
    sprite_indices={};sprite_dimensions={};sprite_chunks=[]
    for source_id in sorted(source_ids):
        sprite_indices[source_id]=[]
        image=assets.sprite(source_id);sprite_dimensions[source_id]=image.size
        for chunk in encode_sprite(image):
            sprite_indices[source_id].append(spr_count+len(sprite_chunks)+1);sprite_chunks.append(chunk)
    new_offsets=[];cursor=len(spr)+4*len(sprite_chunks)
    # The sprite table grows in place before sprite data, so all old offsets
    # shift by four bytes per appended sprite.
    shifted_old=[offset+4*len(sprite_chunks) if offset else 0 for offset in old_offsets]
    for chunk in sprite_chunks:new_offsets.append(cursor);cursor+=len(chunk)
    new_spr=struct.pack('<II',struct.unpack_from('<I',spr)[0],spr_count+len(sprite_chunks))
    new_spr+=struct.pack(f'<{len(shifted_old)+len(new_offsets)}I',*(shifted_old+new_offsets))+spr[8+4*spr_count:]+b''.join(sprite_chunks)

    for looktype,(idle,moving,has_moving) in new_records.items():
        record=b'\xff\x02\x00'+group_record(idle,sprite_indices,sprite_dimensions,1)
        record+=b'\x01'+group_record(moving,sprite_indices,sprite_dimensions) if has_moving else b'\x01'+group_record(idle,sprite_indices,sprite_dimensions,1)
        outfit_records[outfit_offsets[looktype]]=record
    # Keep every existing item/outfit/effect record and only replace selected
    # formerly empty outfit records.
    items=[];pos=12
    for _ in range(item_max-99):
        start=pos;pos=dat.index(b'\xff',pos)+1
        w,h,l,px,py,pz,ph=dat[pos:pos+7];pos+=7+4*w*h*l*px*py*pz*ph;items.append(dat[start:pos])
    new_dat=dat[:12]+b''.join(items+outfit_records+effect_records+missile_records)
    backup=ROOT/'runtime/assets-backup';backup.mkdir(exist_ok=True)
    for path in (dat_path,spr_path):
        saved=backup/path.name
        if not saved.exists():saved.write_bytes(path.read_bytes())
    dat_path.write_bytes(new_dat);spr_path.write_bytes(new_spr)
    report={'looktypes':sorted(looktypes),'addedSprites':len(sprite_chunks),'clientSpriteCount':spr_count+len(sprite_chunks)}
    (ROOT/'runtime/monster-assets-import.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(f'Imported {len(looktypes)} monster appearances and {len(sprite_chunks)} sprites; preserved the rest of the local Tibia assets.')

if __name__=='__main__':main()
