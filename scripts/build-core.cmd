@echo off
rem Build the standalone C++ core (tmp/build/core-default). Pass-through args:
rem -Clean -Tests -Target <name> -Config <Debug|Release>
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0build-core.ps1" %*
exit /b %ERRORLEVEL%