<#
    test-rust.ps1 — run the Rust workspace test suite (builds into
    tmp/build/rust-target). Shorthand for build-rust.ps1 -Tests.

    Usage:
      powershell -ExecutionPolicy Bypass -File scripts\test-rust.ps1
      powershell -ExecutionPolicy Bypass -File scripts\test-rust.ps1 -Package streamfind-rust-mass-spec
      powershell -ExecutionPolicy Bypass -File scripts\test-rust.ps1 -Package streamfind-rust-mass-spec -IncludeReaderInterface
#>
param(
    [string]$Package = '',
    [switch]$Release,
    [switch]$IncludeReaderInterface
)

. "$PSScriptRoot\build-common.ps1"

$args = @()
if ($Package) { $args += @('-Package', $Package) }
if ($Release) { $args += '-Release' }
if ($IncludeReaderInterface) {
    if ($Package -ne 'streamfind-rust-mass-spec') {
        throw '-IncludeReaderInterface requires -Package streamfind-rust-mass-spec'
    }
    $args += @('-Features', 'reader-interface-tests')
}
& "$PSScriptRoot\build-rust.ps1" -Tests @args
exit $LASTEXITCODE