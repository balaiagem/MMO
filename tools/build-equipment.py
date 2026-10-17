"""Build the D&D 5e equipment catalogue for the Tibia items.

Every Tibia item that stands for a 5e SRD item gets that item's name, price
and rules. Outputs:
  rules/equipment.json        catalogue (source for the other outputs)
  rules/equipment_data.lua    loaded by the server (synced to data/lib)
  runtime items.xml           D&D names/descriptions on the mapped items
  runtime NPC shops           D&D prices; NPCs buy back at half price

Currency: one Tibia gold coin is one copper piece (cp). A platinum coin
(100 coins) is therefore one gold piece (gp) and a crystal coin is 100 gp.
"""
from pathlib import Path
import json, re, importlib.util, xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
SRD = ROOT/'rules/content/srd2014/5e-SRD-Equipment.json'
LIVE = ROOT/'runtime/server/data'
COINS_PER_CP = 1
UNIT_CP = {'cp': 1, 'sp': 10, 'ep': 50, 'gp': 100, 'pp': 1000}

# Armour is worn as a Tibia set: the AC only applies with every piece on.
# Piece prices (gp) add up to the SRD price of the armour.
SETS = {
    'leather': dict(srd='leather-armor', pieces={'body': ('leather armor', 4), 'head': ('leather helmet', 2),
                                                 'legs': ('leather legs', 2), 'feet': ('leather boots', 2)}),
    'chain':   dict(srd='chain-mail', pieces={'body': ('chain armor', 43), 'head': ('studded helmet', 15),
                                              'legs': ('studded legs', 15), 'feet': ('leather boots', 2)}),
    'plate':   dict(srd='plate-armor', pieces={'body': ('plate armor', 900), 'head': ('steel helmet', 200),
                                               'legs': ('plate legs', 250), 'feet': ('steel boots', 150)}),
}
# Every Tibia shield is the SRD Shield; the first one is the one NPCs sell.
SHIELDS = ['wooden shield', 'brass shield', 'copper shield', 'studded shield', 'plate shield',
           'steel shield', 'dwarven shield']
# Tibia item -> SRD weapon. The first Tibia item for an SRD weapon is the one sold.
WEAPONS = [
    ('club', 'club'), ('dagger', 'dagger'), ('studded club', 'greatclub'), ('hand axe', 'handaxe'),
    ('hatchet', 'handaxe'), ('mace', 'mace'), ('staff', 'quarterstaff'), ('sickle', 'sickle'),
    ('spear', 'spear'), ('crossbow', 'crossbow-light'), ('bow', 'shortbow'),
    ('battle axe', 'battleaxe'), ('axe', 'battleaxe'), ('morning star', 'morningstar'),
    ('double axe', 'greataxe'), ('two handed sword', 'greatsword'), ('halberd', 'halberd'),
    ('lance', 'lance'), ('longsword', 'longsword'), ('sword', 'longsword'), ('battle hammer', 'maul'),
    ('rapier', 'rapier'), ('sabre', 'scimitar'), ('short sword', 'shortsword'),
    ('war hammer', 'warhammer'), ('elvish bow', 'longbow'),
]
AMMO = [('arrow', 'arrow', 'arrow'), ('bolt', 'crossbow-bolt', 'bolt')]
AMMO_FOR = {'shortbow': 'arrow', 'longbow': 'arrow', 'crossbow-light': 'bolt'}
# Adventuring gear with a direct SRD counterpart.
GEAR = [('backpack', 'backpack'), ('rope', 'rope-hempen-50-feet'), ('torch', 'torch'), ('shovel', 'shovel'),
        ('fishing rod', 'fishing-tackle'), ('bag', 'pouch'), ('pick', 'pick-miners'), ('lute', 'lute'),
        ('spellbook', 'spellbook')]
POTION = ('health potion', dict(name='Potion of Healing', cost_cp=5000, heal='2d4+2'))

# Starting equipment per class id (rules/creation.py ids), from the SRD class kits.
# slot None = goes in the backpack.
KITS = {
    1:  ['set:chain', ('longsword', 1, 'left'), ('wooden shield', 1, 'right'), ('crossbow', 1, None), ('bolt', 20, 'ammo')],
    2:  ['set:leather', ('rapier', 1, 'left'), ('bow', 1, None), ('arrow', 20, 'ammo'), ('dagger', 2, None)],
    3:  ['set:chain', ('mace', 1, 'left'), ('wooden shield', 1, 'right'), ('crossbow', 1, None), ('bolt', 20, 'ammo')],
    4:  [('staff', 1, 'left'), ('spellbook', 1, None)],
    5:  [('double axe', 1, 'left'), ('hand axe', 2, None)],
    6:  ['set:leather', ('rapier', 1, 'left'), ('dagger', 1, None), ('lute', 1, None)],
    7:  ['set:leather', ('staff', 1, 'left'), ('wooden shield', 1, 'right')],
    8:  [('short sword', 1, 'left')],
    9:  ['set:chain', ('longsword', 1, 'left'), ('wooden shield', 1, 'right')],
    10: ['set:leather', ('elvish bow', 1, 'left'), ('arrow', 20, 'ammo'), ('short sword', 2, None)],
    11: [('crossbow', 1, 'left'), ('bolt', 20, 'ammo'), ('dagger', 2, None)],
    12: ['set:leather', ('crossbow', 1, 'left'), ('bolt', 20, 'ammo'), ('dagger', 2, None)],
}
# 5e class proficiencies (armour categories and weapons).
PROFICIENCY = {
    1: dict(armor=['light', 'medium', 'heavy', 'shield'], weapons=['simple', 'martial']),
    2: dict(armor=['light'], weapons=['simple', 'longsword', 'rapier', 'shortsword']),
    3: dict(armor=['light', 'medium', 'heavy', 'shield'], weapons=['simple']),   # Life domain: heavy armour
    4: dict(armor=[], weapons=['dagger', 'quarterstaff', 'crossbow-light']),
    5: dict(armor=['light', 'medium', 'shield'], weapons=['simple', 'martial']),
    6: dict(armor=['light'], weapons=['simple', 'longsword', 'rapier', 'shortsword']),
    7: dict(armor=['light', 'medium', 'shield'], weapons=['club', 'dagger', 'mace', 'quarterstaff', 'scimitar', 'sickle', 'spear']),
    8: dict(armor=[], weapons=['simple', 'shortsword']),
    9: dict(armor=['light', 'medium', 'heavy', 'shield'], weapons=['simple', 'martial']),
    10: dict(armor=['light', 'medium', 'shield'], weapons=['simple', 'martial']),
    11: dict(armor=[], weapons=['dagger', 'quarterstaff', 'crossbow-light']),
    12: dict(armor=['light'], weapons=['simple']),
}
SHOPS = {   # NPC -> catalogue groups it trades in
    'Obi': ['weapon', 'ammo'], 'Dixi': ['armor', 'shield'],
    'Al Dee': ['gear', 'ammo'], "Lee'Delle": ['gear', 'ammo'], 'Lily': ['potion'],
}
PT = {'slashing': 'cortante', 'piercing': 'perfurante', 'bludgeoning': 'contundente'}
PROP = {'finesse': 'acuidade', 'light': 'leve', 'heavy': 'pesada', 'two-handed': 'duas maos',
        'versatile': 'versatil', 'thrown': 'arremesso', 'ammunition': 'municao', 'loading': 'recarga',
        'reach': 'alcance', 'monk': 'monge', 'special': 'especial'}


def cost_cp(entry):
    c = entry['cost']
    return c['quantity'] * UNIT_CP[c['unit']]


def money(cp):
    if cp % 100 == 0: return f'{cp // 100} po'
    if cp % 10 == 0: return f'{cp // 10} pp'
    return f'{cp} pc'


def tibia_ids():
    """Original Tibia item name -> live item id (resolved from the source catalogue)."""
    spec = importlib.util.spec_from_file_location('imp', ROOT/'tools/import-all-items.py')
    imp = importlib.util.module_from_spec(spec); spec.loader.exec_module(imp)
    _, owner = imp.owner_map()
    names = {}
    for entry in ET.parse(ROOT/'runtime/rookgaard-import/source/data/items/items.xml').getroot():
        name = (entry.get('name') or '').lower()
        first = int(entry.get('id', entry.get('fromid', '0')))
        if name and name not in names and first in owner: names[name] = owner[first]
    return names


def build_catalog():
    srd = {e['index']: e for e in json.load(open(SRD, encoding='utf-8'))}
    ids = tibia_ids()

    def tid(name):
        if name not in ids: raise SystemExit(f'Item Tibia nao encontrado: {name}')
        return ids[name]

    items, sets = {}, {}
    for key, s in SETS.items():
        a = srd[s['srd']]
        sets[key] = dict(name=a['name'], category=a['armor_category'].lower(), base=a['armor_class']['base'],
                         dex=a['armor_class']['dex_bonus'], dexMax=2 if a['armor_category'] == 'Medium' else None,
                         strength=a.get('str_minimum') or 0, stealth=bool(a.get('stealth_disadvantage')),
                         cost=cost_cp(a), pieces={})
        for slot, (name, gp) in s['pieces'].items():
            i = tid(name); sets[key]['pieces'][slot] = i
            entry = items.setdefault(i, dict(kind='armor', tibia=name, sets=[], slot=slot, cost=gp * 100,
                                             group='armor', sell=True))
            entry['sets'].append(key)
    sh = srd['shield']
    for n, name in enumerate(SHIELDS):
        items[tid(name)] = dict(kind='shield', tibia=name, name='Shield', bonus=sh['armor_class']['base'],
                                cost=cost_cp(sh), group='shield', sell=n == 0, rename='shield')
    seen = set()
    for name, index in WEAPONS:
        w = srd[index]; props = [p['index'] for p in w.get('properties', [])]
        ranged = w['weapon_range'] == 'Ranged'
        dice, sides = map(int, w['damage']['damage_dice'].split('d'))
        e = dict(kind='weapon', tibia=name, srd=index, name=w['name'], dice=dice, sides=sides,
                 type=w['damage']['damage_type']['index'], category=w['category_range'].split()[0].lower(),
                 ranged=ranged, props=props, cost=cost_cp(w), group='weapon', sell=index not in seen,
                 rename=w['name'].lower().replace('crossbow, light', 'light crossbow'))
        if 'two_handed_damage' in w: e['versatile'] = int(w['two_handed_damage']['damage_dice'].split('d')[1])
        if ranged:
            e['normal'], e['long'] = w['range']['normal'] // 5, w['range']['long'] // 5
            e['ammo'] = AMMO_FOR[index]
        seen.add(index); items[tid(name)] = e
    for name, index, ammo in AMMO:
        a = srd[index]
        items[tid(name)] = dict(kind='ammo', tibia=name, name=a['name'], ammo=ammo,
                                cost=cost_cp(a) // a.get('quantity', 1), group='ammo', sell=True,
                                rename=a['name'].lower(), plural=a['name'].lower() + 's')
    for name, index in GEAR:
        g = srd[index]
        items[tid(name)] = dict(kind='gear', tibia=name, name=g['name'], cost=cost_cp(g), group='gear',
                                sell=True, rename=g['name'].lower())
    name, p = POTION
    items[tid(name)] = dict(kind='potion', tibia=name, name=p['name'], cost=p['cost_cp'], heal=p['heal'],
                            group='potion', sell=True, rename='potion of healing')
    kits = {}
    for cls, kit in KITS.items():
        out = []
        for piece in kit:
            if isinstance(piece, str):
                key = piece.split(':')[1]
                for slot, i in sets[key]['pieces'].items(): out.append(dict(id=i, count=1, slot=slot))
            else:
                n, count, slot = piece
                out.append(dict(id=tid(n), count=count, slot=slot))
        kits[cls] = out
    return dict(currency='1 moeda de ouro = 1 pc; platina = 1 po; cristal = 100 po', coinsPerCp=COINS_PER_CP,
                items={str(k): v for k, v in sorted(items.items())}, sets=sets,
                kits={str(k): v for k, v in kits.items()},
                proficiency={str(k): v for k, v in PROFICIENCY.items()})


def describe(e, cat):
    if e['kind'] == 'armor':
        parts = []
        for key in e['sets']:
            s = cat['sets'][key]
            ac = f"CA {s['base']}" + (' + Des (max 2)' if s['dexMax'] else ' + Des' if s['dex'] else '')
            extra = (f", For {s['strength']}" if s['strength'] else '') + (', desvantagem em Furtividade' if s['stealth'] else '')
            pieces = ', '.join(s['pieces_names'])
            parts.append(f"Peca de {s['name']} ({ac}{extra}; {money(s['cost'])} o conjunto). "
                         f"Precisa do conjunto completo: {pieces}.")
        return ' '.join(parts)
    if e['kind'] == 'shield': return f"Shield: +{e['bonus']} CA. {money(e['cost'])}."
    if e['kind'] == 'weapon':
        props = ', '.join(PROP.get(p, p) for p in e['props'])
        text = f"{e['name']}: {e['dice']}d{e['sides']} {PT.get(e['type'], e['type'])}"
        if e.get('versatile'): text += f" (1d{e['versatile']} com duas maos)"
        if e['ranged']: text += f", alcance {e['normal']}/{e['long']} sqm, usa {e['ammo']}s"
        if props: text += f"; {props}"
        return text + f". {money(e['cost'])}."
    if e['kind'] == 'ammo': return f"{e['name']}: {money(e['cost'] * 20)} por 20."
    if e['kind'] == 'potion': return f"{e['name']}: recupera {e['heal']} PV (uma acao em combate). {money(e['cost'])}."
    return f"{e['name']}. {money(e['cost'])}."


def lua(v):
    if isinstance(v, bool): return 'true' if v else 'false'
    if v is None: return 'nil'
    if isinstance(v, (int, float)): return repr(v)
    if isinstance(v, str): return json.dumps(v, ensure_ascii=False)
    if isinstance(v, list): return '{' + ','.join(lua(x) for x in v) + '}'
    parts = []
    for k, x in v.items():
        if isinstance(k, int) or str(k).isdigit(): key = f'[{k}]'
        elif re.match(r'^[A-Za-z_]\w*$', k): key = k
        else: key = f'[{json.dumps(k)}]'
        parts.append(f'{key}={lua(x)}')
    return '{' + ','.join(parts) + '}'


def apply_item_overlay(cat):
    path = LIVE/'items/items.xml'
    tree = ET.parse(path); byid = {x.get('id'): x for x in tree.getroot()}
    for ident, e in cat['items'].items():
        node = byid.get(ident)
        if node is None: continue
        if e.get('rename'):
            node.set('name', e['rename']); node.set('article', 'an' if e['rename'][0] in 'aeiou' else 'a')
        if e.get('plural'): node.set('plural', e['plural'])
        for attr in node.findall('attribute'):
            if attr.get('key', '').lower() == 'description': node.remove(attr)
        ET.SubElement(node, 'attribute', key='description', value=e['description'])
    tree.write(path, encoding='utf-8', xml_declaration=True)


def shop_label(e, cat):
    # Shop entries are comma separated, so labels must not contain commas.
    if e['kind'] == 'armor': return f"{cat['sets'][e['sets'][0]]['name']} - {e['tibia']}"
    return e['name'].replace(', ', ' ').replace(',', ' ')


def apply_shops(cat):
    items = {int(k): v for k, v in cat['items'].items()}
    for npc in SHOPS:
        if not (LIVE/f'npc/{npc}.xml').exists(): raise SystemExit(f'NPC nao encontrado: {npc}')
    # Always start from the original shops so the script can be re-run.
    original = LIVE/'npc-backup-before-dnd-shops'
    for path in sorted((LIVE/'npc').glob('*.xml')):
        source = original/path.name if (original/path.name).exists() else path
        text = source.read_text(encoding='utf-8')
        groups = SHOPS.get(path.stem, [])

        def rebuild(key, buying):
            m = re.search(rf'(<parameter key="{key}" value=")([^"]*)(")', text)
            entries = [x for x in (m.group(2).split(';') if m else []) if x.strip()]
            out, seen = [], set()
            for raw in entries:
                parts = raw.split(',')
                ident = int(parts[1])
                if ident in seen: continue
                seen.add(ident)
                if ident in items:
                    e = items[ident]
                    if buying and not e['sell']: continue          # one shop entry per D&D item
                    price = e['cost'] if buying else e['cost'] // 2
                    out.append(f"{shop_label(e, cat)},{ident},{max(1, price) * COINS_PER_CP}")
                elif buying and groups and set(groups) <= {'weapon', 'ammo', 'armor', 'shield'}:
                    continue                                      # D&D smiths only sell D&D items
                else: out.append(raw)
            for ident, e in items.items():
                if e['group'] in groups and ident not in seen and (e['sell'] or not buying):
                    price = e['cost'] if buying else e['cost'] // 2
                    if price > 0:
                        out.append(f"{shop_label(e, cat)},{ident},{price * COINS_PER_CP}"); seen.add(ident)
            return m, ';'.join(out) + (';' if out else '')

        changed = False
        for key, buying in (('shop_buyable', True), ('shop_sellable', False)):
            m, value = rebuild(key, buying)
            if m:
                text = text[:m.start(2)] + value + text[m.end(2):]; changed = True
            elif value:
                text = text.replace('</parameters>', f'\t<parameter key="{key}" value="{value}" />\n\t</parameters>')
                changed = True
        if groups and 'module_shop' not in text:
            text = text.replace('<parameters>', '<parameters>\n\t\t<parameter key="module_shop" value="1" />')
        if changed: path.write_text(text, encoding='utf-8')


def main():
    cat = build_catalog()
    for s in cat['sets'].values():
        s['pieces_names'] = [cat['items'][str(i)]['tibia'] for i in s['pieces'].values()]
    for e in cat['items'].values(): e['description'] = describe(e, cat)
    (ROOT/'rules/equipment.json').write_text(json.dumps(cat, indent=1, ensure_ascii=False), encoding='utf-8')
    data = dict(cat)
    data['items'] = {int(k): {a: b for a, b in v.items() if a != 'description'} for k, v in cat['items'].items()}
    data['kits'] = {int(k): v for k, v in cat['kits'].items()}
    data['proficiency'] = {int(k): v for k, v in cat['proficiency'].items()}
    (ROOT/'rules/equipment_data.lua').write_text('-- Gerado por tools/build-equipment.py. Nao edite a mao.\nreturn '
                                                 + lua(data) + '\n', encoding='utf-8')
    apply_item_overlay(cat); apply_shops(cat)
    print(f"{len(cat['items'])} itens D&D, {len(cat['sets'])} conjuntos, kits para {len(cat['kits'])} classes")


if __name__ == '__main__': main()
