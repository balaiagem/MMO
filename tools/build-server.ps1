$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$cmake = "$root/tools/python/cmake/data/bin/cmake.exe"
New-Item -ItemType Directory -Force "$root/logs" | Out-Null
& $cmake -G 'Visual Studio 17 2022' -A x64 -S "$root/server" -B "$root/build/server-vs" `
  "-DCMAKE_TOOLCHAIN_FILE=$root/tools/vcpkg/scripts/buildsystems/vcpkg.cmake" `
  "-DVCPKG_INSTALLED_DIR=$root/build/server/vcpkg_installed" `
  -DDISABLE_STATS=ON -DENABLE_NATIVE_OPTIMIZATIONS=OFF -DBUILD_TESTING=ON `
  2>&1 | Tee-Object "$root/logs/server-configure.log"
if ($LASTEXITCODE -ne 0) { throw 'TFS configuration failed' }
& $cmake --build "$root/build/server-vs" --config Release --parallel 4 2>&1 | Tee-Object "$root/logs/server-build.log"
if ($LASTEXITCODE -ne 0) { throw 'TFS compilation failed' }
& "$root/tools/python/cmake/data/bin/ctest.exe" --test-dir "$root/build/server-vs" -C Release --output-on-failure `
  2>&1 | Tee-Object "$root/logs/server-tests.log"
if ($LASTEXITCODE -ne 0) { throw 'TFS tests failed' }
