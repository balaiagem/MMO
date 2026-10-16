"""Same-origin local creation API. Credentials never enter URLs or logs."""
import hashlib
import json
from pathlib import Path
import subprocess
import threading
import time
from rules.creation import build, catalog, ABILITIES

ROOT = Path(__file__).resolve().parents[1]
LOCK = threading.Lock()
IMPORT_MANIFEST = ROOT/'world/rookgaard-import.json'

def starting_position(ordinal=0):
    if IMPORT_MANIFEST.exists():
        manifest=json.loads(IMPORT_MANIFEST.read_text(encoding='utf-8'))
        positions=manifest.get('safe_positions') or [[manifest['spawn']['x'],manifest['spawn']['y'],manifest['spawn']['z']]]
        return tuple(map(int,positions[ordinal%len(positions)]))
    return 111,111,7

def literal(value):
    return "CONVERT(0x"+str(value).encode('utf-8').hex()+" USING utf8mb4)"

def sql(query):
    result = subprocess.run([str(ROOT/'tools/mariadb-11.4.12-winx64/bin/mariadb.exe'),
        '--defaults-extra-file='+str(ROOT/'runtime/admin.cnf'), '--batch', '--skip-column-names', 'tibia5e_local'],
        input=query.encode('utf-8'), capture_output=True, creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0), timeout=15)
    if result.returncode:
        if b'Duplicate entry' in result.stderr: raise ValueError('Esse nome já está em uso.')
        raise RuntimeError('Não foi possível salvar a ficha no banco local.')
    return result.stdout.decode('utf-8').strip()

def handle(action, data):
    if action == 'catalog': return catalog()
    if action == 'preview': return build(data)
    account, password = data.get('account'), data.get('password')
    if not isinstance(account,str) or not isinstance(password,str) or not account or len(account)>64 or len(password)>128:
        raise ValueError('Informe conta e senha.')
    digest=hashlib.sha1(password.encode()).hexdigest()
    aid=sql(f'SELECT id FROM accounts WHERE name={literal(account)} AND password={literal(digest)};')
    if not aid.isdigit(): raise ValueError('Conta ou senha incorreta.')
    sql((ROOT/'database/migrations/001_character_profiles.sql').read_text())
    if action == 'list':
        rows=sql(f'''SELECT p.name, d.profile, COALESCE(c.value,1), COALESCE(r.value,1), COALESCE(l.value,1),
 p.looktype,p.lookhead,p.lookbody,p.looklegs,p.lookfeet,p.lookaddons,IF(o.player_id IS NULL,0,1)
 FROM players p LEFT JOIN dnd_characters d ON d.player_id=p.id
 LEFT JOIN player_storage c ON c.player_id=p.id AND c.`key`=95001
 LEFT JOIN player_storage r ON r.player_id=p.id AND r.`key`=95002
 LEFT JOIN player_storage l ON l.player_id=p.id AND l.`key`=95003
 LEFT JOIN players_online o ON o.player_id=p.id
 WHERE p.account_id={aid} AND p.deletion=0 ORDER BY p.name;''')
        characters=[]
        for row in rows.splitlines():
            name,profile,*numbers=row.split('\t')
            cls,race,level,look,head,body,legs,feet,addons,online=map(int,numbers)
            characters.append(dict(name=name,profile=json.loads(profile) if profile!='NULL' else None,
                class_id=cls,race_id=race,level=level,online=bool(online),
                outfit=dict(type=look,head=head,body=body,legs=legs,feet=feet,addons=addons)))
        return characters
    if action == 'delete':
        name,confirmation=data.get('name'),data.get('confirmation')
        if not isinstance(name,str) or not isinstance(confirmation,str) or not name or confirmation!=name:
            raise ValueError('Digite o nome exato do personagem para confirmar a exclusão.')
        with LOCK:
            # Soft deletion preserves the character data and releases the active
            # account slot. BINARY prevents case-insensitive confirmation matches.
            rows=sql(f'''SELECT p.id, IF(o.player_id IS NULL,0,1) FROM players p
 LEFT JOIN players_online o ON o.player_id=p.id
 WHERE p.account_id={aid} AND BINARY p.name=BINARY {literal(name)} AND p.deletion=0;''')
            if not rows:raise ValueError('Personagem não encontrado nesta conta.')
            pid,online=rows.split('\t')
            if online!='0':raise ValueError('Desconecte o personagem antes de removê-lo.')
            changed=sql(f'''UPDATE players p LEFT JOIN players_online o ON o.player_id=p.id
 SET p.deletion={int(time.time())}
 WHERE p.id={int(pid)} AND p.account_id={aid} AND p.deletion=0 AND o.player_id IS NULL;
 SELECT ROW_COUNT();''')
            if changed!='1':raise ValueError('Não foi possível remover. Atualize a lista e confira se o personagem está desconectado.')
        return dict(name=name,deleted=True)
    if action != 'create': raise ValueError('Operação desconhecida.')
    profile=build(data)
    with LOCK:
        if int(sql(f'SELECT COUNT(*) FROM players WHERE account_id={aid} AND deletion=0;'))>=12: raise ValueError('Limite de 12 personagens nesta conta. Remova um personagem para liberar espaço.')
        spawn_x,spawn_y,spawn_z=starting_position(int(sql('SELECT COUNT(*) FROM players;')))
        sql((ROOT/'database/migrations/001_character_profiles.sql').read_text())
        hp=profile['hp']
        # One DB transaction creates both engine identity and 5e identity.
        stores={95000:1,95001:catalog()['classes'][profile['class']]['id'],95002:list(catalog()['races']).index(profile['race'])+1,
                95003:1,95004:0,95005:0,95008:0,95009:-1,95060:1,95061:1,
                95010:profile['ac'],95011:profile['speed'],95012:2}
        stores.update({95030+i:(profile['slots'][i] if i<len(profile['slots']) else 0) for i in range(3)})
        stores.update({95033+i:(profile['slots'][i] if i<len(profile['slots']) else 0) for i in range(3)})
        stores.update({95020+i:profile['scores'][a] for i,a in enumerate(ABILITIES)})
        stores.update({95040+i:profile['scores'][a] for i,a in enumerate(ABILITIES)})
        stores[95046]=profile['ac']
        values=','.join(f'(@pid,{k},{v})' for k,v in stores.items())
        sql(f'''START TRANSACTION;
INSERT INTO players(name,account_id,sex,looktype,lookhead,lookbody,looklegs,lookfeet,town_id,posx,posy,posz,health,healthmax,vocation,level,experience)
VALUES({literal(profile['name'])},{aid},{profile['sex']},{profile['looktype']},{profile['colors']['head']},{profile['colors']['body']},{profile['colors']['legs']},{profile['colors']['feet']},1,{spawn_x},{spawn_y},{spawn_z},{hp},{hp},0,1,0);
SET @pid=LAST_INSERT_ID();
INSERT INTO dnd_characters(player_id,profile) VALUES(@pid,{literal(json.dumps(profile,ensure_ascii=False))});
INSERT INTO player_storage(player_id,`key`,value) VALUES {values};
COMMIT;''')
    return profile
