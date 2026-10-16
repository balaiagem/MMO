param([Parameter(Mandatory=$true)][string]$Python)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
Set-Location $root
$lock = Get-Content upstream-lock.json -Raw | ConvertFrom-Json
foreach ($name in @('client','server','vcpkg')) {
    $spec = $lock.$name
    $path = if ($name -eq 'vcpkg') { 'tools/vcpkg' } else { $name }
    if (!(Test-Path "$path/.git")) {
        git clone --filter=blob:none $spec.url $path
        if ($LASTEXITCODE -ne 0) { throw "Clone failed: $name" }
        git -C $path checkout $spec.commit
        if ($LASTEXITCODE -ne 0) { throw "Checkout failed: $name" }
    }
    $actual = git -C $path rev-parse HEAD
    if ($actual -ne $spec.commit) { throw "$path has a different revision; refusing to overwrite work" }
}
foreach ($name in @('client','server')) {
    $patch = "$root/patches/$name.patch"
    if (Test-Path $patch) {
        git -C $name apply --reverse --check $patch 2>$null
        if ($LASTEXITCODE -ne 0) {
            git -C $name apply --check $patch
            if ($LASTEXITCODE -ne 0) { throw "Patch conflicts in $name; preserving files" }
            git -C $name apply $patch
            if ($LASTEXITCODE -ne 0) { throw "Patch failed: $name" }
        }
    }
}
& $Python -m pip install --target tools/python cmake==4.4.4 ninja==1.13.2 lupa==2.8
if ($LASTEXITCODE -ne 0) { throw 'Python dependency installation failed' }
if (!(Test-Path tools/emsdk/.git)) { git clone https://github.com/emscripten-core/emsdk.git tools/emsdk }
& $Python tools/emsdk/emsdk.py install $lock.emscripten
if ($LASTEXITCODE -ne 0) { throw 'Emscripten installation failed' }
& $Python tools/emsdk/emsdk.py activate $lock.emscripten
if ($LASTEXITCODE -ne 0) { throw 'Emscripten activation failed' }
& tools/vcpkg/bootstrap-vcpkg.bat -disableMetrics
if ($LASTEXITCODE -ne 0) { throw 'vcpkg bootstrap failed' }
