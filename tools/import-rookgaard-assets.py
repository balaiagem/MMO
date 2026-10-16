"""Stage map item sprites while retaining the project's outfits/effects/UI."""
from pathlib import Path
import struct, json, importlib.util
ROOT=Path(__file__).resolve().parents[1]
STAGE=ROOT/'runtime/rookgaard-import/staged'
def module(name,path):
    spec=importlib.util.spec_from_file_location(name,path);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
assetslib=module('installed',ROOT/'tools/import-installed-assets.py')
spritecode=module('monsterassets',ROOT/'tools/import-monster-assets.py')
u16=lambda x:struct.pack('<H',x)
u32=lambda x:struct.pack('<I',x)

def read_thing(data,pos,indexbytes):
    start=pos
    sizes={0:2,8:2,9:2,21:4,24:4,25:2,28:2,29:2,32:2}
    while data[pos]!=255:
        flag=data[pos];pos+=1
        if flag>32:raise ValueError(f'Unknown classic flag {flag}')
        pos+=sizes.get(flag,0)
    pos+=1;flags=data[start:pos];start=pos
    w,h=data[pos:pos+2];pos+=2
    if w>1 or h>1:pos+=1
    layers,x,y,z,phases=data[pos:pos+5];pos+=5
    geom=data[start:pos];count=w*h*layers*x*y*z*phases
    ids=struct.unpack_from('<'+('H' if indexbytes==2 else 'I')*count,data,pos)
    return (flags,geom,ids),pos+indexbytes*count

def modern_flags(appearance):
    f=assetslib.fields(appearance.get(3,[b''])[0]);out=bytearray()
    for proto,attr in [(2,1),(3,2),(4,3),(5,4),(6,5),(8,6),(9,7),(19,10),(12,11),(13,12),(14,13),(15,14),(16,15),(18,16),(20,17),(22,20),(24,22),(25,23),(28,26),(29,27),(32,30),(33,31)]:
        if f.get(proto,[0])[0]:out.append(attr)
    for proto,attr,keys in [(1,0,[1]),(10,8,[1]),(11,9,[1]),(23,21,[1,2]),(26,24,[1,2]),(27,25,[1]),(30,28,[1]),(31,29,[1]),(34,32,[1])]:
        if proto in f:
            sub=assetslib.fields(f[proto][0]);out.append(attr)
            for key in keys:out.extend(u16(sub.get(key,[0])[0]))
    # Hook direction is encoded by the classic south/east flags.
    if 21 in f:
        hook=assetslib.fields(f[21][0])
        if hook.get(1,[0])[0]:out.append(18)
        if hook.get(2,[0])[0]:out.append(19)
    return bytes(out)+b'\xff'

def server_subtype_flags(record,metadata):
    # Current CIP assets made some formerly unstackable objects stackable.
    # The wire protocol must follow the source OTB subtype flags exactly.
    (flags,geom,ids),_=read_thing(record,0,4)
    sizes={0:2,8:2,9:2,21:4,24:4,25:2,28:2,29:2,32:2}
    out=bytearray();pos=0
    while flags[pos]!=255:
        attr=flags[pos];size=1+sizes.get(attr,0)
        if attr not in (4,5,10,11):out.extend(flags[pos:pos+size])
        pos+=size
    if metadata['group']==2:out.append(4)
    if metadata['flags']&128:out.append(5)
    if metadata['group']==12:out.append(10)
    if metadata['group']==11:out.append(11)
    return bytes(out)+b'\xff'+geom+b''.join(map(u32,ids))

def main():
    report=json.loads((STAGE/'extraction.json').read_text())
    required={v['client'] for v in report['items'].values()}
    assets=assetslib.Assets();objects={assetslib.fields(v)[1][0]:assetslib.fields(v) for v in assets.appearances[1]}
    dat=(ROOT/'client/data/things/860/Tibia.dat').read_bytes();spr=(ROOT/'client/data/things/860/Tibia.spr').read_bytes()
    oldmax,outfits,effects,missiles=struct.unpack_from('<HHHH',dat,4)
    pos=12
    for _ in range(100,oldmax+1):_,pos=read_thing(dat,pos,4)
    tail=dat[pos:]
    outfit_records=[];outfit_pos=pos
    for _ in range(outfits):
        end=spritecode.read_outfit(dat,outfit_pos);outfit_records.append(dat[outfit_pos:end]);outfit_pos=end
    effect_tail=dat[outfit_pos:]
    outfit_appearances={assetslib.fields(v)[1][0]:assetslib.fields(v) for v in assets.appearances[2]}
    missing_outfits={ident:outfit_appearances[ident] for ident in report.get('required_looktypes',[]) if ident>0 and len(outfit_records[ident-1])==10}
    classic=(ROOT/'runtime/rookgaard-import/classic-assets/Tibia.dat').read_bytes()
    classicspr=(ROOT/'runtime/rookgaard-import/classic-assets/Tibia.spr').read_bytes()
    classicmax=struct.unpack_from('<H',classic,4)[0];classics={};pos=12
    for cid in range(100,classicmax+1):
        record,pos=read_thing(classic,pos,2)
        if cid in required and cid not in objects:classics[cid]=record
    assert not required-objects.keys()-classics.keys(), 'Missing exact item appearances'
    infos={};sourceids=set()
    for cid in sorted(required & objects.keys()):
        info=assetslib.fields(assetslib.fields(objects[cid][2][0])[3][0]);infos[cid]=info;sourceids.update(info[5])
    for appearance in missing_outfits.values():
        for raw in appearance.get(2,[]):sourceids.update(assetslib.fields(assetslib.fields(raw)[3][0])[5])
    oldcount=struct.unpack_from('<I',spr,4)[0];packets=[];indices={};dimensions={}
    for sid in sorted(sourceids):
        image=assets.sprite(sid);dimensions[sid]=image.size
        encoded=spritecode.encode_sprite(image)
        indices[sid]=list(range(oldcount+len(packets)+1,oldcount+len(packets)+len(encoded)+1));packets.extend(encoded)
    records={cid:modern_flags(objects[cid])+spritecode.group_record(info,indices,dimensions) for cid,info in infos.items()}
    for ident,appearance in missing_outfits.items():
        groups={}
        for raw in appearance[2]:
            group=assetslib.fields(raw);groups[group.get(1,[0])[0]]=assetslib.fields(group[3][0])
        moving=groups.get(1) or groups.get(0);idle=groups.get(0) or moving
        record=b'\xff\x02\x00'+spritecode.group_record(idle,indices,dimensions,phase_limit=1)
        record+=b'\x01'+spritecode.group_record(moving,indices,dimensions)
        outfit_records[ident-1]=record
    tail=b''.join(outfit_records)+effect_tail
    for cid,(flags,geom,ids) in classics.items():
        converted=[]
        for sid in ids:
            if sid==0:converted.append(0);continue
            offset=struct.unpack_from('<I',classicspr,6+(sid-1)*4)[0]
            if not offset:converted.append(0);continue
            size=struct.unpack_from('<H',classicspr,offset+3)[0]
            converted.append(oldcount+len(packets)+1);packets.append(classicspr[offset:offset+5+size])
        records[cid]=flags+geom+b''.join(map(u32,converted))
    wire_records={v.get('native',v['client']):server_subtype_flags(records[v['client']],v) for v in report['items'].values()}
    empty=b'\xff'+bytes([1,1,1,1,1,1,0]);maximum=max(wire_records)
    output=dat[:4]+struct.pack('<HHHH',maximum,outfits,effects,missiles)+b''.join(wire_records.get(cid,empty) for cid in range(100,maximum+1))+tail
    destination=STAGE/'client';destination.mkdir(exist_ok=True)
    (destination/'Tibia.dat').write_bytes(output)
    oldoffsets=struct.unpack_from('<'+'I'*oldcount,spr,8);delta=4*len(packets)
    offsets=[v+delta if v else 0 for v in oldoffsets]
    offset=len(spr)+delta
    for packet in packets:offsets.append(offset);offset+=len(packet)
    (destination/'Tibia.spr').write_bytes(spr[:4]+u32(len(offsets))+b''.join(map(u32,offsets))+spr[8+4*oldcount:]+b''.join(packets))
    summary={'map_client_ids':len(required),'max_client_id':maximum,'classic_fallbacks':sorted(classics),'appended_sprites':len(packets),'added_outfit_looktypes':sorted(missing_outfits),'preserved_existing_outfits_and_effects':True}
    (STAGE/'assets-report.json').write_text(json.dumps(summary,indent=2));print(summary)

if __name__=='__main__':main()
