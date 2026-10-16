"""Build a private browser QA package with staged art and automatic QA login."""
from pathlib import Path
import shutil,subprocess,json,re
ROOT=Path(__file__).resolve().parents[1];WORK=ROOT/'runtime/rookgaard-import'
client=WORK/'qa-client';web=WORK/'qa-web';client.mkdir(exist_ok=True);web.mkdir(exist_ok=True)
for name in ['data','modules','mods']:
    if not (client/name).exists():shutil.copytree(ROOT/'client'/name,client/name)
for name in ['config.ini','init.lua','otclientrc.lua']:shutil.copy2(ROOT/'client'/name,client/name)
for name in ['Tibia.dat','Tibia.spr']:shutil.copy2(WORK/'staged/client'/name,client/'data/things/860'/name)
rc='''print('[ROOKQA] isolated client ready')
connect(g_game, {
    onGameStart = function()
        CharacterList.hide()
    end
})
scheduleEvent(function()
    g_game.setClientVersion(860)
    g_game.setProtocolVersion(860)
    g_game.chooseRsa('localhost')
    g_game.loginWorld('admin','admin','Rookgaard','localhost',8092,'lucas','','')
end,1500)
scheduleEvent(function()
    local player=g_game.getLocalPlayer()
    if player then
        local pos=player:getPosition()
        print(string.format('[ROOKQA] online=%s position=%d,%d,%d',tostring(g_game.isOnline()),pos.x,pos.y,pos.z))
        g_game.talk('hi')
    else print('[ROOKQA] offline') end
end,11000)
'''
(client/'otclientrc.lua').write_text(rc)
packager=ROOT/'tools/emsdk/upstream/emscripten/tools/file_packager.py'
command=[str(ROOT/'tools/emsdk/python/3.13.3_64bit/python.exe'),str(packager),str(web/'otclient.data'),'--preload']
for name in ['data','modules','mods','config.ini','init.lua','otclientrc.lua']:command.append(str(client/name)+'@/'+name)
command+=['--js-output='+str(web/'preload.js'),'--use-preload-cache','--separate-metadata']
subprocess.run(command,check=True,creationflags=subprocess.CREATE_NO_WINDOW)
metadata=json.loads((web/'preload.js.metadata').read_text())
js=(ROOT/'build/client-web/bin/otclient.js').read_text();start=js.index('loadPackage({')+len('loadPackage(');end=js.index('})})();var arguments_',start)+1
(web/'otclient.js').write_text(js[:start]+json.dumps(metadata,separators=(',',':'))+js[end:])
for path in (ROOT/'build/client-web/bin').glob('otclient*'):
    if path.suffix not in ['.js','.data']:shutil.copy2(path,web/path.name)
print('Isolated browser package ready at runtime/rookgaard-import/qa-web; live client unchanged.')
