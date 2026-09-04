[CmdletBinding()]
param(
    [ValidateSet('Cpp', 'Rust')]
    [string]$Backend = 'Cpp',
    [ValidateSet('Shimadzu', 'Sciex', 'AgilentChemstation', 'AgilentMassHunter', 'Thermo')]
    [string]$Vendor = 'Shimadzu',
    [string]$InputPath = '',
    [switch]$SkipBuild
)

. (Join-Path $PSScriptRoot 'mcp-common.ps1')
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$vendorRoot = Get-StreamfindVendorRoot

if (-not $InputPath) {
    switch ($Vendor) {
        'Shimadzu' {
            $InputPath = Join-Path $vendorRoot 'shimadzu\karl.lcd'
        }
        'Sciex' {
            $InputPath = (Get-ChildItem -LiteralPath (Join-Path $vendorRoot 'sciex') -Recurse -File -Filter '*.wiff' | Select-Object -First 1).FullName
        }
        'AgilentChemstation' {
            $InputPath = (Get-ChildItem -LiteralPath (Join-Path $vendorRoot 'agilent_chemstation') -Recurse -Directory -Filter '*.D' | Select-Object -First 1).FullName
        }
        'AgilentMassHunter' {
            $InputPath = (Get-ChildItem -LiteralPath (Join-Path $vendorRoot 'agilent_mass_hunter') -Recurse -Directory -Filter '*.d' | Select-Object -First 1).FullName
        }
        'Thermo' {
            $InputPath = (Get-ChildItem -LiteralPath (Join-Path $vendorRoot 'thermo') -Recurse -File -Filter '*.raw' | Select-Object -First 1).FullName
        }
    }
}
if ([string]::IsNullOrWhiteSpace($InputPath) -or -not (Test-Path $InputPath)) {
    throw "No $Vendor fixture was found under $vendorRoot"
}
$InputPath = (Resolve-Path $InputPath).Path

if (-not $SkipBuild) {
    if ($Backend -eq 'Cpp') {
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repoRoot 'scripts\build\build-core.ps1') -Clean -Config Release
        if ($LASTEXITCODE -ne 0) { throw "C++ build failed ($LASTEXITCODE)" }
    } else {
        $buildExitCode = Invoke-StreamfindRustBuild $repoRoot
        if ($buildExitCode -ne 0) { throw "Rust build failed ($buildExitCode)" }
    }
}

$executable = Get-BackendMcpExecutable -RepositoryRoot $repoRoot -Backend $Backend
$catalogue = Join-Path $repoRoot 'semantic\generated\catalogue.duckdb'
$database = Join-Path $repoRoot "tmp\projects\streamfind-$($Backend.ToLowerInvariant())-$($Vendor.ToLowerInvariant())-reader-script.duckdb"
$projectId = "reader-$($Backend.ToLowerInvariant())-$($Vendor.ToLowerInvariant())"
New-Item -ItemType Directory -Force -Path (Split-Path $database -Parent) | Out-Null
Remove-Item -Force -ErrorAction SilentlyContinue $database
$env:STREAMFIND_CATALOGUE = $catalogue
if ($Backend -eq 'Cpp') {
    $env:PATH = (Join-Path $repoRoot 'tmp\build\core-default\tests') + ';' + $env:PATH
}

$process = Start-StreamfindMcp -Executable $executable -Catalogue $catalogue
try {
    Initialize-Mcp $process | Out-Null
    Invoke-McpTool $process 2 'create' @{
        database_path = $database
        project_id = $projectId
        domain = 'mass_spec'
    } | Out-Null
    $added = Invoke-McpTool $process 3 'mass_spec.add_analyses' @{
        database_path = $database
        project_id = $projectId
        analyses = @(@{ path = $InputPath })
    }
    if ([int]$added.row_count -ne 1) {
        throw "Expected one parsed $Vendor analysis, received $($added.row_count)"
    }
    $info = Invoke-McpTool $process 4 'mass_spec.get_analyses_info' @{
        database_path = $database
        project_id = $projectId
    }
    if ([int]$info.row_count -ne 1) {
        throw "Expected one persisted $Vendor analysis, received $($info.row_count)"
    }
    Write-Host "$Backend $Vendor reader test passed: $InputPath"
} finally {
    Stop-StreamfindMcp $process
    Remove-Item -Force -ErrorAction SilentlyContinue $database
}
