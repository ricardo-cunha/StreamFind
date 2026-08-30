<#
    test-core.ps1 — run the C++ core test suite (CTest) against the build tree in
    tmp/build/core-default. Build first with build-core.ps1 (or with -Tests).

    Usage:
      powershell -ExecutionPolicy Bypass -File scripts\test-core.ps1
      powershell -ExecutionPolicy Bypass -File scripts\test-core.ps1 -Config Release
#>
param(
    [string]$Config = 'Debug',
    [switch]$IncludeReaderInterface
)

. "$PSScriptRoot\build-common.ps1"
Start-ScriptLog 'test-core'

$ctest    = Get-CTest
$buildDir = Join-Path $Script:TMP_BUILD 'core-default'
if (-not (Test-Path (Join-Path $buildDir 'build.ninja'))) {
    throw "No CMake build tree at $buildDir - run scripts\build-core.ps1 first."
}

Write-Log "ctest: $ctest"
Write-Log "ctest dir: $buildDir (config $Config)"
$ctestArgs = @('--test-dir', $buildDir, '-C', $Config, '--output-on-failure')
if (-not $IncludeReaderInterface) {
    Write-Log 'Excluding CTest label: reader-interface (use -IncludeReaderInterface to opt in).'
    $ctestArgs += @('-LE', 'reader-interface')
}
& $ctest @ctestArgs
if ($LASTEXITCODE -ne 0) { throw "CTest failed ($LASTEXITCODE)" }
Write-Log 'CTest passed.'