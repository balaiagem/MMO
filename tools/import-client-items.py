"""Give the web client graphics for every item the server knows.

The Rookgaard asset import only staged the ~1300 items placed on the map; every
other item id was written to Tibia.dat as an empty record (0 animation phases),
which crashes the client ("remainder by zero") as soon as such an item is shown.

This fills each empty item record that exists in the classic 8.60 assets
(runtime/rookgaard-import/classic-assets) and appends its sprites to Tibia.spr,
using the same conversion as tools/import-rookgaard-assets.py. Records that are
already filled (map items, outfits, effects, missiles) are left untouched.
Backups of the previous files go to runtime/client-assets-backup/.
"""
from pathlib import Path
import struct, shutil, importlib.util

ROOT = Path(__file__).resolve().parents[1]
THINGS = ROOT/'client/data/things/860'
CLASSIC = ROOT/'runtime/rookgaard-import/classic-assets'
SIZES = {0: 2, 8: 2, 9: 2, 21: 4, 24: 4, 25: 2, 28: 2, 29: 2, 32: 2}
u32 = lambda x: struct.pack('<I', x)


def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m); return m


def read_thing(data, pos, indexbytes):
    start = pos
    while data[pos] != 255:
        flag = data[pos]; pos += 1
        if flag > 32: raise ValueError(f'Unknown flag {flag}')
        pos += SIZES.get(flag, 0)
    pos += 1; flags = data[start:pos]; start = pos
    w, h = data[pos:pos+2]; pos += 2
    if w > 1 or h > 1: pos += 1
    layers, x, y, z, phases = data[pos:pos+5]; pos += 5
    geom = data[start:pos]; count = w*h*layers*x*y*z*phases
    ids = struct.unpack_from('<' + ('H' if indexbytes == 2 else 'I')*count, data, pos)
    return (flags, geom, ids), pos + indexbytes*count


def subtype_flags(flags, group, otbflags):
    """Same rule as import-rookgaard-assets: stackable/fluid/splash follow the OTB."""
    out = bytearray(); pos = 0
    while flags[pos] != 255:
        attr = flags[pos]; size = 1 + SIZES.get(attr, 0)
        if attr not in (4, 5, 10, 11): out.extend(flags[pos:pos+size])
        pos += size
    if group == 2: out.append(4)
    if otbflags & 128: out.append(5)
    if group == 12: out.append(10)
    if group == 11: out.append(11)
    return bytes(out) + b'\xff'


def main():
    imp = module('imp', ROOT/'tools/import-all-items.py')
    otb, owner = imp.owner_map()
    meta = imp.extract.otb_items(otb)
    server = {native: meta[sid] for sid, native in owner.items()}      # client id -> otb metadata

    dat = (THINGS/'Tibia.dat').read_bytes(); spr = (THINGS/'Tibia.spr').read_bytes()
    classic = (CLASSIC/'Tibia.dat').read_bytes(); classicspr = (CLASSIC/'Tibia.spr').read_bytes()
    maximum, outfits, effects, missiles = struct.unpack_from('<HHHH', dat, 4)
    records, pos = {}, 12
    for cid in range(100, maximum + 1):
        start = pos; (_, _, ids), pos = read_thing(dat, pos, 4); records[cid] = (dat[start:pos], len(ids))
    tail = dat[pos:]
    classicmax = struct.unpack_from('<H', classic, 4)[0]; cpos = 12; classics = {}
    for cid in range(100, classicmax + 1):
        record, cpos = read_thing(classic, cpos, 2); classics[cid] = record

    oldcount = struct.unpack_from('<I', spr, 4)[0]; packets = []; filled = []
    for cid in range(100, min(maximum, classicmax) + 1):
        if records[cid][1] > 0 or cid not in server or cid not in classics: continue
        flags, geom, ids = classics[cid]
        if not ids or not any(ids): continue
        converted = []
        for sid in ids:
            offset = struct.unpack_from('<I', classicspr, 6 + (sid-1)*4)[0] if sid else 0
            if not offset: converted.append(0); continue
            size = struct.unpack_from('<H', classicspr, offset + 3)[0]
            converted.append(oldcount + len(packets) + 1); packets.append(classicspr[offset:offset+5+size])
        group, otbflags = server[cid]['group'], server[cid]['flags']
        records[cid] = (subtype_flags(flags, group, otbflags) + geom + b''.join(map(u32, converted)), len(ids))
        filled.append(cid)

    backup = ROOT/'runtime/client-assets-backup'
    if not backup.exists():
        backup.mkdir(parents=True)
        for name in ('Tibia.dat', 'Tibia.spr'): shutil.copy2(THINGS/name, backup/name)
    out_dat = dat[:12] + b''.join(records[cid][0] for cid in range(100, maximum + 1)) + tail
    oldoffsets = struct.unpack_from('<' + 'I'*oldcount, spr, 8); delta = 4*len(packets)
    offsets = [v + delta if v else 0 for v in oldoffsets]
    offset = len(spr) + delta
    for packet in packets: offsets.append(offset); offset += len(packet)
    out_spr = spr[:4] + u32(len(offsets)) + b''.join(map(u32, offsets)) + spr[8+4*oldcount:] + b''.join(packets)
    (THINGS/'Tibia.dat').write_bytes(out_dat); (THINGS/'Tibia.spr').write_bytes(out_spr)
    print(f'{len(filled)} itens ganharam grafico; {len(packets)} sprites adicionados')
    return filled


if __name__ == '__main__': main()
