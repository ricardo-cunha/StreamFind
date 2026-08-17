@echo off
setlocal

set "SERVER=%~dp0build\cmake\default\core\Debug\streamfind_mcp.exe"
if not exist "%SERVER%" (
    echo C++ MCP server not found: "%SERVER%" 1>&2
    echo Build it with: cmake --build --preset default --config Debug 1>&2
    exit /b 1
)

set "TEMP_DIR=%~dp0tmp\mcp-wastewater"
set "CSV=%~dp0tests\data\mass_spec\wastewater\internal_standards.csv"
set "ANALYSIS_1=%~dp0tests\data\mass_spec\wastewater\01_tof_ww_is_pos_blank-r001.mzML"
set "ANALYSIS_2=%~dp0tests\data\mass_spec\wastewater\01_tof_ww_is_pos_blank-r002.mzML"
set "ANALYSIS_3=%~dp0tests\data\mass_spec\wastewater\01_tof_ww_is_pos_blank-r003.mzML"
set "DATABASE=%TEMP_DIR%\wastewater.duckdb"
set "REQUESTS=%TEMP_DIR%\requests.json"
set "RESPONSES=%TEMP_DIR%\responses.jsonl"
set "OUTPUT=%TEMP_DIR%\internal_standard_eics.json"
set "PROJECT_ID=wastewater_internal_standards"

if not exist "%TEMP_DIR%" mkdir "%TEMP_DIR%"
if errorlevel 1 exit /b 1

powershell -NoProfile -ExecutionPolicy Bypass -Command "$rows = Import-Csv -LiteralPath $env:CSV | Where-Object { $_.mass -and $_.rt }; $names = @([IO.Path]::GetFileNameWithoutExtension($env:ANALYSIS_1), [IO.Path]::GetFileNameWithoutExtension($env:ANALYSIS_2), [IO.Path]::GetFileNameWithoutExtension($env:ANALYSIS_3)); $targets = @($rows | ForEach-Object { [ordered]@{ id = $_.name; mass = [double]$_.mass; rt = [double]$_.rt; analyses = $names } }); $requests = @([ordered]@{ jsonrpc = '2.0'; id = 1; method = 'tools/call'; params = [ordered]@{ name = 'create'; arguments = [ordered]@{ database_path = $env:DATABASE; project_id = $env:PROJECT_ID; domain = 'mass_spec' } } }, [ordered]@{ jsonrpc = '2.0'; id = 2; method = 'tools/call'; params = [ordered]@{ name = 'mass_spec.add_analyses'; arguments = [ordered]@{ database_path = $env:DATABASE; project_id = $env:PROJECT_ID; analyses = @([ordered]@{ path = $env:ANALYSIS_1 }, [ordered]@{ path = $env:ANALYSIS_2 }, [ordered]@{ path = $env:ANALYSIS_3 }) } } }, [ordered]@{ jsonrpc = '2.0'; id = 3; method = 'tools/call'; params = [ordered]@{ name = 'mass_spec.get_raw_spectra_eic'; arguments = [ordered]@{ database_path = $env:DATABASE; project_id = $env:PROJECT_ID; analysis_names = $names; levels = @(1); targets = $targets; ppm = 20.0; rt_tolerance = 60.0 } } }); $json = (($requests | ForEach-Object { $_ | ConvertTo-Json -Compress -Depth 20 }) -join [Environment]::NewLine); [IO.File]::WriteAllText($env:REQUESTS, $json, (New-Object Text.UTF8Encoding($false)))"
if errorlevel 1 exit /b 1

type "%REQUESTS%" | "%SERVER%" > "%RESPONSES%"
if errorlevel 1 (
    echo C++ MCP server exited with error %errorlevel%. 1>&2
    exit /b %errorlevel%
)

powershell -NoProfile -ExecutionPolicy Bypass -Command "$responses = @(Get-Content -LiteralPath $env:RESPONSES | Where-Object { $_.Trim() } | ForEach-Object { $_ | ConvertFrom-Json }); $responses | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath ($env:RESPONSES -replace '\.jsonl$','.json') -Encoding UTF8; $responses[-1] | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $env:OUTPUT -Encoding UTF8"
if errorlevel 1 exit /b 1

echo EIC response saved to "%OUTPUT%"
type "%OUTPUT%"
