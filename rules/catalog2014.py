"""Read the pinned SRD reference. Presence is not a claim of runtime support."""
from functools import lru_cache
from pathlib import Path
import hashlib,json
import copy
ROOT=Path(__file__).parent/'content/srd2014'
@lru_cache(maxsize=None)
def collection(name):
    filename='5e-SRD-'+name+'.json'
    manifest=json.loads((ROOT/'manifest.json').read_text())
    record=next(row for row in manifest['collections'] if row['file']==filename)
    raw=(ROOT/filename).read_bytes()
    if hashlib.sha256(raw).hexdigest()!=record['sha256']:raise ValueError('SRD checksum mismatch: '+filename)
    return {entry['index']:entry for entry in json.loads(raw)}
def class_level(class_id,level):
    if type(level) is not int or not 1<=level<=20:raise ValueError('Level must be 1 through 20')
    if class_id not in collection('Classes'):raise ValueError('Unknown SRD class')
    key=f'{class_id}-{level}'
    row=copy.deepcopy(collection('Levels')[key])
    corrections=json.loads((Path(__file__).parent/'srd2014-overrides.json').read_text(encoding='utf-8')).get(key,{})
    for path,correction in corrections.items():
        target=row
        pieces=path.split('.')
        for part in pieces[:-1]:target=target[part]
        if target[pieces[-1]]!=correction['source_value']:raise ValueError('SRD correction no longer matches source: '+key)
        target[pieces[-1]]=correction['value']
    return row
def spell(index):
    return collection('Spells')[index]
def ability_for_skill(index):
    return collection('Skills')[index]['ability_score']['index'].upper()
