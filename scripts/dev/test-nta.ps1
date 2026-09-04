[CmdletBinding()]
param(
    [ValidateSet('Cpp', 'Rust')]
    [string]$Backend = 'Cpp',
    [switch]$RunPipeline,
    [switch]$SkipBuild
)

. (Join-Path $PSScriptRoot 'mcp-common.ps1')
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$dataRoot = Get-StreamfindDataRoot $repoRoot
$wastewater = Join-Path $dataRoot 'mass_spec\wastewater'
$files = @(
    (Join-Path $wastewater '01_tof_ww_is_pos_blank-r001.mzML'),
    (Join-Path $wastewater '01_tof_ww_is_pos_blank-r002.mzML'),
    (Join-Path $wastewater '01_tof_ww_is_pos_blank-r003.mzML')
)
foreach ($file in $files) {
    if (-not (Test-Path $file -PathType Leaf)) {
        throw "Required NTA test data file not found: $file"
    }
}

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
$database = Join-Path $repoRoot "tmp\projects\streamfind-$($Backend.ToLowerInvariant())-nta-script.duckdb"
$projectId = "nta-$($Backend.ToLowerInvariant())"
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
        analyses = @($files | ForEach-Object { @{ path = $_ } })
    }
    if ([int]$added.row_count -ne 3) {
        throw "Expected three wastewater analyses, received $($added.row_count)"
    }
    Invoke-McpTool $process 4 'connect' @{
        database_path = $database
        project_id = $projectId
    } | Out-Null
    $methods = Invoke-McpTool $process 5 'get_available_methods' @{ domain = 'mass_spec' }
    if (-not (@($methods | Where-Object { $_.id -eq 'mass_spec.find_features' }))) {
        throw 'mass_spec.find_features was not discovered as an available workflow method'
    }

    if ($RunPipeline) {
        $analysisNames = @($files | ForEach-Object { [System.IO.Path]::GetFileNameWithoutExtension($_) })
        $parameters = @{
            analysis_names = $analysisNames
            rt_windows_min = @(800.0)
            rt_windows_max = @(1000.0)
            ppm_threshold = 12.0
            noise_threshold = 500.0
            min_snr = 15.0
            min_traces = 5
            baseline_window = 30.0
            max_feature_width = 60.0
            base_quantile = 0.1
        }
        $result = Invoke-McpTool $process 6 'run_method' @{
            database_path = $database
            project_id = $projectId
            method = 'mass_spec.find_features'
            parameters = $parameters
        }
        if ($null -eq $result) { throw 'NTA method returned no result' }
        Write-Host "$Backend NTA pipeline completed."
    } else {
        Write-Host "$Backend NTA data setup and method discovery passed; pipeline not requested."
    }
} finally {
    Stop-StreamfindMcp $process
    Remove-Item -Force -ErrorAction SilentlyContinue $database
}
