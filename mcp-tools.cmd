@echo off
setlocal

set "SERVER=%~dp0build\cmake\default\core\Debug\streamfind_mcp.exe"
if not exist "%SERVER%" (
    echo C++ MCP server not found: "%SERVER%" 1>&2
    echo Build it with: cmake --build --preset default --config Debug 1>&2
    exit /b 1
)

echo {"jsonrpc":"2.0","id":1,"method":"tools/list"} | "%SERVER%"
if errorlevel 1 (
    echo C++ MCP server exited with error %errorlevel%. 1>&2
    exit /b %errorlevel%
)
