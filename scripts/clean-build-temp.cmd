@echo off
setlocal EnableExtensions

rem Remove generated C++, Rust, and repository temporary output.
rem Run from any working directory; the repository root is derived from this file.

set "ROOT=%~dp0.."

call :remove_dir "%ROOT%\build" "root CMake/build output"
call :remove_dir "%ROOT%\core\build" "standalone C++ core build output"
call :remove_dir "%ROOT%\core\vendor\openbabel\build" "vendored OpenBabel build output"
call :remove_dir "%ROOT%\rust\target" "Rust target output"
call :remove_dir "%ROOT%\integrations\cf-streamfind\build" "Cogniflow integration build output"
call :remove_dir "%ROOT%\dist" "distribution output"
call :remove_dir "%ROOT%\site" "documentation site output"
call :remove_dir "%ROOT%\_skbuild" "scikit-build output"
call :remove_dir "%ROOT%\log" "repository logs"
call :remove_dir "%ROOT%\cache" "repository cache"
call :remove_dir "%ROOT%\tmp" "repository temporary output"

for /d %%D in ("%ROOT%\cmake-build-*") do (
    if exist "%%~fD\" call :remove_dir "%%~fD" "CMake build directory"
)

rem Python environments and their caches are intentionally left untouched.

if errorlevel 1 (
    echo Cleanup completed with errors. 1>&2
    exit /b 1
)

echo Generated build and temporary output removed.
exit /b 0

:remove_dir
if not exist "%~1\" exit /b 0
echo Removing %~2: "%~1"
rd /s /q "%~1"
exit /b %errorlevel%
