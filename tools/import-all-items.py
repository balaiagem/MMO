"""Import the full 8.60 item catalogue into the live server.

The Rookgaard import kept only the ~1300 items placed on the map. This builds
items.otb/items.xml from the whole source catalogue using the same rules:
items keep their client (wire) ID, map items keep the IDs they already have,
and when two legacy items share one appearance only the first one is kept so
no ID is defined twice. The previous files are backed up first.
"""
from pathlib import Path
import json, copy, struct, shutil, importlib.util, xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT / 'runtime/rookgaard-import'
LIVE = ROOT / 'runtime/server/data/items'
spec = importlib.util.spec_from_file_location('extract', ROOT / 'tools/extract-rookgaard.py')
extract = importlib.util.module_from_spec(spec); spec.loader.exec_module(extract)

REF_KEYS = {'decayto','rotateto','transformequipto','transformdeequipto','transformto',
            'destroyto','maletransformto','femaletransformto'}

def owner_map():
    """Legacy server id -> live (client) id for every item that is imported."""
    otb = (WORK/'source/data/items/items.otb').read_bytes()
    mapping = extract.otb_items(otb)
    report = json.loads((WORK/'staged/extraction.json').read_text())['items']
    def native(sid):
        entry = report.get(str(sid))
        if entry and 'native' in entry: return entry['native']
        return mapping[sid]['client']
    # Priority: items already on the map, then the rest by legacy ID.
    order = sorted((int(s) for s in report), key=int) + sorted(s for s in mapping if str(s) not in report)
    owner, used = {}, set()
    for sid in order:
        if sid not in mapping: continue
        n = native(sid)
        if n in used: continue
        used.add(n); owner[sid] = n
    return otb, owner

def build():
    otb, owner = owner_map()
    # items.otb
    root, _ = extract.parse(otb, 4); nodes = []
    for kind, props, children in root[2]:
        props = bytearray(props); pos = 4; sid = None; offsets = {}
        while pos < len(props):
            attr, size = struct.unpack_from('<BH', props, pos); pos += 3; offsets[attr] = pos
            if attr == 16: sid = struct.unpack_from('<H', props, pos)[0]
            pos += size
        if sid not in owner: continue
        for attr in (16, 17): struct.pack_into('<H', props, offsets[attr], owner[sid])
        nodes.append((kind, bytes(props), children))
    otb_out = otb[:4] + extract.encode((root[0], root[1], nodes))
    # items.xml
    selected = {}
    for entry in ET.parse(WORK/'source/data/items/items.xml').getroot():
        first = int(entry.get('id', entry.get('fromid', '0'))); last = int(entry.get('toid', str(first)))
        for sid in range(first, last + 1):
            if sid not in owner or owner[sid] in selected: continue
            node = copy.deepcopy(entry); node.attrib.pop('fromid', None); node.attrib.pop('toid', None)
            node.set('id', str(owner[sid]))
            for attr in list(node):
                if attr.get('key', '').lower() in REF_KEYS:
                    value = attr.get('value', '0')
                    if value.isdigit() and int(value) != 0:
                        if int(value) in owner: attr.set('value', str(owner[int(value)]))
                        else: node.remove(attr)
            selected[owner[sid]] = node
    # Moedas precisam de 'worth' ou o servidor nao reconhece dinheiro (addMoney/getMoney).
    for coin, worth in ((3031, 1), (3035, 100), (3043, 10000)):
        node = selected.get(coin)
        if node is not None and not any(a.get('key', '').lower() == 'worth' for a in node):
            ET.SubElement(node, 'attribute', key='worth', value=str(worth))
    items = ET.Element('items')
    for ident in sorted(selected): items.append(selected[ident])
    return otb_out, items, len(nodes)

def main():
    otb_out, items, count = build()
    backup = LIVE / 'backup-before-full-import'
    if not backup.exists():
        backup.mkdir()
        for name in ('items.otb', 'items.xml'): shutil.copy2(LIVE/name, backup/name)
    (LIVE/'items.otb').write_bytes(otb_out)
    ET.ElementTree(items).write(LIVE/'items.xml', encoding='utf-8', xml_declaration=True)
    catalog = ROOT/'rules/equipment.json'
    if catalog.exists():
        spec2 = importlib.util.spec_from_file_location('equipment', ROOT/'tools/build-equipment.py')
        equipment = importlib.util.module_from_spec(spec2); spec2.loader.exec_module(equipment)
        equipment.apply_item_overlay(json.loads(catalog.read_text(encoding='utf-8')))
    print(f'items.otb: {count} tipos | items.xml: {len(items)} itens com nome')

if __name__ == '__main__': main()
