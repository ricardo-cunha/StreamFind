@echo off
rem Run the Rust workspace test suite. Pass-through args: -Package <name> -Release -IncludeReaderInterface
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0test-rust.ps1" %*
exit /b %ERRORLEVEL%