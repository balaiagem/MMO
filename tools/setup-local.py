"""Provision an isolated loopback-only development runtime; never touches another DB."""
from pathlib import Path
import json, subprocess, secrets, shutil, time, socket, hashlib, re
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.hazmat.primitives import serialization
ROOT=Path(__file__).resolve().parents[1]
RUNTIME=ROOT/'runtime'; SERVER=RUNTIME/'server'; DB=RUNTIME/'database'
MDB=ROOT/'tools/mariadb-11.4.12-winx64/bin'
HIDDEN=subprocess.CREATE_NO_WINDOW

def write(path,text):
    path.parent.mkdir(parents=True,exist_ok=True); path.write_text(text,encoding='utf-8')
def run(args,**kwargs):
    result=subprocess.run([str(a) for a in args],creationflags=HIDDEN,capture_output=True,**kwargs)
    if result.returncode:
        # Do not print process arguments, which may contain generated bootstrap secrets.
        raise RuntimeError(result.stderr.decode(errors='replace')[-2000:])
    return result.stdout
def ready(port):
    try:
        with socket.create_connection(('127.0.0.1',port),timeout=.2): return True
    except OSError: return False
def main():
    RUNTIME.mkdir(exist_ok=True)
    secretfile=RUNTIME/'local-secrets.json'
    if not secretfile.exists():
        write(secretfile,json.dumps({k:secrets.token_hex(16) for k in ['db_root','db_game','player_password']},indent=2))
    secret=json.loads(secretfile.read_text())
    secret['player_password']='admin'
    write(secretfile,json.dumps(secret,indent=2))
    if not (DB/'mysql').exists():
        run([MDB/'mariadb-install-db.exe',f'--datadir={DB}',f'--password={secret["db_root"]}','--port=3307','--silent'])
    cnf=RUNTIME/'admin.cnf'
    write(cnf,f'[client]\nuser=root\npassword={secret["db_root"]}\nhost=127.0.0.1\nport=3307\nprotocol=tcp\n')
    if not ready(3307):
        log=(RUNTIME/'mariadb.log').open('ab')
        process=subprocess.Popen([str(MDB/'mariadbd.exe'),f'--datadir={DB}',f'--basedir={MDB.parent}',
            '--bind-address=127.0.0.1','--port=3307','--console'],stdout=log,stderr=log,creationflags=HIDDEN)
        write(RUNTIME/'mariadb.pid',str(process.pid))
        for _ in range(100):
            if ready(3307): break
            if process.poll() is not None: raise RuntimeError('MariaDB failed; see runtime/mariadb.log')
            time.sleep(.1)
        else: raise RuntimeError('MariaDB startup timed out')
    def sql(query): return run([MDB/'mariadb.exe',f'--defaults-extra-file={cnf}','--batch','--skip-column-names'],input=query.encode())
    sql('CREATE DATABASE IF NOT EXISTS tibia5e_local CHARACTER SET utf8mb4;')
    existing=sql("SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='tibia5e_local' AND table_name='accounts';").strip()
    if existing==b'0':
        sql('USE tibia5e_local;\n'+(ROOT/'server/schema.sql').read_text())
        sql("USE tibia5e_local; DELETE FROM players; DELETE FROM accounts;")
    sql(f"CREATE USER IF NOT EXISTS 'tibia5e'@'127.0.0.1' IDENTIFIED BY '{secret['db_game']}'; GRANT ALL ON tibia5e_local.* TO 'tibia5e'@'127.0.0.1';")
    digest=hashlib.sha1(secret['player_password'].encode()).hexdigest()
    sql(f"USE tibia5e_local; INSERT INTO accounts(id,name,password) VALUES(100,'admin','{digest}') ON DUPLICATE KEY UPDATE name='admin',password=VALUES(password);")
    for pid,name,x in [(100,'Explorer',111),(101,'Companion',112)]:
        sql(f"USE tibia5e_local; INSERT IGNORE INTO players(id,name,account_id,looktype,town_id,posx,posy,posz,health,healthmax) VALUES({pid},'{name}',100,1,1,{x},111,7,150,150);")
    data=SERVER/'data'
    for directory in ['items','XML','world','lib','events','scripts/lib','scripts/spells','scripts/chatchannels','monsters','npc/lua','migrations','logs']:
        (data/directory).mkdir(parents=True,exist_ok=True)
    # Remove the old frontier stair handler. Its adjacent-tile teleports overlap
    # the Rookgaard cave path and send players back onto the stair when exiting.
    (data/'scripts/frontier.lua').unlink(missing_ok=True)
    for f in ['items.otb','items.xml']:
        if not (ROOT/'world/rookgaard-import.json').exists() or not (data/'items'/f).exists():
            shutil.copy2(ROOT/'world/generated'/f,data/'items'/f)
    for f in ['rookgaard.otbm','rookgaard-spawn.xml','rookgaard-house.xml']:
        if not (ROOT/'world/rookgaard-import.json').exists() or not (data/'world'/f).exists():
            shutil.copy2(ROOT/'world/generated'/f,data/'world'/f)
    for f in ['vocations.xml','groups.xml','outfits.xml']:
        shutil.copy2(ROOT/'server/data/XML'/f,data/'XML'/f)
    # D&D classes use native vocation None; allow their PvP targeting.
    vocations=data/'XML'/'vocations.xml'
    vocations.write_text(vocations.read_text().replace('allowPvp="0"','allowPvp="1"'))
    # Local GM characters participate in PvP testing.
    import re as group_re
    groups=data/'XML'/'groups.xml'
    group_text=groups.read_text()
    for gid in [6,7]:
        pattern=r'(<group id="'+str(gid)+r'"[\s\S]*?</group>)'
        group_text=group_re.sub(pattern,lambda m:m[0].replace('cannotattackplayer="1"','cannotattackplayer="0"').replace('cannotbeattacked="1"','cannotbeattacked="0"'),group_text)
    groups.write_text(group_text)
    # Lua engine extension code, not upstream world/content scripts.
    write(data/'lib/lib.lua','-- Minimal foundation runtime: native TFS API only.\n')
    write(data/'anti_advertising.lua','-- Local development chat.\n')
    write(data/'events/events.xml','<events/>\n')
    write(data/'XML/zone_weather.xml','<zoneWeather/>\n')
    write(data/'XML/channels.xml','<channels/>\n')
    write(data/'XML/mounts.xml','<mounts/>\n')
    write(data/'raids/raids.xml','<raids/>\n')
    shutil.copy2(ROOT/'world/content/island_guide.lua',data/'npc/lua/island_guide.lua')
    shutil.copy2(ROOT/'world/content/rat.lua',data/'monsters/rat.lua')
    shutil.copy2(ROOT/'world/content/rookgaard.lua',data/'scripts/rookgaard_world.lua')
    shutil.copy2(ROOT/'rules/core.lua',data/'lib/dnd_rules.lua')
    shutil.copy2(ROOT/'rules/characters.lua',data/'lib/dnd_characters.lua')
    shutil.copy2(ROOT/'rules/character_data.lua',data/'lib/dnd_character_data.lua')
    shutil.copy2(ROOT/'world/content/dnd_combat.lua',data/'scripts/dnd_combat.lua')
    shutil.copy2(ROOT/'world/content/gm_tools.lua',data/'scripts/gm_tools.lua')
    shutil.copy2(ROOT/'server/data/scripts/lib/helper_constructors.lua',data/'scripts/lib/helper_constructors.lua')
    shutil.copy2(ROOT/'server/data/scripts/lib/register_monster_type.lua',data/'scripts/lib/register_monster_type.lua')
    write(data/'server_config.lua','-- Classic protocol 860 foundation runtime.\n')
    for source in (ROOT/'server/data/migrations').glob('*.lua'): shutil.copy2(source,data/'migrations'/source.name)
    world=json.loads((ROOT/'world/rookgaard.json').read_text())
    connections=world['connections']
    floors=world['floors']
    origin=world['origin']
    lua=[]
    for c in connections:
        x,y,z=c['from']; a,b,d=c['to']
        symbol=floors[str(z)][y-origin[1]][x-origin[0]]
        item_id={'<':106,'>':107}[symbol]
        lua.append(f'''do
local stairs = MoveEvent()
stairs:onStepIn(function(creature, item, position, fromPosition)
    if not creature:isPlayer() then return true end
    creature:teleportTo(Position({a},{b},{d}), false, CONST_ME_NONE)
    return true
end)
stairs:type("stepin")
stairs:id({item_id})
stairs:register()
end
''')
    write(data/'scripts/rookgaard_stairs.lua','\n'.join(lua))
    keyfile=SERVER/'key.pem'
    if not keyfile.exists():
        key=rsa.generate_private_key(public_exponent=65537,key_size=1024)
        keyfile.write_bytes(key.private_bytes(serialization.Encoding.PEM,serialization.PrivateFormat.TraditionalOpenSSL,serialization.NoEncryption()))
    else: key=serialization.load_pem_private_key(keyfile.read_bytes(),password=None)
    # Public modulus is safe to distribute; private key remains in ignored runtime/.
    write(ROOT/'client/modules/gamelib/tibia5e_key.lua',f"OTSERV_RSA = '{key.public_key().public_numbers().n}'\n")
    config=(ROOT/'server/config.lua.dist').read_text()
    config+='\n-- Isolated development overrides\n'+f'''
ip = "127.0.0.1"
bindOnlyGlobalAddress = true
serverName = "Rookgaard"
worldType = "pvp"
mapName = "rookgaard"
mysqlHost = "127.0.0.1"
mysqlPort = 3307
mysqlUser = "tibia5e"
mysqlPass = "{secret['db_game']}"
mysqlDatabase = "tibia5e_local"
accountManager = false
onePlayerOnlinePerAccount = false
allowClones = false
gameStore = false
imbuementSystemEnabled = false
startupDatabaseOptimization = false
'''
    write(SERVER/'config.lua',config)
    write(RUNTIME/'LOGIN.txt',"Local development only\nAccount: admin\nPassword: admin\nCharacters: Explorer and Companion\n")
    print('Local database provisioned on 127.0.0.1:3307; runtime/server prepared. Credentials: runtime/LOGIN.txt (not printed).')
if __name__=='__main__': main()
