@echo off
setlocal EnableExtensions
rem Run the Rust development-stage NTA/data MCP checks.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0test-nta.ps1" -Backend Rust %*
exit /b %ERRORLEVEL%
