<#
    test-rust.ps1 — run the Rust workspace test suite (builds into
    tmp/build/rust-target). Shorthand for build\build-rust.ps1 -Tests.

    Usage:
      powershell -ExecutionPolicy Bypass -File scripts\build\test-rust.ps1
      powershell -ExecutionPolicy Bypass -File scripts\build\test-rust.ps1 -Package streamfind-rust-mass-spec
#>
param(
    [string]$Package = '',
    [switch]$Release
)

. "$PSScriptRoot\build-common.ps1"

$buildParameters = @{ Tests = $true }
if ($Package) { $buildParameters.Package = $Package }
if ($Release) { $buildParameters.Release = $true }
& "$PSScriptRoot\build-rust.ps1" @buildParameters
exit $LASTEXITCODE