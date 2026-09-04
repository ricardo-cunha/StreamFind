@echo off
setlocal EnableExtensions
rem Run the C++ development-stage NTA/data MCP checks.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0test-nta.ps1" -Backend Cpp %*
exit /b %ERRORLEVEL%
