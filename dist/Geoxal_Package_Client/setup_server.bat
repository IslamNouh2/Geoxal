@echo off
setlocal
cd /d "%~dp0"

echo ==========================================================
echo    INSTALLATION ET CONFIGURATION AUTOMATIQUE GEOXAL
echo ==========================================================
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "setup_server.ps1"

echo.
pause
