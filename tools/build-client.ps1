param([ValidateSet('Release','Debug')][string]$Configuration = 'Release')
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$env:EMSDK = "$root/tools/emsdk"
$env:EMSDK_PYTHON = "$root/tools/emsdk/python/3.13.3_64bit/python.exe"
$env:EMSDK_NODE = "$root/tools/emsdk/node/24.19.0_64bit/node.exe"
$env:VCPKG_ROOT = "$root/tools/vcpkg"
$env:VCPKG_FORCE_SYSTEM_BINARIES = '1'
$env:VCPKG_KEEP_ENV_VARS = 'PATH'
$env:PATH = "$root/tools/python/cmake/data/bin;$root/tools/python/bin;$root/tools/vcpkg/downloads/tools/7zip-26.02-windows;$env:EMSDK/upstream/emscripten;$env:PATH"
$cmake = "$root/tools/python/cmake/data/bin/cmake.exe"
New-Item -ItemType Directory -Force "$root/logs" | Out-Null
& $cmake -G Ninja -S "$root/client" -B "$root/build/client-web" `
  -DWASM=ON "-DCMAKE_TOOLCHAIN_FILE=$env:VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake" `
  "-DVCPKG_CHAINLOAD_TOOLCHAIN_FILE=$env:EMSDK/upstream/emscripten/cmake/Modules/Platform/Emscripten.cmake" `
  -DVCPKG_TARGET_TRIPLET=wasm32-emscripten-pthread `
  "-DVCPKG_OVERLAY_TRIPLETS=$root/client/browser/triplets" `
  "-DVCPKG_OVERLAY_PORTS=$root/client/browser/overlay-ports" `
  -DWASM_USE_WASM_EXCEPTIONS=OFF -DOPTIONS_ENABLE_IPO=OFF -DTOGGLE_BIN_FOLDER=ON `
  "-DCMAKE_BUILD_TYPE=$Configuration" -DCMAKE_CXX_STANDARD=20 `
  '-DCMAKE_C_FLAGS=-pthread -matomics -mbulk-memory -fno-lto' `
  '-DCMAKE_CXX_FLAGS=-pthread -matomics -mbulk-memory -fno-lto -std=c++20' `
  -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=OFF 2>&1 | Tee-Object "$root/logs/client-configure.log"
if ($LASTEXITCODE -ne 0) { throw 'OTClient configuration failed; see logs/client-configure.log' }
# Emscripten emits otclient.data as a side output. Ninja does not track every
# file passed through --preload-file, so make the link dirty when bundled
# client resources changed after the last browser build.
$webOutput = "$root/build/client-web/bin/otclient.js"
$resourceRoots = @("$root/client/data", "$root/client/modules", "$root/client/mods", "$root/client/init.lua", "$root/client/otclientrc.lua")
$newestResource = Get-ChildItem $resourceRoots -Recurse -File | Measure-Object -Property LastWriteTime -Maximum | Select-Object -ExpandProperty Maximum
if (-not (Test-Path $webOutput) -or $newestResource -gt (Get-Item $webOutput).LastWriteTime) {
  & $cmake -E touch "$root/client/src/main.cpp"
}
& $cmake --build "$root/build/client-web" --target otclient --parallel 4 2>&1 | Tee-Object "$root/logs/client-build.log"
if ($LASTEXITCODE -ne 0) { throw 'OTClient build failed; see logs/client-build.log' }
