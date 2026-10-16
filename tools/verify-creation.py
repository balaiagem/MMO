"""Exercise real local HTTP + MariaDB persistence; clean up only our test identity."""
import importlib.util
import json
from pathlib import Path
import sys
import urllib.request
import uuid

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
from rules.creation import CLASSES
spec=importlib.util.spec_from_file_location('svc',ROOT/'tools/character-service.py')
svc=importlib.util.module_from_spec(spec);spec.loader.exec_module(svc)
def post(action,data):
    req=urllib.request.Request('http://localhost:8080/api/creation/'+action,data=json.dumps(data).encode(),headers={'Content-Type':'application/json','Origin':'http://localhost:8080'})
    with urllib.request.urlopen(req,timeout=20) as r:return json.load(r)
name='Codex '+''.join(chr(97+int(x,16)) for x in uuid.uuid4().hex[:12])
data=dict(name=name,race='elf',**{'class':'wizard'},background='acolyte',sex=1,method='standard-array',scores=CLASSES['wizard']['array'],account='admin',password='admin')
created=False
try:
    preview=post('preview',data)
    assert preview['spell_dc']==13 and preview['hp']==7
    post('create',data);created=True
    rows=post('list',data)
    row=next(r for r in rows if r['name']==name)
    assert row['profile']==preview
    stored=svc.sql(f'SELECT p.healthmax,s.value FROM players p JOIN player_storage s ON s.player_id=p.id AND s.`key`=95023 WHERE p.name={svc.literal(name)};')
    assert stored=='7\t16',stored
    try: post('create',data)
    except urllib.error.HTTPError as e: assert e.code==400
    else: raise AssertionError('Duplicate accepted')
    try: post('create',dict(data,password='wrong'))
    except urllib.error.HTTPError as e: assert e.code==400
    else: raise AssertionError('Wrong password accepted')
    print('HTTP preview, create, list, persistent HP/INT, duplicate and authentication verified.')
finally:
    if created:svc.sql(f'DELETE FROM players WHERE name={svc.literal(name)} AND account_id=100;')
html=ROOT/'build/client-web/bin/otclient.html'
s=html.read_text(encoding='utf-8')
if 'creation-link' not in s:
    source=(ROOT/'client/browser/shell.html').read_text(encoding='utf-8')
    link=source[source.index('    <a id="creation-link"'):source.index('    <canvas')]
    s=s.replace('<canvas',link+'<canvas',1)
    html.write_text(s,encoding='utf-8')
