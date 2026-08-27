<#
    test-rust.ps1 — run the Rust workspace test suite (builds into
    tmp/build/rust-target). Shorthand for build-rust.ps1 -Tests.

    Usage:
      powershell -ExecutionPolicy Bypass -File scripts\test-rust.ps1
      powershell -ExecutionPolicy Bypass -File scripts\test-rust.ps1 -Package streamfind-rust-mass-spec
#>
param(
    [string]$Package = '',
    [switch]$Release
)

. "$PSScriptRoot\build-common.ps1"

$args = @()
if ($Package) { $args += @('-Package', $Package) }
if ($Release) { $args += '-Release' }
& "$PSScriptRoot\build-rust.ps1" -Tests @args
exit $LASTEXITCODE