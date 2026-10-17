"""Exercise create/list/delete with temporary accounts only; clean up their rows."""
from pathlib import Path
import importlib.util,json,hashlib,uuid,urllib.request,urllib.error,sys
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT))
spec=importlib.util.spec_from_file_location('manager_qa_service',ROOT/'tools/character-service.py')
service=importlib.util.module_from_spec(spec);spec.loader.exec_module(service)
token=uuid.uuid4().hex[:12]
account='managerqa'+token;other=account+'b';password=uuid.uuid4().hex
account_ids=[]

def api(action,**data):
    data=dict(account=account,password=password,**data)
    req=urllib.request.Request('http://127.0.0.1:8080/api/creation/'+action,data=json.dumps(data).encode(),headers={'Content-Type':'application/json'})
    try:
        with urllib.request.urlopen(req,timeout=20) as response:return json.load(response)
    except urllib.error.HTTPError as error:raise ValueError(json.load(error)['error'])

try:
    for name in [account,other]:
        value=service.sql(f"INSERT INTO accounts(name,password) VALUES({service.literal(name)},{service.literal(hashlib.sha1(password.encode()).hexdigest())}); SELECT LAST_INSERT_ID();")
        assert value.isdigit();account_ids.append(int(value))
    suffix=''.join(chr(97+int(n,16)) for n in token)
    base=dict(race='human',background='acolyte',sex=1,method='standard-array',scores=[15,13,14,8,12,10],skill_choices=['athletics','perception'],expertise_choices=[],proficiency_replacements=[],colors=dict(head=23,body=44,legs=65,feet=86))
    names=[]
    for index in range(12):
        name='Qaa '+suffix+' '+chr(65+index)
        api('create',name=name,**{'class':'fighter'},**base);names.append(name)
    rows=api('list');assert len(rows)==12 and rows[0]['outfit']['head']==23
    try:api('create',name='Qaa '+suffix+' Extra',**{'class':'fighter'},**base);raise AssertionError('Account limit bypassed')
    except ValueError as error:assert 'Limite' in str(error)
    try:api('delete',name=names[0],confirmation=names[0].lower());raise AssertionError('Case-insensitive confirmation allowed')
    except ValueError as error:assert 'exato' in str(error)
    pid=service.sql(f'SELECT id FROM players WHERE account_id={account_ids[0]} AND name={service.literal(names[0])};')
    service.sql(f'INSERT INTO players_online(player_id) VALUES({int(pid)});')
    try:api('delete',name=names[0],confirmation=names[0]);raise AssertionError('Online character deleted')
    except ValueError as error:assert 'Desconecte' in str(error)
    service.sql(f'DELETE FROM players_online WHERE player_id={int(pid)};')
    assert api('delete',name=names[0],confirmation=names[0])['deleted']
    assert len(api('list'))==11
    assert service.sql(f'SELECT COUNT(*) FROM dnd_characters WHERE player_id={int(pid)};')=='1','Soft deletion destroyed the profile'
    api('create',name='Qaa '+suffix+' Novo',**{'class':'fighter'},**base)
    assert len(api('list'))==12,'Deletion did not release the account slot'
    print('Live API: create with colors, full-account limit, exact confirmation, online rejection, soft deletion and released slot passed.')
finally:
    # Only newly generated QA account IDs, never a pre-existing user's account.
    for aid in account_ids:
        assert service.sql(f'SELECT name FROM accounts WHERE id={aid};').startswith('managerqa'+token)
        service.sql(f'DELETE o FROM players_online o JOIN players p ON p.id=o.player_id WHERE p.account_id={aid}; DELETE FROM players WHERE account_id={aid}; DELETE FROM accounts WHERE id={aid};')
    print('Temporary QA accounts and their test characters removed.')
