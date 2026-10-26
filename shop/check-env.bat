@echo off
setlocal
chcp 65001 >nul
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup\env-check.ps1" %*
set "RC=%errorlevel%"
echo.
pause
exit /b %RC%
