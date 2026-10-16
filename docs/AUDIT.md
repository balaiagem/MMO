# Repository audit

Exact source revisions are in ../upstream-lock.json. Sources were cloned and inspected, not inferred from repository names.

| Area | Verified in source | Implication |
|---|---|---|
| Browser client | client/Dockerfile.browser; src/CMakeLists.txt WASM branch; browser overlays | Genuine C++ WebAssembly target; retain it. Upstream Dockerfile uses floating SDK `latest`; local build pins 4.0.23. |
| Transport | src/framework/net/webconnection.cpp | Binary WebSocket subprotocol `binary`; two independent login/game sockets. Gateway must preserve byte streams, not parse JSON. |
| Browser constraints | WASM link flags | WebGL2, workers, pthreads, fixed 1 GiB heap, COOP/COEP needed. No measured FPS or memory-use claim. |
| Graphics | ThingType, SpriteManager, MapView C++ classes | DAT/SPR tile assets for 8.60; Lua/OTUI modules define interface. No replacement renderer. |
| Client features | modules/game_features/features.lua | 860 enables XTEA login, checksums, challenge login, account names, attack sequence. |
| Selected server | src/definitions.h, protocollogin.cpp, protocolgame.cpp | Exactly 860 accepted. RSA, XTEA, 12 signature bytes, native login/game services. End-to-end compatibility still requires execution. |
| Alternative | otland/forgottenserver master/src/definitions.h (remote inspection) | Current source accepts 1310–1311; not chosen for 860 baseline. |
| Server dependencies | server/CMakeLists.txt and vcpkg.json | C++23, OpenSSL 3, Lua 5.5 default (LuaJIT alternative), MariaDB client, asio, abseil, fmt, spdlog, pugixml, simdutf, mio, zlib. |
| Server extensions | data/scripts and src/events.cpp | RevScriptSys, CreatureEvent onHealthChange, combat callbacks, Lua spells. Health callbacks alone are insufficient to replace native mitigation/action timing correctly. |
| Persistence | schema.sql, src/iologindata.cpp, player.h | Existing accounts/players/items database schema. D&D tables not yet added. |
| Assets | client/data/things contains no DAT/SPR | Missing licensed game atlas is a playability blocker. Default third-party asset auto-download disabled. Strict hashes and standard paths preserved. |
| Licensing | client/LICENSE; server/LICENSE | Client MIT, server GPL-2.0. Source licenses do not establish rights to every upstream artwork/map. Do not redistribute the upstream world or proprietary atlas without provenance. |

Local patches address Windows vcpkg environment sanitization, per-socket browser teardown, page-scheme selection, local gateway configuration and disabling automatic third-party game asset downloads. None establishes full protocol compatibility on its own.

Original code/source findings take precedence over old tutorials. Browser transport follows the architecture described by [Emscripten networking](https://emscripten.org/docs/porting/networking.html). The [alternative server definitions](https://github.com/otland/forgottenserver/blob/master/src/definitions.h) were inspected separately. Rules target the [CC SRD 5.1](https://media.dndbeyond.com/compendium-images/srd/5.1/SRD_CC_v5.1.pdf), not the newer SRD 5.2.
