@echo off
chcp 65001 >nul
setlocal
title GKG-Syncthing - Cai dat Sync
cd /d "%~dp0"

if not exist "%~dp0install.ps1" (
    echo.
    echo [LOI] Khong tim thay install.ps1 trong thu muc nay.
    echo Dam bao ban giai nen day du bo cai GKG-Syncthing.
    echo.
    pause
    exit /b 1
)

echo.
echo ========================================
echo    GKG-SYNCTHING - BO CAI SYNC FILE
echo ========================================
echo.
echo Doc README.txt neu ban moi bat dau.
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" -Mode Syncthing %*
set ERR=%ERRORLEVEL%

echo.
if %ERR% neq 0 (
    echo [LOI] Cai dat that bai. Ma loi: %ERR%
) else (
    echo [OK] Hoan tat.
)
echo.
pause
exit /b %ERR%
