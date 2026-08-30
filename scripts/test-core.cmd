@echo off
rem Run the C++ core CTest suite. Pass-through args: -Config <Debug|Release> -IncludeReaderInterface
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0test-core.ps1" %*
exit /b %ERRORLEVEL%