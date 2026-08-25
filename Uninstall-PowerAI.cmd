@echo off
REM Uninstall-PowerAI.cmd - Desinstalador Local para Windows (PowerShell e CMD)
setlocal enabledelayedexpansion

echo ==========================================================
echo  [PowerAI] Desinstalador Local para Windows (PowerShell e CMD)
echo ==========================================================
echo.

set "CURRENT_DIR=%~dp0"
if exist "%CURRENT_DIR%uninstall.ps1" (
    powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%CURRENT_DIR%uninstall.ps1"
) else (
    powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/Luizhcrs/nuno/main/uninstall.ps1 | iex"
)

echo.
pause
