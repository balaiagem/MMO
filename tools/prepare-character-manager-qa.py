"""Private browser UI fixture: same WASM/assets, no game login or character writes."""
from pathlib import Path
import json,uuid,shutil
ROOT=Path(__file__).resolve().parents[1]
source=ROOT/'build/client-web/bin'
target=source/'character-manager-qa';target.mkdir(exist_ok=True)
js=(source/'otclient.js').read_text(encoding='utf-8')
start=js.index('loadPackage({')+len('loadPackage(')
end=js.index('})})();var arguments_',start)+1
metadata=json.loads(js[start:end]);data=(source/'otclient.data').read_bytes()
fixture=r'''
print('[MANAGERQA] boot')
local post=HTTP.post
HTTP.post=function(url,data,callback,...)
 local operation=post(url,data,function(body,err)
  print('[MANAGERQA] callback '..url..' bytes='..tostring(type(body)=='string' and #body or -1)..' err='..tostring(err))
  callback(body,err)
 end,...)
 print('[MANAGERQA] queued '..url..' id='..tostring(operation))
 return operation
end

scheduleEvent(function()
 G.host='localhost';G.account='admin';G.password='admin'
 g_game.setClientVersion(860);g_game.setProtocolVersion(860)
 EnterGame.hide()
 CharacterList.create({}, {status=0,subStatus=0,premDays=0})
 CharacterList.show()
 print('[MANAGERQA] list_open')
end,1800)
scheduleEvent(function()
 print('[MANAGERQA] opening_creator')
 CharacterManager.openCreator()
 print('[MANAGERQA] called_creator')
end,5000)
scheduleEvent(function()
 local w=g_ui.getRootWidget():recursiveGetChildById('characterCreator')
 if not w then print('[MANAGERQA] status '..g_ui.getRootWidget():recursiveGetChildById('managerStatus'):getText()) end
 assert(w,'creator missing')
 w:getChildById('characterName'):setText('Preview Hero')
 w:getChildById('characterClass'):setCurrentOptionByData('rogue')
 w:getChildById('characterRace'):setCurrentOptionByData('elf')
 w:getChildById('characterSex'):setCurrentOptionByData(0)
end,25000)
scheduleEvent(function()
 local w=g_ui.getRootWidget():recursiveGetChildById('characterCreator')
 assert(w and w:getChildById('portrait'):getCreature(),'portrait missing')
 assert(w:recursiveGetChildById('confirmCreate'):isEnabled(),'creation preview failed: '..w:getChildById('previewSummary'):getText())
 print('[MANAGERQA] creator_ready')
end,29000)
scheduleEvent(function()
 CharacterManager.closeCreator()
 local w=g_ui.getRootWidget():recursiveGetChildById('charactersWindow')
 local list=w:getChildById('characters')
 for _,row in ipairs(list:getChildren()) do
   if not row.characterInfo.online then list:focusChild(row);break end
 end
 CharacterManager.openDelete()
 local d=g_ui.getRootWidget():recursiveGetChildById('characterDelete')
 assert(d,'delete dialog missing')
 d:getChildById('confirmation'):setText('Wrong Name')
 assert(not d:getChildById('confirmDelete'):isEnabled(),'wrong confirmation enabled delete')
 print('[MANAGERQA] delete_ready')
end,32000)
scheduleEvent(function()
 CharacterManager.closeDelete()
 print('[MANAGERQA] list_ready')
end,35000)
'''
out=bytearray()
for file in metadata['files']:
    content=data[file['start']:file['end']]
    if file['filename']=='/otclientrc.lua':content=fixture.encode('utf-8')
    file['start']=len(out);out.extend(content);file['end']=len(out)
metadata['remote_package_size']=len(out);metadata['package_uuid']=str(uuid.uuid4())
(target/'otclient.data').write_bytes(out)
(target/'otclient.js').write_text(js[:start]+json.dumps(metadata,separators=(',',':'))+js[end:],encoding='utf-8')
for name in ['otclient.html','otclient.wasm']:
    shutil.copy2(source/name,target/name)
print('Private, read-only UI fixture prepared at /character-manager-qa/otclient.html')
