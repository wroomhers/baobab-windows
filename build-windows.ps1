param(
    [string]$MsysRoot = 'C:\msys64',
    [switch]$SkipDependencies,
    [switch]$NoShortcut
)
$ErrorActionPreference = 'Stop'
$MsysRoot = [IO.Path]::GetFullPath($MsysRoot).TrimEnd('\')
if ($MsysRoot -notmatch '^[A-Za-z]:\\[\x20-\x7e]+$' -or $MsysRoot.Contains("'")) {
    throw 'MSYS2 must be installed at an ASCII drive path without apostrophes.'
}
$bash = Join-Path $MsysRoot 'usr\bin\bash.exe'
if (-not (Test-Path -LiteralPath $bash)) {
    throw "MSYS2 was not found at $MsysRoot. Install it from https://www.msys2.org/."
}
# Never reuse another checkout's sources, Meson cache, or runtime files.
$stageRoot = [IO.Path]::GetFullPath((Join-Path $MsysRoot 'tmp'))
$stage = Join-Path $stageRoot ('baobab-windows-' + [Guid]::NewGuid().ToString('N'))
New-Item -Path $stage -ItemType Directory | Out-Null
try {
    $sourceFiles = & git -C $PSScriptRoot -c core.quotepath=false ls-files --cached --others --exclude-standard
    if ($LASTEXITCODE -ne 0) { throw 'Run this script from a Git checkout with Git installed.' }
    foreach ($relative in $sourceFiles) {
        $sourceFile = Join-Path $PSScriptRoot $relative
        if (Test-Path -LiteralPath $sourceFile -PathType Leaf) {
            $destination = Join-Path $stage $relative
            New-Item -Path ([IO.Path]::GetDirectoryName($destination)) -ItemType Directory -Force | Out-Null
            Copy-Item -LiteralPath $sourceFile -Destination $destination
        }
    }
    (Get-Content -LiteralPath (Join-Path $PSScriptRoot 'build-windows.ini') -Raw).Replace('C:/msys64', $MsysRoot.Replace('\','/')) |
        Set-Content -LiteralPath (Join-Path $stage 'build-windows.ini') -Encoding ASCII
    $stageUnix = '/' + $stage.Substring(0,1).ToLower() + $stage.Substring(2).Replace('\','/')
    $packages = 'itstool python-lxml mingw-w64-ucrt-x86_64-python mingw-w64-ucrt-x86_64-python-lxml mingw-w64-ucrt-x86_64-clang mingw-w64-ucrt-x86_64-gcc mingw-w64-ucrt-x86_64-meson mingw-w64-ucrt-x86_64-ninja mingw-w64-ucrt-x86_64-pkgconf mingw-w64-ucrt-x86_64-gtk4 mingw-w64-ucrt-x86_64-libadwaita mingw-w64-ucrt-x86_64-gettext mingw-w64-ucrt-x86_64-vala'
    $install = if ($SkipDependencies) { ':' } else { "pacman -S --needed --noconfirm $packages" }
    $command = @"
set -e
export MSYSTEM=UCRT64
export PATH=/ucrt64/bin:/usr/bin:`$PATH
$install
cd '$stageUnix'
meson setup build --native-file build-windows.ini --buildtype=release --prefix=/ucrt64
meson compile -C build
"@
    $ErrorActionPreference = 'Continue'
    & $bash -lc $command
    $nativeExit = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    if ($nativeExit -ne 0) { throw "Windows build failed (exit $LASTEXITCODE)." }
    $packageStage = Join-Path $stage 'dist\Baobab'
    $ErrorActionPreference = 'Continue'
    & (Join-Path $MsysRoot 'ucrt64\bin\python.exe') (Join-Path $stage 'build-aux\package-windows.py') $stage (Join-Path $MsysRoot 'ucrt64') $packageStage
    $nativeExit = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    if ($nativeExit -ne 0) { throw "Windows packaging failed (exit $LASTEXITCODE)." }
    $testExe = Join-Path $packageStage 'bin\scanner-smoke.exe'
    Copy-Item -LiteralPath (Join-Path $stage 'build\tests\scanner-tests.exe') -Destination $testExe
    $savedPath = $env:PATH
    try {
        # Exercise the bundle without MSYS2 DLLs on PATH.
        $env:PATH = "$env:SystemRoot\System32;$env:SystemRoot"
        & $testExe
        if ($LASTEXITCODE -ne 0) { throw "Scanner regression tests failed (exit $LASTEXITCODE)." }
    } finally {
        $env:PATH = $savedPath
        [IO.File]::Delete($testExe)
    }
    $dist = Join-Path $PSScriptRoot 'dist'
    $output = Join-Path $dist 'Baobab'
    New-Item -Path $dist -ItemType Directory -Force | Out-Null
    $prepared = Join-Path $dist ('Baobab-new-' + [Guid]::NewGuid().ToString('N'))
    $previous = Join-Path $dist ('Baobab-previous-' + [Guid]::NewGuid().ToString('N'))
    # All directory moves stay inside the known staging or workspace parents.
    if ([IO.Path]::GetFullPath($packageStage) -ne (Join-Path $stage 'dist\Baobab')) {
        throw "Unexpected package staging path: $packageStage"
    }
    foreach ($publishPath in @($prepared, $output, $previous)) {
        if ([IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($publishPath)) -ne [IO.Path]::GetFullPath($dist)) {
            throw "Unexpected publication path: $publishPath"
        }
    }
    Move-Item -LiteralPath $packageStage -Destination $prepared
    # Keep the previous bundle intact if publishing fails (e.g. an open executable).
    $hadPrevious = Test-Path -LiteralPath $output
    if ($hadPrevious) { Move-Item -LiteralPath $output -Destination $previous }
    try {
        Move-Item -LiteralPath $prepared -Destination $output
    } catch {
        if ($hadPrevious) { Move-Item -LiteralPath $previous -Destination $output }
        throw
    }
    if ($hadPrevious) {
        Write-Host "Previous bundle retained at $previous; it can be removed when no longer needed."
    }
    if (-not $NoShortcut) {
        $shell = New-Object -ComObject WScript.Shell
        $shortcut = $shell.CreateShortcut((Join-Path ([Environment]::GetFolderPath('Desktop')) 'Baobab.lnk'))
        $shortcut.TargetPath = Join-Path $output 'bin\baobab.exe'
        $shortcut.WorkingDirectory = $output
        $shortcut.Description = 'Baobab Disk Usage Analyzer'
        $shortcut.Save()
    }
    Write-Host "Windows application ready: $output\bin\baobab.exe"
} finally {
    # Validate the absolute deletion target against the dedicated staging parent.
    $resolvedStage = [IO.Path]::GetFullPath($stage)
    if ([IO.Path]::GetDirectoryName($resolvedStage) -ne $stageRoot -or
        [IO.Path]::GetFileName($resolvedStage) -notmatch '^baobab-windows-[0-9a-f]{32}$') {
        throw "Refusing to remove unexpected staging path: $resolvedStage"
    }
    Remove-Item -LiteralPath $resolvedStage -Recurse -Force
}
