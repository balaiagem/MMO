"""Stop the web client crashing on items that have no graphics.

The live server item catalogue uses client ids up to ~40000, but the 8.60 assets
only have graphics up to ~11700. Item records left with 0 sprites/phases make
OTClient divide by zero ("remainder by zero") when the item is shown. This
rewrites every empty item record as a 1x1, 1-frame thing pointing at sprite 0
(transparent), keeping its flags. Run tools/repack-client.py afterwards.
"""
from pathlib import Path
import struct, shutil, importlib.util

ROOT = Path(__file__).resolve().parents[1]
THINGS = ROOT/'client/data/things/860'
spec = importlib.util.spec_from_file_location('cli', ROOT/'tools/import-client-items.py')
cli = importlib.util.module_from_spec(spec); spec.loader.exec_module(cli)

def main():
    dat = (THINGS/'Tibia.dat').read_bytes()
    maximum = struct.unpack_from('<H', dat, 4)[0]
    out, pos, fixed = [dat[:12]], 12, 0
    for cid in range(100, maximum + 1):
        start = pos
        (flags, geom, ids), pos = cli.read_thing(dat, pos, 4)
        if ids:
            out.append(dat[start:pos])
        else:
            out.append(flags + bytes([1, 1, 1, 1, 1, 1, 1]) + struct.pack('<I', 0)); fixed += 1
    out.append(dat[pos:])
    backup = ROOT/'runtime/client-assets-backup/Tibia.dat.before-placeholders'
    if not backup.exists(): shutil.copy2(THINGS/'Tibia.dat', backup)
    (THINGS/'Tibia.dat').write_bytes(b''.join(out))
    print(f'{fixed} registros vazios viraram placeholder transparente')

if __name__ == '__main__': main()
