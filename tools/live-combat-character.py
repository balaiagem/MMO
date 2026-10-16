"""Prepare/clean an isolated real character for browser combat QA."""
import importlib.util,sys
from pathlib import Path
root=Path(__file__).resolve().parents[1];sys.path.insert(0,str(root))
from rules.creation import CLASSES
spec=importlib.util.spec_from_file_location('svc',root/'tools/character-service.py');svc=importlib.util.module_from_spec(spec);spec.loader.exec_module(svc)
name='Codex Arcane Test'
marker=root/'runtime/dnd-qa-character.id'
if sys.argv[1]=='prepare':
    if svc.sql(f'SELECT id FROM players WHERE name={svc.literal(name)};'):raise SystemExit('Test name already exists; not modifying it.')
    svc.handle('create',dict(name=name,race='human',**{'class':'wizard'},background='acolyte',sex=1,method='standard-array',scores=CLASSES['wizard']['array'],account='admin',password='admin'))
    pid=svc.sql(f'SELECT id FROM players WHERE name={svc.literal(name)};');marker.write_text(pid)
    svc.sql(f'UPDATE players SET posx=106,posy=118,posz=7 WHERE id={int(pid)};')
    print('Isolated Wizard prepared beside surface rats.')
elif sys.argv[1]=='cleanup':
    if marker.exists():
        pid=int(marker.read_text())
        if svc.sql(f'SELECT COUNT(*) FROM players_online WHERE player_id={pid};')=='0':
            svc.sql(f'DELETE FROM players WHERE id={pid} AND name={svc.literal(name)};');marker.unlink();print('Isolated character removed.')
        else: raise SystemExit('Test character is online; log out before cleanup.')
