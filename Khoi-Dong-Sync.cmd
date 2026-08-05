@echo off
chcp 65001 >nul
setlocal
title GKG-Syncthing - Khoi dong Sync
cd /d "%~dp0"

if not exist "%~dp0khoi-dong-sync.ps1" (
    echo [LOI] Khong tim thay khoi-dong-sync.ps1
    pause
    exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0khoi-dong-sync.ps1"
echo.
pause
exit /b %ERRORLEVEL%
