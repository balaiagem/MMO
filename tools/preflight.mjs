import { existsSync, readFileSync, readdirSync } from 'node:fs';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
const root = resolve(fileURLToPath(new URL('..', import.meta.url)));
const checks = [
  ['OTClient source', 'client/CMakeLists.txt'], ['TFS source', 'server/CMakeLists.txt'],
  ['Emscripten compiler', 'tools/emsdk/upstream/emscripten/emcc.py'],
  ['CMake', 'tools/python/cmake/data/bin/cmake.exe'],
  ['Ninja', 'tools/python/bin/ninja.exe'],
  ['860 data definitions', 'client/data/things/860/Tibia.dat'],
  ['860 sprite atlas', 'client/data/things/860/Tibia.spr'],
];
let missing = false;
for (const [label, path] of checks) {
  const ok = existsSync(resolve(root, path)); missing ||= !ok;
  console.log(`${ok ? 'FOUND' : 'MISSING'} ${label}: ${path}`);
}
const dir = resolve(root, 'build/client-web/bin');
const files = existsSync(dir) ? readdirSync(dir) : [];
for (const ext of ['.html', '.js', '.wasm', '.data']) {
  const matches = files.filter(f => f.endsWith(ext));
  console.log(`${matches.length ? 'FOUND' : 'MISSING'} browser ${ext}: ${matches.join(', ')}`);
  missing ||= !matches.length;
}
console.log('Checks establish file presence only. They do not verify login, rendering, ownership of assets, or gameplay.');
process.exitCode = missing ? 1 : 0;
