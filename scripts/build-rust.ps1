<#
    build-rust.ps1 — build the Rust workspace (rust/) into tmp/build/rust-target.

    Usage:
      powershell -ExecutionPolicy Bypass -File scripts\build-rust.ps1
      powershell -ExecutionPolicy Bypass -File scripts\build-rust.ps1 -Clean
      powershell -ExecutionPolicy Bypass -File scripts\build-rust.ps1 -Tests
      powershell -ExecutionPolicy Bypass -File scripts\build-rust.ps1 -Package streamfind-rust-mass-spec

    Flags:
      -Clean    wipe the cargo target dir first
      -Tests    also run cargo test (all targets)
      -Package  build/test a single workspace package (default: all)
      -Release  use the release profile (default: debug)
#>
param(
    [switch]$Clean,
    [switch]$Tests,
    [string]$Package = '',
    [switch]$Release
)

. "$PSScriptRoot\build-common.ps1"
Start-ScriptLog 'build-rust'

$cargo     = Get-Cargo
$targetDir = Join-Path $Script:TMP_BUILD 'rust-target'
$workspace = Join-Path $Script:REPO_ROOT 'rust'

if (-not (Test-Path (Join-Path $workspace 'Cargo.toml'))) {
    throw "Rust workspace not found at $workspace"
}

# Centralize cargo artifacts under tmp/ (AGENTS.md) regardless of .cargo config.
$env:CARGO_TARGET_DIR = $targetDir

if ($Clean -and (Test-Path $targetDir)) {
    Write-Log "Cleaning cargo target dir: $targetDir"
    Remove-Item -Recurse -Force $targetDir
}

$manifest = Join-Path $workspace 'Cargo.toml'

if ($Tests) {
    $testArgs = @('test', '--manifest-path', $manifest)
    if ($Package)  { $testArgs += @('-p', $Package) }
    if ($Release)  { $testArgs += '--release' }
    Write-Log "cargo $($testArgs -join ' ')"
    & $cargo @testArgs
    if ($LASTEXITCODE -ne 0) { throw "cargo test failed ($LASTEXITCODE)" }
} else {
    $buildArgs = @('build', '--manifest-path', $manifest)
    if ($Package)  { $buildArgs += @('-p', $Package) }
    if ($Release)  { $buildArgs += '--release' }
    Write-Log "cargo $($buildArgs -join ' ')"
    & $cargo @buildArgs
    if ($LASTEXITCODE -ne 0) { throw "cargo build failed ($LASTEXITCODE)" }
}

Write-Log "Done. Target dir: $targetDir"