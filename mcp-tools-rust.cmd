@echo off
setlocal

set "SERVER=%~dp0rust\target\debug\streamfind-rust-mcp.exe"
if not exist "%SERVER%" (
    echo Rust MCP server not found: "%SERVER%" 1>&2
    echo Build it with: cargo build --manifest-path rust\Cargo.toml -p streamfind-rust-mcp 1>&2
    exit /b 1
)

echo {"jsonrpc":"2.0","id":1,"method":"tools/list"} | "%SERVER%"
if errorlevel 1 (
    echo Rust MCP server exited with error %errorlevel%. 1>&2
    exit /b %errorlevel%
)
