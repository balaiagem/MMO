"""Refresh preload resources in an already linked Emscripten client.

For Lua/UI/assets changes; C++ changes still require build-client.ps1.
Use the SDK packager, update embedded metadata, and add any new package paths
to the linked loader without rebuilding WebAssembly.
"""
import json, posixpath, re, shutil, subprocess, sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
out=ROOT/'build/client-web/bin'
source=out/'otclient.js'
js=source.read_text(encoding='utf-8')
start=js.index('loadPackage({')+len('loadPackage(')
end=js.index('})})();var arguments_',start)+1
assert 'remote_package_size' in js[start:end] and 'package_uuid' in js[start:end]
temp=ROOT/'runtime/client-preload';temp.mkdir(parents=True,exist_ok=True)
python=ROOT/'tools/emsdk/python/3.13.3_64bit/python.exe'
command=[str(python) if python.exists() and sys.platform=='win32' else sys.executable,str(ROOT/'tools/emsdk/upstream/emscripten/tools/file_packager.py'),
 str(temp/'otclient.data'),'--preload']
for name in ['data','modules','mods','config.ini','init.lua','otclientrc.lua']:
 command.append(str(ROOT/'client'/name)+'@/'+name)
command += ['--js-output='+str(temp/'preload.js'),'--use-preload-cache','--separate-metadata']
subprocess.run(command,cwd=ROOT,check=True,creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
metadata=json.loads((temp/'preload.js.metadata').read_text())
assert metadata['remote_package_size']==(temp/'otclient.data').stat().st_size
assert max(f['end'] for f in metadata['files'])==metadata['remote_package_size']
assert any(f['filename']=='/config.ini' for f in metadata['files']), 'public config.ini was omitted from the browser package'
updated=js[:start]+json.dumps(metadata,separators=(',',':'))+js[end:]
path_call=re.compile(r'''Module\[(?:'FS_createPath'|"FS_createPath")\]\((['"])(.*?)\1,\s*(['"])(.*?)\3,\s*true,\s*true\);''')
def package_dirs(source):
    return {posixpath.normpath(parent+'/'+child) for _,parent,_,child in path_call.findall(source)}

existing_dirs=package_dirs(updated)
missing_calls=[]
for _,parent,_,child in path_call.findall((temp/'preload.js').read_text()):
    normalized=posixpath.normpath(parent+'/'+child)
    if normalized not in existing_dirs:
        missing_calls.append(f'Module["FS_createPath"]({json.dumps(parent)},{json.dumps(child)},true,true);')
        existing_dirs.add(normalized)
if missing_calls:
    anchor='async function processPackageData'
    assert anchor in updated
    updated=updated.replace(anchor,';'.join(missing_calls)+';'+anchor,1)
shutil.copyfile(temp/'otclient.data',out/'otclient.data')
source.write_text(updated,encoding='utf-8')
print('Client Lua/UI assets repackaged with fresh offsets and cache hash; WebAssembly unchanged.')
