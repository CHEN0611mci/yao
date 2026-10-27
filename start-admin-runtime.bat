@echo off
setlocal
chcp 65001 >nul
cd /d "%~dp0"
echo Admin UI: http://127.0.0.1:80/  (dependencies and dist are prepared automatically on first run)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup\start-admin.ps1" %*
set "RC=%errorlevel%"
echo.
pause
exit /b %RC%
